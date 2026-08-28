# Plan

## Milestones
1. **Milestone 1: Setup and E2E Test Suite Framework** (Dual Track - opaque-box testing)
   - Establish the E2E testing framework/infra (`TEST_INFRA.md`).
   - Create test scripts/tools that verify:
     - The visualizer layout, active button colors/glows, sticks, triggers, and touchpad markers.
     - Background mode activation, focus loss notifications, raw HID switching.
     - Accurate CRC32 checksums and sequence number validation for Bluetooth HID reports.
   - Produce `TEST_READY.md`.

2. **Milestone 2: High-Fidelity DualSense Controller Visualization**
   - Redesign `ControllerVisualizerView.swift` to ensure realistic proportions, accurate shapes (D-pad, action buttons, analog sticks inside rims, touchpad, lightbar, triggers, L1/R1, PS, Create, Options).
   - Verify responsive fitting, styling, glowing/shifting colors upon interaction, and LED pulsing/color mapping in both light and dark backgrounds.

3. **Milestone 3: Robust Persistent Bluetooth background trigger & LED settings**
   - Correct sequence number and CRC32 calculations for BT HID reports.
   - Implement a robust background worker loop/scheduler to periodically transmit raw HID reports when the app is backgrounded.
   - Ensure transitions between foreground (GameController API) and background (raw HID bypass) are clean and do not drop settings or freeze.

4. **Milestone 4: Verification and Adversarial Coverage (Tier 5)**
   - Run unit tests and the comprehensive E2E test suite.
   - Perform Challenger-driven adversarial coverage check (white-box review of code paths, negative inputs, edge cases).
   - Perform Forensic Audit to ensure zero cheating and proper implementation.
   - Final review and handoff.
