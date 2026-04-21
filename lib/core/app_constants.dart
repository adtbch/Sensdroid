/// App-wide constants and configuration values
class AppConstants {
  // Communication Protocol Type
  static const String protocolUSB = 'usb';

  // Sensor Update Rates (in milliseconds)
  static const int sensorUpdateFast = 50; // 20 Hz
  static const int sensorUpdateNormal = 100; // 10 Hz
  static const int sensorUpdateSlow = 200; // 5 Hz

  // Default Sampling Rate
  static const int defaultSamplingRate = sensorUpdateFast;
  static const bool allowSamplingRateChange = true;

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
  // App ini mendukung KEDUANYA. Untuk native USB, baudrate yang dipilih
  // biasanya di-ignore oleh CDC device tapi koneksi tetap berjalan normal.
  // ─────────────────────────────────────────────────────────────────────────
  static const int usbMinBaudRate = 9600;
  static const int usbDefaultBaudRate = 115200;
  static const int usbMaxBaudRate = 3000000;

  static const List<int> usbBaudRatePresets = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600,
    1500000,
    2000000,
    2500000,
    3000000,
  ];

  // VID Espressif untuk native USB ESP32-S3/S2/C3 (0x303A)
  // Sudah terdaftar di device_filter.xml agar Android mendeteksi device.
  static const int usbVidEspressifNative = 12346; // 0x303A

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
  static const String sensorYPR = 'YPR';

  // Error Messages
  static const String errorUSBNotConnected = 'USB device is not connected';
  static const String errorInvalidUSBBaudRate =
      'Invalid USB baud rate: must be 9600-3000000';
  static const String errorPermissionDenied = 'Required permission was denied';
}
