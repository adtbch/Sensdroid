import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensdroid/core/app_constants.dart';

/// Utility class to detect available sensors on the device
class SensorDetector {
  static final SensorDetector _instance = SensorDetector._internal();
  factory SensorDetector() => _instance;
  SensorDetector._internal();

  final Map<String, bool> _availableSensors = {};
  bool _isDetected = false;

  /// Get map of available sensors
  Map<String, bool> get availableSensors => Map.unmodifiable(_availableSensors);

  /// Check if detection has been performed
  bool get isDetected => _isDetected;

  /// Detect all available sensors on the device
  Future<Map<String, bool>> detectSensors() async {
    if (_isDetected && _availableSensors.isNotEmpty) {
      return _availableSensors;
    }

    // Run all sensor tests in PARALLEL (~2s total instead of ~8s sequential)
    final results = await Future.wait([
      _testAccelerometer(),
      _testGyroscope(),
      _testMagnetometer(),
      _testGPS(),
    ]);

    _availableSensors[AppConstants.sensorAccelerometer] = results[0];
    _availableSensors[AppConstants.sensorGyroscope] = results[1];
    _availableSensors[AppConstants.sensorMagnetometer] = results[2];
    _availableSensors[AppConstants.sensorGPS] = results[3];

    _isDetected = true;
    return _availableSensors;
  }

  /// Check if a specific sensor is available
  bool isSensorAvailable(String sensorType) {
    return _availableSensors[sensorType] ?? false;
  }

  Future<bool> _testAccelerometer() async {
    try {
      final stream = accelerometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw Exception('Timeout'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testGyroscope() async {
    try {
      final stream = gyroscopeEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw Exception('Timeout'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testMagnetometer() async {
    try {
      final stream = magnetometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw Exception('Timeout'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testGPS() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // GPS is only usable if permission is already granted
      // (whileInUse or always). 'denied' means not yet asked — NOT available.
      // 'deniedForever' means blocked — also NOT available.
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  /// Reset detection cache so the next call to detectSensors() re-tests everything.
  /// Call this after the user grants/revokes permissions.
  void resetCache() {
    _availableSensors.clear();
    _isDetected = false;
  }

  /// Reset detection (for re-testing)
  void reset() {
    resetCache();
  }
}
