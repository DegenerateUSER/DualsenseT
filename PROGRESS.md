# Sticky Fingers (formerly DualSenseT) — Implementation Progress Tracker

> **Purpose:** This file tracks what has been done, what is in progress, and what remains.  
> If a session ends mid-task, the next session should read this file FIRST to resume seamlessly.  
> **Last Updated:** 04/09/2026 20:38 IST

---

## Current Status: 🟢 USB + Bluetooth Feature Pass Hardware-Verified

User hardware retest confirms that adaptive triggers, haptics/rumble, lightbar, mic LED,
player LEDs, sensors, and input now work over both Bluetooth and USB. The Live Map is also
confirmed complete and functional. The BT `seq_tag` low-nibble fix, required HAPTICS_SELECT,
two-report LED ownership sequence, and 48-byte USB report are now a known-good checkpoint.
The high-rate input/UI path has since been optimized without changing HID output bytes.
USB controller audio controls, system-audio capture, and audio-to-haptics streaming are now
implemented. Speaker, microphone, isolated haptic channels, capture meter, and streamed video
haptics worked on physical hardware. The tab-switch/adaptive-trigger coexistence fix is
hardware-verified—including simultaneous adaptive triggers—on a base M1 MacBook Air running
macOS 27 Golden Gate. Continuous haptics now prefill a bounded ring with the first non-silent
buffer before starting its pull-driven AVAudioSourceNode. Test suite: **75/75 passing**.

---

## 🎨 Session: Original 3A App Icon (04/09/2026, 20:38 IST)

- Reviewed supplied 3A (filled) and 3B (outline) concepts at full size and 32×32.
- Selected **3A** for the app and Dock because its solid silhouette remains clearer at small
  sizes; 3B remains better suited to monochrome/menu-bar use.
- Replaced the previous detailed DualSense/PlayStation-logo artwork with a generic controller
  mark using graphite, white, and the existing cyan accent.
- Added editable source at `Assets/Brand/AppIcon-3A.svg` and usage notes at
  `Assets/Brand/README.md`.
- Added `generate-app-icon.sh`, which reproducibly builds all ten required macOS 1×/2× icon
  representations into `Assets/AppIcon.icns`.
- Rebuilt the app, confirmed the bundle contains the generated icon, and revalidated its
  code signature.

---

## 🚀 Session: Open-Source Launch Polish (04/09/2026, 20:10 IST)

**Product and UI**

- Public product name changed to **Sticky Fingers** by owner decision.
- App output is now `Sticky Fingers.app`, executable `StickyFingers`, bundle identifier
  `com.degenerateuser.stickyfingers`.
- Existing Application Support data is copied from the former DualSenseT directory on first
  run so presets are not lost.
- Audio page now presents USB readiness, Audio Haptics, controller audio controls, and one
  live response meter.
- Raw UIDs, channel layout, isolated tests, input format, and stream counters moved into a
  collapsed **Advanced Diagnostics** section.
- Removed the obsolete in-product “Implementation Stages” card.

**Open-source and release**

- Added GPL-3.0 license and HIDAPI third-party notices.
- Added launch README, installation, troubleshooting, architecture, privacy, marketing,
  contribution, security, changelog, release guide, and launch checklist.
- Added issue/PR templates plus build/test CI.
- Added Developer ID signing, hardened runtime, notarization, stapling, checksum, and GitHub
  tag-release automation.
- License and third-party notices now ship inside the app bundle.
- Added Settings links to source, license, and privacy terms.

**Security and verification**

- Found that the UDP listener's “localhost” documentation did not match its actual network
  exposure. Non-loopback peers are now rejected before command parsing.
- Added tests that lock the public app identity and UDP IPv4/IPv6 loopback boundary.
- Automated suite increased from 73 to **75 tests**.
- Final local verification: **75/75 tests pass**, the arm64 bundle builds, plist and
  identifiers validate, GPL notices are sealed into the bundle, code-sign verification
  passes, and the renamed app launches and quits cleanly.
- Shell scripts and all workflow/issue-form YAML parse successfully. CI and Developer ID
  notarization still require the GitHub secrets and Apple credentials documented in
  `RELEASING.md`.
- Added a source-backed DualSenseM comparison and prioritized improvement roadmap.
- Current 1024×1024 icon has no old product text, but its detailed controller and PlayStation
  marks should be replaced with original launch artwork.

**Known launch risk**

The selected “Sticky Fingers” name collides with existing software/game/App Store uses and
unrelated live trademarks. The owner chose to proceed after this was disclosed. A
professional trademark clearance remains an explicit launch gate.

---

## 🖥 Session: Dock Presence & Discoverable Quit (04/09/2026, 19:17 IST)

**Problem:** DualSenseT did not appear in the Dock, so the user could only find a quit path
through Activity Monitor.

**Root cause:** The app explicitly configured both `NSApp.setActivationPolicy(.accessory)`
and generated Info.plist `LSUIElement = true`, which tell macOS to hide the Dock icon.

**Fix**

- Activation policy changed to `.regular`.
- `LSUIElement` changed to `false`.
- Menu-bar helper remains available.
- Added an application menu with **Open Sticky Fingers** (`⌘O`) and
  **Quit Sticky Fingers** (`⌘Q`).
- Clicking the Dock icon now reopens the hidden dashboard through
  `applicationShouldHandleReopen`.
- Existing menu-bar Quit remains available.

**Verification**

- **73/73 tests pass.**
- Full app bundle builds.
- Packaged Info.plist confirms `LSUIElement => false`.
- Dock visibility, Dock-context-menu Quit, reopen, and ⌘Q require visual user verification.

---

## ✅ Session: Golden Gate Audio Haptics Verified (04/09/2026, 19:02 IST)

The final non-silent prefill + pull-driven AVAudioSourceNode architecture works on the remote
base M1 MacBook Air running macOS 27 Golden Gate:

- [x] Captured system/video audio reaches the app.
- [x] DSP generates processed haptic output.
- [x] Ring-buffer output reaches the DualSense actuators.
- [x] Controller vibrates according to playing audio.
- [x] Adaptive trigger modes work simultaneously with streamed audio haptics.
- [x] Existing USB/BT features remain working.

This closes the two critical audio acceptance criteria. Remaining work is hardening rather
than core enablement: restore-after-stop, intensity range, long-run latency/CPU, reconnect,
sleep/wake, permissions/signing, and wired headset verification.

---

## 🔊 Session: Golden Gate Audio Buffer Compatibility (04/09/2026)

**Remote environment:** base M1 MacBook Air running macOS 27 Golden Gate beta. Development
changes are pushed and tested on that separate machine; its app log is not available locally.

**Observed**
- [x] All old controller features still work.
- [x] Isolated Haptic L/R tests vibrate the grips.
- [x] System capture meter moves with video audio.
- [ ] Streamed video audio produces no haptic vibration.

These results prove the controller's Quadraphonic output, PCM mode, haptic channels, and
ScreenCaptureKit capture work. The failing boundary is captured PCM buffer unpacking before
the DSP.

**Root cause:** `processAudioHaptics` used `CMSampleBufferGetDataBuffer` and assumed one
contiguous Float32 block. Golden Gate can expose stereo as separate planar `AudioBuffer`
entries. A raw byte meter can still move while channel offsets consumed by the DSP are wrong
or rejected.

**Fix implemented**
- Switched capture meter and haptic DSP to `CMSampleBuffer.withAudioBufferList`.
- Added logical-channel traversal using each buffer's channel count, data length, and pointer.
- Handles planar stereo, interleaved stereo, mono duplication, and mixed channel groups.
- Added visible remote diagnostics: captured level, processed haptic level, processed/dropped
  counts, and exact input layout.
- Added `testAudioBufferListDecodesPlanarAndInterleavedStereo`.
- **First retest:** format correctly displayed `48000 Hz Float32 · 2 ch · planar buffers
  1+1`, but Processed stopped at exactly `12` (the queue cap) while Dropped reached `9,887`.
  This proved decoding worked but AVAudioPlayerNode never consumed scheduled buffers.
- **Second hypothesis/fix:** schedule before `player.play()`, restart after underruns, and
  release on `.dataConsumed`.
- **Second retest:** still stopped at Processed `12`, Dropped `240`; AVAudioPlayerNode
  remained starved. The timing workaround was rejected.
- **Final architecture:** removed AVAudioPlayerNode from continuous haptics. A preallocated
  stereo ring buffer now feeds AVAudioSourceNode's continuously pulled render callback—the
  same output architecture used by the verified isolated channel tests.
- Added `testHapticRingBufferPreservesStereoFrames`.
- **Third retest:** Captured `23%`, Processed Output `72%`, Processed `1,360`, Dropped
  `1,352`. DSP output was valid, but the source engine had also been started against an empty
  ring and its AudioUnit never pulled.
- **Final startup fix:** prepare the graph during silence; on first non-silent PCM, reset and
  prefill the ring, then start the AudioUnit. Added Rendered/Buffered diagnostics and
  `testHapticSourceStartsOnlyAfterNonSilentPrefill`.
- **73/73 tests pass; full app bundle builds.**

**Next remote test**
- [x] Both captured and processed meters move.
- [x] Pull-driven ring reaches the controller actuators.
- [x] Controller vibrates with video audio.
- [x] Adaptive trigger effects work simultaneously.
- [ ] Record long-run Processed/Rendered/Buffered/Dropped behavior.

See `USB_AUDIO_HAPTICS.md` §10 for the full evidence chain and test procedure.

---

## 🔊 Session: USB Controller Audio — Phase 1 (28/08/2026, 16:32 IST)

**Physical hardware discovered through CoreAudio**
- Output device ID `98`, four output channels, 48,000 Hz.
- Input device ID `94`, two input channels, 48,000 Hz.
- Both endpoints identify as `DualSense Wireless Controller` by Sony Interactive
  Entertainment over USB.
- Output UID and input UID are retained independently because macOS exposes them as separate
  `AudioDeviceID`s.

**Quadraphonic setup hardware-verified**
- Initial layout tag was `0x00000000`; the preferred-layout property is writable.
- A first set attempt using only `MemoryLayout<AudioChannelLayout>.size` correctly surfaced
  CoreAudio error `kAudioHardwareBadPropertySizeError ('!siz')`.
- Fixed by allocating and submitting the exact buffer size advertised by the device's
  `kAudioDevicePropertyPreferredChannelLayout` property.
- Reread succeeds as `kAudioChannelLayoutTag_Quadraphonic`, ordered:
  Front L, Front R, Surround/Haptic L, Surround/Haptic R.

**Implementation**
- Added `ControllerAudioService.swift`: USB-only Sony/DualSense endpoint matching, device
  IDs/UIDs, channel counts, sample rate, layout/readiness status, refresh, and safe
  programmatic Quadraphonic configuration.
- Added `ControllerAudioView.swift` and a new `Audio (USB)` sidebar tab showing the real
  endpoint, output/input/sample-rate capabilities, four-channel map, status/errors, and
  setup action.
- Added CoreAudio + AudioToolbox to both production and test link commands.
- Added two platform-independent discovery/readiness tests.
- **65/65 tests pass; full app bundle builds and has been opened for UI verification.**

**Next stage**
- [x] User verified 4 output / 2 input / 48 kHz / Quadraphonic.
- [x] HID-backed speaker/headset/microphone routing and volume controls implemented.
- [x] Safe per-channel test tones implemented; speaker + channels 3/4 verified.
- [x] Permission-aware system capture and real-time haptic DSP implemented.
- [ ] Wired headset verification (no headset available).
- [ ] Retest simultaneous adaptive triggers + audio haptics after lifecycle fix.

---

## 🔊 Session: USB Audio Controls & Audio Haptics (28/08/2026, 16:40–18:07 IST)

> Full technical implementation, byte map, failure chronology, hardware evidence, retest
> checklist, risks, and resume instructions: **`USB_AUDIO_HAPTICS.md`**

### Implemented

- Added USB-only HID controls for headset/controller-speaker routes, microphone source,
  headset/speaker/microphone volume, hardware microphone mute, and speaker pre-gain.
- Added direct four-channel AVAudioEngine tests:
  - channels 1/2: quiet 440 Hz audible tones;
  - channels 3/4: 120 Hz left/right haptic actuator tones.
- Added ScreenCaptureKit system/game audio capture at 48 kHz stereo with standard macOS
  Screen & System Audio Recording permission and a live level meter.
- Added audio-to-haptics DSP: approximate 20–220 Hz band extraction, adjustable gain,
  limiter, stereo L/R actuator mapping, silent audible output channels, and bounded buffer
  scheduling.
- Added app-global audio services owned by `AppDelegate`, with termination cleanup.
- Added USB PCM/classic-rumble switching while retaining adaptive-trigger enable bits.

### Hardware-Verified

- [x] CoreAudio 4-out / 2-in / 48 kHz discovery.
- [x] Programmatic Quadraphonic layout.
- [x] Left and right isolated PCM haptic actuator tests.
- [x] Controller speaker.
- [x] Controller microphone source/gain/mute.
- [x] ScreenCaptureKit meter follows video audio.
- [x] Video/system audio produces controller haptic vibration.
- [ ] Wired 3.5 mm headset (hardware unavailable).

### Failures and Corrections

1. **Quadraphonic set failed with `'!siz'`:** AppleUSBAudio required the exact property
   buffer size, not `MemoryLayout<AudioChannelLayout>.size`. Fixed using the size returned
   by CoreAudio; hardware reread succeeded.
2. **Channel-test tile confusion:** the prominent upper tiles were informational; actual
   buttons were below the fold. User found the lower controls. UI consolidation remains.
3. **Four-channel stream ran but actuators were silent:** USB report bit 1 selected
   `USE_RUMBLE_NO_HAPTICS`. Added scoped PCM mode (`0x0D`, classic motors zero, improved
   rumble off) and automatic restore to `0x0F`; physical haptic tests then worked.
4. **Audio haptics stopped after navigating to Trigger tabs:** `onDisappear` stopped the
   capture/output engines and restored classic rumble. Fixed by keeping streaming app-global;
   only temporary test tones stop on tab change.
5. **Turning triggers off did not restore haptics:** expected consequence of failure 4—the
   PCM engine had been torn down. Trigger settings themselves were not the conflict.

### Paused Awaiting Retest

- [ ] Start Audio Haptics, then change L2/R2 modes; both effects must continue together.
- [ ] Return to Audio tab; stream must still show running.
- [ ] Stop Audio Haptics; Test Pulse/Heartbeat classic rumble must work again.
- [ ] Verify intensity range, 10-minute stability, CPU, latency, and reconnect behavior.
- [ ] Verify wired headset when available.

### Verification

- Seven audio-specific regression tests added.
- **70/70 tests passing.**
- Full app bundle builds successfully.

---

## ⚙️ Session: Runtime CPU Reduction (28/08/2026, 16:09 IST)

**Why CPU was high**
- DualSense Bluetooth reports arrive at roughly hundreds of samples per second. Every report
  was decoded, enqueued to the main thread, and expanded into many separate `@Published`
  writes (one per button plus sticks, triggers, touches and unchanged battery state).
- Those writes repeatedly invalidated the SwiftUI view tree faster than the display could
  render. USB analog noise and 250 Hz motion callbacks created similar unnecessary updates.
- Optional lightbar breathing sent 20 full HID reports/CRC calculations per second.
- The hidapi reader itself correctly blocks on a condition variable; there was no busy-spin.

**Changes**
- Bluetooth input is still drained continuously, but decode/main-thread delivery is capped
  at 60 Hz.
- BT button state is published as one dictionary snapshot; all controller values are only
  published when they actually change. One-count stick jitter is filtered.
- Hidden UI no longer publishes sticks/buttons/triggers/touch visuals; background touchpad
  gesture recognition and hardware output remain active.
- Motion fusion retains high-rate samples for accuracy, but attitude rendering is capped at
  60 Hz and periodic file logging reduced fivefold.
- Fully occluded windows now pause live UI/sensor publishing until visible again.
- Lightbar breathing cadence reduced from 20 Hz to 10 Hz.
- No trigger/LED/rumble report layout, Bluetooth sequence/CRC, or LED ownership byte changed.

**Regression coverage**
- Added `testBTInputDeliveryIsCappedAtDisplayRate`.
- Added `testAnalogNoiseDoesNotPublishVisualChange`.
- **63/63 tests passing.** Full packaged app build succeeds.

**Runtime verification still needed**
- [x] No-controller dashboard baseline sampled after launch: 0.0–0.7% CPU across five
      one-second samples (not representative of an active USB/BT report stream).
- [ ] Compare Activity Monitor CPU over USB and BT with Live Map open, Sensors open, and
      dashboard closed to the menu bar.
- [ ] Confirm very fast button taps and touchpad swipes remain responsive at the 60 Hz UI cap.
- [ ] Confirm 10 Hz lightbar breathing still looks smooth on hardware.

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

**Git checkpoint:** `603384f` (`checkpoint hardware-verified controller support`) captures
the complete hardware-working state plus the removal of the obsolete Bluetooth warning.
The later Live Map polish and CPU optimizations remain after that checkpoint and do not alter
the verified HID output report builders, Bluetooth sequence/CRC, or LED ownership sequence.

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
- [x] **BT remaining output:** lightbar color, rumble, mic LED, and player LEDs later
  confirmed in the full transport retest.
- [x] **USB lightbar** turns on and tracks the color picker.
- [x] **Live Map** confirmed with live input over both transports.

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
  Also: BT `onDisconnect` now resets the on-screen attitude and posts the app status-change
  notification immediately.

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
- [x] **Input and output over BT while Sticky Fingers is running** — the user confirmed the
  working USB/Bluetooth feature pass. Per-game compatibility should still be reported
  separately because Steam Input and other tools may contend for the device.
- [ ] **BT sensor axis orientation** — see Bug 4 note.
- [ ] BT reconnect cycles (sleep/wake, out-of-range) — exercise the new close/reopen path.
- [ ] Mute button shows correctly in the UI over BT.

### 🧹 Repo Hygiene
- `.agents/`, `.claude/`, local `files/` archives, generated bundles, and zip files are now
  ignored. Public progress, test, license, policy, and launch documentation stays tracked.

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
| Phase 3 | USB Audio controls + system-audio haptics | ✅ Core + trigger coexistence hardware-verified |
| Phase 4 | README + Comparison Table Update | ✅ DONE |
| Phase 5 | Raw-HID Bluetooth via vendored hidapi (output + input over BT) | ✅ Implemented |
| Phase 6 | Pre-BT-feature repo audit (10 fixes, 57/57 tests) | ✅ DONE — awaiting HW verify |
| Phase 7 | Initial output-report/Live Map attempt | ⚠️ Partially superseded |
| Phase 8 | Driver-matching LED handshake, haptics restore, 48-byte USB reports, render-spill fix | ✅ Hardware-verified |

---

## Remaining Work

### Phase 3 — USB Audio & Audio Haptics
- [x] CoreAudio USB endpoint discovery
- [x] Programmatic Quadraphonic layout
- [x] Audio routing/volume/mute tab
- [x] Per-channel speaker/haptic tests
- [x] Permission-aware system audio capture + meter
- [x] System audio → haptic DSP/output
- [x] Hardware-retest trigger coexistence after tab-lifecycle fix
- [ ] Wired headset test
- [ ] Reconnect/long-run/CPU/latency hardening

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
| `ControllerAudioService.swift` (28/08 audio) | DualSense CoreAudio discovery; Quadraphonic setup; HID audio models; isolated 4-channel tests; AVAudioEngine audio-haptics DSP/output |
| `SystemAudioCaptureService.swift` (28/08 audio) | Permission-aware ScreenCaptureKit system audio capture, live meter, and synchronous PCM consumer |
| `ControllerAudioView.swift` (28/08 audio) | Audio tab diagnostics, channel map/tests, routes, volumes, microphone, capture meter, haptic intensity/start/stop, tab-persistent stream lifecycle |
| `ControllerManager.swift` (28/08 audio) | USB audio HID bytes plus scoped `audioHapticsModeEnabled` switch that preserves trigger effects and restores classic rumble |
| `ContentView.swift` / `AppDelegate.swift` (28/08 audio) | Audio tab and long-lived CoreAudio/capture service ownership with termination cleanup |
| `build.sh` (28/08 audio) | Links CoreAudio, AudioToolbox, AVFAudio, ScreenCaptureKit, CoreMedia; adds audio capture permission descriptions |
| `Tests/Tests.swift` (28/08 audio) | Seven audio regressions; total suite now 70 |
| `USB_AUDIO_HAPTICS.md` | Complete implementation/failure/hardware/retest/resume reference |
