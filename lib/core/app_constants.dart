/// App-wide constants and configuration values
class AppConstants {
  // Communication Protocol Types
  static const String protocolBluetooth = 'bluetooth';
  static const String protocolUSB = 'usb';
  static const String protocolWiFi = 'wifi';
  
  // Sensor Update Rates (in milliseconds)
  static const int sensorUpdateFast = 50;      // 20 Hz
  static const int sensorUpdateNormal = 100;   // 10 Hz
  static const int sensorUpdateSlow = 200;     // 5 Hz
  
  // Default Sampling Rate - Fixed to minimum latency
  static const int defaultSamplingRate = sensorUpdateFast; // 50ms = 20Hz for minimum latency
  static const bool allowSamplingRateChange = false; // Fixed sampling rate, no user control
  
  // WiFi Configuration
  static const int wifiDefaultPort = 8080;
  static const String wifiDefaultEndpoint = '/sensor-data';
  
  // USB Configuration
  // ─────────────────────────────────────────────────────────────────────────
  // PENTING: ESP32-S3 punya 2 port USB yang BERBEDA:
  //
  //  1. UART/COM port  → via chip CP2102 / CH340 (konverter serial)
  //                      VID: 4292 (CP210x) atau 6790 (CH340)
  //                      Baud rate berlaku normal (set 921600 harus match)
  //
  //  2. Native USB port → langsung GPIO19/20 ESP32-S3 (CDC on Boot)
  //                       VID: 12346 (0x303A, Espressif Systems)
  //                       Baud rate VIRTUAL / diabaikan oleh USB CDC
  //                       WAJIB: Arduino IDE → Tools → USB CDC on Boot → Enabled
  //
  // App ini mendukung KEDUANYA. Untuk native USB, nilai usbBaudRate
  // dikirim ke device tapi di-ignore — koneksi tetap berjalan normal.
  // ─────────────────────────────────────────────────────────────────────────
  static const int usbBaudRate = 921600;

  // VID Espressif untuk native USB ESP32-S3/S2/C3 (0x303A)
  // Sudah terdaftar di device_filter.xml agar Android mendeteksi device.
  static const int usbVidEspressifNative = 12346; // 0x303A

  // BLE UUIDs — must match ESP32 firmware exactly
  // Service: Environmental Sensing (0x181A)
  static const String bleServiceUuid = '0000181A-0000-1000-8000-00805f9b34fb';
  // Characteristic: Analog (0x2A58) — write target for sensor data
  static const String bleTxCharUuid  = '00002A58-0000-1000-8000-00805f9b34fb';
  
  // Data Packet Configuration
  static const String packetDelimiter = '\n';
  static const String fieldSeparator = ',';
  
  // Sensor Types
  static const String sensorAccelerometer = 'accelerometer';
  static const String sensorGyroscope = 'gyroscope';
  static const String sensorMagnetometer = 'magnetometer';
  static const String sensorGPS = 'gps';
  static const String sensorProximity = 'proximity';
  static const String sensorLight = 'light';
  
  // Error Messages
  static const String errorBluetoothNotAvailable = 'Bluetooth is not available on this device';
  static const String errorUSBNotConnected = 'USB device is not connected';
  static const String errorWiFiNotConnected = 'WiFi is not connected';
  static const String errorPermissionDenied = 'Required permission was denied';
}
