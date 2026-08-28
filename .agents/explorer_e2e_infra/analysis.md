# DualSenseT E2E Test Suite Design Analysis

**Date**: 23/06/2026  
**Status**: DRAFT  
**Author**: Teamwork Explorer (Read-Only Investigator)  

---

## 1. Executive Summary
This document provides a detailed feature inventory of the DualSenseT macOS application and outlines a comprehensive, 4-tier opaque-box End-to-End (E2E) Test Suite design. The suite validates input visualization, background transition persistence, touchpad swipe gesture remapping, per-app profile switching, and UDP command listener integration without requiring access to physical hardware.

---

## 2. Detailed Feature Inventory

### Feature 1: Controller Visualizer View & State Mapping
* **File**: `Sources/Views/ControllerVisualizerView.swift` (Lines 1-607)
* **Description**: Renders a premium vector-based graphical representation of the DualSense controller and overlays real-time input status by subscribing to `ControllerManager`.
* **State Mappings**:
  * **Connection Type Indicator**: Binds to `manager.connectionType` (`"USB"`, `"BT"`, `"Unknown"`) to display a connectivity badge (Lines 72-91).
  * **Shoulder & Trigger Buttons**:
    * **L1**: Maps to `manager.buttonsPressed["l1"] == true` (Line 98).
    * **R1**: Maps to `manager.buttonsPressed["r1"] == true` (Line 104).
    * **L2 (Trigger value & press)**: Maps to `manager.leftTriggerValue` (0.0 to 1.0) and `manager.buttonsPressed["l2"] == true` (Line 96).
    * **R2 (Trigger value & press)**: Maps to `manager.rightTriggerValue` (0.0 to 1.0) and `manager.buttonsPressed["r2"] == true` (Line 102).
  * **D-Pad Directional Buttons**:
    * **Up, Down, Left, Right**: Map to `manager.buttonsPressed["dpadUp" / "dpadDown" / "dpadLeft" / "dpadRight"] == true` (Lines 110-117).
  * **Action Buttons**:
    * **Triangle, Cross, Square, Circle**: Map to `manager.buttonsPressed["triangle" / "cross" / "square" / "circle"] == true` (Lines 122-129).
  * **Thumbsticks (L3 / R3)**:
    * **Left Stick (X/Y Offset & Press)**: Maps to `manager.leftStickValue` (`CGPoint`) and `manager.buttonsPressed["l3"] == true` (Line 133).
    * **Right Stick (X/Y Offset & Press)**: Maps to `manager.rightStickValue` (`CGPoint`) and `manager.buttonsPressed["r3"] == true` (Line 136).
  * **Utility Buttons**:
    * **Create**: Maps to `manager.buttonsPressed["create"] == true` (Line 140).
    * **Options**: Maps to `manager.buttonsPressed["options"] == true` (Line 142).
    * **PlayStation (PS)**: Maps to `manager.buttonsPressed["ps"] == true` (Line 146).
  * **Touchpad Indicators**:
    * **Primary Touch**: Maps to `manager.touchpadPrimaryActive` and `manager.touchpadPrimary` (`CGPoint`) coordinates scaled and repositioned (Lines 150-159).
    * **Secondary Touch**: Maps to `manager.touchpadSecondaryActive` and `manager.touchpadSecondary` (`CGPoint`) coordinates scaled and repositioned (Lines 160-169).
  * **Lightbar RGB & Pulse Animation**:
    * **Color**: Renders `manager.ledColor` (Line 65).
    * **Pulse**: Dynamically overlays opacity pulse using `pulseOpacity` based on `manager.isLedPulsing` state (Lines 70, 175-177, 194-204).

### Feature 2: Background Mode Transitions & Raw HID Output
* **Files**: `Sources/Services/ControllerManager.swift` (Lines 1-1019) and `Sources/AppDelegate.swift` (Lines 1-195)
* **Description**: Ensures adaptive trigger states and LED settings persist when the application loses window focus. Due to macOS restrictions, when backgrounded, standard GameController APIs ignore force feedback commands. The app switches to direct IOHIDManager output reports to maintain trigger states.
* **Key Mechanics**:
  * **State Toggle**: `isAppInForeground` is managed by App Delegate notification observers (AppDelegate.swift Lines 36-62).
  * **Background Resign Notification**:
    * Listens to `NSApplication.didResignActiveNotification` (AppDelegate.swift Lines 36-38).
    * Sets `manager.isAppInForeground = false` (AppDelegate.swift Line 43).
    * Bypasses OS controller resets by firing `applyTriggerSettingsViaHID()` twice asynchronously at 0.05s and 0.2s (AppDelegate.swift Lines 45-51).
  * **Foreground Active Notification**:
    * Listens to `NSApplication.didBecomeActiveNotification` (AppDelegate.swift Lines 53-55).
    * Sets `manager.isAppInForeground = true` (AppDelegate.swift Line 60).
    * Restores standard GameController API control by calling `applyTriggerSettings()` (AppDelegate.swift Line 61).
  * **Raw HID Output Packets**:
    * **Transport Detection**: `getTransportForDualSense()` opens `IOHIDManager` matching Vendor ID `0x054C` and Product IDs `0x0CE6`/`0x0DF2` to read the "Transport" property (ControllerManager.swift Lines 551-578).
    * **USB Report (0x02)**: Packages a 48-byte buffer. Sets Report ID `0x02`, valid flags, L2/R2 modes/parameters, and RGB values (ControllerManager.swift Lines 787-810).
    * **Bluetooth Report (0x31)**: Packages a 78-byte buffer. Sets Report ID `0x31`, sequence numbers (0-15), valid flags, L2/R2 modes/parameters, RGB values, and appends a CRC32 checksum computed with seed byte `0xA2` (ControllerManager.swift Lines 628-639, 812-845).

### Feature 3: Touchpad Swipe Gestures & Keyboard Simulation
* **File**: `Sources/Services/ControllerManager.swift` (Lines 874-957)
* **Description**: Tracks user touch movements on the DualSense touchpad and maps cardinal swipes to simulated keyboard keypresses.
* **Key Mechanics**:
  * **Touch Coordinates**: Received via `GCDualSenseGamepad` `touchpadPrimary` handler (ControllerManager.swift Lines 317-331).
  * **Swipe Detection**: Sets `touchStart` on first touch. Calculates `dx` and `dy`. If distance exceeds the threshold of `0.5`, sets `hasSwiped = true` and triggers direction-specific action (ControllerManager.swift Lines 889-925).
  * **Remapped Actions**: Maps "Up", "Down", "Left", "Right" swipe directions to "Spacebar" (virtual key 49), "Left Arrow" (123), "Right Arrow" (124), "Up Arrow" (126), and "Down Arrow" (125) (ControllerManager.swift Lines 932-948).
  * **Key Simulation**: Dispatches `CGEvent` down and up events using `CGEventSource` targeted at the combined session state (ControllerManager.swift Lines 950-957).
  * **Release Reset**: If coordinates default to `0,0`, resets `touchStart = nil` and `hasSwiped = false` (ControllerManager.swift Lines 927-930).

### Feature 4: Per-App Profile Switching
* **File**: `Sources/Services/ControllerManager.swift` (Lines 959-1018)
* **Description**: Automatically switches trigger presets based on the bundle identifier of the active macOS application.
* **Key Mechanics**:
  * **App Activation Observer**: Subscribes to `NSWorkspace.didActivateApplicationNotification` (ControllerManager.swift Lines 974-978).
  * **Preset Matching**: Extracts the bundle identifier of the newly active application and matches it against `appProfiles` dictionary. If a match is found, applies the corresponding `TriggerPreset` (ControllerManager.swift Lines 979-989).

### Feature 5: UDP Server Integration & Protocol Handling
* **File**: `Sources/Services/UDPListener.swift` (Lines 1-424)
* **Description**: Listens on port 6969 for incoming JSON packets to allow third-party games or emulators to dynamically adjust the controller's triggers and LED status.
* **Key Mechanics**:
  * **Protocol Parsing**: Supports standard DSX packets with nested `DSXInstruction` arrays (Lines 77-84, 101-114) and legacy Flat packets (Lines 86-94, 116-137).
  * **UDP Socket binding**: Listens on UDP port 6969 using Apple's `Network` framework (Lines 15-48).
  * **Trigger Parameter Normalization**: Converts parameters (0-255) to float percentages and applies appropriate `TriggerMode` states (`off`, `feedback`, `weapon`, `vibration`) (Lines 216-422).

---

## 3. Comprehensive 4-Tier Opaque-Box E2E Test Suite Design

To implement "opaque-box" testing for a hardware-dependent system, the E2E test suite must interface at the software boundaries:
1. **Virtual Input Simulation**: Programmatically register a virtual controller using `GCVirtualController` (Apple GameController framework) to emit simulated buttons, axes, and touchpad inputs.
2. **Network Protocol Emulation**: Send actual JSON payloads over UDP socket `127.0.0.1:6969` to test the UDP listener.
3. **Application Lifecycle Simulation**: Post system notification events (`NSApplication.didResignActiveNotification` and `NSApplication.didBecomeActiveNotification`) to simulate focus switching.
4. **HID Output Interception**: Interpose/mock `IOHIDDeviceSetReport` to capture and verify the exact bytes generated in raw HID reports.
5. **System Event Tap Monitor**: Observe virtual keypresses emitted by the application using a local `CGEventTap` to verify swipe remapping.

---

### Tier 1: Feature Coverage
Validates the standard paths and features under typical conditions (>=5 test cases per feature).

#### Feature 1: Controller Visualizer View & State Mapping
* **E2E-1.1.1: Visualizer Button Press Highlights**
  * *Setup*: Initialize GCVirtualController.
  * *Stimulus*: Simulate sequential button presses for all mapped keys: `cross`, `circle`, `square`, `triangle`, `l1`, `r1`, `l3`, `r3`, `create`, `options`, `ps`.
  * *Verification*: Verify `ControllerManager.buttonsPressed` contains `[buttonName: true]` and the corresponding SwiftUI subview is highlighted.
* **E2E-1.1.2: Analog Trigger Gauge Scaling**
  * *Setup*: Initialize GCVirtualController.
  * *Stimulus*: Sweep Left Trigger (L2) value from `0.0` to `0.5` to `1.0`.
  * *Verification*: Assert `leftTriggerValue` matches the simulated values, L2 gauge fill height scales proportionally, and `buttonsPressed["l2"]` changes from `false` to `true` when threshold (>0.0) is crossed.
* **E2E-1.1.3: Thumbstick Coordinates Offset**
  * *Setup*: Initialize GCVirtualController.
  * *Stimulus*: Set left thumbstick position to `(x: -0.75, y: 0.5)`.
  * *Verification*: Verify `leftStickValue` matches exactly and `StickVisual` offset renders at the correct position.
* **E2E-1.1.4: LED Color Change & Pulse Styling**
  * *Setup*: Set `manager.ledColor` to Red `(1.0, 0.0, 0.0)` and `isLedPulsing` to `true`.
  * *Stimulus*: Wait for the visualizer view to render.
  * *Verification*: Check that the `DualSenseLightbar` stroke color matches Red and opacity transitions below 1.0 (pulsing is active).
* **E2E-1.1.5: Connection Type Display Switch**
  * *Setup*: Mock `getTransportForDualSense()` to return `"USB"`, then `"BT"`.
  * *Stimulus*: Trigger `updateConnectionType()`.
  * *Verification*: Assert visualizer renders connection type badge as `"USB"` and `"BT"` respectively.

#### Feature 2: Background Mode Transitions & Raw HID Output
* **E2E-1.2.1: Transition to Background (Raw HID Activation)**
  * *Setup*: Connect virtual controller. App is active in foreground (`isAppInForeground = true`).
  * *Stimulus*: Post `NSApplication.didResignActiveNotification`.
  * *Verification*: Assert `isAppInForeground` becomes `false`. Verify that two async calls to `applyTriggerSettingsViaHID` are scheduled. Intercept `IOHIDDeviceSetReport` to confirm raw report packets are dispatched.
* **E2E-1.2.2: Transition to Foreground (GameController Restoration)**
  * *Setup*: App is in background (`isAppInForeground = false`).
  * *Stimulus*: Post `NSApplication.didBecomeActiveNotification`.
  * *Verification*: Assert `isAppInForeground` becomes `true`. Verify that `applyTriggerSettings()` (GameController API) is immediately executed.
* **E2E-1.2.3: USB Output Report Packet Construction**
  * *Setup*: Configure transport mock to `"USB"`. Set L2 mode to `.feedback` (Start: 0.2, Strength: 0.8) and LED to blue.
  * *Stimulus*: Trigger `applyTriggerSettingsViaHID()`.
  * *Verification*: Intercept the 48-byte USB output report. Check:
    * Byte 0 = `0x02` (Report ID)
    * Byte 11 = L2 trigger mode byte (Feedback)
    * Bytes 45-47 = LED RGB values
* **E2E-1.2.4: Bluetooth Output Report Packet Construction & CRC32**
  * *Setup*: Configure transport mock to `"BT"`. Set R2 mode to `.weapon` (Start: 0.1, End: 0.4, Strength: 0.9) and LED to red.
  * *Stimulus*: Trigger `applyTriggerSettingsViaHID()`.
  * *Verification*: Intercept the 78-byte BT output report. Check:
    * Byte 0 = `0x31` (Report ID)
    * Byte 1 = Sequence number block (`(seq << 4) | 0x02`)
    * Bytes 74-77 = CRC32 checksum. Re-compute CRC32 with seed `0xA2` on bytes 0-73 and verify it matches the report's trailer.
* **E2E-1.2.5: Background Polling Persistent HID Updates**
  * *Setup*: Put app in background. Set a polling timer.
  * *Stimulus*: Modify L2 trigger settings in `ControllerManager` while in background.
  * *Verification*: Confirm that `applyTriggerSettingsViaHID` is triggered at the next 1-second polling timer cycle.

---

### Tier 2: Boundary & Corner Cases
Validates stability and correctness under extreme inputs, invalid formats, or hardware edge states (>=5 test cases per feature/area).

#### Area 1: Extreme Analog Stick & Trigger Values
* **E2E-2.1.1: Maximum Deflection Sticks**
  * *Stimulus*: Simulate stick coordinates at absolute extremes: `(1.0, 1.0)`, `(-1.0, -1.0)`, `(1.0, -1.0)`, `(-1.0, 1.0)`.
  * *Verification*: Confirm `leftStickValue` and `rightStickValue` are parsed without overflow. Verify stick offset visual caps at maximum UI boundary (12 pt offset).
* **E2E-2.1.2: Stick Deadzone Boundaries**
  * *Stimulus*: Simulate micro-movements of stick at `(0.001, -0.001)`.
  * *Verification*: Ensure values are recorded correctly in the manager, and does not cause visual jitter in SwiftUI rendering.
* **E2E-2.1.3: Trigger Calibration Clamp**
  * *Stimulus*: Inject simulated trigger values outside standard range: `-0.5` and `1.5`.
  * *Verification*: Verify UI clamps gauge height between 0.0 and 1.0, and HID bit-packing maps `-0.5` to `0` and `1.5` to max zone values.
* **E2E-2.1.4: Rapid Alternating Stick Values**
  * *Stimulus*: Sweep stick values from `-1.0` to `1.0` at 120Hz frequency.
  * *Verification*: Verify visualizer updates smoothly without interface lag, CPU spikes, or threading crashes in the main dispatch queue.
* **E2E-2.1.5: Simultaneous Sub-threshold Touches**
  * *Stimulus*: Simulating primary touch at `(0.1, 0.1)` and secondary touch at `(0.12, 0.12)` (distance < threshold).
  * *Verification*: Verify no swipe is detected, and touchpad indicators render side-by-side.

#### Area 2: Battery Edge Cases
* **E2E-2.2.1: Extremely Low Battery Level Reporting**
  * *Stimulus*: Mock GCController battery state to return level `0.01` (1% charge) and state `.discharging`.
  * *Verification*: Verify battery label in sidebar displays "1%", menu bar matches "1%", and battery icon changes to low battery status.
* **E2E-2.2.2: Full Charge Transition to AC Power**
  * *Stimulus*: Mock battery state to level `1.0` (100% charge) and state `.charging`.
  * *Verification*: Verify menu bar display switches to AC charging icon and battery label reports "100%".
* **E2E-2.2.3: Battery State Unknown Reporting**
  * *Stimulus*: Mock battery state to level `-1.0` and state `.unknown`.
  * *Verification*: Ensure status display gracefully handles unknown state (shows "--%" instead of crashing or showing invalid values).
* **E2E-2.2.4: Hot-plug Battery Disconnect**
  * *Stimulus*: Simulate controller battery object becoming nil on active connection.
  * *Verification*: Ensure no null-pointer crashes occur, and fallback status is represented in UI.
* **E2E-2.2.5: High-Frequency Battery State Oscillations**
  * *Stimulus*: Alternate battery status between charging and discharging every 10ms.
  * *Verification*: Verify menu bar throttling prevents UI thread lockups and stays responsive.

#### Area 3: High-Frequency LED Pulses & Color Space Conversions
* **E2E-2.3.1: High Frequency Led Pulsing Toggle**
  * *Stimulus*: Set `isLedPulsing` to `true` and toggle it `false` at 50Hz.
  * *Verification*: Ensure `pulsingTimer` is invalidated correctly at each cycle to prevent memory leaks and thread accumulation.
* **E2E-2.3.2: Out of Gamut RGB Settings**
  * *Stimulus*: Set `ledColor` to a wide-gamut P3 color space value outside standard sRGB bounds.
  * *Verification*: Confirm `updateLed()` successfully converts color using `.usingColorSpace(.sRGB)` (ControllerManager.swift Line 854) and prevents color rendering exceptions.
* **E2E-2.3.3: Zero Intensity LED (Off state)**
  * *Stimulus*: Set `ledColor` to black (0,0,0).
  * *Verification*: Verify the HID payload output writes `0` to red, green, and blue bytes, and visualizer renders lightbar with low opacity black.
* **E2E-2.3.4: Pulse Animation Interruptions**
  * *Stimulus*: Enable pulsing, then immediately change LED color, then disable pulsing in rapid succession.
  * *Verification*: Verify the `pulsingTimer` finishes immediately and lightbar color is set to the static target.
* **E2E-2.3.5: Rapid Color Space Switching**
  * *Stimulus*: Change `ledColor` between sRGB, Gray, and CMYK color spaces dynamically.
  * *Verification*: Verify the application safely falls back to standard sRGB representation without crashing (safeguarded by line 856-857).

#### Area 4: Invalid Network Packets & Report Forms
* **E2E-2.4.1: Corrupt JSON Packet on Port 6969**
  * *Stimulus*: Send a malformed payload (e.g. `"{invalid_json:"`) over UDP to port 6969.
  * *Verification*: Ensure the UDP server logs the parsing error, does not crash, and updates `lastMessage` to include "Parse error:" (UDPListener.swift Line 141).
* **E2E-2.4.2: DSX Packet with Missing Trigger Parameters**
  * *Stimulus*: Send a DSX JSON payload with `type: "TriggerUpdate"` but containing only 1 parameter instead of 2.
  * *Verification*: Verify the system catches the out-of-bounds error and logs "DSX Trigger update error: parameters count < 2" (UDPListener.swift Line 153).
* **E2E-2.4.3: Legacy Flat Packet with Invalid RGB Values**
  * *Stimulus*: Send legacy JSON packet with RGB bounds outside 0-255: `{"instruction": "RGB", "r": 300, "g": -50, "b": 100}`.
  * *Verification*: Ensure colors are clamped within 0.0-1.0 range when constructing the `NSColor` object.
* **E2E-2.4.4: Unexpected JSON Schema Keys**
  * *Stimulus*: Send payload containing arbitrary valid JSON that does not match `DSXPacket` or `FlatPacket`.
  * *Verification*: Confirm the listener rejects the packet as parse failure and remains operational.
* **E2E-2.4.5: Massive Network Frame (Buffer Overflow Check)**
  * *Stimulus*: Send a 10KB UDP packet containing nested JSON structures.
  * *Verification*: Assert that the listener processes or rejects the packet cleanly without heap overflow or memory exhaustion.

---

### Tier 3: Cross-Feature Combinations
Validates scenarios where multiple features are active simultaneously (pairwise combinations).

* **E2E-3.1: Simultaneous Active D-Pad and Action Buttons**
  * *Stimulus*: Simulate pressing `dpadUp` and `triangle` simultaneously while sweeping left stick.
  * *Verification*: Check that all events are registered concurrently and represented in the visualizer.
* **E2E-3.2: Trigger Pull During Active Touchpad Swipe**
  * *Stimulus*: Sweep Left Trigger (L2) from 0.0 to 1.0 while performing a swipe gesture on the touchpad.
  * *Verification*: Verify trigger values update smoothly in the UI and the swipe gesture completes by dispatching key simulation without interference.
* **E2E-3.3: Focus Switching During Active UDP Stream**
  * *Setup*: Send a continuous stream of UDP trigger configuration packets (e.g. from an emulator).
  * *Stimulus*: Move the app from foreground to background (post didResignActive).
  * *Verification*: Verify that incoming UDP instructions are parsed and immediately translated to raw HID output reports instead of GameController API calls.
* **E2E-3.4: App Profile Transition Intersecting Active Presets**
  * *Stimulus*: Trigger didActivateApplicationNotification to switch profile to a "Heavy Rifle" app, while simultaneously applying a "Bow & Arrow" preset from the menu bar.
  * *Verification*: Verify application prioritizes the active focused application profile, applying "Heavy Rifle" triggers and LED settings.
* **E2E-3.5: Touchpad Remap Key Simulation and Network LED Change**
  * *Stimulus*: Trigger a Left Swipe (mapping to Left Arrow) while receiving a UDP RGB command.
  * *Verification*: Confirm the virtual key is posted to the OS and the lightbar color updates to the UDP-defined color without delay.

---

### Tier 4: Real-World Application Scenarios
End-to-end integration tests mimicking typical user workflows.

* **E2E-4.1: Standard Gaming Session Lifecycle**
  1. Boot app (auto-starts UDP server).
  2. Connect DualSense controller.
  3. Load "Bow & Arrow" preset.
  4. Perform some gameplay (simulated stick movements and trigger pulls).
  5. Check UI reflects inputs and controller matches preset state.
* **E2E-4.2: Frequent Rapid Foreground / Background Switching**
  * *Stimulus*: Cycle the application between active and resigned state 20 times in rapid succession (100ms intervals).
  * *Verification*: Assert that no memory leaks, thread deadlocks, or stale IOHIDDevice handles occur. Verify the final trigger state matches the latest requested profile.
* **E2E-4.3: App Focus Profile Handshake Sequence**
  1. Boot app with custom profiles saved: `com.apple.Safari -> Bow & Arrow`, `com.apple.Finder -> Racing Brake`.
  2. Focus Safari -> verify "Bow & Arrow" preset is active.
  3. Focus Finder -> verify "Racing Brake" preset is active.
  4. Focus DualSenseT main window -> verify latest preset persists and UI displays active state.
* **E2E-4.4: Complete UDP Control Session**
  1. Boot app.
  2. Connect a virtual controller.
  3. A third-party app connects via UDP, sends custom trigger states (Galloping vibration mode) and switches LED color to Green.
  4. Verify the visualizer and HID output reflect Galloping parameters and LED turns Green.
  5. The controller disconnected notification fires -> verify UDP listener stays listening, but visualizer transitions to "Connect a DualSense controller" screen.

---

## 4. E2E Infrastructure & Execution Strategy

To facilitate automated execution of these test cases, we propose adding an E2E testing extension that uses a virtual controller target and hooks system APIs.

### Test Runner Architecture
* **Virtual Controller Hook**: Uses Apple's `GCVirtualController` to simulate button presses and analog sticks.
* **HID Interceptor**: Integrates a macro `#if TESTING_E2E` in `ControllerManager` that intercepts `IOHIDDeviceSetReport` calls and appends the outgoing buffer to an in-memory queue for verification.
* **Event Monitor**: Uses `CGEvent.tapCreate` to listen for virtual keyboard outputs created by the touchpad swipe gesture remapper.
* **UDP Client Stub**: A built-in test client that sends test packets to local port 6969.

### Runner Command
To execute the E2E tests, the `build.sh` script should be extended to support:
```bash
./build.sh test-e2e
```
Which compiles the codebase with `-DTESTING_E2E` flag and runs the E2E suite, outputting detailed logs and exit codes.

### Test Case Format (Example in Swift)
```swift
#if TESTING_E2E
class E2ETests {
    func testTouchpadSwipeToKeyboardSimulation() throws {
        let manager = ControllerManager()
        manager.touchpadActions["Left"] = "Left Arrow"
        
        // 1. Setup CGEventTap to monitor simulated keystrokes
        let eventMonitor = EventTapMonitor()
        eventMonitor.start()
        
        // 2. Simulate Left swipe coordinates
        manager.handleTouchpadUpdate(x: 0.8, y: 0.5) // Start touch
        manager.handleTouchpadUpdate(x: 0.2, y: 0.5) // Left swipe (dx = -0.6)
        
        // 3. Verify event tap captured Left Arrow keypress
        try XCTAssertTrue(eventMonitor.capturedKeys.contains(123), "Expected Left Arrow (123) simulated keypress")
        
        // 4. Release touch
        manager.handleTouchpadUpdate(x: 0.0, y: 0.0)
        eventMonitor.stop()
    }
}
#endif
```

---

## 5. Traceability Matrix

| Test Tier / Case | Target Code Component | File & Reference Lines |
|---|---|---|
| **E2E-1.1.1** (Visualizer Buttons) | `ControllerVisualizerView` | `ControllerVisualizerView.swift`: 94-148 |
| **E2E-1.1.2** (Trigger Gauge) | `ControllerVisualizerView` | `ControllerVisualizerView.swift`: 96, 102 |
| **E2E-1.1.3** (Stick Offset) | `ControllerVisualizerView` | `ControllerVisualizerView.swift`: 133, 136 |
| **E2E-1.1.4** (Lightbar Color) | `ControllerVisualizerView` | `ControllerVisualizerView.swift`: 63-70 |
| **E2E-1.1.5** (Connection Badge) | `ControllerVisualizerView` | `ControllerVisualizerView.swift`: 72-91 |
| **E2E-1.2.1** (Resign Focus) | `AppDelegate` & `ControllerManager` | `AppDelegate.swift`: 36-51, `ControllerManager.swift`: 517 |
| **E2E-1.2.2** (Active Focus) | `AppDelegate` & `ControllerManager` | `AppDelegate.swift`: 53-62 |
| **E2E-1.2.3** (USB Packet) | `ControllerManager` | `ControllerManager.swift`: 787-810 |
| **E2E-1.2.4** (BT Packet + CRC) | `ControllerManager` | `ControllerManager.swift`: 628-639, 812-845 |
| **E2E-2.1.1** (Extreme Axis) | `ControllerManager` & `StickVisual` | `ControllerManager.swift`: 275-282, `ControllerVisualizerView.swift`: 365-434 |
| **E2E-2.3.1** (High-Freq Pulse) | `ControllerManager` | `ControllerManager.swift`: 860-868 |
| **E2E-2.4.1** (UDP Corrupt JSON) | `UDPListener` | `UDPListener.swift`: 138-142 |
| **E2E-2.4.2** (UDP Missing Params)| `UDPListener` | `UDPListener.swift`: 152-155 |
| **E2E-3.3** (UDP Backgrounding) | `AppDelegate` & `UDPListener` | `AppDelegate.swift`: 36-51, `UDPListener.swift`: 356-372 |
| **E2E-3.4** (App Profile Priority) | `ControllerManager` | `ControllerManager.swift`: 974-989 |
| **E2E-4.2** (Rapid Focus Flapping)| `AppDelegate` | `AppDelegate.swift`: 36-62 |
