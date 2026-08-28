# Original User Request

## Initial Request — 2026-06-23T14:40:30+05:30

Improve the Live Map tab UI to display a realistic, high-quality, properly proportioned DualSense controller visualization and fix the issue where trigger and LED settings stop working in Bluetooth mode when the application is backgrounded.

Working directory: /Users/tusharteotia/Documents/GitHub/DualsenseT
Integrity mode: development

## Requirements

### R1. High-Fidelity DualSense Controller Visualization (Live Map)
Replace the current crude layout in [ControllerVisualizerView.swift](file:///Users/tusharteotia/Documents/GitHub/DualsenseT/Sources/Views/ControllerVisualizerView.swift) with a highly detailed, realistic, and properly proportioned SwiftUI representation of a PlayStation 5 DualSense controller. It must:
- Accurately map and animate all standard buttons (D-pad Up/Down/Left/Right, Cross, Circle, Square, Triangle, L1, R1, L2, R2, Create, Options, PS Button, Touchpad, L3, R3).
- Display real-time analog stick displacements (L3/R3 CGPoint values) with correct scaling/positioning inside their rims.
- Display real-time trigger pull depths (L2/R2) visually on the trigger shapes.
- Support lightbar LED color and pulsing animations using the manager's LED color states.
- Fit within the existing UI aesthetic (dark mode/glassmorphism/HUD window) and be fully responsive.

### R2. Persistent Bluetooth Trigger & LED Settings in Background
Fix the issue where adaptive trigger mode settings and LED settings stop working when the application is in the background or loses focus in Bluetooth mode.
- Ensure the raw HID background bypass correctly initializes and sends reports on a robust loop/scheduler when backgrounded.
- Ensure the sequence number and CRC32 calculations for BT HID reports are correct and match the controller's requirements.
- Prevent settings from resetting or stopping when the application is backgrounded.

## Acceptance Criteria

### Live Map Visuals & Responsiveness
- [ ] The app compiles successfully via `./build.sh`.
- [ ] `ControllerVisualizerView` uses a realistic shape/layout structure representing a DualSense controller with proper proportions (touchpad, handles, sticks, buttons, d-pad).
- [ ] Sticks (L3, R3) animate smoothly offset inside their circular wells according to active joystick coordinates.
- [ ] Button presses (dpad, action buttons, shoulders, triggers, options, create, PS button, touchpad) are visually highlighted (e.g. glowing blue/cyan or color shifts) when pressed.
- [ ] Trigger (L2, R2) indicators show active bar fill matching physical trigger displacement (0.0 to 1.0).
- [ ] Touchpad shows active touch markers (primary/secondary) in real-time.
- [ ] LED glow color and pulsing indicator on the visualizer dynamically updates when the manager's LED settings change.

### Background Persistence
- [ ] The app successfully detects focus loss (`didResignActiveNotification`) and background states.
- [ ] When the app is backgrounded, it correctly switches to raw HID mode and continues transmitting trigger configuration reports.
- [ ] The Bluetooth HID reports include correctly calculated CRC32 checksums and sequence numbers, ensuring the DualSense controller accepts the commands in Bluetooth mode.
- [ ] Testing with `./build.sh test` runs successfully without any test failures.
