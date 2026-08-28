# Scope: E2E Testing Suite

## Objective
Design and implement a comprehensive opaque-box test suite covering:
1. ControllerVisualizerView layout and active states (standard buttons, analog stick positions, trigger pull fills, touchpad touch markers, LED color/pulsing animations).
2. Background mode transitions, didResignActiveNotification handling, and raw HID activation.
3. Bluetooth output reports format, sequence numbers, and CRC32 verification.

## Test Case Design Methodology (Dual Track)
- **Tier 1 - Feature Coverage (>=5 per feature)**: Verify visualizer mapping and background transition logic under basic scenarios.
- **Tier 2 - Boundary & Edge Cases (>=5 per feature)**: Extreme analog stick values, battery level edge cases, high frequency LED pulses, invalid reports.
- **Tier 3 - Cross-Feature Combinations**: Pairwise testing of active inputs (e.g. simultaneous sticks + touchpad touches + buttons).
- **Tier 4 - Real-World Application**: Standard usage sessions, application focus switching, rapid background/foreground transitions.

## Milestones
1. Write `TEST_INFRA.md` describing the feature inventory, test cases, and runner command.
2. Implement test runners and test cases (ensure they run via `./build.sh test`).
3. Verify all tests pass, and publish `TEST_READY.md` at project root.
