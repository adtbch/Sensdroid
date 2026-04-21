import 'package:flutter_test/flutter_test.dart';
import 'package:sensdroid/models/sensor_data.dart';

void main() {
  group('SensorData', () {
    late DateTime testTimestamp;

    setUp(() {
      testTimestamp = DateTime.utc(2026, 2, 19, 12, 0, 0);
    });

    test('constructor creates valid object', () {
      final data = SensorData(
        sensorType: 'accelerometer',
        values: [9.81, 0.0234, -0.1523],
        timestamp: testTimestamp,
        unit: 'm/s²',
      );

      expect(data.sensorType, 'accelerometer');
      expect(data.values.length, 3);
      expect(data.values[0], 9.81);
      expect(data.values[1], 0.0234);
      expect(data.values[2], -0.1523);
      expect(data.timestamp, testTimestamp);
      expect(data.unit, 'm/s²');
    });

    test('toCsv produces correct format', () {
      final data = SensorData(
        sensorType: 'gyroscope',
        values: [0.0012, -0.0045, 0.0089],
        timestamp: testTimestamp,
        unit: 'rad/s',
      );

      final csv = data.toCsv();
      final expected =
          'gyroscope,${testTimestamp.millisecondsSinceEpoch},0.0012,-0.0045,0.0089';

      expect(csv, expected);
    });

    test('toCsv handles different precision', () {
      final data = SensorData(
        sensorType: 'magnetometer',
        values: [1.23456789, 2.34567890, 3.45678901],
        timestamp: testTimestamp,
        unit: 'µT',
      );

      final csv = data.toCsv();
      final parts = csv.split(',');

      // Should be rounded to 4 decimal places
      expect(parts[2], '1.2346');
      expect(parts[3], '2.3457');
      expect(parts[4], '3.4568');
    });

    test('toJson produces correct map', () {
      final data = SensorData(
        sensorType: 'gps',
        values: [-6.2088, 106.8456, 50.0, 0.0],
        timestamp: testTimestamp,
        unit: 'degrees',
      );

      final json = data.toJson();

      expect(json['sensorType'], 'gps');
      expect(json['timestamp'], testTimestamp.millisecondsSinceEpoch);
      expect(json['values'].length, 4);
      expect(json['values'][0], -6.2088);
      expect(json['unit'], 'degrees');
    });

    test('fromJson recreates object correctly', () {
      final json = {
        'sensorType': 'accelerometer',
        'timestamp': testTimestamp.millisecondsSinceEpoch,
        'values': [9.81, 0.0234, -0.1523],
        'unit': 'm/s²',
      };

      final data = SensorData.fromJson(json);

      expect(data.sensorType, 'accelerometer');
      expect(
        data.timestamp.millisecondsSinceEpoch,
        testTimestamp.millisecondsSinceEpoch,
      );
      expect(data.values, [9.81, 0.0234, -0.1523]);
      expect(data.unit, 'm/s²');
    });

    test('toCsv and fromCsv roundtrip compatible (via manual parse)', () {
      final data = SensorData(
        sensorType: 'gyroscope',
        values: [0.001, 0.002, 0.003],
        timestamp: testTimestamp,
        unit: 'rad/s',
      );

      final csv = data.toCsv();
      final parts = csv.split(',');

      // Manual parse (CSV format: type,timestamp,v1,v2,v3)
      expect(parts[0], 'gyroscope');
      expect(parts.length, 5); // type + timestamp + 3 values
      expect(double.parse(parts[2]), 0.0010);
      expect(double.parse(parts[3]), 0.0020);
      expect(double.parse(parts[4]), 0.0030);
    });

    test('handles empty values list', () {
      final data = SensorData(
        sensorType: 'custom',
        values: [],
        timestamp: testTimestamp,
      );

      expect(data.values.isEmpty, true);
      expect(data.toCsv(), 'custom,${testTimestamp.millisecondsSinceEpoch},');
    });
  });
}
