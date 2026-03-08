import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/services/bluetooth/bluetooth_service.dart';
import 'package:sensdroid/services/usb/usb_service.dart';
import 'package:sensdroid/services/wifi/wifi_service.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/logger.dart';
import 'package:sensdroid/core/app_settings.dart';
import 'package:sensdroid/utils/sensor_detector.dart';

/// ViewModel for managing sensor data streaming and transmission
/// Implements MVVM pattern - handles all business logic and state management
class SensorViewModel extends ChangeNotifier {
  late final Logger _logger;
  AppSettings? _settings;

  // ── Communication services ──────────────────────────────────────────────
  late BluetoothService _bluetoothService;
  late USBService _usbService;
  late WiFiService _wifiService;
  CommunicationService? _activeService;

  // ── Connection / protocol state ─────────────────────────────────────────
  String _activeProtocol = AppConstants.protocolBluetooth;
  bool _isConnecting = false;

  // ── Transmission state ──────────────────────────────────────────────────
  bool _isTransmitting = false;
  String? _lastError;
  int _packetsSent = 0;
  int _packetsDropped = 0;
  DateTime? _transmissionStartTime;

  // ── Sampling / buffer ───────────────────────────────────────────────────
  int _samplingRate = AppSettings.defaultSamplingRate;
  Timer? _samplingTimer;
  final int _maxBufferSize = AppSettings.defaultBufferSize;
  final List<SensorData> _dataBuffer = [];
  bool _isFlushing = false;

  // ── Sensor availability & enabled state ────────────────────────────────
  bool _isSensorDetectionComplete = false;
  final Map<String, bool> _availableSensors = {};
  final Map<String, bool> _enabledSensors = {
    AppConstants.sensorAccelerometer: true,
    AppConstants.sensorGyroscope: true,
    AppConstants.sensorMagnetometer: true,
    AppConstants.sensorGPS: false,
  };

  // ── Sensor stream subscriptions ─────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<Position>? _gpsSubscription;

  SensorViewModel() {
    _logger = AppLogger.getLogger(runtimeType.toString());
    _bluetoothService = BluetoothService();
    _usbService = USBService();
    _wifiService = WiFiService();
    _activeService = _bluetoothService;
    _initialize();
  }

  /// Get current settings (null until initialized)
  AppSettings? get settings => _settings;
  
  /// Update settings and apply them
  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    // Apply to runtime variables
    _samplingRate = newSettings.samplingRate;
    notifyListeners();
    _logger.info('Settings updated: ${newSettings.toMap()}');
  }

  /// Update sampling rate (only when not transmitting)
  void updateSamplingRate(int newRate) {
    if (_isTransmitting) {
      _logger.warning('Cannot change sampling rate while transmitting');
      return;
    }
    
    if (newRate < 0 || newRate > 100) {
      _logger.warning('Invalid sampling rate: $newRate (must be 0-100ms)');
      return;
    }
    
    _samplingRate = newRate;
    if (_settings != null) {
      _settings!.samplingRate = newRate;
    }
    notifyListeners();
    _logger.info('Sampling rate updated to ${_samplingRate}ms');
  }

  // Getters
  String get activeProtocol => _activeProtocol;
  ConnectionInfo? get connectionInfo => _activeService?.connectionInfo;
  bool get isConnected => _activeService?.isConnected ?? false;
  bool get isConnecting => _isConnecting;
  bool get isTransmitting => _isTransmitting;
  String? get lastError => _lastError;
  int get packetsSent => _packetsSent;
  int get packetsDropped => _packetsDropped;
  int get samplingRate => _samplingRate;
  Map<String, bool> get enabledSensors => Map.unmodifiable(_enabledSensors);
  Map<String, bool> get availableSensors => Map.unmodifiable(_availableSensors);
  bool get isSensorDetectionComplete => _isSensorDetectionComplete;

  Duration? get transmissionDuration => _transmissionStartTime != null
      ? DateTime.now().difference(_transmissionStartTime!)
      : null;

  double get transmissionRate {
    final dur = transmissionDuration;
    if (dur == null) return 0.0;
    final ms = dur.inMilliseconds;
    if (ms == 0) return 0.0;
    return _packetsSent / (ms / 1000.0);
  }

  Future<void> _initialize() async {
    _logger.info('Initializing SensorViewModel');
    
    // Load settings (shared preferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(prefs);
      _logger.info('Settings loaded: ${_settings!.toMap()}');
      
      // Apply settings to runtime variables
      _samplingRate = _settings!.samplingRate;
      // Note: _maxBufferSize is compile-time constant; could be made dynamic if needed
      _logger.fine('Applied settings: samplingRate=${_samplingRate}ms');
    } catch (e, stackTrace) {
      _logger.warning('Failed to load settings, using defaults', e, stackTrace);
    }
    
    await _bluetoothService.initialize();
    await _usbService.initialize();
    await _wifiService.initialize();
    
    // Detect available sensors
    await detectAvailableSensors();
    _logger.info('SensorViewModel initialization complete');
  }

  /// Detect which sensors are available on this device
  Future<void> detectAvailableSensors() async {
    try {
      _logger.info('Detecting available sensors');
      final detector = SensorDetector();
      final detected = await detector.detectSensors();
      
      _availableSensors.clear();
      _availableSensors.addAll(detected);
      _isSensorDetectionComplete = true;
      
      _logger.info('Sensors detected: $_availableSensors');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe('Error detecting sensors', e, stackTrace);
      _isSensorDetectionComplete = true;
      notifyListeners();
    }
  }

  /// Re-run sensor detection (e.g. after user grants permissions)
  Future<void> redetectSensors() async {
    _logger.info('Redetecting sensors (permissions may have changed)');
    _isSensorDetectionComplete = false;
    notifyListeners();
    SensorDetector().resetCache();
    await detectAvailableSensors();
  }

  /// Switch between communication protocols
  Future<void> switchProtocol(String protocol) async {
    if (_isTransmitting) {
      await stopTransmission();
    }

    // Disconnect current service
    await _activeService?.disconnect();

    // Switch to new service
    switch (protocol) {
      case AppConstants.protocolBluetooth:
        _activeService = _bluetoothService;
        break;
      case AppConstants.protocolUSB:
        _activeService = _usbService;
        break;
      case AppConstants.protocolWiFi:
        _activeService = _wifiService;
        break;
      default:
        throw ArgumentError('Unknown protocol: $protocol');
    }

    _activeProtocol = protocol;
    notifyListeners();
  }

  /// Scan for available devices
  Future<List<String>> scanDevices() async {
    // Only request Bluetooth permissions when the active protocol actually needs them
    if (_activeProtocol == AppConstants.protocolBluetooth) {
      await _requestPermissions();
    }
    final devices = await _activeService?.scan() ?? [];
    return devices;
  }

  /// Connect to a device
  Future<bool> connect(String address) async {
    _isConnecting = true;
    _lastError = null;
    notifyListeners();
    try {
      final success = await _activeService?.connect(address) ?? false;
      if (!success) {
        _lastError = 'Failed to connect to $address';
      }
      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_isTransmitting) {
      await stopTransmission();
    }
    await _activeService?.disconnect();
    notifyListeners();
  }

  /// Toggle sensor enable/disable
  void toggleSensor(String sensorType, bool enabled) {
    _logger.info('Toggling sensor $sensorType: $enabled');
    
    // Only allow toggling if sensor is available
    if (enabled && !(_availableSensors[sensorType] ?? false)) {
      _logger.warning('Cannot enable $sensorType - not available on device');
      return; // Cannot enable unavailable sensor
    }
    
    _enabledSensors[sensorType] = enabled;
    
    // If currently transmitting, restart sensor listeners to apply changes
    if (_isTransmitting) {
      _logger.info('Restarting sensor listeners due to sensor toggle');
      _stopSensorListeners();
      _startSensorListeners();
    }
    
    notifyListeners();
  }

  /// Clear last error message
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Start data transmission
  Future<void> startTransmission() async {
    if (!isConnected) {
      _lastError = 'Not connected to any device';
      _logger.severe('Cannot start transmission: not connected');
      notifyListeners();
      throw Exception(_lastError);
    }

    if (_isTransmitting) {
      _logger.warning('Start transmission called while already transmitting - ignored');
      return;
    }

    _logger.info('Starting sensor transmission (protocol: $_activeProtocol, enabled sensors: ${_enabledSensors.values.where((e) => e).length})');
    
    // Request permissions
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      _lastError = AppConstants.errorPermissionDenied;
      _logger.severe('Permission denied - cannot start transmission');
      notifyListeners();
      throw Exception(_lastError);
    }

    _isTransmitting = true;
    _packetsSent = 0;
    _packetsDropped = 0;
    _transmissionStartTime = DateTime.now();
    _dataBuffer.clear();

    // Start listening to enabled sensors
    _startSensorListeners();
    _startSamplingTimer();

    _logger.info('Transmission started successfully');
    notifyListeners();
  }

  /// Stop data transmission
  Future<void> stopTransmission() async {
    if (!_isTransmitting) {
      _logger.warning('Stop transmission called while not transmitting - ignored');
      return;
    }
    
    _logger.info('Stopping sensor transmission');
    _isTransmitting = false;
    _samplingTimer?.cancel();
    _stopSensorListeners();

    // Wait for any in-progress flush to complete before doing final flush.
    // The timer and sensors are stopped, so no new flush can be triggered —
    // we just need to drain the one that is currently running.
    while (_isFlushing) {
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // Flush remaining buffer
    if (_dataBuffer.isNotEmpty) {
      _logger.fine('Flushing remaining ${_dataBuffer.length} packets during shutdown');
      await _flushBuffer();
    } else {
      _logger.fine('No remaining packets in buffer during shutdown');
    }

    final duration = DateTime.now().difference(_transmissionStartTime!);
    _logger.info('Transmission stopped. Duration: ${duration.inSeconds}s, Packets sent: $_packetsSent, dropped: $_packetsDropped, rate: ${transmissionRate.toStringAsFixed(2)} pps');
    notifyListeners();
  }

  void _startSensorListeners() async {
    // Sampling period matches our 50 ms flush interval (20 Hz).
    // Without this, sensors default to hardware native rate (100–200 Hz)
    // which floods the buffer and causes packet drops.
    const samplingPeriod = Duration(milliseconds: 50);

    // Accelerometer
    if (_enabledSensors[AppConstants.sensorAccelerometer] == true) {
      _accelerometerSubscription =
          accelerometerEventStream(samplingPeriod: samplingPeriod).listen((event) {
        _addSensorData(SensorData(
          sensorType: AppConstants.sensorAccelerometer,
          values: [event.x, event.y, event.z],
          timestamp: DateTime.now(),
          unit: 'm/s²',
        ));
      });
    }

    // Gyroscope
    if (_enabledSensors[AppConstants.sensorGyroscope] == true) {
      _gyroscopeSubscription =
          gyroscopeEventStream(samplingPeriod: samplingPeriod).listen((event) {
        _addSensorData(SensorData(
          sensorType: AppConstants.sensorGyroscope,
          values: [event.x, event.y, event.z],
          timestamp: DateTime.now(),
          unit: 'rad/s',
        ));
      });
    }

    // Magnetometer
    if (_enabledSensors[AppConstants.sensorMagnetometer] == true) {
      _magnetometerSubscription =
          magnetometerEventStream(samplingPeriod: samplingPeriod).listen((event) {
        _addSensorData(SensorData(
          sensorType: AppConstants.sensorMagnetometer,
          values: [event.x, event.y, event.z],
          timestamp: DateTime.now(),
          unit: 'µT',
        ));
      });
    }

    // GPS: MUST be awaited to prevent race condition where stopTransmission
    // is called immediately after start, leaving _gpsSubscription unassigned
    // while the stream already emits. By awaiting, we guarantee subscription
    // is set before any possible cancellation.
    if (_enabledSensors[AppConstants.sensorGPS] == true) {
      await _startGPSListener();
    }
  }

  void _stopSensorListeners() {
    _logger.fine('Stopping all sensor listeners');
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _logger.fine('All sensor listeners stopped');
  }

  Future<void> _startGPSListener() async {
    // Subscribe synchronously so _gpsSubscription is set before any await,
    // preventing a stream leak if stopTransmission() is called immediately.
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _logger.info('Starting GPS listener');
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).handleError((e) {
      _logger.warning('GPS stream error', e);
      _lastError = 'GPS error: $e';
      notifyListeners();
    }).listen((Position position) {
      _addSensorData(SensorData(
        sensorType: AppConstants.sensorGPS,
        values: [
          position.latitude,
          position.longitude,
          position.altitude,
          position.speed,
        ],
        timestamp: DateTime.now(),
        unit: 'degrees',
      ));
    });
  }

  void _startSamplingTimer() {
    _logger.info('Starting sampling timer: ${_samplingRate}ms interval');
    _samplingTimer = Timer.periodic(
      Duration(milliseconds: _samplingRate),
      (timer) {
        // Flush buffer on every interval — ensures data is sent
        // even if buffer hasn't reached max size yet
        if (_dataBuffer.isNotEmpty) {
          _flushBuffer();
        }
      },
    );
  }

  void _addSensorData(SensorData data) {
    if (!_isTransmitting) return;
    
    // Protection against buffer overflow if flush() fails repeatedly
    if (_dataBuffer.length >= _maxBufferSize * 2) {
      _logger.warning('Buffer overflow detected (${_dataBuffer.length} items), dropping oldest entries');
      // Remove oldest 25% to prevent memory issues
      final removeCount = (_maxBufferSize * 0.5).round();
      _dataBuffer.removeRange(0, removeCount);
      _packetsDropped += removeCount;
    }
    
    _dataBuffer.add(data);
    
    // Flush buffer if full
    if (_dataBuffer.length >= _maxBufferSize) {
      _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    // Guard: prevent concurrent flush calls from timer + sensor overflow
    if (_isFlushing || _dataBuffer.isEmpty || _activeService == null) {
      if (_isFlushing) {
        _logger.fine('Flush skipped: already in progress');
      }
      return;
    }
    
    _isFlushing = true;
    final bufferLength = _dataBuffer.length;

    final dataToSend = List<SensorData>.from(_dataBuffer);
    _dataBuffer.clear();

    try {
      _logger.fine('Flushing buffer: $bufferLength packets');
      final sentCount = await _activeService!.sendBatch(dataToSend);
      _packetsSent += sentCount;
      final dropped = bufferLength - sentCount;
      _packetsDropped += dropped;
      
      if (dropped > 0) {
        _logger.warning('Buffer flush had $dropped dropped packets out of $bufferLength');
      } else {
        _logger.fine('Buffer flush successful: $sentCount packets sent');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe('Buffer flush failed', e, stackTrace);
      _packetsDropped += bufferLength;
      notifyListeners();
    } finally {
      _isFlushing = false;
    }
  }

  Future<bool> _requestPermissions() async {
    _logger.info('Requesting permissions for protocol: $_activeProtocol');
    
    // Request Bluetooth permissions ONLY if using Bluetooth protocol
    if (_activeProtocol == AppConstants.protocolBluetooth) {
      _logger.fine('Requesting Bluetooth permissions');
      final bluetoothStatus = await Permission.bluetoothConnect.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final locationStatus = await Permission.locationWhenInUse.request();
      
      if (!bluetoothStatus.isGranted || !bluetoothScanStatus.isGranted || !locationStatus.isGranted) {
        _logger.warning('Bluetooth permissions denied: '
            'Connect=${bluetoothStatus.name}, '
            'Scan=${bluetoothScanStatus.name}, '
            'Location=${locationStatus.name}');
        return false;
      }
      _logger.info('Bluetooth permissions granted');
    }

    // Request location permissions for GPS ONLY if GPS sensor is enabled
    if (_enabledSensors[AppConstants.sensorGPS] == true) {
      _logger.fine('Requesting GPS permission');
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _logger.warning('GPS permission denied: ${status.name}');
        return false;
      }
      _logger.info('GPS permission granted');
    }

    // NOTE: Permission.sensors (BODY_SENSORS) is for heart-rate monitors only
    // on Android 13+. Accelerometer/Gyro/Magnetometer do NOT require
    // runtime permissions — they are hardware-accessible without grant.
    _logger.info('All required permissions granted');
    return true;
  }

  @override
  void dispose() {
    _stopSensorListeners();
    _samplingTimer?.cancel();
    _bluetoothService.dispose();
    _usbService.dispose();
    _wifiService.dispose();
    super.dispose();
  }
}
