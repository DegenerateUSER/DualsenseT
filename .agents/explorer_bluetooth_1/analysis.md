# DualSense Bluetooth, Background Mode, and State Persistence Analysis

This report analyzes the Bluetooth output report formatting, background transmission scheduling, and state persistence issues in `Sources/Services/ControllerManager.swift` and `Sources/AppDelegate.swift`, identifying shortcomings and proposing a detailed fix strategy.

---

## 1. Bluetooth Output Report Format, Sequence Numbers, and CRC32 Calculations

### Formatting & Layout
In `Sources/Services/ControllerManager.swift`, the DualSense output report formatting is handled for two transports: USB (in `sendUSBOutputReport`) and Bluetooth (in `sendBTOutputReport`).
* **USB (Report ID `0x02`)**: Uses a 48-byte report where trigger states start at index 11 (R2) and 22 (L2), and lightbar settings are at index 39 (`valid_flag2`), 42 (`lightbar_setup`), and 45–47 (RGB color).
* **Bluetooth (Report ID `0x31`)**: Uses a 78-byte report. The layout structure matches DualSense specifications by shifting all payload offsets by **+2 bytes** compared to USB.
  * `report[0]` = `0x31` (Report ID)
  * `report[1]` = `(btSequenceNumber << 4) | 0x02` (Sequence number in high nibble, tag `0x02` in low nibble)
  * `report[2]` = `0x10` (Bluetooth tag: `DS_OUTPUT_CONFIG2_COMPATIBLE`)
  * `report[3]` = `0x04 | 0x08` (valid_flag0: enables R2 and L2 trigger effects)
  * `report[4]` = `0x04` (valid_flag1: enables lightbar/LEDs)
  * `report[13]` = `r2.mode` (R2 mode)
  * `report[24]` = `l2.mode` (L2 mode)
  * `report[41]` = `0x02 | 0x10` (valid_flag2: enables lightbar and LED setup)
  * `report[44]` = `0x02` (lightbar setup: host controlled)
  * `report[47..49]` = `ledR`, `ledG`, `ledB` (RGB Color)

### Sequence Numbers
The sequence number `btSequenceNumber` is incremented on each Bluetooth report call:
```swift
btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F
```
This restricts the counter to a 4-bit range (`0x00` to `0x0F`), which complies with the DualSense hardware requirement.

### CRC32 Calculations
The CRC32 is calculated using a precomputed IEEE 802.3 table (`0xEDB88320` polynomial). The controller expects the CRC to include the Bluetooth L2CAP transaction header seed byte `0xA2` followed by the report ID and the entire report payload (excluding the CRC itself).
The implementation correctly handles this by seeding the CRC calculation with `0xA2` and then iterating over the first 74 bytes of the report (`report[0..<74]`):
```swift
private func computeBTCRC32(_ data: [UInt8]) -> UInt32 {
    var crc: UInt32 = 0xFFFFFFFF
    let seedIndex = Int((crc ^ UInt32(0xA2)) & 0xFF)
    crc = Self.crc32Table[seedIndex] ^ (crc >> 8)
    for byte in data {
        let index = Int((crc ^ UInt32(byte)) & 0xFF)
        crc = Self.crc32Table[index] ^ (crc >> 8)
    }
    return ~crc
}
```
The resulting 4-byte CRC is appended to indices 74–77 of the 78-byte report.

---

## 2. Background Transmission Scheduling

### Current Implementation
* When the application loses focus (`NSApplication.didResignActiveNotification` is received by the `AppDelegate`):
  1. `controllerManager.isAppInForeground` is set to `false`.
  2. Two raw HID reports are scheduled using `DispatchQueue.main.asyncAfter` (at 0.05 seconds and 0.2 seconds).
* While in the background, a `pollingTimer` running in `ControllerManager.swift` tick-polls once every **1.0 second**:
  ```swift
  pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      if !self.isAppInForeground {
          self.applyTriggerSettingsViaHID()
      }
      ...
  }
  ```

### Shortcomings
1. **Watchdog Timeout**: The DualSense hardware has an internal timeout (approx. 1.0 to 2.0 seconds) for custom trigger effects and LED states. If it doesn't receive periodic output reports within this window, it reverts the triggers to the default "off" (loose) state. Running a timer at 1.0s is extremely close to the watchdog threshold; any delay/jitter in the main loop will cause the controller to reset.
2. **Main RunLoop Throttling**: The `pollingTimer` is scheduled using `Timer.scheduledTimer` on the main RunLoop (using `.default` mode). When a macOS app is backgrounded, the OS throttles or completely pauses the main RunLoop's execution. This stops the timer from firing, leading to immediate controller state resets.
3. **App Nap Throttling**: macOS App Nap aggressively throttles CPU usage and timers for background applications. Without requesting a process activity assertion, the app's background ticks will be delayed by seconds or minutes.

---

## 3. State Persistence and Background Transitions

### Issues Identified
1. **OS-Initiated Resets**: When the app loses focus, macOS tells the GameController framework that the application is no longer active, causing the OS to send a hardware reset command to the controller. The current implementation attempts to override this using two one-shot delayed HID calls (at 0.05s and 0.2s), but if the OS reset occurs later, or if the controller resets on its own, it won't be overridden until the next 1.0-second timer tick (which might be delayed due to throttling).
2. **Lack of Immediate HID Writes on State Changes**:
   When the app is in the background and a trigger setting changes (e.g., due to a per-app profile auto-switch triggered by `NSWorkspace.didActivateApplicationNotification`), it calls:
   ```swift
   @Published public var l2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
   ```
   `applyTriggerSettings()` only updates the GameController API. In the background, the GameController API calls are silently ignored by the OS. There is no call to `applyTriggerSettingsViaHID()` upon state changes, meaning the new profile settings are never applied until the next (throttled) 1.0s timer tick.

---

## 4. Proposed Fix Strategy

To resolve the reset, freezing, and background transition issues, the following strategy is proposed:

### A. Dedicated Dispatch Source Timer for Keep-Alive
Replace the 1.0s `Timer` on the main RunLoop with a high-frequency `DispatchSourceTimer` running on a background serial queue.
* **Interval**: Set to **100ms** (10Hz) to safely keep the controller watchdog alive and immediately override any OS-initiated reset commands.
* **Thread Safety**: Execute the actual HID write on the main thread via `DispatchQueue.main.async` to ensure thread-safe access to `@Published` settings and `btSequenceNumber`, or capture/synchronize properties to run the write completely on the background thread.

### B. Disable App Nap in the Background
Acquire a process activity assertion when the app is backgrounded to prevent macOS from throttling the background loop:
```swift
private var backgroundActivityToken: NSObjectProtocol?

func startBackgroundActivity() {
    if backgroundActivityToken == nil {
        backgroundActivityToken = ProcessInfo.processInfo.beginActivity(
            options: [.latencyCritical, .userInitiatedActive],
            reason: "DualSense Keep-Alive"
        )
    }
}

func stopBackgroundActivity() {
    if let token = backgroundActivityToken {
        ProcessInfo.processInfo.endActivity(token)
        backgroundActivityToken = nil
    }
}
```

### C. Direct HID Routing on Background State Changes
Modify `applyTriggerSettings()` to check `isAppInForeground`. If `false`, route the update immediately through `applyTriggerSettingsViaHID()`:
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
This ensures that when a per-app profile changes in the background, the new settings are written to the controller instantly.
