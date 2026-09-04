# Architecture

Sticky Fingers is a native SwiftUI/AppKit macOS application built directly with `swiftc`.
It intentionally has no package-manager dependencies. The only vendored library is HIDAPI's
macOS backend for raw Bluetooth HID access.

## Runtime Overview

```text
SwiftUI views
    │
    ├── ControllerManager ── GameController input / USB IOHID output
    │         └────────────── BluetoothHIDController raw BT input/output
    │
    ├── PresetManager ────── local JSON presets
    ├── UDPListener ──────── opt-in localhost DSX-compatible commands
    │
    └── ControllerAudioService
              ├── CoreAudio device discovery and channel layout
              ├── AVAudioEngine four-channel output
              └── SystemAudioCaptureService / ScreenCaptureKit
```

## Application Lifecycle

`Sources/main.swift` creates `NSApplication` and installs `AppDelegate`.

`AppDelegate` owns the long-lived services, creates the Dock window and menu-bar helper,
starts the optional UDP server, and performs shutdown cleanup. Closing the window hides it;
the process and requested background features remain active. `⌘Q` terminates the app.

`AppIdentity` centralizes the public name, executable name, bundle identifier, notification
name, and Application Support migration from the former DualSenseT name.

## Controller Transport

### GameController

Apple's GameController framework supplies the normal controller model and foreground input.
`ControllerManager` coalesces values before publishing them to SwiftUI so high-rate reports
do not cause unnecessary view updates.

### USB Raw HID

USB output reports are sent with IOHID APIs. A 48-byte report carries adaptive trigger state,
classic rumble, LEDs, and—when enabled—controller audio routing and volume fields.

LED ownership is initialized with a dedicated setup report before normal color/player LED
state is sent.

### Bluetooth Raw HID

`BluetoothHIDController` uses the vendored HIDAPI backend because GameController output can
be unreliable when the app loses focus. It:

- Opens Sony vendor/product HID devices with HIDAPI's exclusive macOS option; this enables
  reliable Bluetooth output but requires explicit in-game input compatibility testing.
- Reads Bluetooth input report `0x31`.
- Parses controls, touch contacts, battery, gyro, and accelerometer.
- Writes signed Bluetooth output reports with sequence tags and CRC32.
- Synchronizes connection state and closes the HID handle only after the reader exits.

Bluetooth UI delivery is capped near display rate while the read loop continues draining
reports.

## Background Output

When another application becomes active, `ControllerManager` sends a short exponential
backoff burst of raw HID reports and then maintains state at a lower frequency. This protects
trigger and LED configuration from framework resets without continuously repainting the UI.

UI and sensor publication pause when the main window is hidden, minimized, or fully
occluded. HID output, profiles, gestures, UDP, and active audio haptics remain independent of
window visibility.

## Motion and Touch

Raw gyroscope and accelerometer readings feed a complementary filter:

- Gyroscope integration supplies responsive orientation changes.
- Accelerometer gravity corrects pitch and roll drift.
- Correction gain adapts to motion.
- Resting yaw decays because the controller has no absolute heading reference.

Touchpad contacts are parsed independently for USB and Bluetooth. Gesture recognition can
translate swipes into local key events when Accessibility permission is granted.

## Audio Haptics

Audio is available only over USB.

1. `ControllerAudioService` finds the DualSense CoreAudio endpoint.
2. It configures a Quadraphonic layout: audible L/R followed by haptic L/R.
3. `SystemAudioCaptureService` starts an audio-only ScreenCaptureKit stream.
4. Incoming planar, interleaved, or mono Float32 samples are decoded through
   `CMSampleBuffer.withAudioBufferList`.
5. A band-pass/transient DSP stage derives independent left/right haptic samples.
6. A bounded stereo ring buffer bridges capture and the real-time render callback.
7. `AVAudioSourceNode` pulls four-channel output; channels 3 and 4 drive the grips.
8. HID output temporarily releases classic-rumble mode while PCM haptics are active.

The output AudioUnit starts only after a non-silent prefill to avoid startup starvation.
Changing tabs does not stop the stream.

See [`USB_AUDIO_HAPTICS.md`](../USB_AUDIO_HAPTICS.md) for protocol details, failure history,
and hardware test notes.

## Local Persistence

Application data lives under:

```text
~/Library/Application Support/Sticky Fingers/
├── presets/
└── sticky-fingers.log
```

No cloud account or analytics client is present.

## Network Surface

The optional UDP listener accepts local DSX-compatible JSON commands on port `6969`. It is
off unless enabled and rejects every non-loopback peer before parsing commands. Changes that
allow remote peers require authentication and a security review.

## Build and Test

`build.sh`:

1. Compiles HIDAPI C sources for arm64 macOS 14.
2. Compiles all Swift sources and links Apple frameworks.
3. Creates `Sticky Fingers.app`.
4. Ad-hoc signs local builds or uses `CODESIGN_IDENTITY` for stable signing.

`./build.sh test` compiles the same source set with `TESTING` and runs the custom test
harness. The tests validate serialization, input parsing, protocol reports, CRC, trigger
packing, transport boundaries, background transitions, CPU throttles, audio layouts, PCM
decoding, and ring-buffer behavior.

## Important Constraints

- Minimum target: macOS 14, Apple silicon.
- Only one actively controlled DualSense is supported at a time.
- Controller audio and PCM haptics require USB.
- The project is not sandboxed; raw HID and local integration are incompatible with a
  straightforward Mac App Store build.
- Private Sony protocol details are implemented from public drivers and observed behavior;
  controller firmware changes can require compatibility updates.

