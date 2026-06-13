#if TESTING
import Foundation
import GameController

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
            print("  🟢 Passed: \(name)")
            passCount += 1
        } catch let error as AssertionFailure {
            print("  🔴 Failed: \(name) - \(error.message)")
            failCount += 1
        } catch {
            print("  🔴 Failed: \(name) - Unexpected error: \(error)")
            failCount += 1
        }
    }
    
    func run() {
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
