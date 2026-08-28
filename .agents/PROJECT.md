# Project: DualSenseT UI and Bluetooth Background Fix

## Architecture
- **Views**:
  - `ControllerVisualizerView.swift`: Draws the high-fidelity representation of the DualSense controller and highlights elements.
- **Services**:
  - `ControllerManager.swift`: Manages connection, receives gamepad input events, and applies settings via standard GameController APIs or raw HID mode.
- **App Lifecycle**:
  - `AppDelegate.swift`: Detects background and foreground events to toggle raw HID output.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | E2E Testing Suite | Create robust opaque-box test cases for visuals and background Bluetooth HID reports | None | IN_PROGRESS (a558d933-2f0a-49ba-adcb-8f26a9c19e14) |
| 2 | Live Map UI Redesign | Realistic, high-fidelity SwiftUI visualization of DualSense in `ControllerVisualizerView` | M1 | IN_PROGRESS (0ace24d9-157f-4e19-a220-1397457d5cbf) |
| 3 | Bluetooth background fix | Correct sequence numbers, CRC32, and robust transmission loop in `ControllerManager` | M1 | IN_PROGRESS (00c168a4-1d72-487e-9544-adf74be7cb2c) |
| 4 | Final E2E Pass & Audit | Run all test tiers, run adversarial checks, and pass the Forensic Audit | M2, M3 | PLANNED |

## Interface Contracts
### `ControllerManager` ↔ `ControllerVisualizerView`
- `manager.activeController`: GCController?
- `manager.leftTriggerValue` & `manager.rightTriggerValue`: Double / Float (0.0 to 1.0)
- `manager.leftStickValue` & `manager.rightStickValue`: CGPoint (displacements)
- `manager.buttonsPressed`: [String: Bool] (active highlights)
- `manager.touchpadPrimary` & `manager.touchpadSecondary`: CGPoint
- `manager.ledColor`: NSColor
- `manager.isLedPulsing`: Bool

### Background Bypass Interaction
- `NSApplication.didResignActiveNotification` -> triggers `ControllerManager.applyTriggerSettingsViaHID()` with `isAppInForeground = false`.
- `NSApplication.didBecomeActiveNotification` -> sets `isAppInForeground = true` (uses normal GameController API).
