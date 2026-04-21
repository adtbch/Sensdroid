# Sensdroid (USB UART Only)

Sensdroid adalah aplikasi Flutter yang mengirim data sensor smartphone ke ESP/MCU melalui **USB OTG serial (UART)** dengan fokus latensi rendah.

## Fitur Utama

- Komunikasi **USB serial saja** (tanpa Bluetooth/WiFi).
- Scan dan connect ke device USB serial (CH340, CP210x, FTDI, Prolific, Espressif native USB CDC).
- Baudrate UART dapat diatur dari **9600** sampai **3000000 bps**.
- Pilih sensor yang aktif dikirim: accelerometer, gyroscope, magnetometer, GPS.
- Kontrol sampling rate dan statistik live (packets sent/dropped/rate).

## Stack Teknis

- Flutter + Provider (MVVM)
- `sensors_plus` (sensor stream)
- `geolocator` (GPS)
- `usb_serial` (USB OTG UART)
- `permission_handler`, `shared_preferences`

## Format Data ke ESP

Payload default menggunakan format biner 26 byte per paket (`SensorData.toBytes()`):

- Byte 0: sensor type id
- Byte 1-8: timestamp `uint64` (little-endian)
- Byte 9-24: 4 nilai `float32` (little-endian)
- Byte 25: checksum XOR

Format ini lebih ringkas dibanding CSV/JSON untuk throughput serial tinggi.

## Jalankan Project

```bash
flutter pub get
flutter run
```

## Struktur Arsitektur

- `lib/views/` untuk UI.
- `lib/viewmodels/` untuk state dan business logic.
- `lib/services/usb/` untuk implementasi serial USB.
- `lib/models/` untuk model data.

Detail teknis lengkap ada di `documentation.md`.