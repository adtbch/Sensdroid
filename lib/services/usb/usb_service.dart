import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';
import 'package:sensdroid/core/logger.dart';

/// USB OTG Serial communication service implementation
/// Supports communication with microcontrollers (ESP32, Arduino) and PC via USB
class USBService extends CommunicationService {
  UsbPort? _port;
  
  final StreamController<ConnectionInfo> _connectionController =
      StreamController<ConnectionInfo>.broadcast();
  
  ConnectionInfo _connectionInfo = ConnectionInfo(
    protocol: AppConstants.protocolUSB,
    state: ConnectionState.disconnected,
  );

  late final Logger _logger;
  int _baudRate = AppConstants.usbBaudRate; // default, can be changed via setBaudRate()

  USBService() {
    _logger = AppLogger.getLogger(runtimeType.toString());
  }

  Logger get log => _logger;

  /// Update baud rate for USB serial communication
  void setBaudRate(int baudRate) {
    if (baudRate > 0 && baudRate <= 921600) { // reasonable bounds
      _logger.info('USB baud rate changed: $_baudRate → $baudRate');
      _baudRate = baudRate;
    } else {
      _logger.warning('Invalid baud rate: $baudRate (must be >0 and <=921600)');
    }
  }

  int get baudRate => _baudRate;

  @override
  ConnectionInfo get connectionInfo => _connectionInfo;

  @override
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connectionInfo.isConnected && _port != null;

  void _updateConnectionInfo(ConnectionInfo info) {
    _connectionInfo = info;
    _connectionController.add(info);
  }

  @override
  Future<bool> initialize() async {
    try {
      _logger.info('Initializing USB service');
      // USB Serial doesn't require specific initialization
      return true;
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize USB service', e, stackTrace);
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    // Check if any USB devices are connected
    final devices = await UsbSerial.listDevices();
    return devices.isNotEmpty;
  }

  @override
  Future<List<String>> scan() async {
    final List<String> deviceIds = [];

    try {
      _logger.info('Scanning for USB devices');
      final devices = await UsbSerial.listDevices();
      _logger.fine('Found ${devices.length} USB device(s)');

      for (var device in devices) {
        final deviceId = '${device.vid}:${device.pid}';
        final productName = device.productName;
        final displayName = (productName != null && productName.isNotEmpty)
            ? '$productName||$deviceId'
            : 'USB Device||$deviceId';
        deviceIds.add(displayName);
        _logger.fine('USB Device: $displayName (VID:PID=$deviceId)');
      }

      return deviceIds;
    } catch (e, stackTrace) {
      _logger.warning('USB scan failed', e, stackTrace);
      return deviceIds;
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      _logger.info('Connecting to USB device: $address');
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connecting,
          address: address,
        ),
      );

      // Get list of devices
      final devices = await UsbSerial.listDevices();
      
      if (devices.isEmpty) {
        _logger.severe('No USB devices found during connection attempt');
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.error,
            errorMessage: AppConstants.errorUSBNotConnected,
          ),
        );
        return false;
      }

      // Parse address — may be "ProductName||VID:PID" or plain "VID:PID"
      final rawAddress = address.contains('||') ? address.split('||').last : address;

      // Find device by address (vid:pid format)
      UsbDevice? targetDevice;
      for (var device in devices) {
        final deviceId = '${device.vid}:${device.pid}';
        if (deviceId == rawAddress) {
          targetDevice = device;
          break;
        }
      }

      // If not found, use first available device
      targetDevice ??= devices.first;
      _logger.info('Selected USB device: ${targetDevice.productName ?? "Unknown"} (${targetDevice.vid}:${targetDevice.pid})');

      // Create port
      final device = targetDevice;
      _port = await retryWithBackoff(
        () async => await device.create(),
        maxRetries: 2,
      );
      
      if (_port == null) {
        _logger.severe('Failed to create USB port');
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.error,
            errorMessage: 'Failed to create USB port',
          ),
        );
        return false;
      }

      // Open port with retry
      final opened = await retryWithBackoff(
        () async => await _port!.open(),
        maxRetries: 2,
        shouldRetry: (error) => error.toString().contains('busy') || error.toString().contains('timeout'),
      );
      
      if (!opened) {
        _logger.severe('Failed to open USB port after retries');
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.error,
            errorMessage: 'Failed to open USB port',
          ),
        );
        return false;
      }

      // ─────────────────────────────────────────────────────────────────
      // DTR/RTS note:
      // • UART adapters (CP2102/CH340): DTR=true + RTS=true mengaktifkan
      //   flow control dan menstabilkan komunikasi serial — diperlukan.
      // • Espressif native USB CDC (VID 12346 / 0x303A): DTR/RTS dikirim
      //   via CDC control request; pada ESP32-S3 tidak memicu reset karena
      //   tidak ada hardware auto-reset pada jalur USB native.
      //   Namun, untuk keamanan, kita lewati setDTR/setRTS pada device
      //   Espressif agar tidak berinteraksi dengan firmware CDC.
      // ─────────────────────────────────────────────────────────────────
      final isEspressifNative = targetDevice.vid == AppConstants.usbVidEspressifNative;
      if (!isEspressifNative) {
        await _port!.setDTR(true);
        await _port!.setRTS(true);
      }

      // MUST be awaited — baud rate must be set before any write.
      // Use _baudRate (instance variable) — updated from Settings via setBaudRate().
      // NOT AppConstants.usbBaudRate (compile-time constant) so user
      // configuration from the Settings page is respected.
      try {
        await retryWithBackoff(
          () async => await _port!.setPortParameters(
            _baudRate,
            UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1,
            UsbPort.PARITY_NONE,
          ),
          maxRetries: 2,
        );
        _logger.info('USB port configured: baudrate=$_baudRate');
      } catch (e, stackTrace) {
        _logger.warning('Failed to set port parameters', e, stackTrace);
        // Continue anyway - device might work with default
      }

      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connected,
          deviceName: targetDevice.productName ?? 'USB Device',
          address: '${targetDevice.vid}:${targetDevice.pid}',
          connectedAt: DateTime.now(),
        ),
      );

      _logger.info('USB connected successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('USB connection failed', e, stackTrace);
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _logger.info('Disconnecting from USB device');
      await _port?.close();
      _port = null;
      
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.disconnected,
        ),
      );
      _logger.info('USB disconnected successfully');
    } catch (e, stackTrace) {
      _logger.warning('Error during USB disconnect', e, stackTrace);
    }
  }

  @override
  Future<bool> sendData(SensorData data) async {
    if (!isConnected || _port == null) {
      _logger.warning('Cannot send USB data: not connected');
      return false;
    }

    try {
      // Use efficient binary format (26 bytes per packet)
      final bytes = data.toBytes();
      
      await retryWithBackoff(
        () async => await _port!.write(bytes),
        maxRetries: 2,
        shouldRetry: (error) => error.toString().contains('timeout') || error.toString().contains('fail'),
      );
      
      return true;
    } catch (e, stackTrace) {
      _logger.warning('Failed to send single USB packet', e, stackTrace);
      return false;
    }
  }

  @override
  Future<int> sendBatch(List<SensorData> dataList) async {
    int successCount = 0;
    
    if (!isConnected || _port == null) {
      _logger.warning('Cannot send USB batch: not connected');
      return 0;
    }

    try {
      // Binary format: each packet is exactly 26 bytes
      // Build contiguous byte array of all packets
      final buffer = BytesBuilder(copy: false);
      for (final data in dataList) {
        buffer.add(data.toBytes());
      }
      final bytes = buffer.toBytes();
      
      await retryWithBackoff(
        () async => await _port!.write(bytes),
        maxRetries: 2,
      );
      
      successCount = dataList.length;
      _logger.fine('USB batch sent: ${dataList.length} packets, ${bytes.length} bytes');
    } catch (e, stackTrace) {
      _logger.warning('USB batch send failed, falling back to individual sends', e, stackTrace);
      // If batch write fails, fall back to individual sends
      for (final data in dataList) {
        if (await sendData(data)) {
          successCount++;
        }
      }
    }
    
    return successCount;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    _logger.info('USB service disposed');
  }
}
