# Handoff Report: DualSense Bluetooth & Background Behavior Analysis

## 1. Observation
We observed the following code in the codebase:
1. **Weapon Mode Parameters & Byte**:
   In `Sources/Services/ControllerManager.swift` (lines 693-703):
   ```swift
        case .weapon:
            let startPos = min(7, max(2, Int(round(start * 9.0))))
            let endPos = min(8, max(startPos + 1, Int(round(end * 9.0))))
            let strengthVal = min(8, max(1, Int(round(strength * 7.0)) + 1))
            let startStopZones = UInt16((1 << startPos) | (1 << endPos))
            
            params[0] = UInt8(startStopZones & 0xFF)
            params[1] = UInt8((startStopZones >> 8) & 0xFF)
            params[2] = UInt8(strengthVal - 1)
            return (0x25, params)
   ```
2. **Vibration Mode Frequency Byte Index**:
   In `Sources/Services/ControllerManager.swift` (lines 730-741):
   ```swift
        params[0] = UInt8(activeZones & 0xFF)
        params[1] = UInt8((activeZones >> 8) & 0xFF)
        params[2] = UInt8(strengthZones & 0xFF)
        params[3] = UInt8((strengthZones >> 8) & 0xFF)
        params[4] = UInt8((strengthZones >> 16) & 0xFF)
        params[5] = UInt8((strengthZones >> 24) & 0xFF)
        params[6] = 0
        params[7] = 0
        params[8] = frequency
        params[9] = 0
   ```
3. **Background Update Loop**:
   In `Sources/Services/ControllerManager.swift` (lines 512-520):
   ```swift
    public func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let controller = self.activeController else { return }
            
            // Use raw HID when backgrounded to bypass GameController framework focus restriction
            if !self.isAppInForeground {
                self.applyTriggerSettingsViaHID()
            }
   ```
   And `pollingTimer` runs on the Main Thread / main runloop.
4. **App Resign Active Notification**:
   In `Sources/AppDelegate.swift` (lines 35-51):
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
5. **Preset Application Method**:
   In `Sources/Services/ControllerManager.swift` (lines 177-182):
   ```swift
    public func batchUpdate(_ updates: () -> Void) {
        isBatchUpdating = true
        updates()
        isBatchUpdating = false
        applyTriggerSettings()
    }
   ```
   Where `applyTriggerSettings()` only invokes standard GameController methods.

---

## 2. Logic Chain
1. **Weapon Mode Failure**:
   * As observed in (1), `0x25` is returned as the effect mode byte. However, standard DualSense specifications require `0x02` for weapon mode.
   * Furthermore, the start and end positions are packed into a 16-bit bitmask `(1 << startPos) | (1 << endPos)` instead of being set directly as integer values in `params[0]` and `params[1]`.
   * Therefore, weapon mode trigger settings are ignored or garbled when the application is backgrounded.
2. **Vibration Mode Failure**:
   * As observed in (2), inside `bitpackTriggerArray` (used by vibration mode `0x26`), the frequency is written to `params[8]`.
   * Standard DualSense custom vibration mode (`0x26`) expects the frequency byte at index 6 (`params[6]`).
   * Therefore, custom vibration commands are processed with a frequency of `0` by the controller, rendering vibration inactive.
3. **App Nap & Throttling freeze**:
   * As observed in (3), background updates are sent by `pollingTimer`, which is a standard Cocoa `Timer` running on the main runloop.
   * When the application loses focus and has its windows closed, macOS triggers App Nap. Under App Nap, main runloop timers are heavily throttled (firing once every 10+ seconds) or completely suspended.
   * Consequently, the background keep-alive packets stop sending, freezing the controller's triggers in their last state or letting the OS's default reset take over.
4. **Slow update frequency reset**:
   * As observed in (3), the `pollingTimer` runs at a 1.0s interval.
   * macOS `gamecontrollerd` sends default reset commands to the controller when focus changes.
   * If raw HID packets are only written at 1.0s, the OS's resets will override them immediately during the remaining 99% of the time. We need a higher-frequency update loop (100ms - 200ms) in the background.
5. **Preset Update Hook Failure in Background**:
   * As observed in (4) and (5), when the app switches profile or applies a menu bar quick preset while in the background, it calls `applyTriggerSettings()`, which only invokes the GameController API.
   * Since the GameController API ignores background app updates, the settings are never sent to the controller until the background timer eventually ticks (which is blocked under App Nap).

---

## 3. Caveats
* The analysis assumes that only one DualSense controller is active at any time. When multiple controllers are connected, `findHIDOutputDevice()` returns the first device matching the VID/PID that has `maxOutput >= 48`, which may not correspond to the currently active GCController.
* Power state management (sleep/wake of the system) is not covered by the proposed App Nap prevention activity token, and system-level sleep will still suspend the transmission.

---

## 4. Conclusion
The background adaptive trigger failures are caused by:
1. Malformed HID reports for weapon mode (`0x25` instead of `0x02` with bitmasked positions) and vibration mode (frequency in `params[8]` instead of `params[6]`).
2. App Nap suspension of the main-runloop 1.0s `pollingTimer` when backgrounded.
3. Lack of a fallback to `applyTriggerSettingsViaHID()` during background preset/profile modifications.

A complete fix strategy involves correcting the HID payload mapping, preventing App Nap using `ProcessInfo.processInfo.beginActivity`, scheduling background writes on a dedicated `DispatchSourceTimer` on a serial background queue (running at 150ms intervals), and routing background settings updates through the raw HID bypass.

---

## 5. Verification Method
1. **Compilation**: Run `./build.sh` to ensure the project compiles successfully.
2. **Unit Tests**: Run `./build.sh test` to execute unit tests.
3. **Log Auditing**: Verify that `dualsenset.log` output shows background transitions and HID writes without interruption after closing the main window.
4. **Behavioral Test**: Verify that both L2/R2 triggers keep their adaptive properties when the main window is closed, and when switching active applications (triggering profile changes).
