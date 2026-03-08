import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:sensdroid/models/sensor_data.dart';
import 'package:sensdroid/models/connection_info.dart';
import 'package:sensdroid/services/communication_service.dart';
import 'package:sensdroid/core/app_constants.dart';

/// Bluetooth communication service implementation
/// Handles both Bluetooth Classic and BLE connections
class BluetoothService extends CommunicationService {
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _txCharacteristic;
  // Negotiated MTU minus 3-byte ATT header = max payload per write
  int _mtu = 20;

  final StreamController<ConnectionInfo> _connectionController =
      StreamController<ConnectionInfo>.broadcast();
  
  ConnectionInfo _connectionInfo = ConnectionInfo(
    protocol: AppConstants.protocolBluetooth,
    state: ConnectionState.disconnected,
  );

  @override
  ConnectionInfo get connectionInfo => _connectionInfo;

  @override
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connectionInfo.isConnected;

  void _updateConnectionInfo(ConnectionInfo info) {
    _connectionInfo = info;
    _connectionController.add(info);
  }

  @override
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is available
      final isAvailable = await fbp.FlutterBluePlus.isSupported;
      if (!isAvailable) {
        _updateConnectionInfo(
          _connectionInfo.copyWith(
            state: ConnectionState.error,
            errorMessage: AppConstants.errorBluetoothNotAvailable,
          ),
        );
        return false;
      }
      return true;
    } catch (e) {
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
    return await fbp.FlutterBluePlus.isSupported;
  }

  @override
  Future<List<String>> scan() async {
    // Map of address → display string to avoid duplicates
    final Map<String, String> deviceMap = {};

    try {
      // Listen to scan results as they arrive
      final subscription = fbp.FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          final address = result.device.remoteId.toString();
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;
          final displayName = name.isNotEmpty
              ? '$name||$address'
              : 'BLE Device||$address';
          deviceMap[address] = displayName;
        }
      });

      // Start scan — timeout stops it automatically after 4s
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      // Wait for scan to actually stop (avoids the extra 4s delay)
      await fbp.FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => false,
          );

      await subscription.cancel();
      return deviceMap.values.toList();
    } catch (e) {
      await fbp.FlutterBluePlus.stopScan();
      return deviceMap.values.toList();
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connecting,
          address: address,
        ),
      );

      // Parse address — may be "DeviceName||MAC" or plain "MAC"
      final rawAddress = address.contains('||') ? address.split('||').last : address;

      // Find device by address
      final device = fbp.BluetoothDevice.fromId(rawAddress);
      
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Request higher MTU for larger payloads (Android supports up to 512)
      try {
        _mtu = await device.requestMtu(512) - 3; // subtract ATT header
        if (_mtu < 20) _mtu = 20;
      } catch (_) {
        _mtu = 20; // fallback to safe minimum
      }

      // Discover services
      final List<fbp.BluetoothService> services = await device.discoverServices();

      // ─────────────────────────────────────────────────────────────────
      // IMPORTANT: Match by the SPECIFIC service + characteristic UUID
      // defined in the ESP32 firmware. Using the first writable
      // characteristic is wrong — Generic Access (0x1800) / GATT (0x1801)
      // profiles also expose writable characteristics and are always
      // discovered first, causing data to go to the wrong endpoint.
      // ─────────────────────────────────────────────────────────────────

      final targetServiceUuid =
          fbp.Guid(AppConstants.bleServiceUuid.toLowerCase());
      final targetCharUuid =
          fbp.Guid(AppConstants.bleTxCharUuid.toLowerCase());

      // First pass: look for the exact ESP32 UUID pair
      for (final service in services) {
        if (service.serviceUuid == targetServiceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.characteristicUuid == targetCharUuid &&
                (characteristic.properties.write ||
                    characteristic.properties.writeWithoutResponse)) {
              _txCharacteristic = characteristic;
              break;
            }
          }
        }
        if (_txCharacteristic != null) break;
      }

      // Second pass fallback: any writable characteristic in the target service
      if (_txCharacteristic == null) {
        for (final service in services) {
          if (service.serviceUuid == targetServiceUuid) {
            for (final characteristic in service.characteristics) {
              if (characteristic.properties.write ||
                  characteristic.properties.writeWithoutResponse) {
                _txCharacteristic = characteristic;
                break;
              }
            }
          }
          if (_txCharacteristic != null) break;
        }
      }

      // Last resort fallback: any write characteristic (warn in log)
      if (_txCharacteristic == null) {
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse) {
              _txCharacteristic = characteristic;
              break;
            }
          }
          if (_txCharacteristic != null) break;
        }
      }

      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.connected,
          deviceName: device.platformName.isNotEmpty
              ? device.platformName
              : rawAddress,
          address: rawAddress,
          connectedAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
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
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
      _txCharacteristic = null;
      
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          state: ConnectionState.disconnected,
        ),
      );
    } catch (e) {
      // Handle disconnect error
    }
  }

  @override
  Future<bool> sendData(SensorData data) async {
    if (!isConnected || _txCharacteristic == null) {
      return false;
    }

    try {
      // Use efficient binary format (26 bytes per packet)
      // withoutResponse: false = Write With Response — ESP32 ACKs every write,
      // ensuring delivery and preventing buffer overruns on both sides.
      final bytes = data.toBytes();
      await _txCharacteristic!.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> sendBatch(List<SensorData> dataList) async {
    if (!isConnected || _txCharacteristic == null) {
      return 0;
    }

    try {
      // Binary format: each packet is exactly 26 bytes
      // Build contiguous byte array of all packets
      final buffer = BytesBuilder(copy: false);
      
      for (final data in dataList) {
        buffer.add(data.toBytes());
      }
      
      final fullBytes = buffer.toBytes();
      
      // Chunk into MTU-sized pieces for BLE transmission
      int offset = 0;
      int sentPackets = 0;
      
      while (offset < fullBytes.length) {
        final end = (offset + _mtu).clamp(0, fullBytes.length);
        final chunk = fullBytes.sublist(offset, end);
        await _txCharacteristic!.write(chunk, withoutResponse: false);
        offset = end;
        
        // Calculate how many complete packets sent
        sentPackets = (offset / 26).floor();
      }
      
      return sentPackets;
    } catch (e) {
      // Return 0 on error - no partial success tracking for simplicity
      return 0;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
  }
}
