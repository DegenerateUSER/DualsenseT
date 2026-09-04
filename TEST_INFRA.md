# DualSenseT Testing Infrastructure

## Features Under Test

1. **Controller Visualizer View & Input State Mapping**
   - Maps physical/virtual button presses, thumbstick displacements, trigger values, touchpad coordinate markers, LED color changes, and pulsing animations to the SwiftUI `ControllerVisualizerView`.
2. **Background Mode Transitions & Raw HID Output Bypass**
   - Listens for application focus loss and gain (`NSApplication.didResignActiveNotification` / `NSApplication.didBecomeActiveNotification`) to toggle between GameController API mode and Direct IOHID raw output reports to preserve trigger and LED configurations persistently.
3. **Bluetooth Output Reports & CRC32 Verification**
   - Builds 78-byte direct Bluetooth output reports, updates sequence numbers (0-15 modulo), maps triggers to haptic parameters, and computes the 4-byte Bluetooth CRC32 trailer using seed byte `0xA2`.
4. **Touchpad Gesture Cardinal Swipes & Key Simulation**
   - Monitors touchpad movements and triggers keypress simulations (Spacebar, Arrows) when swipe displacements exceed the 0.5 threshold.
5. **Per-App Profile Switching**
   - Automatically switches trigger presets based on the bundle identifier of the focused application.

---

## Runner Command

To execute the test suite, run the following command in the project root:
```bash
./build.sh test
```

---

## Test Cases Inventory

### Tier 1: Feature Coverage (15 Test Cases)

#### Visualizer Mapping
1. `testVisualizerLeftTriggerMapping`: Verifies that `leftTriggerValue` changes map correctly.
2. `testVisualizerRightTriggerMapping`: Verifies that `rightTriggerValue` changes map correctly.
3. `testVisualizerButtonsPressedMapping`: Verifies that button highlights map correctly for buttons (Cross, Dpad, etc.).
4. `testVisualizerTouchpadMapping`: Verifies that touchpad touch active states and coordinates map correctly.
5. `testVisualizerLedColorAndPulseMapping`: Verifies that LED color and pulse state map correctly.

#### Background Transitions
6. `testBackgroundTransitionToResignActive`: Verifies that `didResignActiveNotification` toggles `isAppInForeground` to `false`.
7. `testBackgroundTransitionToBecomeActive`: Verifies that `didBecomeActiveNotification` toggles `isAppInForeground` to `true`.
8. `testBackgroundTransitionAppliesHIDReport`: Verifies that resigning active generates the raw USB/BT report immediately.
9. `testBackgroundTransitionAppliesNormalTrigger`: Verifies that returning to active mode restores standard GameController API state.
10. `testBackgroundTransitionResetsForegroundState`: Verifies robust focus toggle resetting `isAppInForeground` repeatedly.

#### Bluetooth Output Reports / CRC32
11. `testBTReportHeaderSerialization`: Verifies Report ID 0x31, sequence number flags, and BT tags are set correctly.
12. `testBTReportSequenceNumberIncrement`: Verifies sequence numbers increment modulo 16 on successive outputs.
13. `testBTReportL2TriggerVibrationMapping`: Verifies that vibration parameters pack correctly in BT reports.
14. `testBTReportR2TriggerWeaponMapping`: Verifies that weapon parameters pack correctly in BT reports.
15. `testBTReportCRC32Calculation`: Verifies that direct Bluetooth CRC32 calculations match expected check patterns.

### Tier 2: Boundary & Corner Cases (15 Test Cases)
16. `testTriggerBoundaryL2OffMode`: Verifies off-mode trigger parameters are all zeroed in HID output.
17. `testTriggerBoundaryL2FeedbackStrengthClamping`: Verifies trigger strength clamping at bounds in feedback mode.
18. `testTriggerBoundaryR2WeaponPositionsClamping`: Verifies snap positions clamp to allowed ranges (min 2, max 8).
19. `testTriggerBoundaryL2VibrationClamping`: Verifies vibration amplitude and frequency clamp safely to `[0.0, 1.0]`.
20. `testTouchpadGestureThresholdBoundary`: Verifies that swipes just below 0.5 (0.49) are ignored, and swipes above 0.5 (0.51) trigger.
21. `testCRC32EmptyData`: Verifies CRC32 calculation behaves stably with empty byte buffers.
22. `testCRC32AllZeros`: Verifies CRC32 calculation with a 74-byte buffer of zeros.
23. `testCRC32AllOnes`: Verifies CRC32 calculation with a 74-byte buffer of `0xFF`.
24. `testLEDColorBoundaryConversion`: Verifies converted RGB components clamp cleanly at boundaries.
25. `testPresetBoundaryLoading`: Verifies loading presets with out-of-bounds parameters clamps values safely.
26. `testPerAppProfileEmptyApplication`: Verifies that searching for a non-existent preset name returns `nil` safely.
27. `testTouchpadTimeoutInvalidation`: Verifies touchpad gesture variables reset correctly.
28. `testGyroCalibrationBoundary`: Verifies that `recenterSensors` successfully sets raw attitude calibration reference.
29. `testBatteryLevelClamping`: Verifies that battery percentage levels remain bounded.
30. `testParameterValueBoundaryDecoding`: Verifies JSON decoder handles incorrect/malformed structures in `ParameterValue` safely.

### Tier 3: Cross-Feature Combinations (3 Test Cases)
31. `testTransitionWithTriggerModeChange`: Verifies updating preset during resign focus writes new values to the raw HID output report immediately.
32. `testTouchpadSwipeDuringBackgroundState`: Verifies touchpad gestures work correctly when backgrounded.
33. `testPresetApplicationUpdatesVisualizerAndHID`: Verifies applying presets updates the UI model bindings and the raw HID report simultaneously.

### Tier 4: Real-World Application Scenarios (5 Test Cases)
34. `testScenarioGamingRifleFire`: Simulates a shooter scenario (Weapon preset, trigger press, resign active, BT HID dispatch, become active restoration).
35. `testScenarioRacingBrakeAndGas`: Simulates racing gameplay with mixed trigger states and transitions.
36. `testScenarioAppProfileSwitching`: Simulates automated configuration change when focusing an associated game/application window.
37. `testScenarioDisconnectReconnectCycle`: Simulates physical controller disconnect followed by reconnecting and reapplying custom presets.
38. `testScenarioUDPCommandTriggerUpdate`: Simulates UDP preset JSON packet parsing and trigger updates.

### Existing Unit Tests (4 Test Cases)
39. `testPresetSerialization`: Verifies preset encode/decode JSON loop.
40. `testParameterValueDecoding`: Verifies parsing int/double/string parameter formats.
41. `testTouchpadSwipeGestures`: Verifies basic touchpad swipes.
42. `testQuaternionNormalization`: Verifies identity quaternion maths.

### Tier 5: Trigger Encoding & BT Input Parsing (15 Test Cases)
43. `testWeaponPacksStartStopAsUInt16`: Verifies Weapon start/end zones pack as a uint16 bitmask.
44. `testWeaponEndZone8GoesToHighByte`: Verifies end zone 8 lands in the high bitmask byte.
45. `testSemiAutomaticIsBowWithPackedSnap`: Verifies Semi-Automatic emits mode 0x22 with packed resistance|snap byte.
46. `testAutomaticIsMachineWithFreqAndPeriod`: Verifies Automatic emits mode 0x27 with frequency and period bytes.
47. `testFeedbackZonePacking`: Verifies Feedback per-zone strength bit-packing.
48. `testFullPressMaxesAllZones`: Verifies Full Press sets all 10 zones to max strength.
49. `testVibrationFrequencyAtIndex8`: Verifies vibration frequency byte sits at params[8].
50. `testUSBReportTriggerOffsetsAndFlags`: Verifies USB 0x02 report trigger offsets and valid flags.
51. `testBTReportHasValidCRCAndSeq`: Verifies BT 0x31 report CRC32 trailer and sequence nibble.
52. `testBTInputReportRejectsShortBuffer`: Verifies `parseInputReport` rejects truncated reports.
53. `testBTInputReportButtonsSticksAndTriggers`: Verifies BT 0x31 button/hat/stick/trigger decoding.
54. `testBTInputReportGyroDecoding`: Verifies BT gyro int16-LE decoding (incl. negative values).
55. `testBTInputReportTouchpadContactAndCoordinates`: Verifies BT touch-point contact bit and 12-bit X/Y unpacking.
56. `testBTInputReportBatteryDischargingAndCharging`: Verifies BT battery level + charging status decoding.
57. `testBTInputReportBatteryFull`: Verifies BT battery-full status forces 100%.

### Tier 6: Output State & LED Handshake Regression Coverage (4 Test Cases)
58. `testUSBOutputReportCarriesAllHardwareState`: Verifies the exact 48-byte USB report, required HAPTICS_SELECT/trigger/LED flags, rumble motors, mic LED, player mask, RGB bytes, and absence of a mixed LED setup command.
59. `testBTOutputReportCarriesAllHardwareState`: Verifies the 78-byte BT equivalent, the hardware-confirmed zero sequence-tag low nibble, all hardware state bytes, and CRC32.
60. `testUSBLEDSetupIsDedicatedReport`: Verifies USB LED ownership setup is its own 48-byte LIGHT_OUT report with no state mixed in.
61. `testBTLEDSetupIsDedicatedSignedReport`: Verifies the BT LED setup report has its own sequence number, required tag, LIGHT_OUT payload, and valid CRC32.

### Tier 7: Runtime CPU Guardrails (2 Test Cases)
62. `testBTInputDeliveryIsCappedAtDisplayRate`: Verifies high-rate Bluetooth reports cannot be delivered to SwiftUI faster than the 60 Hz UI budget.
63. `testAnalogNoiseDoesNotPublishVisualChange`: Verifies one-count stick jitter is suppressed while meaningful movement still updates.

### Tier 8: USB Controller Audio Discovery (2 Test Cases)
64. `testDualSenseUSBAudioDeviceMatching`: Verifies discovery accepts Sony DualSense USB audio endpoints while rejecting Bluetooth and unrelated built-in devices.
65. `testControllerAudioQuadraphonicReadiness`: Verifies a four-channel device with the Quadraphonic tag is recognized as L/R/Haptic-L/Haptic-R ready.

### Tier 9: USB Audio Controls & Audio Haptics (7 Test Cases)
66. `testUSBAudioControlsSerializeWithoutChangingTriggerOffsets`: Verifies route/volume/mute/pre-gain fields and ensures audio additions do not move adaptive-trigger offsets.
67. `testAudioControlFlagsAreNeverSentOverBluetooth`: Verifies controller audio state cannot add USB-only audio flags or payload bytes to BT reports.
68. `testUSBAudioHapticsModeTemporarilyReleasesClassicRumble`: Verifies the USB report switches from classic rumble (`0x0F`) to PCM haptics (`0x0D`), zeros classic motors, preserves triggers, and restores the original state.
69. `testSystemAudioMeterNormalization`: Verifies captured RMS values clamp and scale safely into the `0...1` level meter.
70. `testAudioHapticsModePersistsAcrossTriggerChanges`: Verifies Weapon/Feedback changes retain PCM haptics mode and the correct trigger bytes.
71. `testAudioBufferListDecodesPlanarAndInterleavedStereo`: Verifies the production logical-channel iterator decodes Golden Gate-style planar buffers and interleaved stereo identically.
72. `testHapticRingBufferPreservesStereoFrames`: Verifies the Golden Gate pull-driven source-node bridge preserves ordered left/right PCM frames.

---

## Coverage Summary

- **Total Test Cases**: 72
- **Pass Rate**: 100% (72/72)
- **Status**: Verified and Green
- **Last Verified**: 04/09/2026 (after replacing Golden Gate AVAudioPlayerNode scheduling with a pull-driven source-node ring buffer)
- **Execution Log**:
  ```
  Compiling and running DualSenseT Unit Tests...
  ========================================
          DualSenseT UNIT TESTS           
  ========================================
    🟢 Passed: testPresetSerialization
    ...
    🟢 Passed: testBTInputReportBatteryFull
  ========================================
              TEST SUMMARY                
  ========================================
    Passed: 72
    Failed: 0
    Total:  72
  ========================================
  ```
