# Privacy

Sticky Fingers is designed to work locally. The application has no account system,
advertising SDK, analytics SDK, crash-reporting service, or telemetry endpoint.

## Data the App Processes

### Controller input

Buttons, sticks, triggers, touch contacts, motion sensors, battery state, and connection
metadata are read to operate the UI and configured features. They are not uploaded.

### System audio

When you explicitly start Audio Haptics, macOS ScreenCaptureKit provides system-audio sample
buffers. Sticky Fingers:

- Excludes its own audio from capture.
- Converts samples into haptic output in memory.
- Does not record audio or video to disk.
- Does not transmit captured audio.
- Stops capture when you stop Audio Haptics or quit the app.

The permission can be revoked at any time under:

```text
System Settings → Privacy & Security → Screen & System Audio Recording
```

### Touchpad gesture key events

If gesture remapping is enabled, Accessibility access is used only to generate the selected
local keyboard event.

## Data Stored on Disk

Sticky Fingers stores:

- Custom presets as JSON.
- A local diagnostic log.
- User preferences through macOS `UserDefaults`.

Application Support data is under:

```text
~/Library/Application Support/Sticky Fingers/
```

Legacy data from the former DualSenseT name is copied on first launch after the rename.

Logs may include timestamps, connection transitions, app names observed for per-app profile
switching, and diagnostic errors. Review logs before attaching them to a public issue.

## Network Activity

The app does not make outbound internet requests.

The optional UDP server listens on port `6969` for DualSenseX-compatible commands from the
same Mac. It is disabled unless the user starts it or enables automatic startup. Non-loopback
peers are rejected.

GitHub links in the documentation open in the user's browser; the app itself does not check
for updates.

## Release Verification

Official release archives are intended to be Developer ID signed and notarized. Users can
inspect a downloaded app with:

```bash
codesign --verify --deep --strict --verbose=2 "Sticky Fingers.app"
spctl --assess --type execute --verbose=2 "Sticky Fingers.app"
```

The complete source code and build script are available in the repository under GPL-3.0.

## Questions

For non-sensitive privacy questions, use the
[question form](https://github.com/DegenerateUSER/DualsenseT/issues/new?template=question.yml).
Do not include private controller logs or security-sensitive details in a public post.

