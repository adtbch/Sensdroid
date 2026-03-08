# sensdroid

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Project Documentation: SensBridge

**SensDroid** is a high-performance Android application built with **Flutter**. It serves as a universal data gateway, extracting real-time data from internal smartphone sensors and transmitting them to microcontrollers (ESP32/Arduino) or PCs with **ultra-low latency**.

---

## 1. Multi-Protocol Connectivity
The application allows the user to toggle between three primary transmission modes:

1.  **Bluetooth (Classic/BLE):**
    * Scanning for nearby devices.
    * Establishing a handshake and persistent connection with ESP32/Bluetooth modules.
2.  **Wi-Fi (Local Network):**
    * Data transmission via **HTTP/REST** protocol.
    * Requirement: Smartphone must be connected to the ESP32’s Local Access Point or a shared local network.
3.  **USB OTG (Serial Communication):**
    * Direct wired transmission using the **Serial/UART** protocol.
    * Support for transmitting data to both microcontrollers (via CH340, CP2102, or FTDI chips) and PC terminal software.

---

## 2. Key Features & Functionality
* **Modular Sensor Selection:** A UI-based checklist allowing users to toggle specific sensors (e.g., Accelerometer, Gyroscope, Magnetometer, GPS, Proximity, Light) to optimize bandwidth.
* **Low-Latency Data Pipeline:** * Utilization of **Asynchronous Streams** to handle high-frequency sensor updates.
    * Minimized overhead in data packaging to ensure near real-time response for robotics or monitoring.
* **Target Flexibility:** In USB mode, the app must detect and communicate with various serial devices, whether they are embedded controllers or computer systems.
* **Dynamic Sampling Rate:** Ability to adjust how often data is sent to prevent saturating the communication buffer.



---

## 3. Technical Specifications for AI Agent
### **Data Formatting**
To maintain low latency, data should be transmitted in **Compact JSON** or **Delimited Strings** (e.g., `sensor_id:val1,val2,val3;`).

### **Recommended Tech Stack (Flutter Plugins)**
* **Sensors:** `sensors_plus`
* **Bluetooth:** `flutter_blue_plus` (BLE) or `flutter_bluetooth_serial` (Classic).
* **USB/Serial:** `usb_serial` or `flutter_libserialport`.
* **Networking:** `http` or `dio`.
* **Permissions:** `permission_handler` (Critical for Bluetooth, Location, and USB hardware access).

---

## 4. Implementation Goal
The final product should act as a reliable **Sensor Hub**, turning any Android smartphone into a sophisticated IMU/GPS/Environmental sensor package for **IoT, Robotics (ROS 2 integration), and Remote Monitoring** projects.