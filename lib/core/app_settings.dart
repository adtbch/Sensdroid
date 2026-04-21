import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensdroid/core/app_constants.dart';

/// Application settings that can be persisted
/// User-configurable options for Sensdroid
class AppSettings {
  static const String _prefix = 'sensdroid_';

  // Keys
  static const String _keyBufferSize = '${_prefix}buffer_size';
  static const String _keySamplingRate = '${_prefix}sampling_rate';
  static const String _keyUSBbps = '${_prefix}usb_baudrate';
  static const String _keyPerformanceMode = '${_prefix}performance_mode';

  // Default values
  static const int defaultBufferSize = 10;
  static const int defaultSamplingRate = AppConstants.defaultSamplingRate;
  static const int defaultUSBBaudRate = AppConstants.usbDefaultBaudRate;
  static const bool defaultPerformanceMode =
      true; // high performance by default

  final SharedPreferences _prefs;

  AppSettings(this._prefs);

  /// Buffer size (number of sensor packets to batch before sending)
  int get bufferSize => _prefs.getInt(_keyBufferSize) ?? defaultBufferSize;
  set bufferSize(int value) => _prefs.setInt(_keyBufferSize, value);

  /// Sampling rate in milliseconds
  int get samplingRate =>
      _prefs.getInt(_keySamplingRate) ?? defaultSamplingRate;
  set samplingRate(int value) => _prefs.setInt(_keySamplingRate, value);

  /// USB baud rate
  int get usbBaudRate => _prefs.getInt(_keyUSBbps) ?? defaultUSBBaudRate;
  set usbBaudRate(int value) {
    if (value >= AppConstants.usbMinBaudRate &&
        value <= AppConstants.usbMaxBaudRate) {
      _prefs.setInt(_keyUSBbps, value);
    }
  }

  /// Performance mode: true = high performance (lower latency, more CPU/battery)
  /// false = battery saver (higher latency, less resource usage)
  bool get performanceMode =>
      _prefs.getBool(_keyPerformanceMode) ?? defaultPerformanceMode;
  set performanceMode(bool value) => _prefs.setBool(_keyPerformanceMode, value);

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_keyBufferSize);
    await _prefs.remove(_keySamplingRate);
    await _prefs.remove(_keyUSBbps);
    await _prefs.remove(_keyPerformanceMode);
  }

  /// Print current settings for debugging
  Map<String, dynamic> toMap() {
    return {
      'bufferSize': bufferSize,
      'samplingRate': samplingRate,
      'usbBaudRate': usbBaudRate,
      'performanceMode': performanceMode,
    };
  }
}
