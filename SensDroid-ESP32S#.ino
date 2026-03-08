/*
 * ╔═══════════════════════════════════════════════════════════════════╗
 * ║          SENSDROID ESP32-S3 - Multi-Protocol Receiver            ║
 * ║                                                                   ║
 * ║  Description: Universal sensor data receiver for Android app     ║
 * ║  Protocols: USB Native CDC (GPIO19/20) | Bluetooth BLE | WiFi HTTP ║
 * ║  Commands: U=USB, B=Bluetooth, W=WiFi (via Serial)              ║
 * ║  Author: Sensdroid Project                                        ║
 * ║  Board: ESP32-S3                                                  ║
 * ║                                                                   ║
 * ║  Compatible with Sensdroid Android App:                          ║
 * ║  - Modern UI with Glassmorphism design                           ║
 * ║  - Bottom Navigation (Dashboard + Statistics)     /home/aditya/Documents/SensDroid-ESP32S#/SensDroid-ESP32S#.ino               ║
 * ║  - Configurable sampling rate (0-100ms)                          ║
 * ║  - Settings page for WiFi/USB/Performance config                 ║
 * ║                                                                   ║
 * ║  Data Format: 26-byte binary (BT/USB) | JSON (WiFi)             ║
 * ║  Version: 2.0 (Updated: 2026-02-24)                              ║
 * ╚═══════════════════════════════════════════════════════════════════╝
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

// Serial Configuration
// ─────────────────────────────────────────────────────────────────────────────
// ESP32-S3 DUAL SERIAL SETUP:
//
//  ┌─────────────────┬─────────────────┬──────────────────────────────────┐
//  │ Port            │ Pin             │ Fungsi                           │
//  ├─────────────────┼─────────────────┼──────────────────────────────────┤
//  │ Serial  (CDC)   │ GPIO19/20 (USB) │ DATA dari Android app (OTG)      │
//  │ Serial0 (UART)  │ GPIO43/44 (COM) │ DEBUG output ke Arduino IDE      │
//  └─────────────────┴─────────────────┴──────────────────────────────────┘
//
//  • Upload firmware  → tetap via COM port (chip CP2102/CH340, GPIO43/44)
//  • Android app data → via pin USB native ESP32-S3 (GPIO19/20, VID 0x303A)
//  • Serial (USB CDC) baud rate = VIRTUAL / diabaikan, kecepatan USB Full Speed
//  • Serial0 (UART)   baud rate = DEBUG_BAUD_RATE, bisa dibaca di Serial Monitor
//
//  WAJIB di Arduino IDE sebelum upload:
//    Tools → USB CDC on Boot → Enabled
// ─────────────────────────────────────────────────────────────────────────────
#define SERIAL_BAUD_RATE    921600   // Untuk UART Serial0; USB CDC mengabaikan nilai ini
#define DEBUG_BAUD_RATE     115200   // UART debug → terbaca di Arduino IDE Serial Monitor
#define COMMAND_SERIAL      Serial0  // Output debug/status → COM port (UART GPIO43/44)
#define DATA_SERIAL         Serial   // Binary data dari Android → native USB (GPIO19/20)

// WiFi Configuration
// NOTE: Android app Settings page allows WiFi endpoint configuration.
// Configure IP address (auto-assigned by DHCP) and port here.
// Android app will connect to http://<ESP32_IP>:<HTTP_SERVER_PORT>
#define WIFI_SSID           "SENSDROID"      // ⚠️ CHANGE THIS
#define WIFI_PASSWORD       "12345678"  // ⚠️ CHANGE THIS
#define HTTP_SERVER_PORT    8080             // Must match Android app settings

// BLE Configuration
#define BLE_DEVICE_NAME     "ESP32_Sensdroid"
#define BLE_SERVICE_UUID    "0000181A-0000-1000-8000-00805f9b34fb"  // Environmental Sensing
#define BLE_CHAR_UUID       "00002A58-0000-1000-8000-00805f9b34fb"  // Analog

// LED Configuration (Status Indicators)
#define LED_STATUS_PIN      2       // Built-in LED (connection status)
#define LED_DATA_PIN        4       // External LED (data receiving indicator)

// Data Configuration
#define PACKET_SIZE         26      // Binary packet size (bytes)
#define MAX_BUFFER_SIZE     512     // Maximum buffer for batched data

// ═══════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════

// Sensor packet structure (must match Android app - 26 bytes)
struct __attribute__((packed)) SensorPacket {
    uint8_t sensorType;      // Sensor type ID (0-5)
    uint64_t timestamp;      // Unix timestamp in milliseconds
    float values[4];         // Up to 4 sensor values
    uint8_t checksum;        // XOR checksum
};

// Protocol modes
enum Protocol {
    PROTOCOL_USB = 0,
    PROTOCOL_BLUETOOTH = 1,
    PROTOCOL_WIFI = 2
};

// ═══════════════════════════════════════════════════════════════════
// GLOBAL VARIABLES
// ═══════════════════════════════════════════════════════════════════

Protocol currentProtocol = PROTOCOL_USB;
bool isConnected = false;
uint32_t packetsReceived = 0;
uint32_t packetsDropped = 0;
unsigned long lastDataTime = 0;
unsigned long ledDataOffTime = 0;  // Timestamp kapan LED data harus dimatikan (non-blocking)

// BLE Objects
BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool bleDeviceConnected = false;

// WiFi Objects
WebServer httpServer(HTTP_SERVER_PORT);

// USB Buffer
uint8_t usbBuffer[MAX_BUFFER_SIZE];
size_t usbBufferIndex = 0;

// ═══════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

// Get sensor name from type ID
const char* getSensorName(uint8_t type) {
    switch(type) {
        case 0x00: return "Accelerometer";
        case 0x01: return "Gyroscope";
        case 0x02: return "Magnetometer";
        case 0x03: return "GPS";
        case 0x04: return "Proximity";
        case 0x05: return "Light";
        default: return "Unknown";
    }
}

// Get sensor unit from type ID
const char* getSensorUnit(uint8_t type) {
    switch(type) {
        case 0x00: return "m/s²";
        case 0x01: return "rad/s";
        case 0x02: return "µT";
        case 0x03: return "°/m/s";
        case 0x04: return "cm";
        case 0x05: return "lux";
        default: return "";
    }
}

// Verify XOR checksum
bool verifyChecksum(const uint8_t* data, size_t len) {
    if (len < 2) return false;
    
    uint8_t checksum = 0;
    for (size_t i = 0; i < len - 1; i++) {
        checksum ^= data[i];
    }
    
    bool valid = (checksum == data[len - 1]);
    if (!valid) {
        packetsDropped++;
    }
    
    return valid;
}

// LED control functions
void ledStatusOn() {
    digitalWrite(LED_STATUS_PIN, HIGH);
}

void ledStatusOff() {
    digitalWrite(LED_STATUS_PIN, LOW);
}

void ledDataBlink() {
    // Non-blocking blink: nyalakan LED, catat waktu mati.
    // LED dimatikan di loop() melalui checkLedDataOff().
    // Menggunakan delay() di sini akan memblokir CPU 10ms per packet,
    // menyebabkan miss data di sampling rate tinggi (≤10ms).
    digitalWrite(LED_DATA_PIN, HIGH);
    ledDataOffTime = millis() + 20;  // Mati 20ms kemudian
}

void checkLedDataOff() {
    if (ledDataOffTime > 0 && millis() >= ledDataOffTime) {
        digitalWrite(LED_DATA_PIN, LOW);
        ledDataOffTime = 0;
    }
}

void ledStatusBlink(int times, int delayMs = 100) {
    for (int i = 0; i < times; i++) {
        digitalWrite(LED_STATUS_PIN, HIGH);
        delay(delayMs);
        digitalWrite(LED_STATUS_PIN, LOW);
        delay(delayMs);
    }
}

// ═══════════════════════════════════════════════════════════════════
// DATA PROCESSING
// ═══════════════════════════════════════════════════════════════════

// Process and display sensor packet
// Data format: 26 bytes (1 type + 8 timestamp + 16 values + 1 checksum)
// Sent from Android app at sampling rate configured in Dashboard (0-100ms)
void processSensorPacket(const uint8_t* data) {
    // Verify checksum
    if (!verifyChecksum(data, PACKET_SIZE)) {
        COMMAND_SERIAL.println("⚠️  Checksum FAILED! Packet dropped.");
        COMMAND_SERIAL.println("   Check connection quality or reduce sampling rate.");
        return;
    }
    
    // ─────────────────────────────────────────────────────────────────────
    // PENTING: Jangan cast pointer langsung (SensorPacket*)data !
    // usbBuffer adalah uint8_t[] yang hanya 1-byte aligned, sementara
    // uint64_t timestamp di dalam struct butuh 8-byte alignment.
    // Direct cast → LoadStoreAlignment exception → ESP32 crash/reboot.
    // Solusi: memcpy ke struct lokal yang dijamin aligned oleh compiler.
    // ─────────────────────────────────────────────────────────────────────
    SensorPacket packet;  // Stack-allocated → dijamin aligned
    memcpy(&packet, data, PACKET_SIZE);
    
    // Update statistics
    packetsReceived++;
    lastDataTime = millis();
    
    // Blink data LED
    ledDataBlink();
    
    // Display formatted data
    COMMAND_SERIAL.println("┌─────────────────────────────────────────────────────────────┐");
    COMMAND_SERIAL.printf("│ 📊 Sensor: %-20s                       │\n", getSensorName(packet.sensorType));
    COMMAND_SERIAL.printf("│ ⏱️  Timestamp: %-20llu                    │\n", packet.timestamp);
    COMMAND_SERIAL.printf("│ 📈 Values: [%.4f, %.4f, %.4f, %.4f] %-6s       │\n", 
                          packet.values[0], 
                          packet.values[1], 
                          packet.values[2], 
                          packet.values[3],
                          getSensorUnit(packet.sensorType));
    COMMAND_SERIAL.printf("│ ✅ Packets: %lu | Dropped: %lu                            │\n", 
                          packetsReceived, packetsDropped);
    COMMAND_SERIAL.println("└─────────────────────────────────────────────────────────────┘");
}

// ═══════════════════════════════════════════════════════════════════
// USB SERIAL HANDLER
// ═══════════════════════════════════════════════════════════════════

void handleUSBData() {
    // DATA_SERIAL (Serial/USB CDC GPIO19/20) adalah port FISIK TERPISAH dari
    // COMMAND_SERIAL (Serial0/UART GPIO43/44).
    // SEMUA byte yang masuk di sini adalah binary packet dari Android.
    // TIDAK ADA command checking — command datang dari UART, bukan dari sini.
    while (DATA_SERIAL.available() > 0) {
        uint8_t byte = DATA_SERIAL.read();
        
        // Add to buffer
        if (usbBufferIndex < MAX_BUFFER_SIZE) {
            usbBuffer[usbBufferIndex++] = byte;
            
            // Process when we have a complete packet
            if (usbBufferIndex >= PACKET_SIZE) {
                processSensorPacket(usbBuffer);
                usbBufferIndex = 0;  // Reset buffer
            }
        } else {
            // Buffer overflow - reset
            COMMAND_SERIAL.println("⚠️  Buffer overflow! Resetting...");
            COMMAND_SERIAL.println("   Tip: Reduce sampling rate in Android Dashboard.");
            usbBufferIndex = 0;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// BLUETOOTH BLE HANDLER
// ═══════════════════════════════════════════════════════════════════

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleDeviceConnected = true;
        isConnected = true;
        ledStatusOn();
        COMMAND_SERIAL.println("✅ BLE Device connected!");
    };

    void onDisconnect(BLEServer* pServer) {
        bleDeviceConnected = false;
        isConnected = false;
        ledStatusOff();
        COMMAND_SERIAL.println("❌ BLE Device disconnected!");
        
        // Restart advertising
        BLEDevice::startAdvertising();
        COMMAND_SERIAL.println("📡 BLE Advertising restarted...");
    }
};

// BLE Characteristic Callbacks (data reception)
class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        // ESP32 core 3.x getValue() returns Arduino String, not std::string
        String value = pCharacteristic->getValue();
        
        if (value.length() == 0) return;
        
        // Convert to uint8_t* for processing
        const uint8_t* rawData = (const uint8_t*)value.c_str();
        size_t dataLength = value.length();
        
        // Process data in chunks of PACKET_SIZE bytes
        for (size_t i = 0; i + PACKET_SIZE <= dataLength; i += PACKET_SIZE) {
            const uint8_t* data = rawData + i;
            processSensorPacket(data);
        }
        
        // Handle incomplete packet
        if (dataLength % PACKET_SIZE != 0) {
            COMMAND_SERIAL.printf("⚠️  Incomplete BLE packet: %d bytes (expected multiple of %d)\n", 
                                  dataLength, PACKET_SIZE);
        }
    }
};

void initBluetooth() {
    COMMAND_SERIAL.println("🔵 Initializing Bluetooth BLE...");
    
    // Initialize BLE
    BLEDevice::init(BLE_DEVICE_NAME);
    
    // Create BLE Server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    
    // Create BLE Service
    BLEService *pService = pServer->createService(BLEUUID(BLE_SERVICE_UUID));
    
    // Create BLE Characteristic for writing
    pCharacteristic = pService->createCharacteristic(
        BLEUUID(BLE_CHAR_UUID),
        BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_WRITE_NR
    );
    
    pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
    
    // Start service
    pService->start();
    
    // Start advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(BLE_SERVICE_UUID));
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  // Help with iPhone connections
    pAdvertising->setMaxPreferred(0x12);
    BLEDevice::startAdvertising();
    
    COMMAND_SERIAL.println("✅ BLE Server started!");
    COMMAND_SERIAL.printf("   Device Name: %s\n", BLE_DEVICE_NAME);
    COMMAND_SERIAL.println("   Waiting for connection...");
}

// ═══════════════════════════════════════════════════════════════════
// WIFI HTTP HANDLER
// ═══════════════════════════════════════════════════════════════════

// Handle single sensor data (JSON)
void handleSensorDataJSON() {
    if (!httpServer.hasArg("plain")) {
        httpServer.send(400, "text/plain", "No data received");
        return;
    }
    
    String body = httpServer.arg("plain");
    
    // Parse JSON
    JsonDocument doc;  // ArduinoJson 7.x
    DeserializationError error = deserializeJson(doc, body);
    
    if (error) {
        COMMAND_SERIAL.printf("⚠️  JSON parsing failed: %s\n", error.c_str());
        httpServer.send(400, "text/plain", "Invalid JSON");
        return;
    }
    
    // Extract data
    const char* sensorType = doc["sensorType"];
    uint64_t timestamp = doc["timestamp"];
    JsonArray values = doc["values"].as<JsonArray>();
    const char* unit = doc["unit"];
    
    // Update statistics
    packetsReceived++;
    lastDataTime = millis();
    ledDataBlink();
    
    // Display data
    COMMAND_SERIAL.println("┌─────────────────────────────────────────────────────────────┐");
    COMMAND_SERIAL.printf("│ 📊 Sensor: %-20s (WiFi)                    │\n", sensorType);
    COMMAND_SERIAL.printf("│ ⏱️  Timestamp: %-20llu                    │\n", timestamp);
    COMMAND_SERIAL.print("│ 📈 Values: [");
    for (JsonVariant v : values) {
        COMMAND_SERIAL.printf("%.4f ", v.as<float>());
    }
    COMMAND_SERIAL.printf("] %-6s                        │\n", unit);
    COMMAND_SERIAL.printf("│ ✅ Packets: %lu | Dropped: %lu                            │\n", 
                          packetsReceived, packetsDropped);
    COMMAND_SERIAL.println("└─────────────────────────────────────────────────────────────┘");
    
    httpServer.send(200, "text/plain", "OK");
}

// Handle batch sensor data (JSON array)
void handleBatchJSON() {
    if (!httpServer.hasArg("plain")) {
        httpServer.send(400, "text/plain", "No data received");
        return;
    }
    
    String body = httpServer.arg("plain");
    
    // Parse JSON array
    JsonDocument doc;  // ArduinoJson 7.x - dynamic allocation
    DeserializationError error = deserializeJson(doc, body);
    
    if (error) {
        COMMAND_SERIAL.printf("⚠️  JSON parsing failed: %s\n", error.c_str());
        httpServer.send(400, "text/plain", "Invalid JSON");
        return;
    }
    
    JsonArray array = doc.as<JsonArray>();
    COMMAND_SERIAL.printf("📦 Batch received: %d packets (WiFi)\n", array.size());
    ledDataBlink();
    
    // Process each packet
    for (JsonObject item : array) {
        const char* sensorType = item["sensorType"];
        uint64_t timestamp = item["timestamp"];
        JsonArray values = item["values"].as<JsonArray>();
        const char* unit = item["unit"];
        
        packetsReceived++;
        
        COMMAND_SERIAL.printf("  • %s [", sensorType);
        for (JsonVariant v : values) {
            COMMAND_SERIAL.printf("%.4f ", v.as<float>());
        }
        COMMAND_SERIAL.printf("] %s\n", unit);
    }
    
    lastDataTime = millis();
    httpServer.send(200, "text/plain", "OK");
}

void initWiFi() {
    COMMAND_SERIAL.println("📶 Initializing WiFi...");
    COMMAND_SERIAL.printf("   SSID: %s\n", WIFI_SSID);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    // Wait for connection with timeout
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        COMMAND_SERIAL.print(".");
        attempts++;
    }
    COMMAND_SERIAL.println();
    
    if (WiFi.status() != WL_CONNECTED) {
        COMMAND_SERIAL.println("❌ WiFi connection failed!");
        COMMAND_SERIAL.println("   Please check SSID and password in code.");
        return;
    }
    
    COMMAND_SERIAL.println("✅ WiFi connected!");
    COMMAND_SERIAL.printf("   IP Address: %s\n", WiFi.localIP().toString().c_str());
    
    // Setup HTTP endpoints
    httpServer.on("/sensor-data", HTTP_POST, handleSensorDataJSON);
    httpServer.on("/batch", HTTP_POST, handleBatchJSON);
    
    // Root endpoint for testing
    httpServer.on("/", HTTP_GET, []() {
        String html = R"(
<!DOCTYPE html>
<html>
<head>
    <title>Sensdroid ESP32-S3</title>
    <style>
        body { font-family: Arial; padding: 20px; background: #1a1a1a; color: #fff; }
        .status { padding: 20px; background: #2a2a2a; border-radius: 8px; margin: 10px 0; }
        .stat { font-size: 24px; font-weight: bold; color: #4CAF50; }
    </style>
</head>
<body>
    <h1>🚀 Sensdroid ESP32-S3 Receiver</h1>
    <div class="status">
        <h2>📊 Statistics</h2>
        <p>Packets Received: <span class="stat">)" + String(packetsReceived) + R"(</span></p>
        <p>Packets Dropped: <span class="stat">)" + String(packetsDropped) + R"(</span></p>
        <p>Protocol: <span class="stat">WiFi HTTP</span></p>
    </div>
    <div class="status">
        <h2>📡 API Endpoints</h2>
        <p><code>POST /sensor-data</code> - Single sensor packet (JSON)</p>
        <p><code>POST /batch</code> - Batch sensor packets (JSON array)</p>
    </div>
</body>
</html>
        )";
        httpServer.send(200, "text/html", html);
    });
    
    httpServer.begin();
    isConnected = true;
    ledStatusOn();
    
    COMMAND_SERIAL.printf("🌐 HTTP Server started on port %d\n", HTTP_SERVER_PORT);
    COMMAND_SERIAL.println("   Endpoints:");
    COMMAND_SERIAL.printf("   - POST http://%s:%d/sensor-data\n", WiFi.localIP().toString().c_str(), HTTP_SERVER_PORT);
    COMMAND_SERIAL.printf("   - POST http://%s:%d/batch\n", WiFi.localIP().toString().c_str(), HTTP_SERVER_PORT);
}

// ═══════════════════════════════════════════════════════════════════
// PROTOCOL SWITCHING
// ═══════════════════════════════════════════════════════════════════

void switchProtocol(Protocol newProtocol) {
    if (newProtocol == currentProtocol) {
        COMMAND_SERIAL.println("ℹ️  Already using this protocol.");
        return;
    }
    
    // Cleanup current protocol
    ledStatusOff();
    isConnected = false;
    
    currentProtocol = newProtocol;
    
    // Switch to new protocol
    switch (currentProtocol) {
        case PROTOCOL_USB:
            COMMAND_SERIAL.println("\n╔═══════════════════════════════════════════════════════════╗");
            COMMAND_SERIAL.println("║        🔌 Switched to USB SERIAL Protocol                ║");
            COMMAND_SERIAL.println("╚═══════════════════════════════════════════════════════════╝");
            COMMAND_SERIAL.println("   Mode: Native USB CDC (GPIO19/20)");
            COMMAND_SERIAL.println("   Baud Rate: Virtual (diabaikan oleh USB CDC)");
            COMMAND_SERIAL.println("   Menunggu data dari Android app via USB OTG...");
            COMMAND_SERIAL.println();
            COMMAND_SERIAL.println("   📱 Android App Setup:");
            COMMAND_SERIAL.println("   1. Go to Dashboard page");
            COMMAND_SERIAL.println("   2. Select USB protocol");
            COMMAND_SERIAL.println("   3. Hubungkan kabel USB HP ↔ pin USB ESP32-S3");
            COMMAND_SERIAL.println("   4. Tap 'Connect' dan pilih ESP32 device");
            COMMAND_SERIAL.println("   5. Enable sensors dan start transmission");
            usbBufferIndex = 0;  // Reset buffer
            isConnected = true;
            ledStatusBlink(2, 100);
            ledStatusOn();
            break;
            
        case PROTOCOL_BLUETOOTH:
            COMMAND_SERIAL.println("\n╔═══════════════════════════════════════════════════════════╗");
            COMMAND_SERIAL.println("║        🔵 Switched to BLUETOOTH BLE Protocol             ║");
            COMMAND_SERIAL.println("╚═══════════════════════════════════════════════════════════╝");
            if (pServer == nullptr) {
                initBluetooth();
            } else {
                BLEDevice::startAdvertising();
                COMMAND_SERIAL.println("   BLE advertising restarted...");
            }
            COMMAND_SERIAL.println();
            COMMAND_SERIAL.println("   📱 Android App Setup:");
            COMMAND_SERIAL.println("   1. Go to Dashboard page");
            COMMAND_SERIAL.println("   2. Select Bluetooth protocol");
            COMMAND_SERIAL.println("   3. Tap 'Scan' to find devices");
            COMMAND_SERIAL.printf("   4. Connect to '%s'\n", BLE_DEVICE_NAME);
            COMMAND_SERIAL.println("   5. Enable sensors and start transmission");
            COMMAND_SERIAL.println("   6. Check Statistics page for real-time data");
            ledStatusBlink(3, 100);
            break;
            
        case PROTOCOL_WIFI:
            COMMAND_SERIAL.println("\n╔═══════════════════════════════════════════════════════════╗");
            COMMAND_SERIAL.println("║        📶 Switched to WIFI HTTP Protocol                 ║");
            COMMAND_SERIAL.println("╚═══════════════════════════════════════════════════════════╝");
            if (WiFi.status() != WL_CONNECTED) {
                initWiFi();
            } else {
                COMMAND_SERIAL.printf("   WiFi already connected: %s\n", WiFi.localIP().toString().c_str());
                isConnected = true;
                ledStatusOn();
            }
            COMMAND_SERIAL.println();
            COMMAND_SERIAL.println("   📱 Android App Setup:");
            COMMAND_SERIAL.println("   1. Go to Dashboard page");
            COMMAND_SERIAL.println("   2. Select WiFi protocol");
            COMMAND_SERIAL.println("   3. Go to Settings page");
            COMMAND_SERIAL.printf("   4. Enter IP: %s\n", WiFi.localIP().toString().c_str());
            COMMAND_SERIAL.printf("   5. Enter Port: %d\n", HTTP_SERVER_PORT);
            COMMAND_SERIAL.println("   6. Back to Dashboard, tap 'Connect'");
            COMMAND_SERIAL.println("   7. Enable sensors and start transmission");
            ledStatusBlink(4, 100);
            break;
    }
}

// Handle single-character commands
void handleCommand(char cmd) {
    cmd = toupper(cmd);  // Convert to uppercase
    
    COMMAND_SERIAL.printf("\n📥 Command received: '%c'\n", cmd);
    COMMAND_SERIAL.println("   Note: Protocol switching via serial command.");
    COMMAND_SERIAL.println("   Android app will auto-connect to active protocol.\n");
    
    switch (cmd) {
        case 'U':
            switchProtocol(PROTOCOL_USB);
            break;
        case 'B':
            switchProtocol(PROTOCOL_BLUETOOTH);
            break;
        case 'W':
            switchProtocol(PROTOCOL_WIFI);
            break;
        case 'S':
            printStatus();
            break;
        case 'R':
            COMMAND_SERIAL.println("🔄 Resetting statistics...");
            packetsReceived = 0;
            packetsDropped = 0;
            COMMAND_SERIAL.println("✅ Statistics reset!");
            break;
        case 'H':
            printHelp();
            break;
        default:
            COMMAND_SERIAL.printf("⚠️  Unknown command: '%c'\n", cmd);
            COMMAND_SERIAL.println("   Type 'H' for help.");
            break;
    }
}

// Print current status
void printStatus() {
    COMMAND_SERIAL.println("\n╔═══════════════════════════════════════════════════════════╗");
    COMMAND_SERIAL.println("║                  📊 SYSTEM STATUS                         ║");
    COMMAND_SERIAL.println("╠═══════════════════════════════════════════════════════════╣");
    
    // Current Protocol
    COMMAND_SERIAL.print("║ Protocol: ");
    switch (currentProtocol) {
        case PROTOCOL_USB:
            COMMAND_SERIAL.println("USB CDC Native (GPIO19/20, Full Speed)         ║");
            break;
        case PROTOCOL_BLUETOOTH:
            COMMAND_SERIAL.println("Bluetooth BLE                                  ║");
            break;
        case PROTOCOL_WIFI:
            COMMAND_SERIAL.println("WiFi HTTP                                      ║");
            break;
    }
    
    // Connection Status
    COMMAND_SERIAL.printf("║ Connected: %-43s ║\n", isConnected ? "✅ Yes" : "❌ No");
    
    // Statistics
    COMMAND_SERIAL.printf("║ Packets Received: %-35lu ║\n", packetsReceived);
    COMMAND_SERIAL.printf("║ Packets Dropped: %-36lu ║\n", packetsDropped);
    
    // Calculate success rate
    if (packetsReceived + packetsDropped > 0) {
        float successRate = (float)packetsReceived / (packetsReceived + packetsDropped) * 100.0f;
        COMMAND_SERIAL.printf("║ Success Rate: %-35.2f%% ║\n", successRate);
    }
    
    // Last Data Time
    if (lastDataTime > 0) {
        unsigned long timeSince = (millis() - lastDataTime) / 1000;
        COMMAND_SERIAL.printf("║ Last Data: %-27lu seconds ago ║\n", timeSince);
    } else {
        COMMAND_SERIAL.println("║ Last Data: Never                                          ║");
    }
    
    // WiFi Info
    if (currentProtocol == PROTOCOL_WIFI && WiFi.status() == WL_CONNECTED) {
        String ip = WiFi.localIP().toString();
        COMMAND_SERIAL.printf("║ IP Address: %-42s ║\n", ip.c_str());
        COMMAND_SERIAL.println("║                                                           ║");
        COMMAND_SERIAL.println("║ 💡 Configure this IP in Android App Settings page        ║");
    }
    
    // BLE Info
    if (currentProtocol == PROTOCOL_BLUETOOTH) {
        COMMAND_SERIAL.printf("║ BLE Device: %-42s ║\n", BLE_DEVICE_NAME);
        COMMAND_SERIAL.println("║                                                           ║");
        COMMAND_SERIAL.println("║ 💡 Scan for this device in Android App Dashboard         ║");
    }
    
    // USB Info
    if (currentProtocol == PROTOCOL_USB) {
        COMMAND_SERIAL.println("║                                                           ║");
        COMMAND_SERIAL.println("║ 💡 Android → connect via pin USB native (GPIO19/20)      ║");
        COMMAND_SERIAL.println("║ 💡 Baud rate diabaikan — USB CDC Full Speed              ║");
    }
    
    COMMAND_SERIAL.println("╚═══════════════════════════════════════════════════════════╝\n");
}

// Print help menu
void printHelp() {
    COMMAND_SERIAL.println("\n╔═══════════════════════════════════════════════════════════╗");
    COMMAND_SERIAL.println("║                   📖 COMMAND HELP                         ║");
    COMMAND_SERIAL.println("╠═══════════════════════════════════════════════════════════╣");
    COMMAND_SERIAL.println("║ U - Switch to USB Serial protocol                         ║");
    COMMAND_SERIAL.println("║ B - Switch to Bluetooth BLE protocol                      ║");
    COMMAND_SERIAL.println("║ W - Switch to WiFi HTTP protocol                          ║");
    COMMAND_SERIAL.println("║ S - Show current status                                   ║");
    COMMAND_SERIAL.println("║ R - Reset statistics                                      ║");
    COMMAND_SERIAL.println("║ H - Show this help menu                                   ║");
    COMMAND_SERIAL.println("╠═══════════════════════════════════════════════════════════╣");
    COMMAND_SERIAL.println("║ 💡 ANDROID APP TIPS:                                     ║");
    COMMAND_SERIAL.println("║ • Use Dashboard for protocol selection & sensor control   ║");
    COMMAND_SERIAL.println("║ • Adjust sampling rate slider (0-100ms) for data rate     ║");
    COMMAND_SERIAL.println("║ • Check Statistics page for real-time data & metrics      ║");
    COMMAND_SERIAL.println("║ • Configure WiFi/USB in Settings page before connecting   ║");
    COMMAND_SERIAL.println("╚═══════════════════════════════════════════════════════════╝\n");
}

// ═══════════════════════════════════════════════════════════════════
// SETUP & MAIN LOOP
// ═══════════════════════════════════════════════════════════════════

void setup() {
    // ── Debug UART (Serial0, GPIO43/44) ──────────────────────────────────────
    // Selalu aktif via COM port. Bisa dibuka di Arduino IDE Serial Monitor
    // bahkan saat Android sedang connect via USB native.
    COMMAND_SERIAL.begin(DEBUG_BAUD_RATE);   // Serial0 = UART GPIO43/44
    delay(100);

    // ── Native USB CDC (Serial, GPIO19/20) ───────────────────────────────────
    // Menerima binary data dari Android via USB OTG.
    // Baud rate diabaikan (USB Full Speed), begin() hanya mengaktifkan CDC.
    // Wajib: Arduino IDE → Tools → USB CDC on Boot → Enabled
    DATA_SERIAL.begin(SERIAL_BAUD_RATE);     // Serial = USB CDC GPIO19/20
    // Tidak tunggu DATA_SERIAL (android mungkin belum connect saat boot)

    // Wait up to 3 seconds for debug UART to be ready
    while (!COMMAND_SERIAL && millis() < 3000);

    // Allow time for serial monitor to connect
    delay(500);
    
    // Initialize LEDs
    pinMode(LED_STATUS_PIN, OUTPUT);
    pinMode(LED_DATA_PIN, OUTPUT);
    ledStatusOff();
    digitalWrite(LED_DATA_PIN, LOW);
    
    // Startup animation
    for (int i = 0; i < 3; i++) {
        digitalWrite(LED_STATUS_PIN, HIGH);
        digitalWrite(LED_DATA_PIN, HIGH);
        delay(100);
        digitalWrite(LED_STATUS_PIN, LOW);
        digitalWrite(LED_DATA_PIN, LOW);
        delay(100);
    }
    
    // Print banner
    COMMAND_SERIAL.println("\n\n");
    COMMAND_SERIAL.println("╔════════════════════════════════════════════════════════════╗");
    COMMAND_SERIAL.println("║                                                            ║");
    COMMAND_SERIAL.println("║          🚀 SENSDROID ESP32-S3 RECEIVER 🚀                ║");
    COMMAND_SERIAL.println("║                                                            ║");
    COMMAND_SERIAL.println("║            Multi-Protocol Sensor Data Gateway             ║");
    COMMAND_SERIAL.println("║                                                            ║");
    COMMAND_SERIAL.println("╚════════════════════════════════════════════════════════════╝");
    COMMAND_SERIAL.println();
    COMMAND_SERIAL.println("📋 System Information:");
    COMMAND_SERIAL.printf("   • Board: ESP32-S3\n");
    COMMAND_SERIAL.printf("   • Debug UART (Serial0 GPIO43/44): %d baud\n", DEBUG_BAUD_RATE);
    COMMAND_SERIAL.printf("   • Data USB CDC (Serial GPIO19/20): Full Speed (baud ignored)\n");
    COMMAND_SERIAL.printf("   • Packet Size: %d bytes\n", PACKET_SIZE);
    COMMAND_SERIAL.printf("   • Status LED: GPIO %d\n", LED_STATUS_PIN);
    COMMAND_SERIAL.printf("   • Data LED: GPIO %d\n", LED_DATA_PIN);
    COMMAND_SERIAL.println();
    COMMAND_SERIAL.println("📱 Android App Compatibility:");
    COMMAND_SERIAL.println("   • UI: Modern Glassmorphism w/ Bottom Navigation");
    COMMAND_SERIAL.println("   • Dashboard: Protocol selector + Sensor control");
    COMMAND_SERIAL.println("   • Statistics: Real-time data + Raw values");
    COMMAND_SERIAL.println("   • Settings: WiFi/USB config + Performance mode");
    COMMAND_SERIAL.println("   • Sampling Rate: 0-100ms (configurable in Dashboard)");
    COMMAND_SERIAL.println();
    
    // Initialize all protocols
    COMMAND_SERIAL.println("🔧 Initializing protocols...");
    COMMAND_SERIAL.println();
    
    // Initialize Bluetooth
    initBluetooth();
    COMMAND_SERIAL.println();
    
    // Initialize WiFi
    initWiFi();
    COMMAND_SERIAL.println();
    
    // Start with USB protocol
    switchProtocol(PROTOCOL_USB);
    
    // Print help
    printHelp();
    
    COMMAND_SERIAL.println("✅ System ready! Waiting for data or commands...\n");
}

void loop() {
    // ─────────────────────────────────────────────────────────────────────
    // COMMAND_SERIAL (Serial0/UART) dan DATA_SERIAL (Serial/USB CDC) sudah
    // merupakan port FISIK BERBEDA — tidak ada konflik.
    // Commands selalu bisa dibaca via UART tanpa mengganggu USB data.
    // ─────────────────────────────────────────────────────────────────────

    // Handle serial commands dari UART (Arduino IDE Serial Monitor)
    if (COMMAND_SERIAL.available() > 0) {
        char cmd = COMMAND_SERIAL.read();
        if (isprint(cmd)) {
            handleCommand(cmd);
        }
    }

    // Non-blocking LED data indicator
    checkLedDataOff();
    
    // Protocol-specific handlers
    switch (currentProtocol) {
        case PROTOCOL_USB:
            // Cek apakah Android sedang terkoneksi via USB CDC.
            // DATA_SERIAL (Serial/CDC) bernilai true jika host sudah membuka port.
            {
                bool usbCdcConnected = (bool)DATA_SERIAL;
                if (usbCdcConnected != isConnected) {
                    isConnected = usbCdcConnected;
                    if (isConnected) {
                        ledStatusOn();
                        COMMAND_SERIAL.println("✅ Android connected via USB CDC!");
                    } else {
                        ledStatusOff();
                        COMMAND_SERIAL.println("❌ Android disconnected from USB CDC.");
                        usbBufferIndex = 0;  // Buang buffer yang mungkin korup
                    }
                }
            }
            handleUSBData();
            break;
            
        case PROTOCOL_BLUETOOTH:
            // BLE handles data via callbacks
            // Just monitor connection status
            if (bleDeviceConnected != isConnected) {
                isConnected = bleDeviceConnected;
                if (isConnected) {
                    ledStatusOn();
                } else {
                    ledStatusOff();
                }
            }
            break;
            
        case PROTOCOL_WIFI:
            // Handle HTTP requests
            httpServer.handleClient();
            
            // Update connection status based on WiFi
            bool wifiConnected = (WiFi.status() == WL_CONNECTED);
            if (wifiConnected != isConnected) {
                isConnected = wifiConnected;
                if (isConnected) {
                    ledStatusOn();
                } else {
                    ledStatusOff();
                }
            }
            break;
    }
}
