# Sensdroid PC Receiver Launcher
# Urutan: 1) cek device → 2) adb reverse → 3) jalankan Python receiver
# Gunakan: .\tools\start_receiver.ps1

$ADB = "C:\Android\Sdk\platform-tools\adb.exe"
$PORT = 7788

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sensdroid PC Receiver Launcher" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Cek ADB ada
if (-not (Test-Path $ADB)) {
    Write-Host "[ERROR] ADB tidak ditemukan di: $ADB" -ForegroundColor Red
    Write-Host "        Pastikan Android SDK terinstall." -ForegroundColor Red
    exit 1
}

# 2. Cek device tersambung
Write-Host "[1/3] Mengecek perangkat Android..." -ForegroundColor Yellow
$devices = & $ADB devices | Select-String -Pattern "device$"
if (-not $devices) {
    Write-Host "[ERROR] Tidak ada perangkat Android terdeteksi!" -ForegroundColor Red
    Write-Host "        Pastikan:" -ForegroundColor Red
    Write-Host "        - HP tersambung via kabel USB" -ForegroundColor Red
    Write-Host "        - USB Debugging diaktifkan" -ForegroundColor Red
    Write-Host "        - Izinkan koneksi ADB di HP jika ada popup" -ForegroundColor Red
    exit 1
}
Write-Host "        OK - Perangkat ditemukan: $($devices.Line.Trim())" -ForegroundColor Green

# 3. Setup ADB reverse
Write-Host "[2/3] Menjalankan adb reverse tcp:$PORT tcp:$PORT ..." -ForegroundColor Yellow
$result = & $ADB reverse tcp:$PORT tcp:$PORT 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] adb reverse gagal: $result" -ForegroundColor Red
    exit 1
}
Write-Host "        OK - Port $PORT berhasil di-forward ke PC" -ForegroundColor Green

# 4. Jalankan Python receiver
Write-Host "[3/3] Memulai Python receiver di port $PORT..." -ForegroundColor Yellow
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Sekarang di aplikasi Sensdroid:" -ForegroundColor White
Write-Host "  Settings → Target Device = PC" -ForegroundColor White
Write-Host "  Dashboard → Scan → 'PC via ADB TCP' → Connect" -ForegroundColor White
Write-Host "  Start Transmission" -ForegroundColor White
Write-Host "--------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Menunggu koneksi dari HP... (Ctrl+C untuk berhenti)" -ForegroundColor Cyan
Write-Host ""

python -u tools/receiver.py --port $PORT
