# Contributing to Sticky Fingers

Thank you for helping make DualSense support on macOS better. Contributions can be code,
hardware testing, documentation, protocol research, design, localization, or reproducible
bug reports.

## Before You Start

- Search [existing issues](https://github.com/DegenerateUSER/DualsenseT/issues).
- Use an issue for behavior changes that affect protocol compatibility or the user
  experience.
- Never include private Apple credentials, signing certificates, controller logs you have
  not reviewed, or proprietary Sony material.

Small fixes can go directly to a pull request.

## Development Setup

Requirements:

- Apple silicon Mac
- macOS 14 or newer
- Xcode Command Line Tools
- DualSense hardware for transport-dependent changes

Run:

```bash
git clone https://github.com/DegenerateUSER/DualsenseT.git
cd DualsenseT
./build.sh test
./build.sh
open "Sticky Fingers.app"
```

Local builds are ad-hoc signed by default. See
[Installation](docs/INSTALLATION.md#build-from-source) if macOS repeatedly requests audio
capture permission.

## Project Layout

- `Sources/Views/` — SwiftUI user interface
- `Sources/Services/ControllerManager.swift` — controller state and HID output
- `Sources/Services/BluetoothHIDController.swift` — Bluetooth transport and reports
- `Sources/Services/ControllerAudioService.swift` — CoreAudio and haptic DSP
- `Sources/Services/SystemAudioCaptureService.swift` — ScreenCaptureKit audio input
- `Sources/Services/UDPListener.swift` — local DSX-compatible commands
- `Sources/Models/` — presets and shared values
- `Sources/CHidapi/` — vendored HIDAPI source
- `Tests/Tests.swift` — dependency-free test harness

Read [Architecture](docs/ARCHITECTURE.md) before changing transport or audio code.

## Making a Change

1. Fork the repository.
2. Create a focused branch, such as `fix/bt-reconnect`.
3. Keep the patch limited to one concern.
4. Add or update a regression test where the behavior can be tested without hardware.
5. Update user or technical documentation when behavior changes.
6. Run `./build.sh test` and `./build.sh`.
7. Open a pull request using the template.

## Code Style

- Follow standard Swift naming and four-space indentation.
- Keep UI publication on the main queue.
- Do not block HID reader or real-time audio render callbacks.
- Avoid allocating, logging, locking for long periods, or dispatching to the main queue from
  a real-time render callback.
- Keep USB and Bluetooth report layouts independently testable.
- Use bounded buffers for producer/consumer audio paths.
- Preserve background behavior when changing view lifecycle code.

The project intentionally avoids package dependencies. Propose a dependency before adding
one.

## Hardware Test Notes

For HID changes, report:

- DualSense or DualSense Edge
- Controller firmware when available
- USB, Bluetooth, or both
- macOS version and Mac model
- Features tested
- Whether Steam Input or another controller utility was running

For audio changes, also test:

- Quadraphonic setup
- Speaker L/R
- Haptic L/R
- System-audio response
- Switching tabs while streaming
- Adaptive triggers while streaming
- Stop/restore behavior
- Reconnect and at least a 30-minute run when practical

Do not claim hardware verification in docs unless someone performed it.

## Commit and Pull Request Guidance

Use a clear imperative summary, for example:

```text
fix: preserve audio haptics across trigger changes
```

Explain the user impact, root cause, verification, and any untested hardware case. Reviewers
should not have to infer protocol changes from a byte diff.

## Licensing

By submitting a contribution, you agree that it may be distributed under the repository's
[GNU General Public License version 3 only](LICENSE). HIDAPI files retain their upstream notices;
see [Third-Party Notices](THIRD_PARTY_NOTICES.md).

