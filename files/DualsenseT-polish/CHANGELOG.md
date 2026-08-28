# Changelog

All notable changes to DualSenseT will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Initial public release
- Adaptive Trigger configuration (Off, Feedback, Weapon, Vibration modes) for L2 and R2
- LED Lightbar color picker with pulse/breathing mode
- Live Controller Map visualizer (buttons, sticks, touchpad with trails)
- Gyroscope & Accelerometer 3D visualization with attitude quaternion
- Adaptive IMU Complementary Filter (custom implementation bypassing macOS GameController limitation)
- UDP Server emulating DualSenseX protocol on port 6969
- Per-App Profiles with automatic focus-based profile switching
- Touchpad gesture remapping to keyboard keys
- Menu Bar Helper with live battery and connection status
- Raw HID Background Override via IOKit (keeps triggers active while gaming)
- Zero-CPU idle optimization (0.0% CPU when dashboard hidden)
- Preset system (save/load as JSON; built-in Bow & Arrow, Heavy Rifle, Racing Brake)
- Unit test harness covering preset serialization, parameter parsing, touchpad thresholds, quaternion math
