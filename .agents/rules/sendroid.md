---
trigger: always_on
---

---
description: Describe when these instructions should be loaded
# applyTo: 'Describe when these instructions should be loaded' # when provided, instructions will automatically be added to the request context when the pattern matches an attached file
---
# applyTo: **/Sendroid/**

# AI Agent System Instructions: SensBridge Development

## 1. Contextual Awareness & Mandatory Reading
Before generating any code or proposing architectural changes, you MUST:
* **Analyze `README.md`:** Understand the core project objectives, hardware protocols, and high-level requirements.
* **Audit File Structure:** Scan the current directory tree to maintain consistency with existing file placements and naming conventions.
* **Review Existing Code:** Read relevant source files to ensure new implementations align with the established logic and state management patterns.

## 2. Documentation Maintenance (`documentation.md`)
You are responsible for keeping the project's documentation up to date. After every significant code change or structural update, you MUST:
* **Edit `documentation.md`:** Update this file to reflect new features, logic changes, or protocol updates.
* **Folder Mapping:** Provide a clear description of the project's folder structure, explaining the specific purpose and responsibility of each directory (e.g., `services/`, `viewmodels/`, `models/`).
* **Sync Logic:** Ensure that the documentation accurately describes how the frontend (Flutter) interacts with the hardware (ESP32/PC).

## 3. Architectural Standard: MVVM
You must strictly adhere to the **Model-View-ViewModel (MVVM)** pattern combined with a Service-based layer:
* **Models:** Data classes representing sensor readings and communication packets. No business logic.
* **Views:** Flutter UI components and pages. These must be "dumb" and only react to state from the ViewModel.
* **ViewModels:** Manage the application state, handle sensor stream subscriptions, and trigger transmission logic.
* **Services:** Dedicated classes for hardware communication (BluetoothService, USBService, WifiService). Use abstract classes to ensure protocol switching is seamless.

## 4. Technical Development Rules
1.  **Low-Latency Focus:** Prioritize `Streams`, `Isolates`, and asynchronous programming to ensure high-frequency sensor data is transmitted without UI lag.
2.  **Modular Sensor Control:** Implement logic to only listen to sensors selected in the user's checklist. Properly dispose of listeners to optimize battery and CPU usage.
3.  **Protocol Agnosticism:** The ViewModel should interact with an abstraction of the transmission layer so that switching between USB, Wi-Fi, and BT does not require rewriting core logic.
4.  **Robust Error Handling:** Always include handlers for hardware-specific failures (e.g., USB unplugged, Bluetooth connection lost, or Wi-Fi timeouts).

## 5. Operational Workflow
* **Step 1:** Identify the relevant MVVM layer and folder for the task.
* **Step 2:** Generate clean, production-ready code following DRY (Don't Repeat Yourself) principles.
* **Step 3:** Immediately update `documentation.md` to explain the new implementation and any changes to the project structure.

## 6. Communication Style
* Maintain a highly technical, precise, and implementation-focused tone.
* Provide well-commented code that explains "why" a certain approach was taken, especially regarding performance optimizations.