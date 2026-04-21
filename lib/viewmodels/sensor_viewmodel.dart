import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/services/usb/usb_service.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/logger.dart';
import 'package:sensdroid/core/app_settings.dart';
import 'package:sensdroid/utils/sensor_detector.dart';

/// ViewModel for managing sensor data streaming and USB serial transmission.
///
/// Key performance design decisions:
/// - Sensor callbacks write to a pre-allocated fixed-size ring buffer
///   (no heap allocation per sample during hot path).
/// - The sampling timer drains the ring buffer in a single batch write —
///   no mutex/isFlushing flag needed because the timer is the *only* consumer.
/// - notifyListeners() is rate-limited to once per UI_NOTIFY_INTERVAL_MS so
///   the widget tree never rebuilds faster than the display refresh rate.
/// - retryWithBackoff is removed from the send path; a single fire-and-forget
///   write is used. USB CDC will queue internally — retrying only adds delay.
class SensorViewModel extends ChangeNotifier {
  // ── configuration ──────────────────────────────────────────────────────────
  static const int _uiNotifyIntervalMs = 80; // ~12 Hz UI refresh
  static const int _ringCap = 64; // ring buffer capacity (power-of-2)
  // Batch size: how many packets to drain per timer tick.
  // 0 = drain every packet immediately (no timer batching).
  static const int _maxBatchPerTick = 16;

  // ── infrastructure ─────────────────────────────────────────────────────────
  late final Logger _logger;
  AppSettings? _settings;
  bool _isDisposed = false;
  final bool _autoDetectSensors;

  late final USBService _usbService;
  CommunicationService? _activeService;

  // ── connection state ───────────────────────────────────────────────────────
  final String _activeProtocol = AppConstants.protocolUSB;
  bool _isConnecting = false;

  // ── transmission state ─────────────────────────────────────────────────────
  bool _useSensorFusionMode = false; // YPR instead of Raw Accel/Gyro/Mag
  bool _isTransmitting = false;
  String? _lastError;
  int _packetsSent = 0;
  int _packetsDropped = 0;
  DateTime? _transmissionStartTime;

  // ── ring buffer (lock-free single-producer/single-consumer) ────────────────
  // Producer: sensor event isolate (Dart event loop callbacks)
  // Consumer: _samplingTimer periodic callback
  // Both run on the same isolate so no true concurrency — but we still use an
  // index-based ring to avoid List.removeRange() which is O(n).
  final List<SensorData?> _ring = List<SensorData?>.filled(_ringCap, null);
  int _ringHead = 0; // consumer reads from here
  int _ringTail = 0; // producer writes here
  int _ringDropped = 0; // count of drops due to ring full

  // ── sampling timer ─────────────────────────────────────────────────────────
  Timer? _samplingTimer;

  // ── UI notify rate-limit ────────────────────────────────────────────────────
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── sensor availability ────────────────────────────────────────────────────
  bool _isSensorDetectionComplete = false;
  final Map<String, bool> _availableSensors = {};
  final Map<String, bool> _enabledSensors = {
    AppConstants.sensorAccelerometer: true,
    AppConstants.sensorGyroscope: true,
    AppConstants.sensorMagnetometer: true,
    AppConstants.sensorGPS: false,
  };

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  // ── Complementary Filter YPR fusion state ─────────────────────────────────
  // Raw sensor readings
  double _lastAx = 0.0, _lastAy = 0.0, _lastAz = 9.81;
  double _lastGx = 0.0, _lastGy = 0.0, _lastGz = 0.0;
  double _lastMx = 0.0, _lastMy = 0.0, _lastMz = 0.0;
  // Filtered angles (radians)
  double _fusedPitch = 0.0, _fusedRoll = 0.0, _fusedYaw = 0.0;
  // YPR zero offsets — subtracted from fused angles before emitting to UI/serial.
  // Set via zeroYpr(); reset via zeroYpr(reset: true).
  double _yprOffsetYaw = 0.0, _yprOffsetPitch = 0.0, _yprOffsetRoll = 0.0;
  bool get isYprZeroed =>
      _yprOffsetYaw != 0.0 || _yprOffsetPitch != 0.0 || _yprOffsetRoll != 0.0;
  // Monotonic fusion clock for dt calculation (prevents wall-clock jumps).
  final Stopwatch _fusionClock = Stopwatch()..start();
  int? _lastFusionMicros;
  // Alpha: higher value gives faster gyro response; lower = faster accel correction.
  // 0.98 = slight lag correction every ~50 samples (~250ms at 200Hz)
  static const double _cfAlpha = 0.98;
  // Yaw correction gain. 0.97 corrects mag error at ~3% per sample = well-balanced.
  // (was 0.995 which was too slow — yaw took >5s to correct)
  static const double _yawAlpha = 0.97;
  // Magnetometer low-pass: 0.7 = fast enough to track heading changes smoothly.
  static const double _magAlpha = 0.70;
  double _smoothMagX = 0.0, _smoothMagY = 0.0;

  // UI stream for fused orientation (radians). Async broadcast prevents the
  // sensor callback from blocking while downstream UI listeners run.
  static const int _yprUiIntervalMs = 33; // ~30 Hz — smooth & efficient
  int _lastYprUiEmitMicros = 0;
  final StreamController<({double yaw, double pitch, double roll})>
  _fusedOrientationCtrl =
      StreamController<({double yaw, double pitch, double roll})>.broadcast();
  Stream<({double yaw, double pitch, double roll})> get fusedOrientationStream =>
      _fusedOrientationCtrl.stream;

  // Fusion preview lets UI consume fused YPR even when not transmitting.
  int _fusionPreviewClients = 0;
  StreamSubscription<Position>? _gpsSub;

  // ── pre-allocated reusable write buffer ────────────────────────────────────
  // Avoids per-flush BytesBuilder allocation on hot path.
  final BytesBuilder _writeBuffer = BytesBuilder(copy: false);

  // ── constructor ────────────────────────────────────────────────────────────
  SensorViewModel({bool autoDetectSensors = true})
    : _autoDetectSensors = autoDetectSensors {
    _logger = AppLogger.getLogger(runtimeType.toString());
    _usbService = USBService();
    _activeService = _usbService;
    _initialize();
  }

  // ── public getters ─────────────────────────────────────────────────────────
  AppSettings? get settings => _settings;
  int get usbBaudRate => _usbService.baudRate;
  int get minUsbBaudRate => AppConstants.usbMinBaudRate;
  int get maxUsbBaudRate => AppConstants.usbMaxBaudRate;
  List<int> get usbBaudRatePresets => _usbService.supportedBaudRates;
  String get activeProtocol => _activeProtocol;
  ConnectionInfo? get connectionInfo => _activeService?.connectionInfo;
  bool get isConnected => _activeService?.isConnected ?? false;
  bool get isConnecting => _isConnecting;
  bool get isTransmitting => _isTransmitting;
  String? get lastError => _lastError;
  int get packetsSent => _packetsSent;
  int get packetsDropped => _packetsDropped + _ringDropped;

  // Auto-calculated optimal sampling rate based on baud rate and active sensors.
  int get samplingRate {
    final rate = recommendedMinSamplingRate;
    return rate == 0 ? AppConstants.sensorUpdateFast : (rate < 10 ? 10 : rate);
  }

  bool get useSensorFusionMode => _useSensorFusionMode;
  Map<String, bool> get enabledSensors => Map.unmodifiable(_enabledSensors);
  Map<String, bool> get availableSensors => Map.unmodifiable(_availableSensors);
  bool get isSensorDetectionComplete => _isSensorDetectionComplete;

  int get recommendedMinSamplingRate {
    int numSensors;
    if (_useSensorFusionMode) {
      numSensors = 1; // YPR is bundled into a single sensor reading
    } else {
      numSensors = _enabledSensors.values.where((v) => v).length;
    }
    if (numSensors == 0) return 0; // No sensors, no limit

    // ~26 bytes per typical packet
    int bytesPerTick = numSensors * 26;

    // usbBaudRate / 10 is roughly bytes/sec (8 data, 1 start, 1 stop bit)
    double bytesPerSec = usbBaudRate / 10.0;
    if (bytesPerSec <= 0) return 100;

    // minimum MS required to transmit the packet
    double minMs = (bytesPerTick / bytesPerSec) * 1000.0;

    // Add 15% safety margin to account for framing and OS overhead
    // We cap to minimum 1ms, but no upper limit.
    int finalRate = (minMs * 1.15).ceil();
    return finalRate < 1 ? 1 : finalRate;
  }

  Duration? get transmissionDuration => _transmissionStartTime != null
      ? DateTime.now().difference(_transmissionStartTime!)
      : null;

  double get transmissionRate {
    final dur = transmissionDuration;
    if (dur == null || dur.inMilliseconds == 0) return 0.0;
    return _packetsSent / (dur.inMilliseconds / 1000.0);
  }

  // ── settings API ───────────────────────────────────────────────────────────
  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    _usbService.setBaudRate(newSettings.usbBaudRate);
    _throttledNotify();
    _logger.info('Settings updated: ${newSettings.toMap()}');
  }

  Future<bool> updateUsbBaudRate(
    int baudRate, {
    bool reconnectIfConnected = false,
  }) async {
    if (!_usbService.setBaudRate(baudRate)) {
      _lastError = AppConstants.errorInvalidUSBBaudRate;
      _throttledNotify();
      return false;
    }
    _settings?.usbBaudRate = baudRate;
    _lastError = null;

    if (isConnected && reconnectIfConnected) {
      final currentAddress = connectionInfo?.address;
      await disconnect();
      if (currentAddress != null && currentAddress.isNotEmpty) {
        final ok = await connect(currentAddress);
        _throttledNotify();
        return ok;
      }
    }
    _throttledNotify();
    return true;
  }

  // ── sensor toggle ──────────────────────────────────────────────────────────
  void toggleSensorFusionMode(bool value) {
    _useSensorFusionMode = value;
    if (_isTransmitting || _fusionPreviewClients > 0) {
      _stopSensorListeners();
      if (_isTransmitting || (_fusionPreviewClients > 0 && _useSensorFusionMode)) {
        _resetFusionTiming();
        _startSensorListeners();
      }
    }
    _throttledNotify();
  }

  void toggleSensor(String sensorType, bool enabled) {
    if (enabled && !(_availableSensors[sensorType] ?? false)) return;
    _enabledSensors[sensorType] = enabled;
    if (_isTransmitting) {
      _stopSensorListeners();
      _startSensorListeners();
    }
    _throttledNotify();
  }

  /// Start YPR fusion preview (for UI) without starting USB transmission.
  /// Safe to call multiple times; internally reference-counted.
  void startFusionPreview() {
    _fusionPreviewClients++;
    if (_fusionPreviewClients == 1) {
      if (!_isTransmitting && _useSensorFusionMode) {
        _stopSensorListeners();
        _resetFusionTiming();
        _startSensorListeners();
      }
    }
  }

  /// Stop YPR fusion preview (for UI). When no preview clients remain and
  /// transmission is not active, sensor listeners are stopped to save CPU.
  void stopFusionPreview() {
    if (_fusionPreviewClients == 0) return;
    _fusionPreviewClients--;
    if (_fusionPreviewClients == 0 && !_isTransmitting) {
      _stopSensorListeners();
    }
  }

  void clearError() {
    _lastError = null;
    _throttledNotify();
  }

  /// Zero the YPR axes: stores the current fused orientation as the reference
  /// point. All subsequent emitted values will be relative to this snapshot.
  /// Call with [reset] = true to clear offsets and return to absolute values.
  void zeroYpr({bool reset = false}) {
    if (reset) {
      _yprOffsetYaw   = 0.0;
      _yprOffsetPitch = 0.0;
      _yprOffsetRoll  = 0.0;
    } else {
      _yprOffsetYaw   = _fusedYaw;
      _yprOffsetPitch = _fusedPitch;
      _yprOffsetRoll  = _fusedRoll;
    }
    _throttledNotify(); // let UI show the zeroed/reset badge
  }

  // ── connection ─────────────────────────────────────────────────────────────
  Future<List<String>> scanDevices() async =>
      await _activeService?.scan() ?? [];

  Future<bool> connect(String address) async {
    _isConnecting = true;
    _lastError = null;
    _throttledNotify();
    try {
      final configuredBaud = _settings?.usbBaudRate ?? _usbService.baudRate;
      _usbService.setBaudRate(configuredBaud);
      final success = await _activeService?.connect(address) ?? false;
      if (!success) _lastError = 'Failed to connect to $address';
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isConnecting = false;
      _throttledNotify();
    }
  }

  Future<void> disconnect() async {
    if (_isTransmitting) await stopTransmission();
    await _activeService?.disconnect();
    _throttledNotify();
  }

  // ── transmission ───────────────────────────────────────────────────────────
  Future<void> startTransmission() async {
    if (!isConnected) {
      _lastError = 'Not connected to any USB device';
      _throttledNotify();
      throw Exception(_lastError);
    }
    if (_isTransmitting) return;

    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      _lastError = AppConstants.errorPermissionDenied;
      _throttledNotify();
      throw Exception(_lastError);
    }

    _isTransmitting = true;
    _packetsSent = 0;
    _packetsDropped = 0;
    _ringDropped = 0;
    _transmissionStartTime = DateTime.now();
    _ringHead = 0;
    _ringTail = 0;

    // Ensure we never run duplicate listeners (e.g. if fusion preview is active).
    _stopSensorListeners();
    _resetFusionTiming();

    _startSensorListeners();
    _startSamplingTimer();

    _logger.info('USB transmission started');
    _throttledNotify();
  }

  Future<void> stopTransmission() async {
    if (!_isTransmitting) return;

    _isTransmitting = false;
    _samplingTimer?.cancel();
    _samplingTimer = null;
    _stopSensorListeners();

    // If the UI is previewing fusion, resume listeners in preview mode.
    if (_fusionPreviewClients > 0 && _useSensorFusionMode) {
      _resetFusionTiming();
      _startSensorListeners();
    }

    // Drain any remaining buffered packets.
    await _drainAndSend();

    _logger.info(
      'Transmission stopped — sent=$_packetsSent '
      'dropped=${_packetsDropped + _ringDropped} '
      'rate=${transmissionRate.toStringAsFixed(1)} pkt/s',
    );
    _forceNotify();
  }

  // ── sensor listeners ───────────────────────────────────────────────────────
  void _startSensorListeners() {
    // Use SENSOR_DELAY_FASTEST (~0 ms) for IMU sensors — the sampling timer
    // controls actual transmission rate, so there is no harm in reading faster.
    const samplingPeriod = Duration(milliseconds: 5); // ~200 Hz max

    if (_useSensorFusionMode) {
      // Complementary Filter Fusion: Gyro + Accel + Mag
      _accelSub = accelerometerEventStream(samplingPeriod: samplingPeriod)
          .listen((e) {
            _lastAx = e.x;
            _lastAy = e.y;
            _lastAz = e.z;
          });
      _gyroSub = gyroscopeEventStream(samplingPeriod: samplingPeriod).listen((
        e,
      ) {
        _lastGx = e.x;
        _lastGy = e.y;
        _lastGz = e.z;
        _emitFusedYPR();
      });
      _magnetoSub = magnetometerEventStream(samplingPeriod: samplingPeriod)
          .listen((e) {
            _lastMx = e.x;
            _lastMy = e.y;
            _lastMz = e.z;
          });
    } else {
      if (_enabledSensors[AppConstants.sensorAccelerometer] == true) {
        _accelSub = accelerometerEventStream(samplingPeriod: samplingPeriod)
            .listen(
              (e) => _ringPush(
                SensorData(
                  sensorType: AppConstants.sensorAccelerometer,
                  values: [e.x, e.y, e.z],
                  timestamp: DateTime.now(),
                  unit: 'm/s²',
                ),
              ),
            );
      }

      if (_enabledSensors[AppConstants.sensorGyroscope] == true) {
        _gyroSub = gyroscopeEventStream(samplingPeriod: samplingPeriod).listen(
          (e) => _ringPush(
            SensorData(
              sensorType: AppConstants.sensorGyroscope,
              values: [e.x, e.y, e.z],
              timestamp: DateTime.now(),
              unit: 'rad/s',
            ),
          ),
        );
      }

      if (_enabledSensors[AppConstants.sensorMagnetometer] == true) {
        _magnetoSub = magnetometerEventStream(samplingPeriod: samplingPeriod)
            .listen(
              (e) => _ringPush(
                SensorData(
                  sensorType: AppConstants.sensorMagnetometer,
                  values: [e.x, e.y, e.z],
                  timestamp: DateTime.now(),
                  unit: 'µT',
                ),
              ),
            );
      }
    }

    if (_enabledSensors[AppConstants.sensorGPS] == true) {
      _startGPSListener();
    }
  }

  void _emitFusedYPR() {
    final nowMicros = _fusionClock.elapsedMicroseconds;
    final prevMicros = _lastFusionMicros;
    _lastFusionMicros = nowMicros;

    // ── 1. Accel-only pitch & roll (absolute reference, noisy during motion) ──
    final accelPitch = math.atan2(
      -_lastAx,
      math.sqrt(_lastAy * _lastAy + _lastAz * _lastAz),
    );
    final accelRoll = math.atan2(_lastAy, _lastAz);

    // ── 2. Tilt-compensated magnetometer yaw reference (absolute, noisy) ─────
    final cp0 = math.cos(_fusedPitch), sp0 = math.sin(_fusedPitch);
    final cr0 = math.cos(_fusedRoll), sr0 = math.sin(_fusedRoll);
    final magX0 = _lastMx * cp0 + _lastMz * sp0;
    final magY0 = _lastMx * sr0 * sp0 + _lastMy * cr0 - _lastMz * sr0 * cp0;
    _smoothMagX = _magAlpha * _smoothMagX + (1.0 - _magAlpha) * magX0;
    _smoothMagY = _magAlpha * _smoothMagY + (1.0 - _magAlpha) * magY0;
    final yawMag = math.atan2(-_smoothMagY, _smoothMagX);

    if (prevMicros == null) {
      // First sample – initialise from accel + mag.
      _fusedPitch = accelPitch;
      _fusedRoll = accelRoll;
      _fusedYaw = yawMag;
      _emitFusedToUi(nowMicros);
      return;
    }

    // ── 3. Gyro integration (fast) ───────────────────────────────────────────
    var dt = (nowMicros - prevMicros) / 1e6; // seconds
    if (!dt.isFinite) return;
    // Clamp dt to avoid big jumps when app is backgrounded.
    if (dt < 0.0002) dt = 0.0002;
    if (dt > 0.05) dt = 0.05;

    final gyroPitch = _fusedPitch + _lastGx * dt;
    final gyroRoll = _fusedRoll + _lastGy * dt;
    final gyroYaw = _wrapRadPi(_fusedYaw + _lastGz * dt);

    // ── 4. Complementary Filter: blend gyro & accel (pitch/roll) ─────────────
    _fusedPitch = _cfAlpha * gyroPitch + (1.0 - _cfAlpha) * accelPitch;
    _fusedRoll = _cfAlpha * gyroRoll + (1.0 - _cfAlpha) * accelRoll;

    // ── 5. Yaw: fast gyro + slow mag correction (wrap-safe) ─────────────────
    final yawError = _wrapRadPi(yawMag - gyroYaw);
    _fusedYaw = _wrapRadPi(gyroYaw + (1.0 - _yawAlpha) * yawError);

    // Convert to degree axis in range [-180, 180] for downstream consumers.
    if (_isTransmitting) {
      final now = DateTime.now();
      final yawDeg = _wrapDeg(_fusedYaw * 180.0 / math.pi);
      final pitchDeg = _wrapDeg(_fusedPitch * 180.0 / math.pi);
      final rollDeg = _wrapDeg(_fusedRoll * 180.0 / math.pi);
      _ringPush(
        SensorData(
          sensorType: AppConstants.sensorYPR,
          values: [yawDeg, pitchDeg, rollDeg],
          timestamp: now,
          unit: 'deg',
        ),
      );
    }

    _emitFusedToUi(nowMicros);
  }

  void _emitFusedToUi(int nowMicros) {
    if (_isDisposed) return;
    if (_fusedOrientationCtrl.isClosed) return;

    final minDeltaUs = _yprUiIntervalMs * 1000;
    if (nowMicros - _lastYprUiEmitMicros < minDeltaUs) return;
    _lastYprUiEmitMicros = nowMicros;

    // Apply zero offsets: subtract stored reference, wrap to [-π, π].
    _fusedOrientationCtrl.add((
      yaw:   _wrapRadPi(_fusedYaw   - _yprOffsetYaw),
      pitch: _wrapRadPi(_fusedPitch - _yprOffsetPitch),
      roll:  _wrapRadPi(_fusedRoll  - _yprOffsetRoll),
    ));
  }

  double _wrapRadPi(double value) {
    var wrapped = (value + math.pi) % (2.0 * math.pi);
    if (wrapped < 0) {
      wrapped += 2.0 * math.pi;
    }
    return wrapped - math.pi;
  }

  void _resetFusionTiming() {
    _lastFusionMicros = null;
    _lastYprUiEmitMicros = 0;
  }

  double _wrapDeg(double value) {
    var wrapped = (value + 180.0) % 360.0;
    if (wrapped < 0) {
      wrapped += 360.0;
    }
    return wrapped - 180.0;
  }

  void _stopSensorListeners() {
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _magnetoSub?.cancel();
    _magnetoSub = null;

    _gpsSub?.cancel();
    _gpsSub = null;
  }

  void _startGPSListener() {
    _gpsSub =
        Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
              ),
            )
            .handleError((e) {
              _logger.warning('GPS stream error', e);
              _lastError = 'GPS error: $e';
              _throttledNotify();
            })
            .listen(
              (p) => _ringPush(
                SensorData(
                  sensorType: AppConstants.sensorGPS,
                  values: [p.latitude, p.longitude, p.altitude, p.speed],
                  timestamp: DateTime.now(),
                  unit: 'degrees',
                ),
              ),
            );
  }

  // ── ring buffer helpers ────────────────────────────────────────────────────
  /// Push a new sample into the ring. If the ring is full, the *oldest* sample
  /// is silently dropped (overwrite from head) so the ESP always gets the
  /// freshest data rather than stale queued data.
  void _ringPush(SensorData data) {
    final nextTail = (_ringTail + 1) & (_ringCap - 1);
    if (nextTail == _ringHead) {
      // Ring is full — overwrite oldest (advance head).
      _ringHead = (_ringHead + 1) & (_ringCap - 1);
      _ringDropped++;
    }
    _ring[_ringTail] = data;
    _ringTail = nextTail;
  }

  int get _ringSize => (_ringTail - _ringHead) & (_ringCap - 1);

  // ── sampling timer ─────────────────────────────────────────────────────────
  void _startSamplingTimer() {
    // Minimum 1 ms interval; 0 means "as fast as possible" → use 1 ms.
    final currentRate = samplingRate;
    final intervalMs = currentRate <= 0 ? 1 : currentRate;
    _logger.info(
      'Sampling timer: ${intervalMs}ms (${(1000 / intervalMs).toStringAsFixed(0)} Hz)',
    );

    _samplingTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_ringSize > 0) {
        // Fire-and-forget: we don't await to keep timer callbacks non-blocking.
        unawaited(_drainAndSend());
      }
    });
  }

  /// Drain up to [_maxBatchPerTick] packets from the ring and send them over
  /// USB in a single write. No mutex needed because timer is the only consumer.
  Future<void> _drainAndSend() async {
    if (!isConnected || _activeService == null) return;

    final count = _ringSize.clamp(0, _maxBatchPerTick);
    if (count == 0) return;

    // Build a packed byte buffer directly. 26 bytes per packet.
    _writeBuffer.clear();
    for (int i = 0; i < count; i++) {
      final idx = (_ringHead + i) & (_ringCap - 1);
      _writeBuffer.add(_ring[idx]!.toBytes());
      _ring[idx] = null; // release reference for GC
    }
    _ringHead = (_ringHead + count) & (_ringCap - 1);

    final bytes = _writeBuffer.takeBytes();

    try {
      // Single write — no retry. USB CDC driver will queue internally.
      await _usbService.writeRaw(bytes);
      _packetsSent += count;
    } catch (e) {
      _packetsDropped += count;
      _logger.warning('USB write failed: $e');
    }

    _throttledNotify();
  }

  // ── UI notify rate-limiter ─────────────────────────────────────────────────
  void _throttledNotify() {
    if (_isDisposed) return;
    final now = DateTime.now();
    if (now.difference(_lastNotifyTime).inMilliseconds >= _uiNotifyIntervalMs) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  void _forceNotify() {
    if (_isDisposed) return;
    _lastNotifyTime = DateTime.now();
    notifyListeners();
  }

  // ── init & detection ───────────────────────────────────────────────────────
  Future<void> _initialize() async {
    _logger.info('Initializing SensorViewModel …');
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(prefs);
      _usbService.setBaudRate(_settings!.usbBaudRate);
    } catch (e, st) {
      _logger.warning('Failed to load settings, using defaults', e, st);
      _usbService.setBaudRate(AppConstants.usbDefaultBaudRate);
    }
    if (_isDisposed) return;
    await _usbService.initialize();
    if (_isDisposed) return;
    if (_autoDetectSensors) {
      await detectAvailableSensors();
    } else {
      _isSensorDetectionComplete = true;
      _forceNotify();
    }
    _logger.info('SensorViewModel ready');
  }

  Future<void> detectAvailableSensors() async {
    try {
      final detected = await SensorDetector().detectSensors();
      _availableSensors
        ..clear()
        ..addAll(detected);
      _isSensorDetectionComplete = true;
      _forceNotify();
    } catch (e, st) {
      _logger.severe('Error detecting sensors', e, st);
      _isSensorDetectionComplete = true;
      _forceNotify();
    }
  }

  Future<void> redetectSensors() async {
    _isSensorDetectionComplete = false;
    _forceNotify();
    SensorDetector().resetCache();
    await detectAvailableSensors();
  }

  Future<bool> _requestPermissions() async {
    if (_enabledSensors[AppConstants.sensorGPS] == true) {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _samplingTimer?.cancel();
    _stopSensorListeners();
    unawaited(_fusedOrientationCtrl.close());
    unawaited(_usbService.dispose());
    super.dispose();
  }
}
