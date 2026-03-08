# Sensdroid Project Documentation

## Project Overview

**Sensdroid** is a high-performance Flutter Android application that serves as a universal data gateway for transmitting real-time sensor data from smartphones to microcontrollers (ESP32/Arduino) or PCs with ultra-low latency.

---

## Architecture: MVVM Pattern

The project strictly follows the **Model-View-ViewModel (MVVM)** architectural pattern combined with a service-based layer for hardware communication.

### Architecture Layers

```
┌─────────────────────────────────────────┐
│              View Layer                  │
│    (UI Components - Flutter Widgets)    │
└──────────────┬──────────────────────────┘
               │
               ├─ Observes State
               │
┌──────────────▼──────────────────────────┐
│         ViewModel Layer                  │
│   (Business Logic & State Management)   │
└──────────────┬──────────────────────────┘
               │
               ├─ Interacts via Abstraction
               │
┌──────────────▼──────────────────────────┐
│          Service Layer                   │
│  (Hardware Communication - Abstract)     │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴──────┬──────────┐
       │              │          │
┌──────▼─────┐ ┌──────▼─────┐ ┌─▼──────────┐
│ Bluetooth  │ │    USB     │ │    WiFi    │
│  Service   │ │  Service   │ │  Service   │
└────────────┘ └────────────┘ └────────────┘
               │
┌──────────────▼──────────────────────────┐
│           Model Layer                    │
│     (Data Classes - No Logic)           │
└─────────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── core/                              # Core utilities and constants
│   └── app_constants.dart            # App-wide constants
├── models/                            # Data models (no business logic)
│   ├── sensor_data.dart              # Sensor data representation
│   └── connection_info.dart          # Connection state model
├── views/                             # UI Layer (Flutter widgets)
│   ├── pages/                        # Full-screen pages
│   │   ├── main_navigation.dart      # Bottom navigation container
│   │   ├── dashboard_page.dart       # Main control dashboard
│   │   ├── statistics_page.dart      # Statistics & raw data display
│   │   ├── home_page.dart            # Legacy page (deprecated)
│   │   └── sensors_page.dart         # Sensor overview
│   ├── settings_page.dart            # App settings & configuration
│   └── widgets/                      # Reusable UI components
│       └── device_scan_dialog.dart   # Device scanning dialog
├── viewmodels/                        # Business logic & state
│   └── sensor_viewmodel.dart         # Manages sensor & transmission state
└── services/                          # Hardware communication layer
    ├── communication_service.dart    # Abstract service interface
    ├── bluetooth/
    │   └── bluetooth_service.dart    # Bluetooth implementation
    ├── usb/
    │   └── usb_service.dart          # USB OTG implementation
    └── wifi/
        └── wifi_service.dart         # WiFi/HTTP implementation
```

---

## Folder Descriptions

### `/lib/core/`
Contains app-wide constants, configurations, and utility classes that are used across the entire application.

- **`app_constants.dart`**: Defines protocol types, sensor types, default values, error messages, and configuration constants.

### `/lib/models/`
Pure data classes representing sensor readings and connection states. **No business logic** should exist in this layer.

- **`sensor_data.dart`**: Represents data from various device sensors with timestamp and unit information. Includes serialization methods (Binary and JSON).
- **`connection_info.dart`**: Represents connection state, device information, and error messages for current communication protocol.

### `/lib/views/`
Flutter UI components organized into pages and reusable widgets. Views are "dumb" and only react to state changes from ViewModels.

**Modern UI Features:**
- **Glassmorphism Design**: Frosted glass effect with backdrop blur
- **Blue Tech Theme**: Cyan (#00D9FF) primary with dark blue background
- **Bottom Navigation**: 2 tabs (Dashboard + Statistics) for organized UX
- **Responsive Animations**: Smooth transitions and state changes

**Pages:**
- **`main_navigation.dart`**: Bottom navigation container with 2 tabs
  - Uses IndexedStack to preserve state across tab switches
  - Glassmorphism bottom bar with blur effect
  
- **`dashboard_page.dart`**: Main control center providing:
  - Protocol selection (Bluetooth/USB/WiFi) with animated tabs
  - Device scanning and connection management
  - **Sampling rate control slider (0-100ms)** - always visible
  - Sensor overview badges (when connected)
  - Transmission start/stop controls
  - Real-time connection status
  
- **`statistics_page.dart`**: Dual-tab display with:
  - **Statistics Tab**: Packets sent/dropped, transmission rate, duration
  - **Raw Data Tab**: Real-time sensor values with pause/reset controls
  - Live data indicators and charts
  
- **`sensors_page.dart`**: Detailed sensor information and status

- **`settings_page.dart`**: App configuration:
  - WiFi endpoint configuration (IP + Port)
  - USB baud rate settings
  - Performance mode toggle
  - Reset to defaults option

**Widgets:**
- **`device_scan_dialog.dart`**: Modern scanning dialog with:
  - Glassmorphism design
  - Device name + address display
  - "NAMED" badge for identified devices
  - Animated scan progress
  - Error/empty states

### `/lib/viewmodels/`
Manages application state and business logic. ViewModels interact with services and notify views of state changes.

- **`sensor_viewmodel.dart`**: Core ViewModel responsible for:
  - Sensor stream subscriptions (accelerometer, gyroscope, magnetometer, GPS)
  - Protocol switching between Bluetooth, USB, and WiFi
  - Connection management
  - Data batching and transmission
  - Permission handling
  - Statistics tracking (packets sent, dropped, transmission rate)

### `/lib/services/`
Hardware communication layer with abstract interface and concrete implementations.

#### **`communication_service.dart`** (Abstract Base Class)
Defines the contract that all communication services must implement:
- `initialize()`: Initialize the service
- `connect(address)`: Connect to device/endpoint
- `disconnect()`: Disconnect from current connection
- `sendData(data)`: Send single sensor data packet
- `sendBatch(dataList)`: Send multiple packets efficiently
- `scan()`: Discover available devices
- `isAvailable()`: Check if protocol is available on device
- Stream-based connection state updates

#### **Bluetooth Service** (`bluetooth/bluetooth_service.dart`)
- Uses `flutter_blue_plus` package
- Supports BLE (Bluetooth Low Energy)
- Device scanning with timeout
- Characteristic-based data transmission
- Automatic service discovery

#### **USB Service** (`usb/usb_service.dart`)
- Uses `usb_serial` package
- Supports USB OTG serial communication
- Compatible with CH340, CP2102, FTDI, Prolific adapters
- Configurable baud rate (default: 115200)
- Batch transmission optimization

#### **WiFi Service** (`wifi/wifi_service.dart`)
- Uses `dio` for HTTP requests
- RESTful API communication
- JSON payload format
- Batch endpoint support (`/batch`)
- Configurable IP address and port

---

## Communication Flow

### Data Transmission Pipeline

```
Sensor Hardware
      │
      ├─► Sensor Stream (accelerometer, gyroscope, etc.)
      │
      ▼
SensorViewModel
      │
      ├─► Create SensorData objects with timestamp
      ├─► Add to buffer (max 10 items)
      │
      ▼
Data Buffer
      │
      ├─► Flush when full or on timer (sampling rate)
      ├─► Encode to Binary (BT/USB) or JSON (WiFi)
      │
      ▼
CommunicationService (abstraction)
      │
      ├─► Route to active service
      │
      ▼
┌─────┴─────┬─────────┬─────────┐
│           │         │         │
Bluetooth   USB      WiFi      Device
Service     Service  Service   (ESP32/PC)
│ (Binary)  │(Binary) │ (JSON)
▼           ▼         ▼
ESP32/BT   ESP32/USB  ESP32/WiFi or PC
```

---

## Key Features Implementation

### 1. **Protocol Agnosticism**
The `CommunicationService` abstraction allows seamless protocol switching without rewriting core logic. The ViewModel only interacts with the abstract interface.

### 2. **Modular Sensor Control**
Users can enable/disable specific sensors via UI checklist. The ViewModel only subscribes to enabled sensors, optimizing battery and CPU usage.

### 3. **Low-Latency Streaming**
- **Streams**: Asynchronous sensor streams prevent UI blocking
- **Isolates**: Could be implemented for heavy data processing (future enhancement)
- **Batching**: Multiple sensor readings batched before transmission to reduce overhead

### 4. **Efficient Binary Encoding**
- **26-byte packets**: 50-60% smaller than text-based formats
- **Zero parsing overhead**: ESP can directly cast bytes to struct
- **Built-in checksum**: XOR validation for data integrity
- **Fixed-size packets**: Predictable memory allocation on microcontrollers
- Protocol-specific: Binary for BT/USB, JSON for WiFi

### 5. **Adjustable Sampling Rate**
Sampling rate is user-configurable from **0ms to 100ms** (0Hz to ∞Hz). This allows:
- **0-10ms**: Ultra-fast real-time control (robotics, drones)
- **20-50ms**: Balanced performance and battery life
- **50-100ms**: Power-efficient long-term monitoring
- Real-time frequency display (Hz)
- Disabled during transmission to prevent corruption

### 6. **Robust Error Handling**
- Connection state tracking with error messages
- Permission request handling for Bluetooth, Location, and Sensors
- Graceful fallback for failed batch transmissions
- Packet drop counting for monitoring

---

## Data Format

Sensdroid uses **efficient binary format** for Bluetooth and USB transmission, and **JSON format** for WiFi transmission.

### Binary Format (Bluetooth/USB) - RECOMMENDED

**26 bytes per packet - 50-60% smaller than CSV!**

Sensdroid transmits sensor data in a highly efficient binary format optimized for microcontrollers:

```
╔══════════════════════════════════════════════════════════════╗
║  Byte 0   │  Bytes 1-8   │   Bytes 9-24    │   Byte 25     ║
║  Sensor   │  Timestamp   │  Sensor Values  │   Checksum    ║
║  Type ID  │  (uint64)    │  (4×float32)    │   (XOR)       ║
╚══════════════════════════════════════════════════════════════╝
   1 byte      8 bytes         16 bytes          1 byte
                          Total: 26 bytes
```

#### Field Descriptions:

**Byte 0: Sensor Type ID**
- `0x00` = Accelerometer (m/s²)
- `0x01` = Gyroscope (rad/s)
- `0x02` = Magnetometer (µT)
- `0x03` = GPS (lat, lon, alt, speed)
- `0x04` = Proximity (cm)
- `0x05` = Light (lux)
- `0xFF` = Unknown sensor

**Bytes 1-8: Timestamp (uint64, little-endian)**
- Milliseconds since Unix epoch
- Example: `1708819200000` = 2024-02-25 00:00:00 UTC

**Bytes 9-24: Sensor Values (4× float32, little-endian)**
- Up to 4 floating-point values
- Unused values padded with `0.0`
- IEEE 754 single-precision format

**Byte 25: Checksum**
- XOR of all previous 25 bytes
- For data integrity verification

#### Example Binary Packet:

**Accelerometer reading: [0.1234, -9.8123, 0.0456]**
```
Hex: 00 40 E2 01 8E 8D 01 00 00 8F C2 FC 3D 0A D7 1D C2 3A 8E 3A 3D 00 00 00 00 A3
     ││ └──────────┬──────────┘ └──────┬─────┘ └──────┬─────┘ └──────┬─────┘ ││
     ││      Timestamp          Value[0]        Value[1]        Value[2]      ││
     │└─ Type=0 (Accel)                                           Zeros       │└─ Checksum
     └─ Header                                                    (padding)    └─ Integrity
```

### ESP32/Arduino Parsing Code

#### C/C++ Struct Definition:
```cpp
#include <Arduino.h>

// Packet structure (must be packed to avoid padding)
struct __attribute__((packed)) SensorPacket {
    uint8_t sensorType;      // Sensor type ID (0-5)
    uint64_t timestamp;      // Unix timestamp in milliseconds
    float values[4];         // Up to 4 sensor values
    uint8_t checksum;        // XOR checksum
};

// Sensor type names
const char* getSensorName(uint8_t type) {
    switch(type) {
        case 0: return "Accelerometer";
        case 1: return "Gyroscope";
        case 2: return "Magnetometer";
        case 3: return "GPS";
        case 4: return "Proximity";
        case 5: return "Light";
        default: return "Unknown";
    }
}

// Verify packet integrity
bool verifyChecksum(const uint8_t* data, size_t len) {
    uint8_t checksum = 0;
    for (size_t i = 0; i < len - 1; i++) {
        checksum ^= data[i];
    }
    return checksum == data[len - 1];
}

void setup() {
    Serial.begin(115200);
    // For USB: Configure baud rate to 115200
    // For Bluetooth: Setup BLE server (see below)
}

void loop() {
    // USB Serial Example
    if (Serial.available() >= 26) {
        uint8_t buffer[26];
        Serial.readBytes(buffer, 26);
        
        // Verify checksum
        if (!verifyChecksum(buffer, 26)) {
            Serial.println("⚠️ Checksum failed!");
            return;
        }
        
        // Cast to struct (efficient - no parsing!)
        SensorPacket* packet = (SensorPacket*)buffer;
        
        // Display data
        Serial.printf("📊 %s | Time: %llu | Values: [%.4f, %.4f, %.4f, %.4f]\n",
            getSensorName(packet->sensorType),
            packet->timestamp,
            packet->values[0],
            packet->values[1],
            packet->values[2],
            packet->values[3]
        );
    }
}
```

#### Bluetooth BLE Server Example:
```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLECharacteristic* pCharacteristic;

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        // Process in chunks of 26 bytes
        for (size_t i = 0; i + 26 <= value.length(); i += 26) {
            const uint8_t* data = (const uint8_t*)value.data() + i;
            
            // Verify checksum
            if (!verifyChecksum(data, 26)) {
                Serial.println("⚠️ Checksum failed!");
                continue;
            }
            
            // Cast to struct
            SensorPacket* packet = (SensorPacket*)data;
            
            // Process packet
            Serial.printf("📊 %s | Values: [%.4f, %.4f, %.4f]\n",
                getSensorName(packet->sensorType),
                packet->values[0],
                packet->values[1],
                packet->values[2]
            );
        }
    }
};

void setup() {
    Serial.begin(115200);
    
    // Initialize BLE
    BLEDevice::init("ESP32_Sensor_Receiver");
    BLEServer *pServer = BLEDevice::createServer();
    BLEService *pService = pServer->createService(BLEUUID((uint16_t)0x181A)); // Environmental Sensing
    
    pCharacteristic = pService->createCharacteristic(
        BLEUUID((uint16_t)0x2A58), // Analog characteristic
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    
    pCharacteristic->setCallbacks(new MyCallbacks());
    pService->start();
    
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(pService->getUUID());
    pAdvertising->start();
    
    Serial.println("✅ BLE Server started. Waiting for connection...");
}

void loop() {
    delay(1000);
}
```

#### Python Example (for PC/Raspberry Pi):
```python
import struct
import serial

# Connect to USB serial
ser = serial.Serial('/dev/ttyUSB0', 115200)

SENSOR_NAMES = {
    0: "Accelerometer",
    1: "Gyroscope", 
    2: "Magnetometer",
    3: "GPS",
    4: "Proximity",
    5: "Light"
}

def verify_checksum(data):
    """Verify XOR checksum"""
    checksum = 0
    for byte in data[:-1]:
        checksum ^= byte
    return checksum == data[-1]

def parse_packet(data):
    """Parse 26-byte binary packet"""
    if len(data) != 26:
        return None
    
    if not verify_checksum(data):
        print("⚠️ Checksum failed!")
        return None
    
    # Unpack: 1 byte, 8 bytes, 4 floats, 1 byte
    sensor_type, timestamp, v0, v1, v2, v3, checksum = struct.unpack(
        '<BQffffB', data
    )
    
    return {
        'sensor': SENSOR_NAMES.get(sensor_type, 'Unknown'),
        'timestamp': timestamp,
        'values': [v0, v1, v2, v3]
    }

# Main loop
while True:
    if ser.in_waiting >= 26:
        data = ser.read(26)
        packet = parse_packet(data)
        
        if packet:
            print(f"📊 {packet['sensor']:15} | Time: {packet['timestamp']} | "
                  f"Values: {packet['values']}")
```

---

### JSON Format (WiFi Only)

For **WiFi communication**, Sensdroid uses JSON format for better compatibility with web servers and APIs.

#### Single Packet Format:
```json
{
  "sensorType": "accelerometer",
  "timestamp": 1708521234567,
  "values": [9.81, 0.0234, -0.1523],
  "unit": "m/s²"
}
```

**Field Descriptions:**
- `sensorType`: String identifier (accelerometer, gyroscope, magnetometer, gps, proximity, light)
- `timestamp`: Unix timestamp in milliseconds
- `values`: Array of floating-point sensor values
- `unit`: Measurement unit (m/s², rad/s, µT, etc.)

#### Batch Format:
```json
[
  {
    "sensorType": "accelerometer",
    "timestamp": 1708521234567,
    "values": [9.81, 0.0234, -0.1523],
    "unit": "m/s²"
  },
  {
    "sensorType": "gyroscope",
    "timestamp": 1708521234618,
    "values": [0.0012, -0.0045, 0.0089],
    "unit": "rad/s"
  }
]
```

#### ESP32 WiFi Server Example:
```cpp
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

WebServer server(8080);

void handleSensorData() {
    if (server.hasArg("plain")) {
        String body = server.arg("plain");
        
        // Parse JSON
        StaticJsonDocument<512> doc;
        DeserializationError error = deserializeJson(doc, body);
        
        if (error) {
            server.send(400, "text/plain", "Invalid JSON");
            return;
        }
        
        // Extract data
        const char* sensorType = doc["sensorType"];
        uint64_t timestamp = doc["timestamp"];
        JsonArray values = doc["values"].as<JsonArray>();
        
        Serial.printf("📊 %s | Time: %llu | Values: ", sensorType, timestamp);
        for (JsonVariant v : values) {
            Serial.printf("%.4f ", v.as<float>());
        }
        Serial.println();
        
        server.send(200, "text/plain", "OK");
    } else {
        server.send(400, "text/plain", "No data");
    }
}

void handleBatch() {
    if (server.hasArg("plain")) {
        String body = server.arg("plain");
        
        // Parse JSON array
        StaticJsonDocument<2048> doc;
        DeserializationError error = deserializeJson(doc, body);
        
        if (error) {
            server.send(400, "text/plain", "Invalid JSON");
            return;
        }
        
        JsonArray array = doc.as<JsonArray>();
        Serial.printf("📦 Batch received: %d packets\n", array.size());
        
        for (JsonObject item : array) {
            const char* sensorType = item["sensorType"];
            JsonArray values = item["values"].as<JsonArray>();
            
            Serial.printf("  • %s: ", sensorType);
            for (JsonVariant v : values) {
                Serial.printf("%.4f ", v.as<float>());
            }
            Serial.println();
        }
        
        server.send(200, "text/plain", "OK");
    }
}

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    WiFi.begin("YOUR_SSID", "YOUR_PASSWORD");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\n✅ WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    
    // Setup endpoints
    server.on("/sensor-data", HTTP_POST, handleSensorData);
    server.on("/batch", HTTP_POST, handleBatch);
    
    server.begin();
    Serial.println("🌐 HTTP Server started on port 8080");
}

void loop() {
    server.handleClient();
}
```

---

### Format Comparison

| Aspect | Binary (BT/USB) | JSON (WiFi) |
|--------|-----------------|-------------|
| **Size per packet** | 26 bytes | ~100-150 bytes |
| **Parsing speed** | ⚡ Instant (memcpy) | 🐢 Slow (string parsing) |
| **Human readable** | ❌ No | ✅ Yes |
| **Debugging** | Hard | Easy |
| **ESP32 RAM usage** | Low | Higher |
| **Checksum** | ✅ Built-in | ❌ None (rely on HTTP) |
| **Best for** | Real-time, embedded | Web APIs, logging |

**Recommendation:**
- **Bluetooth/USB**: Use Binary for maximum efficiency and speed
- **WiFi**: Use JSON for compatibility with standard web tools

---

## Android Configuration

### Minimum SDK: API 23 (Android 6.0 Marshmallow)
Required for USB OTG and Bluetooth LE features.

### Target SDK: API 34 (Android 14)
Latest Android compatibility.

### Permissions Required

#### Bluetooth
- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `BLUETOOTH_SCAN`
- `BLUETOOTH_CONNECT`
- `BLUETOOTH_ADVERTISE`

#### Location (for Bluetooth scanning on Android 12+)
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

#### Network/WiFi
- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_STATE`

#### USB
- `USB_PERMISSION`

#### Sensors
- `HIGH_SAMPLING_RATE_SENSORS`
- `ACTIVITY_RECOGNITION`

### USB Device Filter
Located at: `android/app/src/main/res/xml/device_filter.xml`

Supports:
- CH340/CH341 USB-Serial (Vendor ID: 6790)
- CP210x USB-Serial (Vendor ID: 4292)
- FTDI USB-Serial (Vendor ID: 1027)
- Prolific USB-Serial (Vendor ID: 1659)
- Arduino Boards (Vendor IDs: 9025, 10755)
- ESP32 Development Boards

---

## Dependencies

### State Management
- **provider** (^6.1.2): State management using ChangeNotifier pattern

### Sensors
- **sensors_plus** (^6.0.1): Accelerometer, gyroscope, magnetometer
- **geolocator** (^13.0.2): GPS location data
- **permission_handler** (^11.3.1): Runtime permission requests

### Communication
- **flutter_blue_plus** (^1.35.10): Bluetooth Low Energy
- **usb_serial** (^0.5.2): USB OTG serial communication
- **dio** (^5.7.0): HTTP client for WiFi communication
- **http** (^1.2.2): HTTP utilities
- **connectivity_plus** (^6.1.1): Network connectivity detection

### Utilities
- **intl** (^0.20.1): Date formatting and internationalization

---

## Future Enhancements

### 1. **Isolate-based Processing**
Move sensor data processing to separate isolate for true parallel execution and zero UI lag.

### 2. **mDNS Service Discovery**
Automatic WiFi device discovery using Bonjour/mDNS instead of manual IP entry.

### 3. **Data Compression**
Implement compression (e.g., gzip) for WiFi transmission to reduce bandwidth.

### 4. **Recording & Playback**
Save sensor data sessions for later analysis or replay.

### 5. **Custom Sensor Calibration**
Allow users to calibrate sensors for improved accuracy.

### 6. **Additional Sensors**
- Proximity sensor
- Light/Ambient light sensor
- Barometer
- Temperature sensor

### 7. **Multi-device Connection**
Simultaneously transmit to multiple devices (e.g., Bluetooth + WiFi).

---

## Development Guidelines

### When Adding New Features

1. **Determine MVVM Layer**: Identify whether the feature belongs in Model, View, or ViewModel.
2. **Follow DRY Principle**: Avoid code duplication; extract reusable logic into services or utilities.
3. **Update Documentation**: Immediately update this file to reflect new implementations.
4. **Test Hardware Integration**: Always test with actual ESP32/Arduino devices, not just simulators.

### Code Style
- Use meaningful variable names
- Add comments explaining "why", not "what"
- Keep functions small and focused (Single Responsibility Principle)
- Handle errors gracefully with user-friendly messages

### Performance Considerations
- Always dispose of StreamSubscriptions to prevent memory leaks
- Use `const` constructors for immutable widgets
- Profile app with high-frequency sensor data to identify bottlenecks
- Consider battery impact when enabling multiple sensors

---

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- ViewModel state transitions
- Data batching logic

### Integration Tests
- Service initialization and connection flows
- Sensor stream handling
- Protocol switching

### Hardware Tests
- Bluetooth connection with ESP32
- USB communication with Arduino/ESP32
- WiFi transmission to local server
- High-frequency data transmission (100+ Hz)

---

## Troubleshooting

### Bluetooth Won't Connect
- Ensure Bluetooth is enabled on device
- Grant Location permission (required for scanning on Android 12+)
- Check that ESP32 is advertising and not already connected

### USB Device Not Detected
- Enable USB OTG in device settings
- Use compatible USB OTG cable
- Check device_filter.xml includes your adapter's Vendor ID

### WiFi Connection Fails
- Verify device and ESP32 are on same network
- Check firewall settings on PC/ESP32
- Ensure correct IP address and port

### High Packet Drop Rate
- Reduce sampling rate
- Disable unnecessary sensors
- Check Bluetooth/USB connection stability
- For WiFi, verify network bandwidth

---

## License & Credits

**Project**: Sensdroid  
**Architecture**: MVVM + Service Layer  
**Platform**: Flutter (Android Only)  
**Target Hardware**: ESP32, Arduino, PC

---

**Last Updated**: 2026-02-24  
**Documentation Version**: 2.0  
**Major Changes**: Implemented binary format for efficient data transmission
