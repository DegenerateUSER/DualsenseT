# Handoff Report - Explorer Bluetooth 3

## 1. Observation
I observed the following source code locations and behaviors in the workspace:

- In `Sources/Services/ControllerManager.swift`:
  - **Line 790** (USB report setup):
    ```swift
    report[0] = 0x02  // USB Report ID
    report[1] = 0x04 | 0x08
    report[2] = 0x04
    ```
  - **Line 820** (Bluetooth report setup):
    ```swift
    report[3] = 0x04 | 0x08   // valid_flag0
    report[4] = 0x04           // valid_flag1
    ```
  - **Line 698-702** (Weapon mode parameter packing):
    ```swift
    let startStopZones = UInt16((1 << startPos) | (1 << endPos))
    
    params[0] = UInt8(startStopZones & 0xFF)
    params[1] = UInt8((startStopZones >> 8) & 0xFF)
    params[2] = UInt8(strengthVal - 1)
    ```
  - **Line 513-529** (Timer-based polling):
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
  - **Line 580** (`applyTriggerSettings` does not delegate to raw HID when backgrounded):
    ```swift
    public func applyTriggerSettings(log: Bool = true) {
        guard let controller = activeController else { ... }
        guard let gamepad = controller.extendedGamepad as? GCDualSenseGamepad else { ... }
        ...
    ```
  - **Line 114-120** (Settings not loaded/saved on initialization):
    ```swift
    public init() {
        GCController.shouldMonitorBackgroundEvents = true
        setupControllerDiscovery()
        startPolling()
        loadTouchpadActions()
        loadAppProfiles()
    }
    ```

- In `Sources/AppDelegate.swift`:
  - **Line 36-51** (Background resigned active handling):
    ```swift
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

---

## 2. Logic Chain
1. **Background Mode/Focus Triggers**: When the app resigns active status, the macOS GameController framework sends a reset report to turn off trigger effects. The app attempts to bypass this by setting `isAppInForeground = false` and calling `applyTriggerSettingsViaHID()` via `asyncAfter` and a 1.0-second `Timer` (Observation 1: `startPolling`).
2. **Timer Suspending (App Nap)**: Because the `Timer` is scheduled on the main run loop, macOS App Nap throttles it when the app is backgrounded. This suspends the keep-alive updates, causing the triggers to remain disabled.
3. **Invalid Activation Flags (valid_flag1)**: Even when `applyTriggerSettingsViaHID` executes, the DualSense controller ignores the trigger settings. The HID specification dictates that bits `0x01` (Right Trigger) and `0x02` (Left Trigger) in `valid_flag1` must be set. The current code only sets it to `0x04` (Player LEDs) for both USB and BT (Observation 1: lines 790 and 820).
4. **Invalid USB Report Size**: `sendUSBOutputReport` allocates 48 bytes (Observation 1: line 788), but the standard DualSense USB output report 0x02 is 63 bytes. This size mismatch can cause the OS USB stack or controller firmware to reject the packet.
5. **Faulty Weapon Mode Parameter Mapping**: Packing the start/stop positions into a single `UInt16` and splitting them by byte order causes start and end zones to bleed together in `params[0]` if they are less than 8, leaving `params[1]` as 0 (Observation 1: lines 698-702). This misconfigures the trigger's zone limits on the hardware.
6. **Setting Freeze during Background State**: If a setting is updated while the app is in the background (e.g. via UDP or profiles), the didSet observer calls `applyTriggerSettings()`. However, `applyTriggerSettings` only uses the GameController API, which macOS blocks in the background (Observation 1: line 580). This freezes updates until the app returns to the foreground.

---

## 3. Caveats
- No real DualSense controller hardware was connected to test the raw HID output report changes. The logic is based on verified specifications of the DualSense HID protocol.
- App Nap behavior varies depending on OS configurations, energy saving preferences, and whether other background operations are running.

---

## 4. Conclusion
The background mode trigger resets and freezes are caused by:
1. Incorrect `valid_flag1` values in raw HID reports that cause the controller to ignore trigger updates.
2. Aggressive macOS App Nap throttling that suspends the main run loop keep-alive timer.
3. Lack of redirection to raw HID output in `applyTriggerSettings()` when the app is backgrounded.
4. Incorrect packing of weapon mode start/end zones.

Implementing the proposed fix strategy will resolve these issues.

---

## 5. Verification Method
1. **Compilation**: Run `./build.sh` to ensure the project compiles successfully.
2. **Unit Tests**: Run `./build.sh test` to execute all unit tests. All tests must pass:
   ```
   ========================================
           DualSenseT UNIT TESTS           
   ========================================
     🟢 Passed: testPresetSerialization
     🟢 Passed: testParameterValueDecoding
     🟢 Passed: testTouchpadSwipeGestures
     🟢 Passed: testQuaternionNormalization
   ========================================
   ```
3. **Manual Validation**:
   - Run the app, connect a DualSense controller via Bluetooth or USB.
   - Set trigger effects, background the app (minimize or click another window).
   - Check if trigger effects remain active in the background.
