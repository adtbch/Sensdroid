import 'package:shared_preferences/shared_preferences.dart';

/// Application settings that can be persisted
/// User-configurable options for Sensdroid
class AppSettings {
  static const String _prefix = 'sensdroid_';

  // Keys
  static const String _keyBufferSize = '${_prefix}buffer_size';
  static const String _keySamplingRate = '${_prefix}sampling_rate';
  static const String _keyUSBbps = '${_prefix}usb_baudrate';
  static const String _keyWiFiEndpoint = '${_prefix}wifi_endpoint';
  static const String _keyWiFiPort = '${_prefix}wifi_port';
  static const String _keyPerformanceMode = '${_prefix}performance_mode';

  // Default values
  static const int defaultBufferSize = 10;
  static const int defaultSamplingRate = 50; // ms (20 Hz)
  static const int defaultUSBBaudRate = 115200;
  static const String defaultWiFiEndpoint = '/sensor-data';
  static const int defaultWiFiPort = 8080;
  static const bool defaultPerformanceMode = true; // high performance by default

  final SharedPreferences _prefs;

  AppSettings(this._prefs);

  /// Buffer size (number of sensor packets to batch before sending)
  int get bufferSize => _prefs.getInt(_keyBufferSize) ?? defaultBufferSize;
  set bufferSize(int value) => _prefs.setInt(_keyBufferSize, value);

  /// Sampling rate in milliseconds
  int get samplingRate => _prefs.getInt(_keySamplingRate) ?? defaultSamplingRate;
  set samplingRate(int value) => _prefs.setInt(_keySamplingRate, value);

  /// USB baud rate
  int get usbBaudRate => _prefs.getInt(_keyUSBbps) ?? defaultUSBBaudRate;
  set usbBaudRate(int value) => _prefs.setInt(_keyUSBbps, value);

  /// WiFi endpoint path (e.g., /sensor-data)
  String get wifiEndpoint => _prefs.getString(_keyWiFiEndpoint) ?? defaultWiFiEndpoint;
  set wifiEndpoint(String value) => _prefs.setString(_keyWiFiEndpoint, value);

  /// WiFi port
  int get wifiPort => _prefs.getInt(_keyWiFiPort) ?? defaultWiFiPort;
  set wifiPort(int value) => _prefs.setInt(_keyWiFiPort, value);

  /// Performance mode: true = high performance (lower latency, more CPU/battery)
  /// false = battery saver (higher latency, less resource usage)
  bool get performanceMode => _prefs.getBool(_keyPerformanceMode) ?? defaultPerformanceMode;
  set performanceMode(bool value) => _prefs.setBool(_keyPerformanceMode, value);

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.remove(_keyBufferSize);
    await _prefs.remove(_keySamplingRate);
    await _prefs.remove(_keyUSBbps);
    await _prefs.remove(_keyWiFiEndpoint);
    await _prefs.remove(_keyWiFiPort);
    await _prefs.remove(_keyPerformanceMode);
  }

  /// Print current settings for debugging
  Map<String, dynamic> toMap() {
    return {
      'bufferSize': bufferSize,
      'samplingRate': samplingRate,
      'usbBaudRate': usbBaudRate,
      'wifiEndpoint': wifiEndpoint,
      'wifiPort': wifiPort,
      'performanceMode': performanceMode,
    };
  }
}
