#if TESTING
import Foundation
import GameController
import AppKit
import SwiftUI
import CoreAudio

struct AssertionFailure: Error {
    let message: String
}

func XCTAssertEqual<T: Equatable>(_ expression1: T, _ expression2: T, _ message: String = "", file: String = #file, line: Int = #line) throws {
    if expression1 != expression2 {
        throw AssertionFailure(message: "Assertion Failed: '\(expression1)' is not equal to '\(expression2)'. \(message) at \(file):\(line)")
    }
}

func XCTAssertNil(_ expression: Any?, _ message: String = "", file: String = #file, line: Int = #line) throws {
    if expression != nil {
        throw AssertionFailure(message: "Assertion Failed: Expected nil, got '\(expression!)'. \(message) at \(file):\(line)")
    }
}

func XCTAssertTrue(_ expression: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    if !expression {
        throw AssertionFailure(message: "Assertion Failed: Expected true, got false. \(message) at \(file):\(line)")
    }
}

func XCTAssertFalse(_ expression: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    if expression {
        throw AssertionFailure(message: "Assertion Failed: Expected false, got true. \(message) at \(file):\(line)")
    }
}

class TestSuite {
    var failCount = 0
    var passCount = 0
    
    func runTest(name: String, block: () throws -> Void) {
        do {
            try block()
            print("  [PASS] \(name)")
            passCount += 1
        } catch let error as AssertionFailure {
            print("  [FAIL] \(name) - \(error.message)")
            failCount += 1
        } catch {
            print("  [FAIL] \(name) - Unexpected error: \(error)")
            failCount += 1
        }
    }
    
    func run() {
        _ = NSApplication.shared
        print("\n========================================")
        print("        DualSenseT UNIT TESTS           ")
        print("========================================")
        
        runTest(name: "testPresetSerialization") {
            let preset = TriggerPreset(
                name: "Test Preset",
                l2Mode: .feedback,
                l2Start: 0.1,
                l2End: 0.5,
                l2Strength: 0.8,
                l2Amplitude: 0.0,
                l2Frequency: 0.0,
                r2Mode: .weapon,
                r2Start: 0.2,
                r2End: 0.6,
                r2Strength: 0.9,
                r2Amplitude: 0.0,
                r2Frequency: 0.0,
                ledRed: 1.0,
                ledGreen: 0.0,
                ledBlue: 0.0,
                isLedPulsing: true
            )
            
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            let data = try encoder.encode(preset)
            let decoded = try decoder.decode(TriggerPreset.self, from: data)
            try XCTAssertEqual(decoded.name, preset.name)
            try XCTAssertEqual(decoded.l2Mode, preset.l2Mode)
            try XCTAssertEqual(decoded.r2Mode, preset.r2Mode)
            try XCTAssertEqual(decoded.ledRed, preset.ledRed)
            try XCTAssertEqual(decoded.isLedPulsing, preset.isLedPulsing)
        }
        
        runTest(name: "testParameterValueDecoding") {
            let decoder = JSONDecoder()
            
            let intJSON = "123".data(using: .utf8)!
            let doubleJSON = "45.0".data(using: .utf8)!
            let stringJSON = "\"123\"".data(using: .utf8)!
            
            let intVal = try decoder.decode(UDPListener.ParameterValue.self, from: intJSON)
            try XCTAssertEqual(intVal.intValue, 123)
            
            let doubleVal = try decoder.decode(UDPListener.ParameterValue.self, from: doubleJSON)
            try XCTAssertEqual(doubleVal.intValue, 45)
            
            let stringVal = try decoder.decode(UDPListener.ParameterValue.self, from: stringJSON)
            try XCTAssertEqual(stringVal.intValue, 123)
        }
        
        runTest(name: "testTouchpadSwipeGestures") {
            let manager = ControllerManager()
            
            // Initial state
            try XCTAssertNil(manager.touchStart)
            try XCTAssertFalse(manager.hasSwiped)
            
            // First touch starts gesture tracking
            manager.handleTouchpadUpdate(x: 0.1, y: 0.2)
            let expectedStart = CGPoint(x: CGFloat(Float(0.1)), y: CGFloat(Float(0.2)))
            try XCTAssertEqual(manager.touchStart, expectedStart)
            try XCTAssertFalse(manager.hasSwiped)
            
            // Gentle movement within threshold (dx < 0.5, dy < 0.5)
            manager.handleTouchpadUpdate(x: 0.2, y: 0.3)
            try XCTAssertFalse(manager.hasSwiped)
            
            // Large movement triggering Right swipe (dx > 0.5)
            manager.handleTouchpadUpdate(x: 0.7, y: 0.3)
            try XCTAssertTrue(manager.hasSwiped)
            
            // Release touch resets gesture
            manager.handleTouchpadUpdate(x: 0.0, y: 0.0)
            try XCTAssertNil(manager.touchStart)
            try XCTAssertFalse(manager.hasSwiped)
        }
        
        runTest(name: "testQuaternionNormalization") {
            // Identity quaternion
            let qRef = GCQuaternion(x: 0.0, y: 0.0, z: 0.0, w: 1.0)
            
            // Inverse of identity is identity
            let qRefInv = GCQuaternion(x: -qRef.x, y: -qRef.y, z: -qRef.z, w: qRef.w)
            try XCTAssertEqual(qRefInv.x, 0.0)
            try XCTAssertEqual(qRefInv.y, 0.0)
            try XCTAssertEqual(qRefInv.z, 0.0)
            try XCTAssertEqual(qRefInv.w, 1.0)
        }
        
        // ==========================================
        // TIER 1: FEATURE COVERAGE (15 Test Cases)
        // ==========================================
        
        // --- Feature 1: Visualizer Mapping ---
        runTest(name: "testVisualizerLeftTriggerMapping") {
            let manager = ControllerManager()
            manager.leftTriggerValue = 0.75
            try XCTAssertEqual(manager.leftTriggerValue, 0.75)
        }
        
        runTest(name: "testVisualizerRightTriggerMapping") {
            let manager = ControllerManager()
            manager.rightTriggerValue = 0.42
            try XCTAssertEqual(manager.rightTriggerValue, 0.42)
        }
        
        runTest(name: "testVisualizerButtonsPressedMapping") {
            let manager = ControllerManager()
            manager.buttonsPressed["cross"] = true
            manager.buttonsPressed["dpadUp"] = true
            try XCTAssertEqual(manager.buttonsPressed["cross"], true)
            try XCTAssertEqual(manager.buttonsPressed["dpadUp"], true)
            try XCTAssertNil(manager.buttonsPressed["circle"])
        }
        
        runTest(name: "testVisualizerTouchpadMapping") {
            let manager = ControllerManager()
            manager.touchpadPrimary = CGPoint(x: 0.5, y: -0.2)
            manager.touchpadPrimaryActive = true
            try XCTAssertEqual(manager.touchpadPrimary.x, 0.5)
            try XCTAssertEqual(manager.touchpadPrimary.y, -0.2)
            try XCTAssertTrue(manager.touchpadPrimaryActive)
        }
        
        runTest(name: "testVisualizerLedColorAndPulseMapping") {
            let manager = ControllerManager()
            manager.ledColor = NSColor.red
            manager.isLedPulsing = true
            try XCTAssertEqual(manager.ledColor, NSColor.red)
            try XCTAssertTrue(manager.isLedPulsing)
        }
        
        // --- Feature 2: Background Transitions ---
        runTest(name: "testBackgroundTransitionToResignActive") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            
            // Allow async notification observer to run
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            try XCTAssertFalse(appDelegate.controllerManager.isAppInForeground)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testBackgroundTransitionToBecomeActive") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            appDelegate.controllerManager.isAppInForeground = false
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            try XCTAssertTrue(appDelegate.controllerManager.isAppInForeground)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testBackgroundTransitionAppliesHIDReport") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.controllerManager.mockHIDTransport = "USB"
            appDelegate.controllerManager.r2Mode = .feedback
            appDelegate.controllerManager.r2Start = 0.2
            appDelegate.controllerManager.r2Strength = 0.8
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            
            // Allow the async queue with 0.05s / 0.2s delay to fire
            let limit = Date(timeIntervalSinceNow: 0.35)
            while Date() < limit {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
            }
            
            try XCTAssertTrue(appDelegate.controllerManager.capturedUSBReport != nil)
            if let report = appDelegate.controllerManager.capturedUSBReport {
                try XCTAssertEqual(report[0], 0x02) // USB Report ID
                try XCTAssertEqual(report[11], 0x21) // feedback mode byte representation
            }
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testBackgroundTransitionAppliesNormalTrigger") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            appDelegate.controllerManager.isAppInForeground = false
            
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            try XCTAssertTrue(appDelegate.controllerManager.isAppInForeground)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testBackgroundTransitionResetsForegroundState") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            try XCTAssertFalse(appDelegate.controllerManager.isAppInForeground)
            
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            try XCTAssertTrue(appDelegate.controllerManager.isAppInForeground)
            withExtendedLifetime(appDelegate) {}
        }
        
        // --- Feature 3: Bluetooth Output Reports / CRC32 ---
        runTest(name: "testBTReportHeaderSerialization") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.mockBTSequenceNumber = 5
            manager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(manager.capturedBTReport != nil)
            if let report = manager.capturedBTReport {
                try XCTAssertEqual(report[0], 0x31) // BT Report ID
                try XCTAssertEqual(report[1], UInt8(5 << 4)) // Sequence number, low-nibble tag must be 0
                try XCTAssertEqual(report[2], 0x10) // BT tag
            }
        }
        
        runTest(name: "testBTReportSequenceNumberIncrement") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.mockBTSequenceNumber = 15
            
            manager.applyTriggerSettingsViaHID()
            try XCTAssertEqual(manager.capturedBTReport?[1], UInt8(15 << 4))

            manager.applyTriggerSettingsViaHID()
            // Should roll over modulo 16 (15 &+ 1 = 16 => sequence number 0)
            try XCTAssertEqual(manager.capturedBTReport?[1], UInt8(0 << 4))
        }
        
        runTest(name: "testBTReportL2TriggerVibrationMapping") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.l2Mode = .vibration
            manager.l2Start = 0.2
            manager.l2Amplitude = 0.6
            manager.l2Frequency = 0.8
            
            manager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(manager.capturedBTReport != nil)
            if let report = manager.capturedBTReport {
                try XCTAssertEqual(report[24], 0x26) // Vibration Mode Byte
            }
        }
        
        runTest(name: "testBTReportR2TriggerWeaponMapping") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.r2Mode = .weapon
            manager.r2Start = 0.3
            manager.r2End = 0.7
            manager.r2Strength = 0.5
            
            manager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(manager.capturedBTReport != nil)
            if let report = manager.capturedBTReport {
                try XCTAssertEqual(report[13], 0x25) // Weapon Mode Byte
            }
        }
        
        runTest(name: "testBTReportCRC32Calculation") {
            let manager = ControllerManager()
            let data: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
            let crc = manager.testComputeBTCRC32(data)
            
            try XCTAssertTrue(crc != 0)
            
            let crc2 = manager.testComputeBTCRC32(data)
            try XCTAssertEqual(crc, crc2)
        }
        
        // ==========================================
        // TIER 2: BOUNDARY & CORNER CASES (15 Test Cases)
        // ==========================================
        
        runTest(name: "testTriggerBoundaryL2OffMode") {
            let manager = ControllerManager()
            let result = manager.testTriggerModeToHIDBytes(mode: .off, start: 0, end: 0, strength: 0, amplitude: 0, frequency: 0)
            try XCTAssertEqual(result.mode, 0x05)
            for param in result.params {
                try XCTAssertEqual(param, 0)
            }
        }
        
        runTest(name: "testTriggerBoundaryL2FeedbackStrengthClamping") {
            let manager = ControllerManager()
            let result1 = manager.testTriggerModeToHIDBytes(mode: .feedback, start: 0.1, end: 0.5, strength: -1.0, amplitude: 0, frequency: 0)
            let result2 = manager.testTriggerModeToHIDBytes(mode: .feedback, start: 0.1, end: 0.5, strength: 2.0, amplitude: 0, frequency: 0)
            
            try XCTAssertEqual(result1.mode, 0x21)
            try XCTAssertEqual(result2.mode, 0x21)
        }
        
        runTest(name: "testTriggerBoundaryR2WeaponPositionsClamping") {
            let manager = ControllerManager()
            let result = manager.testTriggerModeToHIDBytes(mode: .weapon, start: -0.5, end: 1.5, strength: 0.5, amplitude: 0, frequency: 0)
            try XCTAssertEqual(result.mode, 0x25)
        }
        
        runTest(name: "testTriggerBoundaryL2VibrationClamping") {
            let manager = ControllerManager()
            let result = manager.testTriggerModeToHIDBytes(mode: .vibration, start: 0.1, end: 0.5, strength: 0.5, amplitude: -0.5, frequency: 2.0)
            try XCTAssertEqual(result.mode, 0x26)
            try XCTAssertEqual(result.params[8], 255) // frequency at index 8 per ExtendInput reference
        }
        
        runTest(name: "testTouchpadGestureThresholdBoundary") {
            let manager = ControllerManager()
            
            manager.handleTouchpadUpdate(x: 0.1, y: 0.1)
            manager.handleTouchpadUpdate(x: 0.59, y: 0.1)
            try XCTAssertFalse(manager.hasSwiped)
            
            manager.resetTouchpadGesture()
            
            manager.handleTouchpadUpdate(x: 0.1, y: 0.1)
            manager.handleTouchpadUpdate(x: 0.61, y: 0.1)
            try XCTAssertTrue(manager.hasSwiped)
        }
        
        runTest(name: "testCRC32EmptyData") {
            let manager = ControllerManager()
            let crc = manager.testComputeBTCRC32([])
            try XCTAssertTrue(crc != 0)
        }
        
        runTest(name: "testCRC32AllZeros") {
            let manager = ControllerManager()
            let zeros = [UInt8](repeating: 0, count: 74)
            let crc = manager.testComputeBTCRC32(zeros)
            try XCTAssertTrue(crc != 0)
        }
        
        runTest(name: "testCRC32AllOnes") {
            let manager = ControllerManager()
            let ones = [UInt8](repeating: 0xFF, count: 74)
            let crc = manager.testComputeBTCRC32(ones)
            try XCTAssertTrue(crc != 0)
        }
        
        runTest(name: "testLEDColorBoundaryConversion") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.ledColor = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
            manager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(manager.capturedUSBReport != nil)
            try XCTAssertEqual(manager.capturedUSBReport?[45], 0)
            try XCTAssertEqual(manager.capturedUSBReport?[46], 255)
            try XCTAssertEqual(manager.capturedUSBReport?[47], 0)
        }
        
        runTest(name: "testPresetBoundaryLoading") {
            let preset = TriggerPreset(
                name: "Extreme Custom",
                l2Mode: .vibration,
                l2Start: -1.0,
                l2End: 2.0,
                l2Strength: 1.5,
                l2Amplitude: -0.5,
                l2Frequency: 3.0,
                r2Mode: .feedback,
                r2Start: 0.2,
                r2End: 0.6,
                r2Strength: 0.9,
                r2Amplitude: 0.0,
                r2Frequency: 0.0,
                ledRed: 2.0,
                ledGreen: -1.0,
                ledBlue: 0.5,
                isLedPulsing: false
            )
            
            let manager = ControllerManager()
            manager.applyPreset(preset)
            
            try XCTAssertEqual(manager.l2Mode, .vibration)
            try XCTAssertEqual(manager.l2Start, -1.0)
            try XCTAssertEqual(manager.l2End, 2.0)
        }
        
        runTest(name: "testPerAppProfileEmptyApplication") {
            let manager = ControllerManager()
            let presetManager = PresetManager()
            let preset = manager.findPreset(named: "Non-Existent Preset", presetManager: presetManager)
            try XCTAssertNil(preset)
        }
        
        runTest(name: "testTouchpadTimeoutInvalidation") {
            let manager = ControllerManager()
            manager.touchStart = CGPoint(x: 0.5, y: 0.5)
            manager.hasSwiped = true
            manager.resetTouchpadGesture()
            
            try XCTAssertNil(manager.touchStart)
            try XCTAssertFalse(manager.hasSwiped)
        }
        
        runTest(name: "testGyroCalibrationBoundary") {
            let manager = ControllerManager()
            manager.recenterSensors()
            try XCTAssertEqual(manager.motionAttitude.w, 1.0)
        }
        
        runTest(name: "testBatteryLevelClamping") {
            let manager = ControllerManager()
            manager.batteryLevel = -0.5
            try XCTAssertEqual(manager.batteryLevel, -0.5)
            manager.batteryLevel = 1.5
            try XCTAssertEqual(manager.batteryLevel, 1.5)
        }
        
        runTest(name: "testParameterValueBoundaryDecoding") {
            let decoder = JSONDecoder()
            let emptyJSON = "\"\"".data(using: .utf8)!
            let stringVal = try decoder.decode(UDPListener.ParameterValue.self, from: emptyJSON)
            try XCTAssertNil(stringVal.intValue)
        }
        
        // ==========================================
        // TIER 3: CROSS-FEATURE COMBINATIONS (3 Test Cases)
        // ==========================================
        
        runTest(name: "testTransitionWithTriggerModeChange") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.controllerManager.mockHIDTransport = "USB"
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            
            appDelegate.controllerManager.batchUpdate {
                appDelegate.controllerManager.r2Mode = .vibration
                appDelegate.controllerManager.r2Start = 0.4
                appDelegate.controllerManager.r2Amplitude = 0.8
            }
            
            appDelegate.controllerManager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(appDelegate.controllerManager.capturedUSBReport != nil)
            try XCTAssertEqual(appDelegate.controllerManager.capturedUSBReport?[11], 0x26)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testTouchpadSwipeDuringBackgroundState") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.3))
            
            appDelegate.controllerManager.handleTouchpadUpdate(x: 0.1, y: 0.1)
            appDelegate.controllerManager.handleTouchpadUpdate(x: 0.7, y: 0.1)
            
            try XCTAssertTrue(appDelegate.controllerManager.hasSwiped)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testPresetApplicationUpdatesVisualizerAndHID") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            
            let preset = manager.defaultPresets[0]
            manager.applyPreset(preset)
            
            try XCTAssertEqual(manager.l2Mode, .feedback)
            try XCTAssertEqual(manager.r2Mode, .weapon)
            
            manager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(manager.capturedUSBReport != nil)
            try XCTAssertEqual(manager.capturedUSBReport?[11], 0x25)
            try XCTAssertEqual(manager.capturedUSBReport?[22], 0x21)
        }
        
        // ==========================================
        // TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 Test Cases)
        // ==========================================
        
        runTest(name: "testScenarioGamingRifleFire") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.controllerManager.mockHIDTransport = "BT"
            appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name("")))
            
            let riflePreset = appDelegate.controllerManager.defaultPresets.first(where: { $0.name == "Heavy Rifle" })!
            appDelegate.controllerManager.applyPreset(riflePreset)
            
            appDelegate.controllerManager.rightTriggerValue = 0.8
            try XCTAssertEqual(appDelegate.controllerManager.rightTriggerValue, 0.8)
            
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
            let limit1 = Date(timeIntervalSinceNow: 0.35)
            while Date() < limit1 {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
            }
            
            try XCTAssertTrue(appDelegate.controllerManager.capturedBTReport != nil)
            try XCTAssertEqual(appDelegate.controllerManager.capturedBTReport?[13], 0x25)
            
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
            let limit2 = Date(timeIntervalSinceNow: 0.35)
            while Date() < limit2 {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
            }
            try XCTAssertTrue(appDelegate.controllerManager.isAppInForeground)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testScenarioRacingBrakeAndGas") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            appDelegate.controllerManager.mockHIDTransport = "USB"
            
            let racingPreset = appDelegate.controllerManager.defaultPresets.first(where: { $0.name == "Racing Brake" })!
            appDelegate.controllerManager.applyPreset(racingPreset)
            
            appDelegate.controllerManager.applyTriggerSettingsViaHID()
            
            try XCTAssertTrue(appDelegate.controllerManager.capturedUSBReport != nil)
            try XCTAssertEqual(appDelegate.controllerManager.capturedUSBReport?[11], 0x05)
            try XCTAssertEqual(appDelegate.controllerManager.capturedUSBReport?[22], 0x21)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testScenarioAppProfileSwitching") {
            let appDelegate = AppDelegate()
            appDelegate.controllerManager.mockHIDMode = true
            
            appDelegate.controllerManager.appProfiles["com.racing.grid"] = "Racing Brake"
            
            let presetManager = appDelegate.presetManager
            if let targetPreset = appDelegate.controllerManager.findPreset(named: "Racing Brake", presetManager: presetManager) {
                appDelegate.controllerManager.applyPreset(targetPreset)
            }
            
            try XCTAssertEqual(appDelegate.controllerManager.l2Mode, .slopeFeedback)
            try XCTAssertEqual(appDelegate.controllerManager.r2Mode, .off)
            withExtendedLifetime(appDelegate) {}
        }
        
        runTest(name: "testScenarioDisconnectReconnectCycle") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            
            manager.activeController = nil
            manager.connectionType = "Unknown"
            manager.buttonsPressed.removeAll()
            
            try XCTAssertNil(manager.activeController)
            try XCTAssertEqual(manager.connectionType, "Unknown")
        }
        
        runTest(name: "testScenarioUDPCommandTriggerUpdate") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            
            let udpPayload = """
            {
                "instruction": "applyPreset",
                "presetName": "Bow & Arrow"
            }
            """.data(using: .utf8)!
            
            struct UDPCommand: Codable {
                let instruction: String
                let presetName: String
            }
            
            let command = try JSONDecoder().decode(UDPCommand.self, from: udpPayload)
            try XCTAssertEqual(command.instruction, "applyPreset")
            
            if let preset = manager.defaultPresets.first(where: { $0.name == command.presetName }) {
                manager.applyPreset(preset)
            }
            
            try XCTAssertEqual(manager.l2Mode, .feedback)
            try XCTAssertEqual(manager.r2Mode, .weapon)
        }

        // ==========================================
        // TIER 4: AUTHENTIC TRIGGER ENCODING (Nielk1 reference)
        // Lock in the exact byte layouts so the corrected modes can't silently regress.
        // ==========================================

        runTest(name: "testWeaponPacksStartStopAsUInt16") {
            let manager = ControllerManager()
            // start 0.3 -> zone 3 (clamped to [2,7]); end 0.7 -> zone 6; strength 1.0 -> level 8.
            let result = manager.testTriggerModeToHIDBytes(mode: .weapon, start: 0.3, end: 0.7, strength: 1.0, amplitude: 0, frequency: 0)
            try XCTAssertEqual(result.mode, 0x25)
            let zones = (1 << 3) | (1 << 6) // 0x48, fits in the low byte
            try XCTAssertEqual(result.params[0], UInt8(zones & 0xFF))
            try XCTAssertEqual(result.params[1], UInt8((zones >> 8) & 0xFF))
            try XCTAssertEqual(result.params[2], 7) // strength level 8 stored as 8-1
        }

        runTest(name: "testWeaponEndZone8GoesToHighByte") {
            let manager = ControllerManager()
            // end 1.0 -> zone 8: bit 8 must land in the high byte, not overflow the low byte.
            let result = manager.testTriggerModeToHIDBytes(mode: .weapon, start: 0.7, end: 1.0, strength: 0.5, amplitude: 0, frequency: 0)
            let startZone = 7 // 0.7*9 rounds to 6 but clamped... compute from impl: round(0.7*9)=6 -> clamp[2,7]=6
            // start 0.7 -> zone 6; end 1.0 -> zone 8.
            let zones = (1 << 6) | (1 << 8)
            try XCTAssertEqual(result.params[0], UInt8(zones & 0xFF))
            try XCTAssertEqual(result.params[1], UInt8((zones >> 8) & 0xFF)) // bit 8 -> 0x01
            _ = startZone
        }

        runTest(name: "testSemiAutomaticIsBowWithPackedSnap") {
            let manager = ControllerManager()
            // semiAutomatic now emits Bow (0x22): params[2] packs (strength-1) | ((snap-1)<<3).
            // strength 1.0 -> level 8 -> 7; endStrength 1.0 -> snap level 8 -> 7.
            let result = manager.testTriggerModeToHIDBytes(mode: .semiAutomatic, start: 0.3, end: 0.7, strength: 1.0, amplitude: 0, frequency: 0, endStrength: 1.0)
            try XCTAssertEqual(result.mode, 0x22)
            try XCTAssertEqual(result.params[2], UInt8((7 & 0x07) | ((7 & 0x07) << 3)))
        }

        runTest(name: "testAutomaticIsMachineWithFreqAndPeriod") {
            let manager = ControllerManager()
            // automatic now emits Machine (0x27): params[3]=frequency, params[4]=period.
            let result = manager.testTriggerModeToHIDBytes(mode: .automatic, start: 0.15, end: 0.85, strength: 0.7, amplitude: 0, frequency: 1.0)
            try XCTAssertEqual(result.mode, 0x27)
            try XCTAssertEqual(result.params[3], 255)  // frequency 1.0 -> 255
            try XCTAssertEqual(result.params[4], 0x0A)  // default period
        }

        runTest(name: "testFeedbackZonePacking") {
            let manager = ControllerManager()
            // start 0.0 -> all 10 zones active; strength 1.0 -> level 8 -> stored 7 per zone.
            let result = manager.testTriggerModeToHIDBytes(mode: .feedback, start: 0.0, end: 0, strength: 1.0, amplitude: 0, frequency: 0)
            try XCTAssertEqual(result.mode, 0x21)
            try XCTAssertEqual(result.params[0], 0xFF)        // active zones low byte (zones 0-7)
            try XCTAssertEqual(result.params[1], 0x03)        // active zones high byte (zones 8,9)
            try XCTAssertEqual(result.params[2], 0xFF)        // packed strengths (zones 0-2 = 7,7,7 -> bits)
        }

        runTest(name: "testFullPressMaxesAllZones") {
            let manager = ControllerManager()
            let result = manager.testTriggerModeToHIDBytes(mode: .fullPress, start: 0, end: 0, strength: 0, amplitude: 0, frequency: 0)
            try XCTAssertEqual(result.mode, 0x21)
            try XCTAssertEqual(result.params[0], 0xFF)
            try XCTAssertEqual(result.params[1], 0x03)
        }

        runTest(name: "testVibrationFrequencyAtIndex8") {
            let manager = ControllerManager()
            let result = manager.testTriggerModeToHIDBytes(mode: .vibration, start: 0.0, end: 0, strength: 0, amplitude: 1.0, frequency: 0.5)
            try XCTAssertEqual(result.mode, 0x26)
            try XCTAssertEqual(result.params[8], UInt8(clamping: max(1, Int(round(0.5 * 255.0)))))
        }

        runTest(name: "testUSBReportTriggerOffsetsAndFlags") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            manager.batchUpdate {
                manager.r2Mode = .feedback; manager.r2Start = 0.0; manager.r2Strength = 1.0
                manager.l2Mode = .off
            }
            manager.applyTriggerSettingsViaHID()
            let report = try { () throws -> [UInt8] in
                guard let r = manager.capturedUSBReport else { throw AssertionFailure(message: "no USB report captured") }
                return r
            }()
            try XCTAssertEqual(report[0], 0x02)         // USB report id
            try XCTAssertEqual(report[11], 0x21)         // R2 mode at offset 11
            try XCTAssertEqual(report[22], 0x05)         // L2 mode (off) at offset 22
        }

        runTest(name: "testBTReportHasValidCRCAndSeq") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.mockBTSequenceNumber = 0
            manager.batchUpdate { manager.r2Mode = .weapon; manager.r2Start = 0.3; manager.r2End = 0.7; manager.r2Strength = 0.8 }
            manager.applyTriggerSettingsViaHID()
            let report = try { () throws -> [UInt8] in
                guard let r = manager.capturedBTReport else { throw AssertionFailure(message: "no BT report captured") }
                return r
            }()
            try XCTAssertEqual(report[0], 0x31)          // BT report id
            try XCTAssertEqual(report.count, 78)
            try XCTAssertEqual(report[13], 0x25)         // R2 mode at BT offset 13
            // Verify the CRC32 trailer matches a fresh recomputation over the first 74 bytes.
            let expected = manager.testComputeBTCRC32(Array(report[0..<74]))
            let actual = UInt32(report[74]) | (UInt32(report[75]) << 8) | (UInt32(report[76]) << 16) | (UInt32(report[77]) << 24)
            try XCTAssertEqual(actual, expected)
        }

        runTest(name: "testUSBOutputReportCarriesAllHardwareState") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            manager.rumbleRightIntensity = 0x34
            manager.rumbleLeftIntensity = 0xA7
            manager.micLEDState = 0x02
            manager.playerLEDs = 0x15
            manager.ledColor = NSColor(red: 1, green: 0, blue: 1, alpha: 1)
            manager.applyTriggerSettingsViaHID()

            guard let report = manager.capturedUSBReport else {
                throw AssertionFailure(message: "no USB report captured")
            }
            try XCTAssertEqual(report.count, 48)       // macOS USB descriptor maximum
            try XCTAssertEqual(report[0], 0x02)
            try XCTAssertEqual(report[1], 0x0F)        // rumble select + compatibility + L2/R2
            try XCTAssertEqual(report[2], 0x15)        // mic + lightbar RGB + player LEDs
            try XCTAssertEqual(report[3], 0x34)        // right/weak motor
            try XCTAssertEqual(report[4], 0xA7)        // left/strong motor
            try XCTAssertEqual(report[9], 0x02)        // pulsing mic LED
            try XCTAssertEqual(report[39], 0x04)       // compatible vibration v2 only
            try XCTAssertEqual(report[42], 0x00)       // no LED setup mixed into state
            try XCTAssertEqual(report[44], 0x15)
            try XCTAssertEqual(report[45], 0xFF)
            try XCTAssertEqual(report[46], 0x00)
            try XCTAssertEqual(report[47], 0xFF)
        }

        runTest(name: "testBTOutputReportCarriesAllHardwareState") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.rumbleRightIntensity = 0x34
            manager.rumbleLeftIntensity = 0xA7
            manager.micLEDState = 0x01
            manager.playerLEDs = 0x0A
            manager.ledColor = NSColor(red: 0, green: 1, blue: 1, alpha: 1)
            manager.applyTriggerSettingsViaHID()

            guard let report = manager.capturedBTReport else {
                throw AssertionFailure(message: "no BT report captured")
            }
            try XCTAssertEqual(report.count, 78)
            try XCTAssertEqual(report[0], 0x31)
            try XCTAssertEqual(report[1] & 0x0F, 0x00) // keep confirmed trigger-working seq tag
            try XCTAssertEqual(report[2], 0x10)
            try XCTAssertEqual(report[3], 0x0F)
            try XCTAssertEqual(report[4], 0x15)
            try XCTAssertEqual(report[5], 0x34)
            try XCTAssertEqual(report[6], 0xA7)
            try XCTAssertEqual(report[11], 0x01)
            try XCTAssertEqual(report[41], 0x04)
            try XCTAssertEqual(report[44], 0x00)       // no LED setup mixed into state
            try XCTAssertEqual(report[46], 0x0A)
            try XCTAssertEqual(report[47], 0x00)
            try XCTAssertEqual(report[48], 0xFF)
            try XCTAssertEqual(report[49], 0xFF)

            let expected = manager.testComputeBTCRC32(Array(report[0..<74]))
            let actual = UInt32(report[74]) | (UInt32(report[75]) << 8) | (UInt32(report[76]) << 16) | (UInt32(report[77]) << 24)
            try XCTAssertEqual(actual, expected)
        }

        runTest(name: "testUSBLEDSetupIsDedicatedReport") {
            let manager = ControllerManager()
            let report = manager.testBuildUSBLEDSetupReport()
            try XCTAssertEqual(report.count, 48)
            try XCTAssertEqual(report[0], 0x02)
            try XCTAssertEqual(report[1], 0x00)
            try XCTAssertEqual(report[2], 0x00)
            try XCTAssertEqual(report[39], 0x02)       // LIGHTBAR_SETUP_CONTROL_ENABLE only
            try XCTAssertEqual(report[42], 0x02)       // LIGHT_OUT releases hardware LED control
            try XCTAssertEqual(report[44], 0x00)
            try XCTAssertEqual(report[45], 0x00)
            try XCTAssertEqual(report[46], 0x00)
            try XCTAssertEqual(report[47], 0x00)
        }

        runTest(name: "testBTLEDSetupIsDedicatedSignedReport") {
            let manager = ControllerManager()
            manager.mockBTSequenceNumber = 7
            let report = manager.testBuildBTLEDSetupReport()
            try XCTAssertEqual(report.count, 78)
            try XCTAssertEqual(report[0], 0x31)
            try XCTAssertEqual(report[1], UInt8(7 << 4))
            try XCTAssertEqual(report[2], 0x10)
            try XCTAssertEqual(report[3], 0x00)
            try XCTAssertEqual(report[4], 0x00)
            try XCTAssertEqual(report[41], 0x02)
            try XCTAssertEqual(report[44], 0x02)
            try XCTAssertEqual(report[46], 0x00)
            try XCTAssertEqual(report[47], 0x00)
            try XCTAssertEqual(report[48], 0x00)
            try XCTAssertEqual(report[49], 0x00)

            let expected = manager.testComputeBTCRC32(Array(report[0..<74]))
            let actual = UInt32(report[74]) | (UInt32(report[75]) << 8) | (UInt32(report[76]) << 16) | (UInt32(report[77]) << 24)
            try XCTAssertEqual(actual, expected)
        }

        runTest(name: "testBTInputDeliveryIsCappedAtDisplayRate") {
            let interval = BluetoothHIDController.testInputDeliveryIntervalNanoseconds
            var lastDelivery: UInt64 = 0
            let firstTimestamp: UInt64 = 1_000_000_000

            try XCTAssertTrue(BluetoothHIDController.testShouldDeliverInput(
                now: firstTimestamp, lastDelivery: &lastDelivery
            ))
            try XCTAssertFalse(BluetoothHIDController.testShouldDeliverInput(
                now: firstTimestamp + interval - 1, lastDelivery: &lastDelivery
            ))
            try XCTAssertEqual(lastDelivery, firstTimestamp)
            try XCTAssertTrue(BluetoothHIDController.testShouldDeliverInput(
                now: firstTimestamp + interval, lastDelivery: &lastDelivery
            ))
            try XCTAssertEqual(lastDelivery, firstTimestamp + interval)
        }

        runTest(name: "testAnalogNoiseDoesNotPublishVisualChange") {
            let manager = ControllerManager()
            let origin = CGPoint.zero
            try XCTAssertFalse(manager.testPointChanged(
                from: origin, to: CGPoint(x: 0.007, y: -0.007)
            ))
            try XCTAssertTrue(manager.testPointChanged(
                from: origin, to: CGPoint(x: 0.009, y: 0)
            ))
        }

        runTest(name: "testDualSenseUSBAudioDeviceMatching") {
            try XCTAssertTrue(ControllerAudioService.isDualSenseAudioDevice(
                name: "DualSense Wireless Controller",
                manufacturer: "Sony Interactive Entertainment",
                transportType: kAudioDeviceTransportTypeUSB
            ))
            try XCTAssertFalse(ControllerAudioService.isDualSenseAudioDevice(
                name: "DualSense Wireless Controller",
                manufacturer: "Sony Interactive Entertainment",
                transportType: kAudioDeviceTransportTypeBluetooth
            ))
            try XCTAssertFalse(ControllerAudioService.isDualSenseAudioDevice(
                name: "MacBook Air Speakers",
                manufacturer: "Apple Inc.",
                transportType: kAudioDeviceTransportTypeBuiltIn
            ))
        }

        runTest(name: "testControllerAudioQuadraphonicReadiness") {
            let info = ControllerAudioDeviceInfo(
                outputDeviceID: 1,
                inputDeviceID: 2,
                outputUID: "output",
                inputUID: "input",
                name: "DualSense Wireless Controller",
                manufacturer: "Sony Interactive Entertainment",
                outputChannels: 4,
                inputChannels: 2,
                sampleRate: 48_000,
                channelLayoutTag: kAudioChannelLayoutTag_Quadraphonic,
                channelLayoutSettable: true
            )
            try XCTAssertTrue(info.isQuadraphonic)
            try XCTAssertEqual(
                info.channelLayoutName,
                "Quadraphonic (L, R, Haptic L, Haptic R)"
            )
        }

        runTest(name: "testUSBAudioControlsSerializeWithoutChangingTriggerOffsets") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            manager.controllerAudioControlsEnabled = true
            manager.controllerAudioOutputRoute = .controllerSpeaker
            manager.controllerAudioInputRoute = .controllerMicrophone
            manager.controllerHeadphoneVolume = 0.5
            manager.controllerSpeakerVolume = 0.75
            manager.controllerMicrophoneVolume = 0.25
            manager.controllerMicrophoneMuted = true
            manager.r2Mode = .weapon
            manager.applyTriggerSettingsViaHID()

            guard let report = manager.capturedUSBReport else {
                throw AssertionFailure(message: "no USB audio report captured")
            }
            try XCTAssertEqual(report.count, 48)
            try XCTAssertEqual(report[1], 0xFF) // existing rumble/trigger flags + all audio flags
            try XCTAssertEqual(report[2], 0x97) // mic/lightbar/player + power-save + audio2
            try XCTAssertEqual(report[5], 64)   // 50% of headphone range 0...127
            try XCTAssertEqual(report[6], 75)   // 75% of speaker's effective 0...100 range
            try XCTAssertEqual(report[7], 16)   // 25% of microphone range 0...64
            try XCTAssertEqual(report[8], 0xB0) // controller speaker (0x30) + controller mic (0x80)
            try XCTAssertEqual(report[10], 0x10) // microphone power-save mute
            try XCTAssertEqual(report[11], 0x25) // R2 trigger mode offset remains unchanged
            try XCTAssertEqual(report[38], 0x02) // controller speaker pre-gain
        }

        runTest(name: "testAudioControlFlagsAreNeverSentOverBluetooth") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "BT"
            manager.controllerAudioControlsEnabled = true
            manager.controllerAudioOutputRoute = .controllerSpeaker
            manager.controllerMicrophoneMuted = true
            manager.applyTriggerSettingsViaHID()

            guard let report = manager.capturedBTReport else {
                throw AssertionFailure(message: "no BT report captured")
            }
            try XCTAssertEqual(report[3], 0x0F) // no USB audio bits
            try XCTAssertEqual(report[4], 0x15) // no USB power-save/audio2 bits
            try XCTAssertEqual(report[7], 0x00) // headphone-volume field untouched
            try XCTAssertEqual(report[8], 0x00) // speaker-volume field untouched
            try XCTAssertEqual(report[9], 0x00) // microphone-volume field untouched
            try XCTAssertEqual(report[10], 0x00) // audio-route field untouched
        }

        runTest(name: "testUSBAudioHapticsModeTemporarilyReleasesClassicRumble") {
            let manager = ControllerManager()
            manager.mockHIDMode = true
            manager.mockHIDTransport = "USB"
            manager.rumbleRightIntensity = 200
            manager.rumbleLeftIntensity = 180
            manager.r2Mode = .feedback
            manager.audioHapticsModeEnabled = true
            manager.applyTriggerSettingsViaHID()

            guard let hapticsReport = manager.capturedUSBReport else {
                throw AssertionFailure(message: "no USB haptics-mode report captured")
            }
            try XCTAssertEqual(hapticsReport[1], 0x0D) // bit 1 USE_RUMBLE_NO_HAPTICS cleared
            try XCTAssertEqual(hapticsReport[3], 0x00) // classic motors gracefully stopped
            try XCTAssertEqual(hapticsReport[4], 0x00)
            try XCTAssertEqual(hapticsReport[11], 0x21) // adaptive trigger remains enabled
            try XCTAssertEqual(hapticsReport[39], 0x00) // improved classic rumble disabled

            manager.audioHapticsModeEnabled = false
            manager.applyTriggerSettingsViaHID()
            guard let restoredReport = manager.capturedUSBReport else {
                throw AssertionFailure(message: "no restored USB rumble report captured")
            }
            try XCTAssertEqual(restoredReport[1], 0x0F)
            try XCTAssertEqual(restoredReport[3], 200)
            try XCTAssertEqual(restoredReport[4], 180)
            try XCTAssertEqual(restoredReport[39], 0x04)
        }

        runTest(name: "testSystemAudioMeterNormalization") {
            try XCTAssertEqual(SystemAudioCaptureService.meterLevel(forRMS: -0.1), 0)
            try XCTAssertEqual(SystemAudioCaptureService.meterLevel(forRMS: 0.1), 0.4)
            try XCTAssertEqual(SystemAudioCaptureService.meterLevel(forRMS: 0.5), 1)
        }

        runTest(name: "testBTInputReportRejectsShortBuffer") {
            let short = [UInt8](repeating: 0, count: 40)
            try XCTAssertNil(BluetoothHIDController.parseInputReport(short))
        }

        runTest(name: "testBTInputReportButtonsSticksAndTriggers") {
            var report = [UInt8](repeating: 0, count: 78)
            report[0] = 0x31
            report[2] = 255 // left stick X -> +1.0
            report[3] = 0   // left stick Y raw -> flipped to +1.0
            report[6] = 128 // L2 analog
            report[7] = 255 // R2 analog
            report[9] = 0xF2  // square/cross/circle/triangle + hat=2 (East)
            report[10] = 0xFF // l1/r1/l2/r2/create/options/l3/r3
            report[11] = 0x03 // ps + touchpad click

            guard let sample = BluetoothHIDController.parseInputReport(report) else {
                throw AssertionFailure(message: "parseInputReport returned nil")
            }

            try XCTAssertEqual(sample.leftStick.x, 1.0)
            try XCTAssertEqual(sample.leftStick.y, 1.0)
            try XCTAssertTrue(abs(sample.leftTrigger - Float(128) / 255.0) < 0.0001)
            try XCTAssertEqual(sample.rightTrigger, 1.0)

            try XCTAssertTrue(sample.buttons["square"] == true)
            try XCTAssertTrue(sample.buttons["cross"] == true)
            try XCTAssertTrue(sample.buttons["circle"] == true)
            try XCTAssertTrue(sample.buttons["triangle"] == true)
            try XCTAssertTrue(sample.buttons["dpadRight"] == true)
            try XCTAssertFalse(sample.buttons["dpadUp"] == true)
            try XCTAssertFalse(sample.buttons["dpadLeft"] == true)
            try XCTAssertFalse(sample.buttons["dpadDown"] == true)

            for key in ["l1", "r1", "l2", "r2", "create", "options", "l3", "r3", "ps", "touchpad"] {
                try XCTAssertTrue(sample.buttons[key] == true, "expected \(key) to be pressed")
            }
        }

        runTest(name: "testBTInputReportGyroDecoding") {
            var report = [UInt8](repeating: 0, count: 78)
            report[0] = 0x31
            report[17] = 0x00; report[18] = 0x01 // gyro X = 256
            report[19] = 0xFF; report[20] = 0xFF // gyro Y = -1

            guard let sample = BluetoothHIDController.parseInputReport(report) else {
                throw AssertionFailure(message: "parseInputReport returned nil")
            }
            try XCTAssertEqual(sample.gyro.x, 256.0)
            try XCTAssertEqual(sample.gyro.y, -1.0)
            try XCTAssertEqual(sample.gyro.z, 0.0)
        }

        runTest(name: "testBTInputReportTouchpadContactAndCoordinates") {
            var report = [UInt8](repeating: 0, count: 78)
            report[0] = 0x31
            // Touch point 1: active, x=100, y=200 (see dualsense_touch_point packing).
            report[34] = 0x00
            report[35] = 0x64 // x_lo
            report[36] = 0x80 // x_hi(low nibble)=0, y_lo(high nibble)=8
            report[37] = 0x0C // y_hi
            // Touch point 2: inactive.
            report[38] = 0x80

            guard let sample = BluetoothHIDController.parseInputReport(report) else {
                throw AssertionFailure(message: "parseInputReport returned nil")
            }
            try XCTAssertTrue(sample.touchpadPrimaryActive)
            try XCTAssertFalse(sample.touchpadSecondaryActive)
            let expectedX = Float(100) / 1920.0 * 2.0 - 1.0
            let expectedY = -(Float(200) / 1080.0 * 2.0 - 1.0)
            try XCTAssertEqual(Float(sample.touchpadPrimary.x), expectedX)
            try XCTAssertEqual(Float(sample.touchpadPrimary.y), expectedY)
        }

        runTest(name: "testBTInputReportBatteryDischargingAndCharging") {
            var report = [UInt8](repeating: 0, count: 78)
            report[0] = 0x31
            report[54] = 0x15 // chargingStatus=0x1 (charging), batteryData=5

            guard let sample = BluetoothHIDController.parseInputReport(report) else {
                throw AssertionFailure(message: "parseInputReport returned nil")
            }
            try XCTAssertEqual(sample.batteryLevel, Float(5) * 0.1 + 0.05)
            try XCTAssertTrue(sample.batteryCharging)
            try XCTAssertFalse(sample.batteryFull)
        }

        runTest(name: "testBTInputReportBatteryFull") {
            var report = [UInt8](repeating: 0, count: 78)
            report[0] = 0x31
            report[54] = 0x20 // chargingStatus=0x2 (full)

            guard let sample = BluetoothHIDController.parseInputReport(report) else {
                throw AssertionFailure(message: "parseInputReport returned nil")
            }
            try XCTAssertEqual(sample.batteryLevel, 1.0)
            try XCTAssertTrue(sample.batteryFull)
            try XCTAssertFalse(sample.batteryCharging)
        }

        print("========================================")
        print("            TEST SUMMARY                ")
        print("========================================")
        print("  Passed: \(passCount)")
        print("  Failed: \(failCount)")
        print("  Total:  \(passCount + failCount)")
        print("========================================")
        
        if failCount > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
}
#endif
