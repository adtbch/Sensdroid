# Sensdroid Documentation (USB UART Only)

## 1. Gambaran Umum

`Sensdroid` adalah aplikasi Android berbasis Flutter untuk streaming data sensor ponsel ke ESP melalui **USB OTG serial (UART)**.

Versi saat ini sengaja difokuskan ke satu protokol:

- USB serial UART (`usb_serial`)
- Tanpa Bluetooth
- Tanpa WiFi/HTTP

Fokus utama implementasi:

- Latensi rendah
- Pipeline data konsisten
- UI sederhana untuk scan/connect USB, atur baudrate, dan start/stop transmisi
- Mode fusion YPR dengan output derajat `-180..180`

---

## 2. Arsitektur (MVVM + Service)

### View

UI hanya membaca state dari `SensorViewModel` dan memicu action:

- scan/connect/disconnect USB
- update baudrate
- toggle sensor
- start/stop transmisi

### ViewModel

`SensorViewModel` adalah pusat orkestrasi:

- state koneksi USB
- state transmisi dan statistik
- langganan stream sensor
- buffering + flush batch ke service
- sinkronisasi setting (sampling + baudrate)

### Service

`USBService` menangani operasi hardware USB serial:

- scan perangkat
- buka/tutup port
- set parameter UART
- kirim paket tunggal/batch

### Model

- `SensorData`: representasi data sensor + serializer biner
- `ConnectionInfo`: status koneksi

---

## 3. Alur Frontend <-> Hardware ESP

1. User scan device USB dari dashboard.
2. User pilih device lalu connect.
3. ViewModel memastikan baudrate dari settings diterapkan ke `USBService`.
4. Saat start transmission:
   - sensor stream aktif sesuai sensor yang di-enable
   - data masuk buffer
   - buffer di-flush periodik/bila penuh
5. `USBService` mengirim batch data biner ke UART ESP.
6. Statistik `sent/dropped/rate` diperbarui real-time.

---

## 4. UART & Baudrate

Rentang baudrate yang didukung aplikasi:

- Minimum: `9600`
- Default: `115200`
- Maksimum: `3000000`

Preset di UI:

- 9600, 19200, 38400, 57600
- 115200, 230400, 460800, 921600
- 1500000, 2000000, 2500000, 3000000

Catatan praktis:

- UART bridge (CH340/CP210x/FTDI) butuh baudrate yang match dengan firmware ESP.
- Native USB CDC ESP bisa mengabaikan baudrate secara virtual, namun aplikasi tetap menyet nilai baudrate agar kompatibel lintas adapter.

---

## 5. YPR Fusion (Derajat + Realtime)

Mode `3D Sensor Fusion (YPR)` menggabungkan accelerometer + gyroscope + magnetometer dengan complementary filter.

Perilaku saat ini:

- Nilai `yaw`, `pitch`, `roll` dikonversi ke **derajat** dan dinormalisasi ke rentang `[-180, 180]`.
- Paket YPR dari `SensorViewModel` memakai unit `deg`.
- Tampilan Statistics menampilkan metrik YPR dalam derajat (`°`) dengan label `deg (-180..180)`.
- Visualisasi 3D tetap memakai radian internal untuk rotasi matrix yang stabil.

Perbaikan latency & presisi (untuk kontrol robot):

- **Single source of truth:** fusion dihitung di `SensorViewModel`, UI hanya render.
- **Yaw low-latency:** yaw diintegrasikan dari **gyro Z** (respons cepat), lalu dikoreksi perlahan oleh magnetometer (mengurangi drift tanpa menambah lag besar).
- **Fusion preview:** `StatisticsPage` memanggil `startFusionPreview()` agar stream fused YPR tetap tersedia walau transmission belum aktif.

Optimasi latency pada halaman Statistics:

- `StatisticsPage` subscribe ke `SensorViewModel.fusedOrientationStream` (radian) untuk visualisasi 3D dan konversi derajat untuk display.
- Saat fusion aktif, listener raw IMU di halaman Statistics dimatikan untuk mengurangi beban CPU dan menghindari duplikasi komputasi.

---

## 6. Format Data Serial

`SensorData.toBytes()` memakai frame biner 26 byte:

- Byte 0: sensor type id
- Byte 1-8: timestamp `uint64` little-endian
- Byte 9-24: 4 x `float32` little-endian
- Byte 25: checksum XOR

Keuntungan:

- payload kecil
- parsing cepat di ESP
- integritas data dengan checksum

---

## 7. Folder Mapping

### Root

- `README.md`: ringkasan project dan quick start
- `documentation.md`: dokumen teknis terperinci
- `pubspec.yaml`: dependency Flutter

### `lib/core/`

- `app_constants.dart`: konstanta protokol USB, baudrate, sensor id, error text
- `app_settings.dart`: akses setting persisten (`SharedPreferences`)
- `batch_sender.dart`: util batching tambahan
- `logger.dart`: logger factory

### `lib/models/`

- `sensor_data.dart`: model data sensor + serializer biner/json
- `connection_info.dart`: model state koneksi

### `lib/services/`

- `communication_service.dart`: kontrak service komunikasi
- `usb/usb_service.dart`: implementasi USB OTG UART

### `lib/viewmodels/`

- `sensor_viewmodel.dart`: state management utama, transmisi USB, dan output YPR fusion derajat `-180..180`

### `lib/views/`

- `pages/dashboard_page.dart`: halaman kontrol USB utama
- `pages/statistics_page.dart`: statistik + raw sensor data + tampilan YPR realtime dalam derajat
- `pages/sensors_page.dart`: panel sensor (tetap tersedia)
- `pages/main_navigation.dart`: bottom navigation
- `settings_page.dart`: pengaturan baudrate/transmission
- `widgets/device_scan_dialog.dart`: dialog scan USB serial
- `widgets/error_dialog.dart`: dialog error reusable
- `widgets/animated_status_dot.dart`: indikator status koneksi/transmisi
- `widgets/sensor_value_bar.dart`: bar visualisasi nilai sensor per axis

### `lib/utils/`

- `sensor_detector.dart`: deteksi ketersediaan sensor
- `isolate_processor.dart`: util isolate

### `android/`

- `AndroidManifest.xml`: permission USB + sensor, plus USB attach intent filter
- `res/xml/device_filter.xml`: whitelist vendor ID USB serial

### `test/`

- `test/unit/viewmodels/sensor_viewmodel_test.dart`: unit test ViewModel
- `test/unit/models/sensor_data_test.dart`: unit test serializer data sensor
- `test/widget_test.dart`: smoke test UI dasar

---

## 8. Permission & Platform

Manifest saat ini hanya memuat permission yang relevan untuk mode USB + sensor.

- USB host feature
- USB attach intent
- GPS/location (hanya diperlukan jika GPS sensor aktif)

---

## 9. Status Validasi

Hasil validasi terbaru:

- `flutter test test/unit/viewmodels/sensor_viewmodel_test.dart test/widget_test.dart` -> lulus.
- `flutter analyze --no-fatal-infos` -> tanpa error blocking, masih ada info lint style/deprecation existing (`withOpacity`).

---

## 10. Catatan Pengembangan Lanjutan

Potensi peningkatan berikutnya:

1. Migrasi `withOpacity` ke API `withValues` pada seluruh UI.
2. Menambahkan parser/monitor data balik dari ESP (RX stream) untuk debug link UART dua arah.
3. Menambahkan profil performa per baudrate untuk rekomendasi otomatis di UI.