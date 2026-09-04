# Changelog

All notable changes to Sticky Fingers are recorded here. The project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and intends to use
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Adaptive trigger configuration with 11 native effect modes.
- USB and Bluetooth output for adaptive triggers, lightbar, mic LED, player LEDs, and
  classic rumble.
- DualSenseX-compatible UDP command server on port `6969`.
- Built-in and custom presets with per-application switching.
- Live controller map, touch contacts, battery, and fused motion visualization.
- Touchpad swipe-to-key remapping.
- USB controller speaker, headset, and microphone controls.
- Quadraphonic speaker configuration and isolated output-channel tests.
- System-audio-driven stereo haptics through ScreenCaptureKit and AVAudioEngine.
- Dock application behavior, menu-bar status, reopen handling, and standard `⌘Q`.
- Public installation, architecture, troubleshooting, privacy, contribution, security, and
  release documentation.
- Continuous integration and a signed/notarized GitHub release workflow.

### Changed

- Renamed the public application from DualSenseT to **Sticky Fingers**.
- Replaced the Sony-branded legacy artwork with the original filled 3A app/Dock icon and
  added its reproducible vector-to-`.icns` build script.
- Migrates legacy presets and logs into the new Application Support directory.
- Simplified the Audio page around user controls; raw device and stream details now live in
  a collapsed Advanced Diagnostics section.
- Reduced input-driven CPU work by throttling UI delivery, coalescing state, filtering
  analog noise, and pausing hidden-window rendering.
- Made audio haptics persist across tab changes and coexist with adaptive trigger updates.

### Fixed

- Correct Bluetooth sequence tags and CRC-signed output reports.
- USB and Bluetooth LED ownership/setup ordering.
- USB output report size and classic-rumble flag regressions.
- Bluetooth motion, mute-button, touchpad-origin, reconnect, and shutdown handling.
- HID handle leaks and disconnect races.
- CoreAudio channel-layout property sizing.
- Planar/interleaved ScreenCaptureKit PCM decoding.
- Audio-player starvation on newer macOS builds by using a pull-driven source node and
  bounded ring buffer.
- Restored classic rumble automatically after PCM haptics stop.

### Security

- Reject non-loopback peers before accepting UDP controller commands.
- Documented local capture, storage, network, and release-verification behavior.

## Release Status

The first public version has not been tagged. Remaining hardware gates are tracked in
[`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md), including wired-headset validation,
disconnect/reconnect testing, and a sustained audio-haptics run.

