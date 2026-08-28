# Context

## Codebase Components
- `Sources/Services/ControllerManager.swift`: Handles physical controllers (USB/Bluetooth), polling, and applying settings. Contains code for raw HID reports (USB and Bluetooth), including seed-based CRC32 calculations and sequence number tracking.
- `Sources/Views/ControllerVisualizerView.swift`: Displays a custom vector-drawn UI representing the DualSense controller. Tracks buttons, joysticks, trigger values, LED pulse animations, and touchpad touch points.
- `Sources/AppDelegate.swift`: Observes `didResignActiveNotification` (focus loss / background) and `didBecomeActiveNotification` (focus gain / foreground), instructing the controller manager to switch between standard GameController API and raw HID mode.
- `Tests/Tests.swift`: Contains simple unit tests for presets, parameter values, touch gestures, and quaternion math.
- `build.sh`: Script for building the app bundle and running unit tests via command-line.

## Requirements Focus
- **R1: High-Fidelity Controller Visualization**:
  Improve shapes, proportions, styling, responsive scaling, active stick displacement bounds, button glows/visual shifts, and LED color/pulsing representation in `ControllerVisualizerView.swift`.
- **R2: Persistent Bluetooth Trigger/LED Settings in Background**:
  Resolve report failure in Bluetooth background mode. Ensure sequence number logic, CRC32 computations, and the background loop/scheduler (e.g. replacing/supplementing the 1-second timer or handling focus loss correctly) work reliably.

## Verification
- Target verification using `./build.sh test`.
- Add comprehensive E2E integration test checks if possible.
