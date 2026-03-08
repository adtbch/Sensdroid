import 'dart:typed_data';
import 'package:sensdroid/core/app_constants.dart';

/// Represents sensor data from various device sensors
class SensorData {
  final String sensorType;
  final List<double> values;
  final DateTime timestamp;
  final String? unit;

  SensorData({
    required this.sensorType,
    required this.values,
    required this.timestamp,
    this.unit,
  });

  /// Convert sensor data to CSV format for transmission
  /// Format: sensorType,timestamp,value1,value2,value3,...
  String toCsv() {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    final valuesStr = values.map((v) => v.toStringAsFixed(4)).join(',');
    return '$sensorType,$timestampMs,$valuesStr';
  }

  /// Convert sensor data to efficient binary format for transmission
  /// 
  /// Binary Format (26 bytes total):
  /// - Byte 0:      Sensor Type ID (1 byte)
  ///                0 = Accelerometer, 1 = Gyroscope, 2 = Magnetometer, 3 = GPS
  /// - Bytes 1-8:   Timestamp (8 bytes, uint64, little-endian)
  /// - Bytes 9-24:  Sensor Values (16 bytes, 4x float32, little-endian)
  ///                Values padded with 0.0 if less than 4 values
  /// - Byte 25:     Checksum (1 byte, XOR of all previous bytes)
  /// 
  /// Benefits over CSV:
  /// - 26 bytes vs ~50-60 bytes CSV (50-60% size reduction)
  /// - No string parsing needed on ESP side
  /// - Fixed size for predictable buffer allocation
  /// - Checksum for data integrity verification
  Uint8List toBytes() {
    final buffer = ByteData(26);
    
    // Byte 0: Sensor type ID
    final sensorTypeId = _getSensorTypeId(sensorType);
    buffer.setUint8(0, sensorTypeId);
    
    // Bytes 1-8: Timestamp (uint64 little-endian)
    final timestampMs = timestamp.millisecondsSinceEpoch;
    buffer.setUint64(1, timestampMs, Endian.little);
    
    // Bytes 9-24: Up to 4 float values (float32 little-endian)
    for (int i = 0; i < 4; i++) {
      final value = i < values.length ? values[i] : 0.0;
      buffer.setFloat32(9 + (i * 4), value, Endian.little);
    }
    
    // Byte 25: Checksum (XOR of all previous bytes)
    final bytes = buffer.buffer.asUint8List();
    int checksum = 0;
    for (int i = 0; i < 25; i++) {
      checksum ^= bytes[i];
    }
    buffer.setUint8(25, checksum);
    
    return bytes;
  }

  /// Get sensor type ID for binary encoding
  static int _getSensorTypeId(String sensorType) {
    switch (sensorType) {
      case AppConstants.sensorAccelerometer:
        return 0;
      case AppConstants.sensorGyroscope:
        return 1;
      case AppConstants.sensorMagnetometer:
        return 2;
      case AppConstants.sensorGPS:
        return 3;
      case AppConstants.sensorProximity:
        return 4;
      case AppConstants.sensorLight:
        return 5;
      default:
        return 255; // Unknown sensor
    }
  }

  /// Get sensor type string from binary ID
  static String _getSensorTypeName(int typeId) {
    switch (typeId) {
      case 0:
        return AppConstants.sensorAccelerometer;
      case 1:
        return AppConstants.sensorGyroscope;
      case 2:
        return AppConstants.sensorMagnetometer;
      case 3:
        return AppConstants.sensorGPS;
      case 4:
        return AppConstants.sensorProximity;
      case 5:
        return AppConstants.sensorLight;
      default:
        return 'unknown';
    }
  }

  /// Create SensorData from binary format
  /// 
  /// Throws FormatException if:
  /// - Data length is not 26 bytes
  /// - Checksum validation fails
  factory SensorData.fromBytes(Uint8List bytes) {
    if (bytes.length != 26) {
      throw FormatException('Invalid binary data length: ${bytes.length} (expected 26)');
    }
    
    final buffer = ByteData.sublistView(bytes);
    
    // Verify checksum
    int checksum = 0;
    for (int i = 0; i < 25; i++) {
      checksum ^= bytes[i];
    }
    final receivedChecksum = buffer.getUint8(25);
    if (checksum != receivedChecksum) {
      throw FormatException('Checksum mismatch: expected $checksum, got $receivedChecksum');
    }
    
    // Parse sensor type
    final sensorTypeId = buffer.getUint8(0);
    final sensorType = _getSensorTypeName(sensorTypeId);
    
    // Parse timestamp
    final timestampMs = buffer.getUint64(1, Endian.little);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    
    // Parse values (4x float32)
    final values = <double>[];
    for (int i = 0; i < 4; i++) {
      final value = buffer.getFloat32(9 + (i * 4), Endian.little);
      if (value != 0.0 || i < 3) {  // Include non-zero or first 3 values
        values.add(value);
      }
    }
    
    return SensorData(
      sensorType: sensorType,
      values: values,
      timestamp: timestamp,
    );
  }

  /// Convert sensor data to JSON format
  Map<String, dynamic> toJson() {
    return {
      'sensorType': sensorType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'values': values,
      'unit': unit,
    };
  }

  /// Create SensorData from JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      sensorType: json['sensorType'] as String,
      values: (json['values'] as List<dynamic>).map((v) => v as double).toList(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      unit: json['unit'] as String?,
    );
  }

  @override
  String toString() {
    return 'SensorData(type: $sensorType, values: $values, time: $timestamp)';
  }
}
