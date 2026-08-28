# Analysis Report: DualSense Bluetooth, Background Scheduling, and State Persistence

* **Date**: 23/06/2026
* **Explorer**: Explorer 2 (Teamwork Explorer)
* **Status**: Analysis Complete

---

## Executive Summary
This report analyzes the Bluetooth report formatting, CRC32 calculations, background scheduling mechanisms, and state persistence issues in `Sources/Services/ControllerManager.swift` and `Sources/AppDelegate.swift`. 

Four key critical issues have been identified:
1. **Weapon Mode Encoding Bug**: The weapon trigger mode uses an incorrect mode byte (`0x25` instead of `0x02`) and sends a packed bitmask instead of direct integer coordinates, breaking weapon mode when the app is backgrounded.
2. **Vibration Mode Frequency Index Bug**: The vibration frequency byte is packed at `params[8]` instead of the required `params[6]`, sending a frequency of `0` and disabling vibration effects.
3. **App Nap Throttling**: Background operations are scheduled on a main runloop `Timer` (1.0s interval), which gets throttled or completely suspended by macOS App Nap when the application is backgrounded or its window is closed.
4. **Incorrect Background Trigger Update Hook**: App profile and quick preset updates only call the GameController API, which macOS ignores for background applications, causing the controller's triggers to freeze or reset until the slow background timer ticks.

---

## Detailed Analysis

### 1. Bluetooth Output Report, Sequence Numbers, & CRC32
The Bluetooth output report format, sequence numbers, and CRC32 are implemented in `Sources/Services/ControllerManager.swift` via the `sendBTOutputReport` function:

```swift
private func sendBTOutputReport(device: IOHIDDevice, r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]), ledR: UInt8, ledG: UInt8, ledB: UInt8) -> IOReturn {
    var report = [UInt8](repeating: 0, count: 78)
    report[0] = 0x31  // BT Report ID
    report[1] = (btSequenceNumber << 4) | 0x02
    btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F
    report[2] = 0x10  // BT tag
    
    report[3] = 0x04 | 0x08   // valid_flag0
    report[4] = 0x04           // valid_flag1
    
    report[13] = r2.mode
    for i in 0..<min(r2.params.count, 10) {
        report[14 + i] = r2.params[i]
    }
    
    report[24] = l2.mode
    for i in 0..<min(l2.params.count, 10) {
        report[25 + i] = l2.params[i]
    }
    
    report[41] = 0x02 | 0x10  // valid_flag2
    report[44] = 0x02          // lightbar_setup
    report[47] = ledR
    report[48] = ledG
    report[49] = ledB
    
    let crc = computeBTCRC32(Array(report[0..<74]))
    report[74] = UInt8(crc & 0xFF)
    report[75] = UInt8((crc >> 8) & 0xFF)
    report[76] = UInt8((crc >> 16) & 0xFF)
    report[77] = UInt8((crc >> 24) & 0xFF)
    
    return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
}
```

#### Evaluation against DualSense Specifications:
* **Report ID**: `0x31` is the correct HID report ID for sending extended controller configuration (including triggers and LEDs) over Bluetooth.
* **Sequence Number**: Byte 1 uses `(btSequenceNumber << 4) | 0x02`. The sequence number cycles from `0` to `15` using `(btSequenceNumber &+ 1) & 0x0F`. This is correct and prevents the controller firmware from dropping packets.
* **CRC32 Seed & Calculation**: 
  * The CRC32 algorithm uses the IEEE 802.3 standard polynomial `0xEDB88320`.
  * When communicating over Bluetooth, the controller expects the CRC32 to protect the entire L2CAP transmission. This includes a leading transaction header byte (`0xA2`), which denotes an outgoing HID output report.
  * In `computeBTCRC32`, the byte `0xA2` is correctly processed as the initial seed byte before the report content (`report[0..<74]`) is processed.
  * The resulting CRC32 is written in little-endian format across bytes 74-77. This is correct.
* **Payload Offset Shift**:
  * In USB reports (ID `0x02`), the payload begins at byte 1.
  * In Bluetooth reports (ID `0x31`), the payload is shifted by 2 bytes (starting at byte 3) to accommodate the sequence and BT tag bytes.
  * The shifted offsets in `sendBTOutputReport` (e.g., L2 mode at index 24 instead of 22, R2 mode at index 13 instead of 11, and LED components at indices 47-49 instead of 45-47) are mathematically correct and match the hardware specifications.

#### Identified Bugs:
1. **Weapon Mode Parameterization Bug** (`ControllerManager.swift`, lines 693-703):
   * **Observed**: The code returns mode byte `0x25` and packs the start/end zones into a 16-bit bitmask `(1 << startPos) | (1 << endPos)` across `params[0]` and `params[1]`.
   * **Correction**: DualSense controllers do not have a mode `0x25`. The standard weapon mode is `0x02` (or `0x02` in standard reports, matching GameController weapon mode). It expects the start and end positions directly as integer values in `params[0]` and `params[1]`, and the strength directly in `params[2]`.
2. **Vibration Mode Frequency Index Bug** (`ControllerManager.swift`, lines 730-741):
   * **Observed**: Inside `bitpackTriggerArray` (used by vibration mode `0x26`), the frequency is written to `params[8]`.
   * **Correction**: The DualSense custom vibration mode `0x26` expects the frequency byte to be stored at index 6 (`params[6]`), not index 8. Because it is written to index 8, a frequency of `0` is sent at index 6, silencing the vibration effect.

---

### 2. Background Transmission & Scheduling
Background transmission is initiated when the application resigns focus:

```swift
// AppDelegate.swift (lines 36-51)
NotificationCenter.default.addObserver(
    forName: NSApplication.didResignActiveNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    guard let self = self else { return }
    logToFile("Application resigned active. Switching to raw HID output mode.")
    self.controllerManager.isAppInForeground = false
    // Immediately send raw HID report to override the OS reset
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.controllerManager.applyTriggerSettingsViaHID()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.controllerManager.applyTriggerSettingsViaHID()
    }
}
```

Once `isAppInForeground` is set to `false`, raw HID updates depend on the `pollingTimer` in `ControllerManager.swift`:

```swift
public func startPolling() {
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self, let controller = self.activeController else { return }
        
        // Use raw HID when backgrounded to bypass GameController framework focus restriction
        if !self.isAppInForeground {
            self.applyTriggerSettingsViaHID()
        }
        ...
```

#### Identified Shortcomings:
1. **Timer Throttling (App Nap)**:
   * The background scheduler uses a standard `Timer` attached to the main run loop.
   * On macOS, when an application loses focus and has its windows closed/hidden, the system places it into "App Nap". The main thread is throttled, causing the `pollingTimer` to fire at a drastically reduced rate (once every 10+ seconds) or suspend completely.
2. **Slow Update Frequency (1.0 Hz)**:
   * A polling interval of 1.0 second is too slow. The macOS GameController daemon (`gamecontrollerd`) constantly sends reset reports to controllers when foreground applications change.
   * If the app only sends a raw HID report every 1.0s, the OS's reset command will win, and the controller's triggers will go loose. A higher-frequency background timer (100ms - 200ms) is needed to continually enforce the trigger settings.
3. **Main-Thread I/O Blocking**:
   * Writing to HID via `IOHIDDeviceSetReport` is a blocking I/O operation. Running it on the main thread's run loop can block UI updates and introduce latency.

---

### 3. State Persistence Issues
Settings reset, freeze, or stop during background transitions due to two main design issues:

1. **No Power/App Nap Assertions**:
   * The app fails to register a background activity token with macOS. Consequently, App Nap freezes the background execution loop, preventing the transmission of keep-alive HID packets.
2. **Missing HID Route for Settings Updates in the Background**:
   * When an app profile activates (detected via `NSWorkspace.didActivateApplicationNotification`) or a user selects a menu-bar quick preset, the app calls `applyPreset(preset)`.
   * `applyPreset` calls `applyTriggerSettings()`, which exclusively uses the GameController API.
   * Because the app is backgrounded, the GameController API silently discards these configuration requests. There is no fallback call to `applyTriggerSettingsViaHID()`. Consequently, background setting changes are lost and never transmitted to the controller.

---

## Proposed Fix Strategy

### Phase A: Correct HID Payload Structuring

#### 1. Fix Weapon Mode Parameterization
Update the `.weapon` case in `triggerModeToHIDBytes` inside `Sources/Services/ControllerManager.swift` to use standard weapon mode `0x02` and pass direct parameters:

```swift
case .weapon:
    // Convert 0.0-1.0 float ranges to standard 0-9 values for DualSense
    let startPos = min(9, max(0, Int(round(start * 9.0))))
    let endPos = min(9, max(startPos + 1, Int(round(end * 9.0))))
    let strengthVal = min(8, max(0, Int(round(strength * 8.0))))
    
    params[0] = UInt8(startPos)
    params[1] = UInt8(endPos)
    params[2] = UInt8(strengthVal)
    return (0x02, params) // Standard weapon mode effect code
```

#### 2. Fix Vibration Mode Frequency Index
Correct index assignment for the frequency byte inside `bitpackTriggerArray`:

```swift
private func bitpackTriggerArray(mode: UInt8, strengthArray: [UInt8], frequency: UInt8) -> (mode: UInt8, params: [UInt8]) {
    var params = [UInt8](repeating: 0, count: 10)
    var strengthZones: UInt32 = 0
    var activeZones: UInt16 = 0
    
    for i in 0..<10 {
        let val = strengthArray[i]
        if val > 0 {
            let strengthValue = UInt32((val - 1) & 0x07)
            strengthZones |= (strengthValue << (3 * i))
            activeZones |= UInt16(1 << i)
        }
    }
    
    params[0] = UInt8(activeZones & 0xFF)
    params[1] = UInt8((activeZones >> 8) & 0xFF)
    params[2] = UInt8(strengthZones & 0xFF)
    params[3] = UInt8((strengthZones >> 8) & 0xFF)
    params[4] = UInt8((strengthZones >> 16) & 0xFF)
    params[5] = UInt8((strengthZones >> 24) & 0xFF)
    params[6] = frequency // Fixed index (was params[8])
    params[7] = 0
    params[8] = 0
    params[9] = 0
    
    return (mode, params)
}
```

---

### Phase B: Implement App Nap Prevention
Add activity tracking inside `ControllerManager.swift` to prevent the OS from suspending the application:

```swift
// In ControllerManager.swift
private var activityToken: NSObjectProtocol?

public func preventAppNap() {
    guard activityToken == nil else { return }
    activityToken = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled],
        reason: "DualSenseT Controller Keep-Alive"
    )
    logToFile("App Nap prevention activated.")
}

public func allowAppNap() {
    if let token = activityToken {
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
        logToFile("App Nap prevention deactivated.")
    }
}
```

* **Integration**: Call `preventAppNap()` in `controllerConnected(_:)` and `allowAppNap()` when a controller disconnects.

---

### Phase C: Dedicated Background Thread & Dispatch Source Timer
Replace the 1.0s main-runloop `pollingTimer` with a high-precision `DispatchSourceTimer` running on a dedicated serial background queue for HID operations:

```swift
// In ControllerManager.swift
private let hidQueue = DispatchQueue(label: "com.tushar.DualSenseT.hid", qos: .userInteractive)
private var hidTimer: DispatchSourceTimer?

public func startHidTimer() {
    hidTimer?.cancel()
    
    let timer = DispatchSource.makeTimerSource(queue: hidQueue)
    // Run at 150ms intervals to continuously override OS resets and prevent controller state timeouts
    timer.schedule(deadline: .now(), repeating: .milliseconds(150))
    timer.setEventHandler { [weak self] in
        guard let self = self else { return }
        if !self.isAppInForeground {
            self.applyTriggerSettingsViaHID()
        }
    }
    
    hidTimer = timer
    timer.resume()
    logToFile("Background HID Dispatch Timer started.")
}

public func stopHidTimer() {
    hidTimer?.cancel()
    hidTimer = nil
    logToFile("Background HID Dispatch Timer stopped.")
}
```

* **Integration**:
  * Call `startHidTimer()` inside `controllerConnected(_:)`.
  * Call `stopHidTimer()` inside `clearHIDDevice()` / disconnection hooks.
  * Keep `startPolling()` solely for battery level and connection type checks (which are safe to throttle and run at 1.0s).

---

### Phase D: Immediate Background Settings Routing
Modify `applyTriggerSettings(log:)` to route through the HID writer when in the background:

```swift
public func applyTriggerSettings(log: Bool = true) {
    // If backgrounded, GameController framework is inactive; route immediately to HID
    if !isAppInForeground {
        applyTriggerSettingsViaHID()
        return
    }
    
    guard let controller = activeController else {
        if log { logToFile("applyTriggerSettings skipped: activeController is nil") }
        return
    }
    guard let gamepad = controller.extendedGamepad as? GCDualSenseGamepad else {
        if log { logToFile("applyTriggerSettings error: gamepad is not GCDualSenseGamepad") }
        return
    }
    
    let l2 = gamepad.leftTrigger
    let r2 = gamepad.rightTrigger
    
    if log {
        logToFile("applyTriggerSettings (GC): L2Mode=\(l2Mode), R2Mode=\(r2Mode)")
    }
    
    // Apply settings using standard GCController API...
}
```

This guarantees that any changes to trigger settings (e.g. via quick preset menus or app profile detection) are applied immediately without wait times or freezing.
