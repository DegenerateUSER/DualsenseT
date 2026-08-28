# DualSenseT Bluetooth and Background Mode Analysis

## Executive Summary
This report analyzes issues in `Sources/Services/ControllerManager.swift` and `Sources/AppDelegate.swift` concerning Bluetooth output report formats, background transmission scheduling, and state persistence during background transitions. The investigation revealed critical bugs in the raw HID report flags, parameter packing, App Nap throttling, and background routing that cause trigger settings to reset, freeze, or fail to apply when the application is backgrounded or loses focus.

---

## 1. Bluetooth/USB Output Report Format, Sequence Numbers, and CRC32

### 1.1 Output Report Formats & Activation Flags
When the application is in the background, it falls back to raw HID reports using `sendBTOutputReport` (for Bluetooth) and `sendUSBOutputReport` (for USB) to bypass Apple's GameController framework focus restrictions. However, these functions fail to apply trigger settings due to incorrect activation flags:
- **`valid_flag1` Bug (Critical)**:
  - In `sendUSBOutputReport` (line 790), the code sets `report[2] = 0x04` (index 2 is `valid_flag1` for USB).
  - In `sendBTOutputReport` (line 820), the code sets `report[4] = 0x04` (index 4 is `valid_flag1` for BT).
  - According to the DualSense HID protocol specification, the bits for `valid_flag1` are:
    - `0x01` (bit 0): Enable Right Trigger emulation/effect
    - `0x02` (bit 1): Enable Left Trigger emulation/effect
    - `0x04` (bit 2): Enable Player LEDs setup
  - Because the code sets `valid_flag1` strictly to `0x04`, the controller only updates the Player LEDs (if any) and **completely ignores the R2/L2 mode and parameter bytes**.
  - **Fix**: Set `valid_flag1` to `0x03` (enable Right + Left triggers) or `0x07` (Right + Left triggers + Player LEDs). Since the app does not set player LEDs in the report, `0x03` is recommended.

- **USB Report Size**:
  - `sendUSBOutputReport` (line 788) initializes the USB output report with a size of 48 bytes:
    `var report = [UInt8](repeating: 0, count: 48)`
  - The standard size for the DualSense USB output report (Report ID `0x02`) is **63 bytes**. A size mismatch can cause some USB stacks or firmware versions to reject the report with a parameter error.
  - **Fix**: Initialize the report with a size of 63 bytes.

- **Weapon Mode Parameter Packing**:
  - In `triggerModeToHIDBytes` (lines 693-702), the `.weapon` mode parameters are bit-packed as follows:
    ```swift
    let startStopZones = UInt16((1 << startPos) | (1 << endPos))
    params[0] = UInt8(startStopZones & 0xFF)
    params[1] = UInt8((startStopZones >> 8) & 0xFF)
    ```
  - For DualSense custom weapon mode (Report `0x25`), the controller expects `params[0]` to be the start zone mask (`1 << startPos`) and `params[1]` to be the end zone mask (`1 << endPos`) as two independent 8-bit parameters.
  - Packing them into a single `UInt16` and splitting by byte order merges both masks into `params[0]` (if both positions are < 8), leaving `params[1] = 0`. This misconfigures the trigger's zone limits.
  - **Fix**:
    ```swift
    params[0] = UInt8(1 << startPos)
    params[1] = UInt8(1 << endPos)
    ```

### 1.2 Sequence Numbers
- **Implementation**: The sequence number is correctly formatted in byte 1 of the Bluetooth report:
  `report[1] = (btSequenceNumber << 4) | 0x02`
- The counter `btSequenceNumber` increments and wraps correctly:
  `btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F`
- **Shortcoming**: The counter is a single global instance variable. If multiple controllers are connected, their sequence numbers would share the same counter, causing sequence skips. However, since only one active controller is managed at a time, this has minimal practical impact.

### 1.3 CRC32 Calculations
- **Implementation**: `computeBTCRC32` implements the standard IEEE 802.3 CRC32 algorithm (polynomial `0xEDB88320`).
- It correctly seeds the calculation with the L2CAP HID transaction header byte `0xA2` (which is prepended by the OS Bluetooth stack but must be included in the checksum).
- The CRC bytes are appended at the end of the report (bytes 74-77 of the 78-byte report) in little-endian order, matching the DualSense requirements.

---

## 2. Background Transmission Scheduling

### 2.1 Current Scheduling Mechanism
- When the app is in the foreground, changes are pushed immediately using the GameController API via `applyTriggerSettings()`.
- When the app loses focus (backgrounded), `AppDelegate.swift` listens for `NSApplication.didResignActiveNotification`, sets `isAppInForeground = false`, and schedules two raw HID reports at `+0.05s` and `+0.2s` on the main queue using `DispatchQueue.main.asyncAfter`.
- A 1-second `Timer` scheduled on the main run loop in `startPolling()` periodically calls `applyTriggerSettingsViaHID()` when `isAppInForeground` is `false`.

### 2.2 Shortcomings & Bugs in Scheduling
1. **App Nap Throttling**: macOS aggressively throttles the main run loop of applications that are backgrounded or have no visible window (App Nap). The `pollingTimer` and `asyncAfter` blocks are delayed or suspended, stopping keep-alive packets.
2. **GameController Framework Reset Race**: When focus is lost, the GameController framework automatically transmits a reset packet to clear trigger effects. If our scheduled raw HID writes execute before or at the same time as this reset packet, the reset packet overwrites our settings. If App Nap delays our write, the triggers remain disabled indefinitely.
3. **Low Polling Frequency**: A 1.0-second interval is slow, leaving a wide window where the trigger settings can be reset by the OS or other applications.

---

## 3. State Persistence and Background Transitions

### 3.1 Why Settings Reset, Freeze, or Stop
1. **Reset on Focus Loss**:
   - The GameController framework's reset packet disables the triggers.
   - The app's raw HID fallback packets try to restore the settings but fail because of the incorrect `valid_flag1 = 0x04` bug, leaving the triggers reset.
2. **Freeze on Background Changes**:
   - When settings are changed (e.g., via a incoming UDP command or profile transition) while the app is in the background, the `didSet` observers call `applyTriggerSettings()`.
   - `applyTriggerSettings()` only invokes the `GCController` API, which is blocked by the OS in the background. It does not fall back to `applyTriggerSettingsViaHID()`.
   - Consequently, settings changes are ignored and frozen until the app returns to the foreground.
3. **No Launch Persistence**:
   - The trigger modes, starts, ends, strengths, amplitudes, and frequencies are not saved to `UserDefaults`. On app launch, the settings reset to default values.

---

## 4. Proposed Fix Strategy

### Step 1: Correct the HID Report Flags and Sizes
Update `Sources/Services/ControllerManager.swift`:
- Set `valid_flag1` to `0x03` (Right + Left Trigger enabled) in `sendUSBOutputReport` and `sendBTOutputReport`.
  - In `sendUSBOutputReport`: change `report[2] = 0x04` to `report[2] = 0x03`.
  - In `sendBTOutputReport`: change `report[4] = 0x04` to `report[4] = 0x03`.
- Increase the USB report size to 63 bytes:
  - In `sendUSBOutputReport`: change `var report = [UInt8](repeating: 0, count: 48)` to `var report = [UInt8](repeating: 0, count: 63)`.

### Step 2: Fix Weapon Mode Parameter Packing
Update `triggerModeToHIDBytes` in `Sources/Services/ControllerManager.swift`:
- Replace the `UInt16` packing with separate byte assignments:
  ```swift
  case .weapon:
      let startPos = min(7, max(2, Int(round(start * 9.0))))
      let endPos = min(8, max(startPos + 1, Int(round(end * 9.0))))
      let strengthVal = min(8, max(1, Int(round(strength * 7.0)) + 1))
      
      params[0] = UInt8(1 << startPos)
      params[1] = UInt8(1 << endPos)
      params[2] = UInt8(strengthVal - 1)
      return (0x25, params)
  ```

### Step 3: Support Background Transitions in `applyTriggerSettings`
Update `applyTriggerSettings` in `Sources/Services/ControllerManager.swift` to automatically route settings to the raw HID writer when backgrounded:
```swift
public func applyTriggerSettings(log: Bool = true) {
    if !isAppInForeground {
        applyTriggerSettingsViaHID()
        return
    }
    
    guard let controller = activeController else { ... }
    ...
}
```

### Step 4: Prevent App Nap Throttling
Use macOS `ProcessInfo` API to request latency-critical execution and prevent App Nap:
- Add a property in `ControllerManager.swift`:
  `private var backgroundActivity: NSObjectProtocol?`
- Implement helper methods:
  ```swift
  public func preventAppNap() {
      guard backgroundActivity == nil else { return }
      backgroundActivity = ProcessInfo.processInfo.beginActivity(
          options: [.latencyCritical, .idleSystemSleepDisabled],
          reason: "DualSenseT Controller Keep-Alive"
      )
  }

  public func allowAppNap() {
      if let activity = backgroundActivity {
          ProcessInfo.processInfo.endActivity(activity)
          backgroundActivity = nil
      }
  }
  ```
- Call `preventAppNap()` when a controller connects, and `allowAppNap()` when it disconnects.

### Step 5: Replace Polling Timer with a DispatchSourceTimer
Use a high-priority background queue and a `DispatchSourceTimer` instead of a main run-loop `Timer`:
- In `ControllerManager.swift`, replace `pollingTimer` with:
  ```swift
  private let keepAliveQueue = DispatchQueue(label: "com.tushar.DualSenseT.keepalive", qos: .userInteractive)
  private var keepAliveTimer: DispatchSourceTimer?
  ```
- Implement `startBackgroundPolling()`:
  ```swift
  public func startBackgroundPolling() {
      keepAliveTimer?.cancel()
      let timer = DispatchSource.makeTimerSource(queue: keepAliveQueue)
      timer.schedule(deadline: .now(), repeating: .milliseconds(500))
      timer.setEventHandler { [weak self] in
          guard let self = self else { return }
          if !self.isAppInForeground {
              self.applyTriggerSettingsViaHID()
          }
      }
      timer.resume()
      keepAliveTimer = timer
  }
  ```
- This ensures that if the OS sends a focus-loss reset, our background queue will quickly re-apply the trigger settings within 500ms.

### Step 6: Persist Active Settings
- Add loading/saving of trigger settings (L2/R2 modes, start, end, strength, amplitude, frequency, and LED colors) to `UserDefaults` in `ControllerManager.swift` to ensure they persist across application launches.
