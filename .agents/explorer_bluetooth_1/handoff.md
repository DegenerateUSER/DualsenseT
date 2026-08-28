# Handoff Report — Explorer 1

## 1. Observation
We observed the following files and code snippets in `/Users/tusharteotia/Documents/GitHub/DualsenseT/`:

### A. Bluetooth Output Report Layout, Sequence Numbers, and CRC32
In `Sources/Services/ControllerManager.swift`, lines 812–845:
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
And `computeBTCRC32` on lines 628–639:
```swift
    private func computeBTCRC32(_ data: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        // Process seed byte 0xA2 (DualSense BT output report seed)
        let seedIndex = Int((crc ^ UInt32(0xA2)) & 0xFF)
        crc = Self.crc32Table[seedIndex] ^ (crc >> 8)
        // Process report data
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = Self.crc32Table[index] ^ (crc >> 8)
        }
        return ~crc
    }
```

### B. Background Mode Scheduling
In `Sources/AppDelegate.swift`, lines 36–51 (handling `NSApplication.didResignActiveNotification`):
```swift
        // Background focus restoration observers using raw HID bypass
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
And in `Sources/Services/ControllerManager.swift`, lines 512–520 (the `pollingTimer`):
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

### C. State Persistence and Background Transitions
In `Sources/Services/ControllerManager.swift`, lines 16–28 (trigger setting `didSet` observers):
```swift
    @Published public var l2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    ...
    @Published public var r2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    ...
```
And `applyTriggerSettings` on lines 580–592:
```swift
    public func applyTriggerSettings(log: Bool = true) {
        guard let controller = activeController else { ... }
        guard let gamepad = controller.extendedGamepad as? GCDualSenseGamepad else { ... }
        ...
```
This method only interacts with the GameController framework object (`gamepad.leftTrigger` / `gamepad.rightTrigger`), which is ignored by macOS when the app is in the background.

---

## 2. Logic Chain
1. **Bluetooth Format and CRC Validation**:
   - The Bluetooth layout in `sendBTOutputReport` has a 3-byte header and a +2 payload offset compared to USB.
   - The CRC32 algorithm uses standard IEEE 802.3 and incorporates the `0xA2` Bluetooth HID transaction header seed, processing the first 74 bytes of the report.
   - **Conclusion**: The formatting, sequence counter logic, and CRC32 algorithm match DualSense specifications.

2. **Background Transmission Failure**:
   - When the app is backgrounded, the OS restricts GameController framework outputs, resetting the controller's triggers to default.
   - The app attempts to bypass this by setting `isAppInForeground = false` and calling `applyTriggerSettingsViaHID()`.
   - The 1.0s `pollingTimer` is scheduled using standard `Timer.scheduledTimer` on the main RunLoop under `.default` mode.
   - Once backgrounded, macOS App Nap and main RunLoop throttling degrade this timer, causing it to delay or cease firing entirely.
   - Since the DualSense controller watchdog triggers within 1.0–2.0 seconds, any throttling delay resets the trigger settings.
   - **Conclusion**: The scheduling mechanism is throttled and is too slow (1.0s) to keep the controller watchdog alive.

3. **Background Setting/Profile Freeze**:
   - Per-app profiles are evaluated when an app is focused via `NSWorkspace.didActivateApplicationNotification`.
   - Switching to a target game places `DualSenseT` in the background (`isAppInForeground = false`).
   - Changing settings via `applyPreset()` or properties calls `applyTriggerSettings()`.
   - `applyTriggerSettings()` only attempts to write using the GameController API, which is blocked by the OS in the background.
   - **Conclusion**: Settings changes are lost because they are not directly routed to the raw HID write (`applyTriggerSettingsViaHID()`) when the app is in the background.

---

## 3. Caveats
- No actual hardware tests were run since this is a read-only investigation. Analysis is based entirely on code logic and known DualSense / macOS behavior.
- Multi-controller scenarios (where `IOHIDManagerCopyDevices` could match multiple controllers) were not investigated in depth. The code assumes a single connected DualSense controller.

---

## 4. Conclusion
The bugs and shortcomings causing resetting, freezing, or stopping settings during background transitions are:
1. Standard `Timer` throttling on the main RunLoop due to background focus loss.
2. App Nap throttling background execution.
3. Too slow keep-alive frequency (1.0s timer vs. ~1-2s watchdog timeout).
4. No direct routing of settings updates to raw HID when in the background.

**Fix Strategy**:
- Replace the main loop `Timer` with a `DispatchSourceTimer` running at **100ms** (10Hz) on a background serial queue.
- Use `ProcessInfo.processInfo.beginActivity(options:reason:)` to disable App Nap in the background.
- Modify `applyTriggerSettings()` to check `!isAppInForeground` and immediately redirect to `applyTriggerSettingsViaHID()`.

---

## 5. Verification Method
1. **Compilation**: Run `swift build` or project build command to ensure no syntax errors.
2. **Foreground/Background Transition Verification**:
   - Check the console logs.
   - Observe if transition logs `"Application resigned active. Switching to raw HID output mode."` are followed immediately by repeated raw HID transmission logs at a 100ms interval.
   - Ensure the controller triggers do not lose their resistance or reset when switching focus away from the application.
3. **App Profile Verification**:
   - Link a profile to a game, focus the game, and verify that the trigger effect changes instantly on the controller without returning focus to the `DualSenseT` app.
