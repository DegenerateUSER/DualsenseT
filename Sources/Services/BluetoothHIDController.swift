import Foundation
import CoreGraphics

/// Owns the DualSense's Bluetooth HID connection end-to-end via a vendored `hidapi`
/// (Sources/CHidapi), bypassing GameController framework entirely for BT.
///
/// hidapi's macOS backend seizes the device exclusively by default
/// (`hid_darwin_set_open_exclusive`, called internally by `hid_init()`) — this is what
/// actually lets output reports reach the hardware over BT: without exclusive access,
/// `IOHIDDeviceSetReport` is documented to silently no-op or intermittently fail when
/// another client (macOS's own GameController HID client) has a competing open on the
/// same device. Because we now hold the device exclusively, GameController can no
/// longer reliably deliver input for it either, so this class also reads and parses
/// raw 0x31 input reports itself.
public final class BluetoothHIDController {
    /// The controller can emit input reports at roughly 250 Hz. Rendering every packet
    /// overloads the main thread and SwiftUI without making a 60 Hz display look smoother.
    /// We still drain hidapi at full speed, but decode/deliver at most once per display frame.
    private static let inputDeliveryIntervalNanoseconds: UInt64 = 16_666_667

    private static func shouldDeliverInput(now: UInt64, lastDelivery: inout UInt64) -> Bool {
        guard lastDelivery == 0
                || now &- lastDelivery >= inputDeliveryIntervalNanoseconds else {
            return false
        }
        lastDelivery = now
        return true
    }

    #if TESTING
    public static var testInputDeliveryIntervalNanoseconds: UInt64 {
        inputDeliveryIntervalNanoseconds
    }

    public static func testShouldDeliverInput(now: UInt64, lastDelivery: inout UInt64) -> Bool {
        shouldDeliverInput(now: now, lastDelivery: &lastDelivery)
    }
    #endif

    public struct InputSample {
        public var buttons: [String: Bool]
        public var leftStick: CGPoint
        public var rightStick: CGPoint
        public var leftTrigger: Float
        public var rightTrigger: Float
        public var touchpadPrimary: CGPoint
        public var touchpadPrimaryActive: Bool
        public var touchpadSecondary: CGPoint
        public var touchpadSecondaryActive: Bool
        public var gyro: (x: Double, y: Double, z: Double)
        public var accel: (x: Double, y: Double, z: Double)
        public var batteryLevel: Float
        public var batteryCharging: Bool
        public var batteryFull: Bool
    }

    public static let vendorID: UInt16 = 0x054C
    public static let productIDs: [UInt16] = [0x0CE6, 0x0DF2]

    /// Called on the main queue whenever a new input report is parsed.
    public var onInput: ((InputSample) -> Void)?
    /// Called on the main queue if the read loop gives up on the connection.
    public var onDisconnect: (() -> Void)?

    /// Lock-guarded: written on the main thread (connect/disconnect) and the read
    /// thread (readLoop exit), read from the main thread and `backgroundQueue`.
    public private(set) var isConnected: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isConnected }
        set { stateLock.lock(); _isConnected = newValue; stateLock.unlock() }
    }

    private var device: OpaquePointer?
    private var readThread: Thread?
    private let deviceLock = NSLock()
    private let stateLock = NSLock()
    private var _isConnected = false
    private var _shouldStopReading = false

    /// Lock-guarded: written by `disconnect()` on any thread, read by the read thread.
    private var shouldStopReading: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _shouldStopReading }
        set { stateLock.lock(); _shouldStopReading = newValue; stateLock.unlock() }
    }

    public init() {}

    deinit {
        // The read thread strongly holds self for the duration of readLoop(), so by
        // the time deinit runs no read thread can be inside hid_read_timeout.
        if let dev = device {
            hid_close(dev)
            device = nil
        }
    }

    /// Decodes hidapi's `const wchar_t*` global/device error string into a Swift String.
    private static func lastError(device: OpaquePointer? = nil) -> String {
        guard let errPtr = hid_error(device) else { return "unknown error" }
        var scalars: [Unicode.Scalar] = []
        var i = 0
        while errPtr[i] != 0 {
            if let scalar = Unicode.Scalar(UInt32(bitPattern: errPtr[i])) {
                scalars.append(scalar)
            }
            i += 1
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Enumerates connected HID devices and returns the hidapi path of a
    /// Bluetooth-transport DualSense/DualSense Edge, if any is currently paired/awake.
    public static func findBluetoothPath() -> String? {
        guard let head = hid_enumerate(vendorID, 0) else { return nil }
        defer { hid_free_enumeration(head) }

        var cursor: UnsafeMutablePointer<hid_device_info>? = head
        while let node = cursor {
            let info = node.pointee
            if productIDs.contains(info.product_id), info.bus_type == HID_API_BUS_BLUETOOTH, let path = info.path {
                return String(cString: path)
            }
            cursor = info.next
        }
        return nil
    }

    /// Opens the device exclusively and starts the background read loop. Safe to call
    /// only when not already connected.
    @discardableResult
    public func connect(path: String) -> Bool {
        hid_darwin_set_open_exclusive(1)
        guard let dev = hid_open_path(path) else {
            logToFile("BluetoothHIDController: hid_open_path failed: \(Self.lastError())")
            return false
        }

        deviceLock.lock()
        // Safety net: the read loop closes the handle when it exits, so this should
        // always be nil here — but never overwrite a live handle without closing it.
        if let stale = device {
            hid_close(stale)
        }
        device = dev
        deviceLock.unlock()

        isConnected = true
        hasLoggedFirstWrite = false
        shouldStopReading = false
        let thread = Thread { [weak self] in self?.readLoop() }
        thread.name = "com.tushar.DualSenseT.btHIDRead"
        thread.start()
        readThread = thread

        logToFile("BluetoothHIDController: connected exclusively via hidapi at \(path)")
        return true
    }

    public func disconnect() {
        shouldStopReading = true
        // The read thread closes the device handle itself when it exits (it may be
        // blocked inside hid_read_timeout for up to 100ms). Wait for it rather than
        // closing the handle out from under it — hidapi forbids any other thread
        // using the device while hid_close runs.
        if let thread = readThread, thread.isExecuting {
            let deadline = Date().addingTimeInterval(1.0)
            while !thread.isFinished && Date() < deadline {
                usleep(5_000)
            }
        }
        deviceLock.lock()
        if let dev = device {
            hid_close(dev)
            device = nil
        }
        deviceLock.unlock()
        isConnected = false
        readThread = nil
    }

    private var hasLoggedFirstWrite = false

    /// Writes a pre-built output report (see `ControllerManager.buildBTOutputReport`).
    /// Retries a few times with a short backoff — the same shape as the existing USB
    /// IOKit write path — since Bluetooth writes occasionally fail transiently.
    @discardableResult
    public func write(_ report: [UInt8]) -> Bool {
        deviceLock.lock()
        let dev = device
        deviceLock.unlock()
        guard let dev = dev else { return false }

        var buffer = report
        let count = buffer.count
        let maxAttempts = 4
        for attempt in 1...maxAttempts {
            let result: Int32 = buffer.withUnsafeMutableBufferPointer { ptr in
                hid_write(dev, ptr.baseAddress, count)
            }
            if result >= 0 {
                if !hasLoggedFirstWrite {
                    hasLoggedFirstWrite = true
                    logToFile("BluetoothHIDController: first output report accepted by hid_write (\(result) bytes).")
                }
                return true
            }
            if attempt < maxAttempts { usleep(useconds_t(attempt * 2000)) }
        }
        logToFile("BluetoothHIDController: hid_write failed after \(maxAttempts) attempts: \(Self.lastError(device: dev))")
        return false
    }

    private func readLoop() {
        let reportSize = 78
        var buf = [UInt8](repeating: 0, count: reportSize)
        var consecutiveFailures = 0
        var lastInputDeliveryTime: UInt64 = 0

        while !shouldStopReading {
            deviceLock.lock()
            let dev = device
            deviceLock.unlock()
            guard let dev = dev else { break }

            let n: Int32 = buf.withUnsafeMutableBufferPointer { ptr in
                hid_read_timeout(dev, ptr.baseAddress, reportSize, 100)
            }
            if shouldStopReading { break }

            if n < 0 {
                consecutiveFailures += 1
                logToFile("BluetoothHIDController: hid_read_timeout failed (\(consecutiveFailures) consecutive): \(Self.lastError(device: dev))")
                if consecutiveFailures >= 5 { break }
                usleep(50_000)
                continue
            }
            consecutiveFailures = 0
            if n == 0 { continue } // timed out, no report available

            let now = DispatchTime.now().uptimeNanoseconds
            if Int(n) == reportSize, buf[0] == 0x31,
               Self.shouldDeliverInput(now: now, lastDelivery: &lastInputDeliveryTime),
               let sample = Self.parseInputReport(buf) {
                let handler = onInput
                DispatchQueue.main.async { handler?(sample) }
            }
        }

        // Close the handle here, on the read thread, once the loop has stopped
        // touching it — this both satisfies hidapi's "no other thread may use the
        // device during hid_close" rule and prevents leaking the handle across
        // reconnect cycles.
        deviceLock.lock()
        if let dev = device {
            hid_close(dev)
            device = nil
        }
        deviceLock.unlock()

        isConnected = false
        let handler = onDisconnect
        DispatchQueue.main.async { handler?() }
        logToFile("BluetoothHIDController: read loop exited, disconnected.")
    }

    // MARK: - Input report parsing (0x31, 78 bytes)
    //
    // Offsets verified against the Linux `hid-playstation.c` driver's
    // `dualsense_input_report` struct, applied at the kernel's documented "+2 for BT"
    // base (byte 0 = report ID 0x31, byte 1 = seq number, byte 2 = payload start).

    static func parseInputReport(_ report: [UInt8]) -> InputSample? {
        guard report.count >= 62 else { return nil }

        func axis(_ raw: UInt8) -> Float {
            return (Float(raw) - 127.5) / 127.5
        }
        let leftStick = CGPoint(x: CGFloat(axis(report[2])), y: CGFloat(-axis(report[3])))
        let rightStick = CGPoint(x: CGFloat(axis(report[4])), y: CGFloat(-axis(report[5])))
        let leftTrigger = Float(report[6]) / 255.0
        let rightTrigger = Float(report[7]) / 255.0

        let b0 = report[9]
        let b1 = report[10]
        let b2 = report[11]
        var buttons: [String: Bool] = [:]
        buttons["square"] = (b0 & 0x10) != 0
        buttons["cross"] = (b0 & 0x20) != 0
        buttons["circle"] = (b0 & 0x40) != 0
        buttons["triangle"] = (b0 & 0x80) != 0
        let hat = b0 & 0x0F
        buttons["dpadUp"] = hat == 0 || hat == 1 || hat == 7
        buttons["dpadRight"] = hat == 1 || hat == 2 || hat == 3
        buttons["dpadDown"] = hat == 3 || hat == 4 || hat == 5
        buttons["dpadLeft"] = hat == 5 || hat == 6 || hat == 7
        buttons["l1"] = (b1 & 0x01) != 0
        buttons["r1"] = (b1 & 0x02) != 0
        buttons["l2"] = (b1 & 0x04) != 0
        buttons["r2"] = (b1 & 0x08) != 0
        buttons["create"] = (b1 & 0x10) != 0
        buttons["options"] = (b1 & 0x20) != 0
        buttons["l3"] = (b1 & 0x40) != 0
        buttons["r3"] = (b1 & 0x80) != 0
        buttons["ps"] = (b2 & 0x01) != 0
        buttons["touchpad"] = (b2 & 0x02) != 0
        buttons["mute"] = (b2 & 0x04) != 0

        func int16LE(_ lo: UInt8, _ hi: UInt8) -> Double {
            return Double(Int16(bitPattern: UInt16(lo) | (UInt16(hi) << 8)))
        }
        let gyro = (x: int16LE(report[17], report[18]),
                    y: int16LE(report[19], report[20]),
                    z: int16LE(report[21], report[22]))
        let accel = (x: int16LE(report[23], report[24]),
                     y: int16LE(report[25], report[26]),
                     z: int16LE(report[27], report[28]))

        // Touch point: byte0 bit7 clear = active (contact down); 12-bit X/Y split
        // across the remaining 3 bytes. DualSense touchpad resolution ~1920x1080.
        func touch(_ base: Int) -> (active: Bool, point: CGPoint) {
            let c0 = report[base]
            let active = (c0 & 0x80) == 0
            let xLo = report[base + 1]
            let mid = report[base + 2]
            let yHi = report[base + 3]
            let x = Int(xLo) | (Int(mid & 0x0F) << 8)
            let y = (Int(yHi) << 4) | Int((mid & 0xF0) >> 4)
            let normX = Float(x) / 1920.0 * 2.0 - 1.0
            let normY = -(Float(y) / 1080.0 * 2.0 - 1.0)
            return (active, CGPoint(x: CGFloat(normX), y: CGFloat(normY)))
        }
        let touch1 = touch(34)
        let touch2 = touch(38)

        let status0 = report[54]
        let batteryData = status0 & 0x0F
        let chargingStatus = (status0 >> 4) & 0x0F
        let batteryLevel = min(1.0, Float(batteryData) * 0.1 + 0.05)
        let charging = chargingStatus == 0x1
        let full = chargingStatus == 0x2

        return InputSample(
            buttons: buttons,
            leftStick: leftStick,
            rightStick: rightStick,
            leftTrigger: leftTrigger,
            rightTrigger: rightTrigger,
            touchpadPrimary: touch1.point,
            touchpadPrimaryActive: touch1.active,
            touchpadSecondary: touch2.point,
            touchpadSecondaryActive: touch2.active,
            gyro: gyro,
            accel: accel,
            batteryLevel: full ? 1.0 : batteryLevel,
            batteryCharging: charging,
            batteryFull: full
        )
    }
}
