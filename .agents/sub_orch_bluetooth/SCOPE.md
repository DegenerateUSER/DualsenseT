# Scope: Persistent Bluetooth Settings in Background

## Objective
Fix the issue where adaptive trigger mode settings and LED settings stop working when the application is backgrounded or loses focus in Bluetooth mode.

## Requirements
- **Sequence Number & CRC32**: Ensure Bluetooth output report format, sequence numbers, and CRC32 calculations match the controller requirements.
- **Robust Transmission Loop**: Implement a persistent background timer/scheduler or thread to send raw HID reports when the app is backgrounded.
- **State Persistence**: Avoid settings reset, freezing, or stopping during background transitions.

## Milestones
1. Analyze `ControllerManager.swift` background mode, sequence number, and CRC32 calculation.
2. Fix Bluetooth report packet structure and CRC calculation issues.
3. Optimize background loop frequency and reliability.
4. Verify compiling via `./build.sh` and execution under background states.
