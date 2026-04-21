import 'dart:async';
import 'dart:isolate';
import 'package:sensdroid/models/sensor_data.dart';

/// Isolate-based data processing utilities
/// For high-frequency sensor data (100+ Hz) to prevent UI thread blocking
class IsolateProcessor {
  /// Parse CSV data in background isolate to avoid blocking UI thread
  /// Returns parsed SensorData objects
  static Future<List<SensorData>> parseCsvInIsolate(
    List<String> csvLines,
  ) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _parseCsvIsolate,
      _IsolateData(csvLines: csvLines, sendPort: receivePort.sendPort),
    );

    final result = await receivePort.first;
    return result;
  }

  /// Serialize SensorData to CSV in background isolate
  static Future<List<String>> serializeToCsvInIsolate(
    List<SensorData> dataList,
  ) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _serializeToCsvIsolate,
      _IsolateData(dataList: dataList, sendPort: receivePort.sendPort),
    );

    final result = await receivePort.first;
    return result;
  }

  /// Serialize SensorData to JSON in background isolate
  static Future<List<Map<String, dynamic>>> serializeToJsonInIsolate(
    List<SensorData> dataList,
  ) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _serializeToJsonIsolate,
      _IsolateData(dataList: dataList, sendPort: receivePort.sendPort),
    );

    final result = await receivePort.first;
    return result;
  }
}

/// Data structure untuk passing ke isolate
class _IsolateData {
  final List<String>? csvLines;
  final List<SensorData>? dataList;
  final SendPort sendPort;

  _IsolateData({this.csvLines, this.dataList, required this.sendPort});
}

void _parseCsvIsolate(_IsolateData data) {
  try {
    final results = <SensorData>[];

    for (final line in data.csvLines!) {
      try {
        final parts = line.split(',');
        if (parts.length < 5) continue; // minimum: type,timestamp,v1,v2,v3

        final sensorType = parts[0];
        final timestamp = int.tryParse(parts[1]) ?? 0;
        final values = parts
            .skip(2)
            .map((v) => double.tryParse(v))
            .whereType<double>()
            .toList();

        if (values.length < parts.length - 2) {
          continue; // some values failed to parse
        }

        final sensorData = SensorData(
          sensorType: sensorType,
          values: values,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          unit: 'unknown', // unit not stored in CSV
        );

        results.add(sensorData);
      } catch (e) {
        // Skip invalid lines
      }
    }

    data.sendPort.send(results);
  } catch (e) {
    data.sendPort.send(<SensorData>[]);
  }
}

void _serializeToCsvIsolate(_IsolateData data) {
  try {
    final results = <String>[];

    for (final sensorData in data.dataList!) {
      final csv = sensorData.toCsv();
      results.add(csv);
    }

    data.sendPort.send(results);
  } catch (e) {
    data.sendPort.send(<String>[]);
  }
}

void _serializeToJsonIsolate(_IsolateData data) {
  try {
    final results = <Map<String, dynamic>>[];

    for (final sensorData in data.dataList!) {
      results.add(sensorData.toJson());
    }

    data.sendPort.send(results);
  } catch (e) {
    data.sendPort.send(<Map<String, dynamic>>[]);
  }
}
