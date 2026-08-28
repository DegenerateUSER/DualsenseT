# DualSenseT — Implementation Progress Tracker

> **Purpose:** This file tracks what has been done, what is in progress, and what remains.  
> If a session ends mid-task, the next session should read this file FIRST to resume seamlessly.  
> **Last Updated:** 28/08/2026 15:40 IST

---

## Current Status: 🟢 USB + Bluetooth Feature Pass Hardware-Verified

User hardware retest confirms that adaptive triggers, haptics/rumble, lightbar, mic LED,
player LEDs, sensors, and input now work over both Bluetooth and USB. The Live Map is also
confirmed complete and functional. The BT `seq_tag` low-nibble fix, required HAPTICS_SELECT,
two-report LED ownership sequence, and 48-byte USB report are now a known-good checkpoint.
Test suite: **61/61 passing**.

---

## ✅ Session: Full Hardware Verification (28/08/2026, 15:39 IST)

**User-confirmed on physical DualSense hardware:**
- [x] Bluetooth L2 and R2 adaptive-trigger modes.
- [x] Bluetooth lightbar, player LEDs, mic LED, and rumble/haptics.
- [x] Bluetooth sensors and live input.
- [x] USB adaptive triggers, lightbar, player LEDs, mic LED, and rumble/haptics.
- [x] Live Map is complete and all mapped inputs work.

**UI correction:** Removed the obsolete yellow warning claiming adaptive triggers are
unavailable over Bluetooth. The exclusive raw-HID path now demonstrably supports them.

**Checkpoint rule:** Preserve the current HID builders and connection lifecycle as the
known-good hardware baseline. Future Live Map improvements must be visual-only and must not
alter `ControllerManager` output report bytes, Bluetooth sequencing/CRC, or HID ownership.

---

## 🛠 Session: Hardware Feedback Correction (28/08/2026, 15:20 IST)

### ✅ Hardware-Verified and Locked

**Bluetooth L2 and R2 adaptive-trigger modes work.**
- This confirms the 78-byte BT transport, CRC32, trigger offsets, trigger encodings, and
  especially `seq_tag = sequence << 4` (low nibble `0`) are accepted by the controller.
- Regression tests retain the zero low nibble and the exact L2/R2 enable bits. Do not
  restore the former `| 0x02` tag.

### Regressions Found and Corrected

**1. USB haptics stopped after `HAPTICS_SELECT` was removed**
- **What was broken in the previous attempt:** The prior interpretation of
  `HAPTICS_SELECT` was wrong. Linux `hid-playstation.c` explicitly sets it with the comment
  **"Select classic rumble style haptics and enable it."**
- **Fix:** Restore `valid_flag0 = 0x0F` on USB and BT:
  COMPATIBLE_VIBRATION (`0x01`) + HAPTICS_SELECT (`0x02`) + R2 (`0x04`) + L2 (`0x08`).
- Trigger bytes/offsets are unchanged, preserving the confirmed BT success.

**2. Lightbar setup and LED state were incorrectly combined in one report**
- The first attempt changed `lightbar_setup` from `LIGHT_OUT (0x02)` to `LIGHT_ON (0x01)`
  but still mixed the setup flag with RGB/player-LED fields. This is not the sequence used
  by the Linux driver.
- **Correct sequence now implemented per `dualsense_reset_leds()`:**
  1. Once per new USB/BT HID connection, send a dedicated setup report containing only
     `LIGHTBAR_SETUP_CONTROL_ENABLE` and `LIGHT_OUT (0x02)`. This ends the controller-owned
     startup animation and releases LED control to software.
  2. After 10 ms, send the normal state report with lightbar RGB + player LED flags/values,
     **without any lightbar-setup command**.
- Per-transport initialization state resets on disconnect/reopen. BT setup reports receive
  their own sequence number and valid CRC32.

**3. USB report length exceeded the device's macOS HID descriptor**
- The hardware log reports `IOHIDMaxOutputReportSize = 48` for USB, but the app sent the
  Linux-padded 63-byte buffer. All used USB fields end at byte 47.
- **Fix:** USB setup and state reports are exactly 48 bytes. BT remains exactly 78 bytes.

**4. Live Map's lower/right controller body was covered by a render spill**
- **Root Cause confirmed from the user's screenshot and isolated PNG render:** the custom
  touchpad `Shape` occupied the entire controller canvas while returning an offset subpath.
  Its gradient backing leaked from the touchpad's top-left corner to the bottom/right canvas
  edges, drawing the large grey rectangle over the shell. The controller geometry itself
  was present underneath.
- **Fix:** The touchpad is now a standard `RoundedRectangle` with an explicit local frame
  and position. Both grips and the complete lower shell render correctly. Removed the
  ambient backlight that produced a blue wedge between the grips.

### Regression Coverage Added
- `testUSBOutputReportCarriesAllHardwareState`
- `testBTOutputReportCarriesAllHardwareState`
- `testUSBLEDSetupIsDedicatedReport`
- `testBTLEDSetupIsDedicatedSignedReport`
- TESTING captures now call the production report builders rather than maintaining duplicate
  serializers that could drift.
- **61/61 tests passing**; corrected Live Map verified with the real SwiftUI view rendered
  offscreen at 1400×1040.

### ⚠️ Hardware Retest Required
- [x] Bluetooth L2/R2 adaptive-trigger modes.
- [x] USB rumble/haptics after restoring HAPTICS_SELECT.
- [x] USB lightbar and player indicator LEDs after the two-report initialization sequence.
- [x] BT lightbar, player LEDs, rumble, and mic LED after the two-report sequence.
- [x] Live Map in the packaged app.

---

## 🔧 Session: Initial BT Output / USB Lightbar / Live Map Attempt (28/08/2026, PM)

> **Partially superseded by the Hardware Feedback Correction above.** The BT sequence-tag
> change was confirmed correct. The `LIGHT_ON` and HAPTICS_SELECT conclusions were incorrect
> and have been replaced by the driver-matching implementation documented above.

**Context:** User's first hardware test after the audit: "nothing works over bluetooth
except the sensors, and over wired connection the lightbar doesn't work at all, and the
live map on the frontend is totally broken." Sensors working over BT proved the input path
(0x31 parsing) was fine — so output reports were being built wrong or rejected wholesale.

### Bugs Fixed

**1. BT output reports rejected — `seq_tag` low nibble was `0x02`** (`ControllerManager.swift` → `buildBTOutputReport`)
- **Root Cause:** Byte 1 of the BT 0x31 output report was `(seq << 4) | 0x02`. Both
  authoritative references — Linux `hid-playstation.c` ("Lowest 4-bit is tag and can be
  zero for now") and `dualsensectl` (`seq_tag` low-nibble bitfield left 0) — require the
  low nibble to be **0**. A nonzero tag risks the firmware silently dropping every output
  report → exactly the "nothing works over BT" symptom. (`hid_write` itself succeeds —
  confirmed by log "first output report accepted by hid_write (78 bytes)" — so this was a
  content-level rejection, not a transport failure.)
- **Fix:** `report[1] = btSequenceNumber << 4`.

**2. Initial lightbar diagnosis — SUPERSEDED** (`buildUSBOutputReport` / `buildBTOutputReport`)
- **Root Cause:** `lightbar_setup` byte was `0x02` with `valid_flag2` bit 1
  (`LIGHTBAR_SETUP_CONTROL_ENABLE`) set. Per `dualsensectl`/`hid-playstation.c`,
  `0x02 = DS_OUTPUT_LIGHTBAR_SETUP_LIGHT_OUT` ("fade light out" — the kernel uses it in the
  driver *remove* path). `0x01 = LIGHT_ON`. Every output report was actively turning the
  lightbar off → lightbar dead over USB (and would have been over BT too).
- **Initial fix (incorrect):** `lightbar_setup = 0x01` in every state report.
- **Current fix:** dedicated one-time `LIGHT_OUT (0x02)` setup report, then a separate RGB/
  player-LED state report with no setup flag.

**3. `HAPTICS_SELECT` diagnosis — SUPERSEDED** (both builders)
- Removing bit 1 caused USB haptics to stop. The kernel explicitly requires it for classic
  rumble-style haptics. It is restored; `valid_flag0` is `0x0F`.

**4. Junk/undefined valid-flag bits** (both builders)
- `valid_flag1` bit 1 (POWER_SAVE_CONTROL_ENABLE) was set although we never manage power
  save → dropped; now `0x01|0x04|0x10` (mic LED + lightbar RGB + player LEDs).
- `valid_flag2` included undefined bit 4 (`0x10`) → dropped. Normal state reports now use
  only `0x04` (COMPATIBLE_VIBRATION2); dedicated LED setup reports use only `0x02`.

**5. Live Map rebuilt** (`ControllerVisualizerView.swift`)
- **Root Cause:** The previous redesign only verified compilation. The shell body relied on
  `VisualEffectView` glassmorphism over a transparent window → invisible silhouette with
  buttons floating in space; D-pad/action buttons scattered without cluster backing;
  lightbar stroke hidden under the touchpad; player LEDs tied to `GCController.playerIndex`
  (nil over BT → hidden).
- **Fix (verified with an offscreen render harness that rasterizes the real view to PNG):**
  - New symmetric `DualSenseShell` path with solid dark gradient fill + rim stroke + shadow
    (reads on any background, no `VisualEffectView` dependency).
  - `ClusterBacking` plates (plus-shaped for D-pad, circular for action buttons) unify the
    clusters; spacing tightened.
  - Lightbar drawn *before* the touchpad with a slight outward inset, thicker stroke, and
    double glow — clearly visible, still pulses with `isLedPulsing`.
  - `PlayerIndicatorLEDs` now driven by `manager.playerLEDs` bitmask (transport-agnostic,
    matches the Haptics tab) instead of `GCController.playerIndex`.
  - All live bindings (sticks, triggers, buttons, touch markers, connection pill) kept;
    leaf components restyled for contrast on dark backgrounds.

### Test updates
- `Tests.swift`: BT header assertions updated to expect low-nibble tag `0`
  (`report[1] == seq << 4`).
- This attempt had **57/57 passing**, but lacked exact flag/setup tests; the corrective
  session added them and removed the duplicate TESTING serializers.

### ⚠️ Must Verify On Hardware (this session's fixes)
- [x] **BT adaptive triggers:** L2/R2 modes confirmed working on hardware.
- [ ] **BT remaining output:** lightbar color, rumble, mic LED, player LEDs.
- [ ] **USB lightbar** turns on and tracks the color picker.
- [ ] **Live Map** in the real app window (render harness verified layout; confirm live
      input updates over both transports).
- [ ] If BT output is *still* dead after the seq-tag fix, next suspect is transport-level:
      capture `IOHIDDeviceSetReport`/`hid_write` return codes from the log file.

---

## 🔍 Session: Pre-Bluetooth Repository Audit & Fixes (28/08/2026)

**Context:** After the raw-HID Bluetooth rework (vendored hidapi in `Sources/CHidapi`,
new `BluetoothHIDController.swift`, `ControllerManager` BT/USB split), the whole repo was
reviewed before feature-testing BT. All issues found were fixed in the same session.

### Bugs Fixed

**1. `isLikelyBluetoothGCController` ignored its argument** (`ControllerManager.swift`)
- **Root Cause:** Returned `true` whenever *any* BT DualSense was enumerable, regardless of
  which controller was passed in — so a USB DualSense or non-DualSense controller connected
  alongside a BT one could never become `activeController`.
- **Fix:** Now only ignores DualSense-family controllers (`GCProductCategoryDualSense` /
  `"DualSense Edge"` string, since the Edge constant isn't in the build SDK) and only when a
  BT DualSense path actually exists. Policy confirmed with user: one active controller at a
  time, BT preferred.

**2. `hid_close` use-after-free race** (`BluetoothHIDController.swift`)
- **Root Cause:** `disconnect()` called `hid_close(dev)` while the read thread could be
  blocked inside `hid_read_timeout(dev, …)` on the same handle. hidapi forbids any other
  thread using the device during `hid_close`.
- **Fix:** `disconnect()` now signals the read thread and waits (≤1s) for it to exit; the
  read thread closes the handle itself once clear of `hid_read_timeout`.

**3. hidapi handle leak on BT reconnect** (`BluetoothHIDController.swift`)
- **Root Cause:** `readLoop()` exited without `hid_close`, leaving `device` non-nil; the next
  `connect()` overwrote it, leaking the old handle every reconnect cycle.
- **Fix:** `readLoop()` closes the handle on exit; `connect()` defensively closes any stale
  handle before caching the new one. Added `deinit` cleanup.

**4. Gyro/accel parsed but dropped over BT — Sensors tab dead** (`ControllerManager.swift`)
- **Root Cause:** `handleBluetoothInput` decoded `sample.gyro`/`sample.accel` but never fed
  them anywhere; `updateMotionSensorsState()` requires a `GCController` (nil over BT).
- **Fix:** Extracted the complementary-filter pipeline into shared `processMotionSample(...)`
  used by both the GameController motion callback (USB) and the BT input path. BT scaling:
  gyro ±2000 dps (16.384 LSB/dps → rad/s), accel ±4g (8192 LSB/g). Filter-state reset on
  Sensors-tab activation now happens before the `GCController` guard so it applies over BT.
- **⚠️ Open:** Axis signs follow the `dualsense_input_report` layout (x=pitch, y=yaw, z=roll)
  but are unverified on hardware — if orientation looks mirrored, flip signs at the call
  site in `handleBluetoothInput` (marked with a comment).

**5. `IOHIDManager` leak** (`ControllerManager.swift` → `findHIDOutputDevice`)
- **Root Cause:** Early `return nil` when no devices matched never closed the freshly
  created manager.
- **Fix:** `IOHIDManagerClose` on the empty-result path.

**6. Mute button not parsed over BT** (`BluetoothHIDController.swift`)
- **Fix:** `buttons["mute"] = (b2 & 0x04) != 0` added to `parseInputReport`.

**7. Touchpad center `(0,0)` treated as finger-lift** (`ControllerManager.swift`)
- **Root Cause:** `handleTouchpadUpdate` reset the gesture on `(0,0)` — correct for the
  GameController path (no release event) but wrong over BT, where `(0,0)` is the valid
  center pixel and a real contact bit exists.
- **Fix:** New `resetOnZero` parameter (default `true`, preserves GC behavior); BT path
  passes `false` and relies on the contact bit.

**8. Data races on `isConnected` / `shouldStopReading`** (`BluetoothHIDController.swift`)
- **Fix:** Both are now lock-guarded (`stateLock`); they are shared across main, read, and
  background threads.

**9. No BT cleanup on quit** (`AppDelegate.swift`, `ControllerManager.swift`)
- **Fix:** New `ControllerManager.shutdown()` (stops background timer, ends App Nap
  activity, disconnects the exclusive BT session), called from `applicationWillTerminate`.
  Also: BT `onDisconnect` now resets the on-screen attitude and posts
  `DualSenseTStatusChanged` immediately.

**10. `LSMinimumSystemVersion` mismatch** (`build.sh`)
- **Root Cause:** Generated Info.plist claimed macOS 12.0 while the binary targets macOS 14.0.
- **Fix:** Info.plist now says 14.0.

### Verified Working (not changed)
- 0x31 BT input-report offsets in `parseInputReport` match Linux `hid-playstation.c`
  (`dualsense_input_report` at +2 base): sticks, triggers, buttons/hat, gyro, accel,
  touch points, status/battery all correct.
- BT output report: CRC32 with `0xA2` seed over bytes 0–73, seq nibble, trigger/LED/rumble
  offsets — all covered by unit tests.
- Vendored hidapi is 0.14.0 and supports `bus_type` (`HID_API_BUS_BLUETOOTH`).

### ⚠️ Must Verify On Hardware (next session)
- [ ] **In-game input over BT while DualSenseT is running** — the exclusive seize
  (`kIOHIDOptionsTypeSeizeDevice` via hidapi) that makes BT output reports work may block
  games/other apps from opening the controller. Biggest open design risk. (User: not yet tested.)
- [ ] **BT sensor axis orientation** — see Bug 4 note.
- [ ] BT reconnect cycles (sleep/wake, out-of-range) — exercise the new close/reopen path.
- [ ] Mute button shows correctly in the UI over BT.

### 🧹 Repo Hygiene (decision pending)
- Untracked: `.agents/`, `files/` (contains a full duplicate "DualsenseT-polish" project),
  `files.zip`, `PROGRESS.md`, `TEST_INFRA.md`, `TEST_READY.md` — decide what gets committed
  before publishing.

---

## 📜 History

### 24/06/2026 — Bug Fixes Applied (awaiting retest)

Two critical bugs were fixed. Awaiting user testing to verify.

---

## 🔧 Bug Fixes Applied (24/06/2026)

### Bug 1 FIX: Vibration frequency byte at wrong offset
**Root Cause:** In `bitpackTriggerArray()`, frequency was placed at `params[6]` but the DualSense firmware expects it at `params[8]` (per ExtendInput reference implementation by Nielk1).
**Fix:** Moved frequency from `params[6]` to `params[8]`, matching the reference layout:
```
params[0-1] = activeZones (2 bytes)
params[2-5] = strengthZones packed (4 bytes)
params[6-7] = 0x00 (unused)
params[8]   = frequency ← was at [6], now correctly at [8]
params[9]   = 0x00
```

### Bug 2 FIX: BT settings stop when app loses focus
**Root Cause:** `applyTriggerSettingsViaHID()` had `guard activeController != nil else { return }` which blocked ALL raw HID writes when GameController framework nils the controller on focus loss.
**Fix:** Removed the guard. IOKit HID device handles are independent of GameController API — we discover HID devices via `findHIDOutputDevice()` which works regardless of GameController state.

---

## Phase Summary

| Phase | Description | Status |
|---|---|---|
| Phase 0 | Fix BT Background Settings Persistence | ✅ Bug fixed |
| Phase 1 | Mic LED + Player LEDs + Rumble Motor Test | ✅ DONE |
| Phase 2 | Expand Trigger Modes (4 → 11) + Presets + UDP | ✅ Bug fixed |
| Phase 3 | USB Audio Routing | ⏸ Deferred |
| Phase 4 | README + Comparison Table Update | ✅ DONE |
| Phase 5 | Raw-HID Bluetooth via vendored hidapi (output + input over BT) | ✅ Implemented |
| Phase 6 | Pre-BT-feature repo audit (10 fixes, 57/57 tests) | ✅ DONE — awaiting HW verify |
| Phase 7 | Initial output-report/Live Map attempt | ⚠️ Partially superseded |
| Phase 8 | Driver-matching LED handshake, haptics restore, 48-byte USB reports, render-spill fix | ✅ Implemented — awaiting HW retest |

---

## Remaining Work

### Phase 3 — USB Audio Routing (Deferred)
- [ ] CoreAudio aggregate device creation
- [ ] Audio routing tab UI

### Bluetooth Hardware Verification (NEXT)
- [x] BT L2/R2 adaptive-trigger modes (hardware-confirmed 28/08/2026)
- [x] BT remaining output: LED, rumble, mic LED, player LEDs
- [x] USB rumble/haptics after HAPTICS_SELECT restore
- [x] USB lightbar tracks color picker
- [x] Live Map live updates over USB + BT
- [ ] In-game input over BT while app is running (exclusive-seize risk)
- [ ] Sensors tab over BT (axis signs)
- [ ] BT reconnect cycles (sleep/wake/out-of-range)

---

## Key Files Modified

| File | Changes |
|---|---|
| `ControllerManager.swift` | Fixed `bitpackTriggerArray()` frequency offset (params[6]→params[8]), removed `activeController` guard from `applyTriggerSettingsViaHID()` |
| `ControllerManager.swift` (28/08 audit) | Per-controller `isLikelyBluetoothGCController`; shared `processMotionSample()` for USB+BT; BT gyro/accel wiring; `resetOnZero` touchpad fix; `IOHIDManager` leak fix; `shutdown()`; status post on BT disconnect |
| `BluetoothHIDController.swift` (28/08 audit) | Thread-safe `disconnect()` (no `hid_close` race); handle closed on read-loop exit (leak fix); lock-guarded `isConnected`/`shouldStopReading`; `deinit`; mute button parsing |
| `AppDelegate.swift` (28/08 audit) | `applicationWillTerminate` → `controllerManager.shutdown()` |
| `build.sh` (28/08 audit) | `LSMinimumSystemVersion` 12.0 → 14.0 (matches build target) |
| `ControllerManager.swift` (28/08 PM) | BT seq_tag low nibble 0 (hardware-confirmed trigger fix); restored required HAPTICS_SELECT; one-time dedicated LIGHT_OUT LED-control handshake followed by separate state reports; USB report length 48; per-transport reconnect reset; TESTING captures use production builders |
| `ControllerVisualizerView.swift` (28/08 PM) | Live Map rebuilt; fixed full-canvas touchpad gradient spill that covered the right/lower shell by locally framing the touchpad; removed center blue wedge; player LEDs from `playerLEDs` bitmask |
| `Tests/Tests.swift` (28/08 PM) | BT seq-tag invariant plus exact USB/BT state flags, haptics bytes, LED setup separation, report lengths, and CRC coverage (61 tests total) |
