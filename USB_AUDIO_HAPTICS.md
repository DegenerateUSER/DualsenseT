# DualSenseT — USB Controller Audio & Audio Haptics

> **Purpose:** Technical handoff and hardware-validation record for the USB audio feature.  
> **Last Updated:** 04/09/2026 18:02 IST
> **Current State:** Golden Gate buffer-layout compatibility fix implemented and awaiting
> remote hardware retest. Core
> discovery, Quadraphonic setup, controller speaker, microphone, isolated haptic channels,
> system-audio capture, and audio-to-haptics streaming have worked on physical hardware.
> Simultaneous adaptive triggers + audio haptics and macOS 27 streaming must be retested.

---

## 1. Scope

This feature is **USB only**. Bluetooth exposes the DualSense HID interface but does not
expose its USB Audio Class input/output endpoints.

Implemented:
- Discovery of the separate DualSense CoreAudio input and output devices.
- Programmatic Quadraphonic speaker-layout configuration.
- HID-backed controller speaker/headset/microphone routing and volume controls.
- Hardware microphone mute.
- Direct per-channel audible and haptic test tones.
- Permission-aware system/game audio capture.
- Live audio-level meter.
- Stereo audio-to-haptics DSP streamed to the two grip actuators.
- Temporary switching between classic rumble and PCM audio-haptics modes.
- Continued audio-haptics streaming while navigating to other app tabs.

Not yet fully verified:
- Wired 3.5 mm headset output/input (no wired headset available during this session).
- Audio haptics continuing while L2/R2 modes are changed after the latest lifecycle fix.
- Classic rumble returning after Audio Haptics is stopped.
- Haptic Intensity slider response and left/right balance during streamed system audio.
- Streamed audio haptics on macOS 27 Golden Gate after the portable AudioBufferList fix.
- Disconnect/reconnect, sleep/wake, long-running drift, CPU use, and underrun behavior.

---

## 2. Physical CoreAudio Device Observed

The controller was connected with a data-capable USB cable. `system_profiler
SPAudioDataType` and the in-app discovery service reported:

- Name: `DualSense Wireless Controller`
- Manufacturer: `Sony Interactive Entertainment`
- Transport: USB
- Output: **4 channels at 48,000 Hz**
- Input: **2 channels at 48,000 Hz**
- Output `AudioDeviceID` during this session: `98`
- Input `AudioDeviceID` during this session: `94`
- Output UID:
  `AppleUSBAudioEngine:Sony Interactive Entertainment:DualSense Wireless Controller:1100000:1`
- Input UID:
  `AppleUSBAudioEngine:Sony Interactive Entertainment:DualSense Wireless Controller:1100000:2`

`AudioDeviceID` values are ephemeral and can change after reconnect/reboot. Code must
rediscover by name + manufacturer + USB transport and retain UIDs only as stable references.

### Verified Channel Order

After setting `kAudioChannelLayoutTag_Quadraphonic`, CoreAudio exposes:

1. Front Left — audible/headset left
2. Front Right — audible/headset right / controller speaker source
3. Surround Left — left grip voice-coil haptic actuator
4. Surround Right — right grip voice-coil haptic actuator

---

## 3. Quadraphonic Configuration

Audio haptics require channels 3 and 4 to remain visible. macOS initially returned channel
layout tag `0x00000000`, despite exposing four output channels.

### First Attempt — Failed

The first implementation passed `MemoryLayout<AudioChannelLayout>.size` to
`AudioObjectSetPropertyData`.

Result:

```text
kAudioHardwareBadPropertySizeError ('!siz')
```

### Root Cause

AppleUSBAudio requires the exact byte count advertised by
`kAudioDevicePropertyPreferredChannelLayout`. Its current property buffer includes space for
channel descriptions even when the replacement layout uses a predefined tag with zero
descriptions.

### Fix — Hardware Verified

1. Query `AudioObjectGetPropertyDataSize`.
2. Allocate that exact number of bytes.
3. Zero the complete buffer.
4. Set:
   - `mChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic`
   - empty bitmap
   - zero channel descriptions
5. Submit the full advertised buffer size.
6. Wait briefly and reread the property.

The physical device then reported:

```text
Quadraphonic (L, R, Haptic L, Haptic R)
```

This layout persists in macOS Audio MIDI configuration but is still checked on every app
session.

---

## 4. HID Controller Audio Controls

Audio controls are merged into the existing 48-byte USB output report. Bluetooth output
reports never receive these flags.

### User-Facing Controls

- Enable/disable controller audio control updates.
- Output route:
  - Headset stereo
  - Headset mono
  - Headset-left + controller-speaker-right split
  - Controller speaker
- Microphone source:
  - Automatic/both
  - Headset microphone
  - Controller microphone
- Headset volume
- Controller speaker volume
- Microphone gain
- Hardware microphone mute

### USB Report Fields

- Byte `1`, bits `4...7`: headset volume, speaker volume, microphone volume, audio route.
- Byte `5`: headset volume (`0...127`).
- Byte `6`: speaker volume (effective range used: `0...100`).
- Byte `7`: microphone volume (`0...64`).
- Byte `8`: output route bits `4...5` + input route bits `6...7`.
- Byte `10`, bit `4`: hardware microphone mute.
- Byte `38`: controller speaker pre-gain (`0x02`).

When audio controls are enabled, USB `valid_flag0` becomes `0xFF`. Existing adaptive-trigger
offsets remain byte `11` for R2 and byte `22` for L2. A regression test verifies those offsets
do not move.

### Hardware Results

- Controller speaker: **working**.
- Controller microphone source/gain/mute: **working**.
- Wired headset stereo/volume/headset microphone: **not tested** (no wired headset).

For the internal controller speaker, the protocol routes the right/front channel to the
speaker. Therefore a Front Left test may be silent in controller-speaker mode; use a wired
stereo headset to validate Front Left/Right independently.

---

## 5. Isolated Channel Tests

`ControllerAudioService` creates a dedicated `AVAudioEngine`, binds its output AudioUnit
directly to the DualSense output `AudioDeviceID`, and uses a 48 kHz Float32 deinterleaved
Quadraphonic format. It never changes the Mac's default output.

- Channels 1/2 use a quiet 440 Hz audible tone.
- Channels 3/4 use a 120 Hz actuator test tone.
- Tone length: approximately 0.5 seconds.
- Attack/release ramps prevent clicks.
- The real-time source callback clears unused channels and performs no allocation, locking,
  logging, or UI updates.

### UI Confusion Encountered

The first screenshot showed a prominent four-channel map near the top and the actual test
buttons farther down. The user initially clicked the informational tiles, so no click was
logged and no active state appeared. After scrolling to **Isolated Channel Tests**, the
actual buttons turned cyan.

Future UI cleanup: either make the top channel map tiles trigger tests directly or label them
clearly as a diagram. Do not keep two visually similar sets of channel tiles.

---

## 6. Why the First Haptic Tone Was Silent

### Symptom

CoreAudio successfully started:

```text
4 ch, 48000 Hz, Float32, deinterleaved
```

The test tile activated, but the controller did not vibrate.

### Root Cause

The known-good controller output report selected classic rumble:

- Byte `1`, bit `0`: enable rumble emulation.
- Byte `1`, bit `1`: `USE_RUMBLE_NO_HAPTICS`.
- Byte `39`, bit `2`: improved classic rumble.

That state intentionally routes the voice-coil actuators to compatibility rumble rather than
raw PCM channels 3/4.

### Fix — Hardware Verified

While a USB PCM haptic stream is active:

- Retain byte `1` bit `0` for a graceful transition.
- Clear byte `1` bit `1` (`USE_RUMBLE_NO_HAPTICS`).
- Keep L2/R2 enable bits unchanged.
- Set classic motor bytes `3/4` to zero.
- Clear byte `39` improved-rumble bit.

This produces USB byte `1 = 0x0D` before optional audio-control bits. When streaming stops,
the app restores the known-good classic-rumble state (`0x0F`, original motor values, byte
`39 = 0x04`).

After this change, the physical controller's left and right haptic test channels worked.

---

## 7. System Audio Capture

Implemented in `SystemAudioCaptureService.swift` using ScreenCaptureKit.

Configuration:
- Audio capture enabled.
- Current app audio excluded to avoid feedback.
- 48,000 Hz stereo.
- Minimal 2×2 / 1 fps display-backed configuration; only an audio stream output is
  registered.
- Audio callbacks use a dedicated serial queue.
- UI level updates are limited to 20 Hz.

Required Info.plist descriptions:
- `NSAudioCaptureUsageDescription`
- `NSScreenCaptureUsageDescription`

The user grants access under:

```text
System Settings → Privacy & Security → Screen & System Audio Recording
```

### Hardware Result

The user played a video and confirmed the cyan meter rose and fell with the audio level.
Therefore permission, ScreenCaptureKit capture, Float32 buffer access, and level extraction
are all working.

---

## 8. Audio-to-Haptics DSP and Output

The capture callback is connected synchronously to `ControllerAudioService`.

Pipeline:

```text
System/Game Stereo Audio
  → ScreenCaptureKit (48 kHz Float32)
  → 20–220 Hz band extraction
  → user intensity gain
  → hard safety limiter [-1, +1]
  → Quadraphonic channel 3 (left) / channel 4 (right)
  → DualSense voice-coil actuators
```

Details:
- Channels 1 and 2 in the haptic output stream are explicitly zeroed, so the app does not
  duplicate audible audio through the controller.
- The user's normal Mac output remains unchanged.
- The left captured channel drives the left grip; right drives right.
- Two one-pole low-pass states form an approximate 20–220 Hz band:
  - 220 Hz coefficient: `0.02839`
  - 20 Hz coefficient: `0.002615`
- Gain spans approximately `4...18` from the Haptic Intensity slider.
- Output is clamped to `[-1, +1]`.
- AVAudioPCMBuffer scheduling is capped at 12 queued buffers; excess capture buffers are
  dropped instead of allowing unbounded latency.

### Hardware Result

The user confirmed that playing a video produced controller vibration that followed the
captured audio. The Haptic Intensity slider response was not explicitly confirmed.

---

## 9. Tab-Switch / Adaptive Trigger Coexistence Failure

### Symptom

1. Audio Haptics worked.
2. User navigated to a trigger page and enabled an adaptive-trigger mode.
3. Trigger effect worked.
4. Audio haptics stopped.
5. Turning the trigger mode off did not restart audio haptics.

### Root Cause

`ControllerAudioView.onDisappear` called both:

- `stopChannelTest()`
- `stopAudioHaptics()`

Changing tabs destroyed the Audio view, stopped ScreenCaptureKit and AVAudioEngine, removed
the sample handler, and restored classic-rumble mode. Trigger changes were not conflicting
with PCM; the PCM engine no longer existed.

### Fix Implemented — Awaiting Hardware Retest

- Audio haptics are now app-global services owned by `AppDelegate`.
- Leaving the Audio tab no longer stops capture/DSP or changes haptic mode.
- Only short isolated channel tests are cancelled when leaving the tab.
- Every subsequent trigger report reads `audioHapticsModeEnabled`; while streaming it retains
  byte `1 = 0x0D` and all trigger mode bytes.
- Returning to the Audio tab should still show the stream as running.
- Explicit **Stop Haptics** or app termination stops the stream and restores classic rumble.

Automated regression:

```text
testAudioHapticsModePersistsAcrossTriggerChanges
```

The user deferred this hardware retest to the next session.

---

## 10. macOS 27 Golden Gate Cross-Device Failure

### Test Environment

- Remote test machine: base M1 MacBook Air.
- OS: macOS 27 Golden Gate beta.
- Changes are pushed from the development Mac and tested on that separate machine, so local
  `dualsenset.log` does not contain the remote run.

### Evidence

- Old HID features: working.
- Isolated Haptic L/R channel tests: working.
- System audio capture meter: moving with video volume.
- Streamed audio haptics: no controller vibration.

This isolates the failure to the **captured PCM → DSP buffer-unpacking bridge**:

- Quadraphonic controller output is valid (isolated channel tests work).
- PCM haptics mode is valid.
- ScreenCaptureKit permission/capture is valid (meter moves).
- The failure occurs only when captured system audio is decoded into haptic samples.

### Root Cause

The initial implementation called `CMSampleBufferGetDataBuffer` and treated the returned
`CMBlockBuffer` as one contiguous Float32 array:

- for planar audio, it assumed right-channel samples began exactly `frameCount` floats after
  left-channel samples;
- for interleaved audio, it assumed one buffer with L/R pairs.

That happened to work on the original test Mac. ScreenCaptureKit on Golden Gate can expose
separate planar `AudioBuffer` entries whose storage and padding must be read through the
`AudioBufferList`. A raw byte scan can still make the level meter move while the DSP reads
the wrong offsets or rejects the length, producing no actuator output.

### Fix Implemented — Awaiting Remote Retest

- Replaced raw `CMBlockBuffer` indexing with `CMSampleBuffer.withAudioBufferList`.
- Logical channel lookup now follows each buffer's `mNumberChannels`, `mDataByteSize`, and
  `mData`.
- Supports:
  - one interleaved stereo buffer;
  - two separate one-channel planar buffers;
  - mono input duplicated to both grips;
  - mixed buffer groupings without assuming contiguous channel storage.
- Updated the capture meter to iterate the real `AudioBufferList` too.
- Added visible remote diagnostics:
  - captured audio level;
  - processed haptic output level;
  - processed buffer count;
  - dropped buffer count;
  - exact captured PCM layout.
- Added `testAudioBufferListDecodesPlanarAndInterleavedStereo`.

Expected successful remote state while video is playing:

```text
Captured Audio: moving
Processed Haptic Output: moving
Processed: continuously increasing
Dropped: ideally 0 or low
Input format: 48000 Hz Float32 · 2 ch · planar/interleaved ...
```

---

## 11. Test Coverage

The suite currently has **71/71 passing tests**.

Audio-specific tests:

1. `testDualSenseUSBAudioDeviceMatching`
   - Accepts Sony DualSense USB audio endpoints.
   - Rejects Bluetooth and unrelated built-in devices.
2. `testControllerAudioQuadraphonicReadiness`
   - Recognizes a four-channel Quadraphonic device as haptics-ready.
3. `testUSBAudioControlsSerializeWithoutChangingTriggerOffsets`
   - Verifies volume/routing/mute bytes and unchanged R2/L2 offsets.
4. `testAudioControlFlagsAreNeverSentOverBluetooth`
   - Ensures USB audio state cannot leak into BT reports.
5. `testUSBAudioHapticsModeTemporarilyReleasesClassicRumble`
   - Verifies `0x0F → 0x0D → 0x0F`, motor zero/restore, trigger preservation, and improved
     rumble disable/restore.
6. `testSystemAudioMeterNormalization`
   - Verifies capture RMS maps safely into the UI's `0...1` meter.
7. `testAudioHapticsModePersistsAcrossTriggerChanges`
   - Verifies Weapon → Feedback updates keep PCM mode selected.
8. `testAudioBufferListDecodesPlanarAndInterleavedStereo`
   - Verifies the production channel iterator reads separate planar and combined interleaved
     stereo layouts identically.

These tests validate state and packet construction. They do not replace physical audio
hardware testing.

---

## 12. Required Retest Before Continuing

Use the rebuilt app with the controller connected through USB.

### Golden Gate Buffer Compatibility

1. Start Audio Haptics on the base M1 MacBook Air running macOS 27 Golden Gate.
2. Play the same video used for the failed test.
3. Confirm both Captured Audio and Processed Haptic Output meters move.
4. Confirm Processed continuously increases.
5. Record the displayed input-format line and Dropped count.
6. Confirm the controller vibrates; if not, send a screenshot of these diagnostics.

### A. Trigger + Audio Haptics Simultaneously

1. Open **Audio (USB)**.
2. Start **Audio Haptics**.
3. Play a video with bass and confirm vibration.
4. Without stopping haptics, open **Left Trigger** or **Right Trigger**.
5. Apply Weapon, Feedback, or Vibration.
6. Confirm:
   - adaptive-trigger resistance works;
   - video-driven grip vibration continues;
   - returning to Audio still shows haptics running.
7. Move Haptic Intensity from 20% to 90% and confirm a clear strength difference.

### B. Stop and Restore

1. Return to **Audio (USB)**.
2. Click **Stop Haptics**.
3. Open **Haptics**.
4. Run Test Pulse / Heartbeat.
5. Confirm classic rumble returned.

### C. Stability

1. Run audio haptics for at least 10 minutes.
2. Watch for increasing delay, stutter, silence, or high CPU.
3. Close/reopen the main window while streaming.
4. Stop playback, then start another video.
5. Unplug/replug USB only after stopping haptics; reconnect recovery is not hardened yet.

### D. Wired Headset — Deferred

When a wired 3.5 mm headset is available:

1. Plug it into the bottom-center DualSense jack.
2. Select **Headset (Stereo)**.
3. Front Left must play in the left ear.
4. Front Right must play in the right ear.
5. Verify headset volume.
6. If the headset has a TRRS microphone, select **Headset Microphone** and verify gain/mute.

---

## 13. Known Technical Risks

- ScreenCaptureKit must still provide 32-bit Float PCM, but planar/interleaved storage is now
  handled through CoreMedia's canonical AudioBufferList API.
- The capture path allocates an `AVAudioPCMBuffer` per incoming buffer. This is off the
  AudioUnit render thread but should be replaced by a preallocated ring-buffer pool if CPU,
  allocations, or latency are high.
- Queue depth is bounded, but long-session clock drift between ScreenCaptureKit and the
  DualSense output device has not been measured.
- Audio intensity is read across queues; production hardening should use a small synchronized
  parameter snapshot.
- Device removal while AVAudioEngine is active is not yet handled gracefully.
- CoreAudio hotplug listening is not implemented; discovery currently occurs on init/refresh.
- A reconnect can produce new `AudioDeviceID`s, requiring engine rebuild from the stable UID.
- Screen/system audio permission denial and later permission changes need a dedicated
  in-app recovery flow.
- Audio Haptics is intentionally unavailable over Bluetooth.
- CPU use while streaming has not been profiled. The earlier general CPU optimization does
  not measure this new capture/DSP pipeline.

---

## 14. File Inventory

- `Sources/Services/ControllerAudioService.swift`
  - CoreAudio discovery and Quadraphonic configuration.
  - Isolated channel AVAudioEngine.
  - Full audio-haptics output engine and DSP.
- `Sources/Services/SystemAudioCaptureService.swift`
  - ScreenCaptureKit permission/capture lifecycle.
  - Audio level meter and synchronous sample consumer.
- `Sources/Views/ControllerAudioView.swift`
  - Audio diagnostics, routes, volumes, mute, tests, capture meter, intensity, start/stop.
- `Sources/Services/ControllerManager.swift`
  - USB audio HID state and PCM/classic-rumble selector.
- `Sources/Views/ContentView.swift`
  - Audio tab routing and service ownership injection.
- `Sources/AppDelegate.swift`
  - Long-lived audio services and termination cleanup.
- `build.sh`
  - CoreAudio, AudioToolbox, AVFAudio, ScreenCaptureKit, CoreMedia linkage.
  - Audio/screen capture usage descriptions.
- `Tests/Tests.swift`
  - Seven audio-specific regressions listed above.

---

## 15. Git / Resume Point

- Known-good pre-audio hardware checkpoint:
  - `603384f` — `checkpoint hardware-verified controller support`
- Audio implementation commit currently at repository HEAD:
  - `ce14471` — `feat: implement audio haptics functionality and UI integration`
- Changes after that commit at pause time:
  - `ControllerAudioView.swift`: keep audio haptics alive across tab navigation.
  - `Tests/Tests.swift`: coexistence regression test.

Before continuing, read:

1. `PROGRESS.md`
2. `USB_AUDIO_HAPTICS.md`
3. `TEST_INFRA.md`
4. The latest hardware response from the user

Do not change the known-good BT/USB report headers, LED handshake, trigger offsets, or CRC
while refining audio. The only intentional USB rumble-selector change is scoped to
`audioHapticsModeEnabled`.

