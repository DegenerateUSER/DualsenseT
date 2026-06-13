import Foundation
import GameController
import AppKit
import IOKit
import IOKit.hid

public class ControllerManager: ObservableObject {
    @Published public var controllers: [GCController] = []
    @Published public var activeController: GCController? = nil
    
    @Published public var connectionType: String = "Unknown" // "USB", "BT", "Unknown"
    @Published public var batteryLevel: Float = 0.0
    @Published public var batteryState: GCDeviceBattery.State = .unknown
    
    // Trigger Settings
    @Published public var l2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Start: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2End: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Strength: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Amplitude: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Frequency: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    
    @Published public var r2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Start: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2End: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Strength: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Amplitude: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Frequency: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    
    // Live Input States
    @Published public var buttonsPressed: [String: Bool] = [:]
    @Published public var leftStickValue: CGPoint = .zero
    @Published public var rightStickValue: CGPoint = .zero
    @Published public var touchpadPrimary: CGPoint = .zero
    @Published public var touchpadSecondary: CGPoint = .zero
    @Published public var touchpadPrimaryActive: Bool = false
    @Published public var touchpadSecondaryActive: Bool = false
    @Published public var leftTriggerValue: Float = 0.0
    @Published public var rightTriggerValue: Float = 0.0
    
    // Gyro/Motion
    @Published public var motionAttitude: GCQuaternion = GCQuaternion(x: 0, y: 0, z: 0, w: 1)
    
    // LED State - PlayStation Blue (RGB) by default to prevent system color conversion issues
    @Published public var ledColor: NSColor = NSColor(red: 0.0, green: 0.44, blue: 0.82, alpha: 1.0) { didSet { updateLed() } }
    @Published public var isLedPulsing: Bool = false { didSet { updateLed() } }
    
    // Touchpad Gesture Remapping State
    @Published public var touchpadActions: [String: String] = [
        "Up": "None",
        "Down": "None",
        "Left": "None",
        "Right": "None"
    ] {
        didSet {
            saveTouchpadActions()
        }
    }
    
    // Per-App Profile State
    @Published public var appProfiles: [String: String] = [:]
    
    @Published public var isUIVisible: Bool = false { didSet { updateMotionSensorsState() } }
    @Published public var isSensorsTabActive: Bool = false { didSet { updateMotionSensorsState() } }
    
    private var pollingTimer: Timer?
    private var pulsingTimer: Timer?
    private var touchpadPrimaryTimeout: Timer?
    private var touchpadSecondaryTimeout: Timer?
    private var motionUpdateCount = 0
    private var filteredPitch: Double = 0.0
    private var filteredRoll: Double = 0.0
    private var filteredYaw: Double = 0.0
    private var lastMotionTimestamp: TimeInterval = 0.0
    private var rawMotionAttitude: GCQuaternion = GCQuaternion(x: 0, y: 0, z: 0, w: 1)
    private var sensorReferenceOrientation: GCQuaternion = GCQuaternion(x: 0, y: 0, z: 0, w: 1)
    
    // Raw HID output state for background trigger persistence
    private var hidManager: IOHIDManager?
    private var hidOutputDevice: IOHIDDevice?
    private var btSequenceNumber: UInt8 = 0
    private var lastHIDErrorLogged: Bool = false
    public var isAppInForeground: Bool = true
    
    // CRC32 lookup table for Bluetooth output reports
    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
    
    // Touchpad Gesture Tracking Variables (internal for testing)
    public var touchStart: CGPoint?
    public var hasSwiped = false
    
    public let defaultPresets: [TriggerPreset] = [
        TriggerPreset(name: "Bow & Arrow", l2Mode: .feedback, l2Start: 0.1, l2End: 0.8, l2Strength: 0.4, l2Amplitude: 0, l2Frequency: 0, r2Mode: .weapon, r2Start: 0.2, r2End: 0.6, r2Strength: 0.8, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.0, ledGreen: 0.5, ledBlue: 1.0, isLedPulsing: false),
        TriggerPreset(name: "Heavy Rifle", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .weapon, r2Start: 0.1, r2End: 0.4, r2Strength: 0.9, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.1, ledBlue: 0.1, isLedPulsing: true),
        TriggerPreset(name: "Racing Brake", l2Mode: .feedback, l2Start: 0.0, l2End: 0, l2Strength: 0.8, l2Amplitude: 0, l2Frequency: 0, r2Mode: .off, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.5, ledBlue: 0.0, isLedPulsing: false),
        TriggerPreset(name: "Soft Click", l2Mode: .feedback, l2Start: 0.2, l2End: 0, l2Strength: 0.3, l2Amplitude: 0, l2Frequency: 0, r2Mode: .feedback, r2Start: 0.2, r2End: 0, r2Strength: 0.3, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.5, ledGreen: 0.0, ledBlue: 0.5, isLedPulsing: false),
        TriggerPreset(name: "Off", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .off, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.0, ledGreen: 0.44, ledBlue: 0.82, isLedPulsing: false)
    ]
    
    public init() {
        GCController.shouldMonitorBackgroundEvents = true
        setupControllerDiscovery()
        startPolling()
        loadTouchpadActions()
        loadAppProfiles()
    }
    
    public func setupControllerDiscovery() {
        if let firstController = GCController.controllers().first {
            controllerConnected(firstController)
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let controller = notification.object as? GCController else { return }
            if self.activeController == nil {
                self.controllerConnected(controller)
            }
            self.controllers = GCController.controllers()
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let controller = notification.object as? GCController else { return }
            if self.activeController == controller {
                self.activeController = nil
                self.connectionType = "Unknown"
                self.buttonsPressed.removeAll()
                self.clearHIDDevice()
                if let nextController = GCController.controllers().first(where: { $0 != controller }) {
                    self.controllerConnected(nextController)
                }
            }
            self.controllers = GCController.controllers()
            NotificationCenter.default.post(name: NSNotification.Name("DualSenseTStatusChanged"), object: nil)
        }
    }
    
    public func controllerConnected(_ controller: GCController) {
        logToFile("Controller connected: \(controller.vendorName ?? "Unknown") [Category: \(controller.productCategory)]")
        self.activeController = controller
        setupHandlers(for: controller)
        
        if controller.light == nil {
            logToFile("WARNING: controller.light is nil! App needs to run as signed macOS App Bundle (.app).")
        }
        
        // Auto-reconnect: Apply settings
        applyTriggerSettings()
        updateLed()
        
        NotificationCenter.default.post(name: NSNotification.Name("DualSenseTStatusChanged"), object: nil)
    }
    
    private var isBatchUpdating = false
    
    public func batchUpdate(_ updates: () -> Void) {
        isBatchUpdating = true
        updates()
        isBatchUpdating = false
        applyTriggerSettings()
    }
    
    public func applyPreset(_ preset: TriggerPreset) {
        batchUpdate {
            l2Mode = preset.l2Mode
            l2Start = preset.l2Start
            l2End = preset.l2End
            l2Strength = preset.l2Strength
            l2Amplitude = preset.l2Amplitude
            l2Frequency = preset.l2Frequency
            
            r2Mode = preset.r2Mode
            r2Start = preset.r2Start
            r2End = preset.r2End
            r2Strength = preset.r2Strength
            r2Amplitude = preset.r2Amplitude
            r2Frequency = preset.r2Frequency
        }
        
        ledColor = NSColor(red: CGFloat(preset.ledRed), green: CGFloat(preset.ledGreen), blue: CGFloat(preset.ledBlue), alpha: 1.0)
        isLedPulsing = preset.isLedPulsing
        updateLed()
    }
    
    public func setupHandlers(for controller: GCController) {
        updateConnectionType()
        
        if let battery = controller.battery {
            self.batteryLevel = battery.batteryLevel
            self.batteryState = battery.batteryState
        }
        
        guard let gamepad = controller.extendedGamepad else { return }
        self.buttonsPressed.removeAll()
        
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["cross"] = pressed }
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["circle"] = pressed }
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["square"] = pressed }
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["triangle"] = pressed }
        }
        
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["l1"] = pressed }
        }
        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["r1"] = pressed }
        }
        
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async {
                self.buttonsPressed["l2"] = pressed
                self.leftTriggerValue = value
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async {
                self.buttonsPressed["r2"] = pressed
                self.rightTriggerValue = value
            }
        }
        
        gamepad.dpad.up.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["dpadUp"] = pressed }
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["dpadDown"] = pressed }
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["dpadLeft"] = pressed }
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["dpadRight"] = pressed }
        }
        
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, x, y) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.leftStickValue = CGPoint(x: CGFloat(x), y: CGFloat(y)) }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, x, y) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.rightStickValue = CGPoint(x: CGFloat(x), y: CGFloat(y)) }
        }
        
        if let l3 = gamepad.leftThumbstickButton {
            l3.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async { self.buttonsPressed["l3"] = pressed }
            }
        }
        if let r3 = gamepad.rightThumbstickButton {
            r3.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async { self.buttonsPressed["r3"] = pressed }
            }
        }
        
        if let options = gamepad.buttonOptions {
            options.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async { self.buttonsPressed["create"] = pressed }
            }
        }
        
        gamepad.buttonMenu.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async { self.buttonsPressed["options"] = pressed }
        }
        
        if let home = gamepad.buttonHome {
            home.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async { self.buttonsPressed["ps"] = pressed }
            }
        }
        
        if let ds = gamepad as? GCDualSenseGamepad {
            ds.touchpadPrimary.valueChangedHandler = { [weak self] (_, x, y) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if self.isUIVisible {
                        self.touchpadPrimary = CGPoint(x: CGFloat(x), y: CGFloat(y))
                        self.touchpadPrimaryActive = true
                        self.touchpadPrimaryTimeout?.invalidate()
                        self.touchpadPrimaryTimeout = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                            self?.touchpadPrimaryActive = false
                            self?.resetTouchpadGesture()
                        }
                    }
                    self.handleTouchpadUpdate(x: x, y: y)
                }
            }
            ds.touchpadSecondary.valueChangedHandler = { [weak self] (_, x, y) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async {
                    self.touchpadSecondary = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    self.touchpadSecondaryActive = true
                    self.touchpadSecondaryTimeout?.invalidate()
                    self.touchpadSecondaryTimeout = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                        self?.touchpadSecondaryActive = false
                    }
                }
            }
            ds.touchpadButton.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self, self.isUIVisible else { return }
                DispatchQueue.main.async { self.buttonsPressed["touchpad"] = pressed }
            }
        }
        
        updateMotionSensorsState()
    }
    
    public func updateMotionSensorsState() {
        guard let controller = activeController else { return }
        guard let motion = controller.motion else { return }
        
        let shouldBeActive = isSensorsTabActive && isUIVisible
        
        logToFile("updateMotionSensorsState: shouldBeActive=\(shouldBeActive), sensorsActive=\(motion.sensorsActive), hasAttitude=\(motion.hasAttitude), hasRotationRate=\(motion.hasRotationRate), hasGravity=\(motion.hasGravityAndUserAcceleration)")
        
        if shouldBeActive {
            // Reset filter states when activating
            self.filteredPitch = 0.0
            self.filteredRoll = 0.0
            self.filteredYaw = 0.0
            self.lastMotionTimestamp = 0.0
            
            motion.valueChangedHandler = { [weak self] m in
                guard let self = self else { return }
                
                let now: Double = ProcessInfo.processInfo.systemUptime
                let dt: Double
                if self.lastMotionTimestamp == 0.0 {
                    dt = 0.004 // Default to 250Hz dt (4ms)
                } else {
                    dt = min(0.1, now - self.lastMotionTimestamp)
                }
                self.lastMotionTimestamp = now
                
                // Get rotation rates (radians/sec)
                let gyroX: Double = Double(m.rotationRate.x)
                let gyroY: Double = Double(m.rotationRate.y)
                let gyroZ: Double = Double(m.rotationRate.z)
                
                // Get accelerometer acceleration (g's)
                let accX: Double = Double(m.acceleration.x)
                let accY: Double = Double(m.acceleration.y)
                let accZ: Double = Double(m.acceleration.z)
                
                // Integrate gyro data
                self.filteredPitch += gyroX * dt
                self.filteredRoll += gyroZ * dt
                self.filteredYaw += gyroY * dt
                
                // Use accelerometer to correct pitch and roll drift
                let xx: Double = accX * accX
                let zz: Double = accZ * accZ
                let normAcc: Double = sqrt(xx + accY * accY + zz)
                
                let gyroGG: Double = gyroX * gyroX + gyroY * gyroY
                let gyroMag: Double = sqrt(gyroGG + gyroZ * gyroZ)
                
                // Adaptive gain: only correct pitch & roll if gravity is dominant (normAcc close to 1.0g)
                var kAcc: Double = 0.0
                let deltaAcc: Double = abs(normAcc - 1.0)
                if deltaAcc < 0.15 {
                    if gyroMag < 0.03 {
                        kAcc = 0.1 // Fast correction when stationary
                    } else {
                        kAcc = 0.01 // Slow correction during gentle movements
                    }
                }
                
                if kAcc > 0.0 {
                    let rootXZ: Double = sqrt(xx + zz)
                    let accPitch: Double = atan2(accY, rootXZ)
                    let accRoll: Double = atan2(-accX, -accZ)
                    
                    let pIntegrated: Double = self.filteredPitch
                    let rIntegrated: Double = self.filteredRoll
                    self.filteredPitch = (1.0 - kAcc) * pIntegrated + kAcc * accPitch
                    self.filteredRoll = (1.0 - kAcc) * rIntegrated + kAcc * accRoll
                }
                
                // Slow yaw recovery to 0.0 when controller is resting to prevent yaw drift
                if gyroMag < 0.03 {
                    let yIntegrated: Double = self.filteredYaw
                    self.filteredYaw = 0.998 * yIntegrated
                }
                
                // Convert Euler angles (Pitch, Yaw, Roll) to GCQuaternion
                let halfYaw: Double = self.filteredYaw * 0.5
                let halfPitch: Double = self.filteredPitch * 0.5
                let halfRoll: Double = self.filteredRoll * 0.5
                
                let cy: Double = cos(halfYaw)
                let sy: Double = sin(halfYaw)
                let cp: Double = cos(halfPitch)
                let sp: Double = sin(halfPitch)
                let cr: Double = cos(halfRoll)
                let sr: Double = sin(halfRoll)
                
                let crcp: Double = cr * cp
                let crsp: Double = cr * sp
                let srcp: Double = sr * cp
                let srsp: Double = sr * sp
                
                let qw_d: Double = crcp * cy + srsp * sy
                let qx_d: Double = srcp * cy - crsp * sy
                let qy_d: Double = crsp * cy + srcp * sy
                let qz_d: Double = crcp * sy - srsp * cy
                
                let sumSq: Double = qx_d * qx_d + qy_d * qy_d + qz_d * qz_d + qw_d * qw_d
                let len: Double = sqrt(sumSq)
                
                let qwNorm: Double = len > 0.0 ? qw_d / len : 1.0
                let qxNorm: Double = len > 0.0 ? qx_d / len : 0.0
                let qyNorm: Double = len > 0.0 ? qy_d / len : 0.0
                let qzNorm: Double = len > 0.0 ? qz_d / len : 0.0
                
                let calculatedAttitude = GCQuaternion(x: qxNorm, y: qyNorm, z: qzNorm, w: qwNorm)
                self.rawMotionAttitude = calculatedAttitude
                
                // Calculate relative orientation: q_clean = q_ref.inverse * q_raw
                let q_ref = self.sensorReferenceOrientation
                let q_ref_inv = GCQuaternion(x: -q_ref.x, y: -q_ref.y, z: -q_ref.z, w: q_ref.w)
                
                let w1 = q_ref_inv.w
                let x1 = q_ref_inv.x
                let y1 = q_ref_inv.y
                let z1 = q_ref_inv.z
                
                let w = w1 * calculatedAttitude.w - x1 * calculatedAttitude.x - y1 * calculatedAttitude.y - z1 * calculatedAttitude.z
                let x = w1 * calculatedAttitude.x + x1 * calculatedAttitude.w + y1 * calculatedAttitude.z - z1 * calculatedAttitude.y
                let y = w1 * calculatedAttitude.y - x1 * calculatedAttitude.z + y1 * calculatedAttitude.w + z1 * calculatedAttitude.x
                let z = w1 * calculatedAttitude.z + x1 * calculatedAttitude.y - y1 * calculatedAttitude.x + z1 * calculatedAttitude.w
                
                let finalLen = sqrt(w*w + x*x + y*y + z*z)
                let finalW = finalLen > 0.0 ? w / finalLen : 1.0
                let finalX = finalLen > 0.0 ? x / finalLen : 0.0
                let finalY = finalLen > 0.0 ? y / finalLen : 0.0
                let finalZ = finalLen > 0.0 ? z / finalLen : 0.0
                
                let finalAttitude = GCQuaternion(x: finalX, y: finalY, z: finalZ, w: finalW)
                
                self.motionUpdateCount += 1
                if self.motionUpdateCount % 200 == 0 {
                    logToFile("Motion callback \(self.motionUpdateCount): rotX=\(String(format: "%.3f", gyroX)), rotY=\(String(format: "%.3f", gyroY)), rotZ=\(String(format: "%.3f", gyroZ)) | calculatedAttitude: w=\(String(format: "%.3f", qwNorm)), x=\(String(format: "%.3f", qxNorm)), y=\(String(format: "%.3f", qyNorm)), z=\(String(format: "%.3f", qzNorm))")
                }
                
                DispatchQueue.main.async {
                    self.motionAttitude = finalAttitude
                }
            }
            if !motion.sensorsActive {
                motion.sensorsActive = true
                logToFile("Motion sensors activated: sensorsActive set to true")
            }
        } else {
            motion.valueChangedHandler = nil
            if motion.sensorsActive {
                motion.sensorsActive = false
                logToFile("Motion sensors deactivated: sensorsActive set to false")
            }
        }
    }
    
    public func recenterSensors() {
        sensorReferenceOrientation = rawMotionAttitude
        logToFile("Sensors recentered to w=\(rawMotionAttitude.w), x=\(rawMotionAttitude.x), y=\(rawMotionAttitude.y), z=\(rawMotionAttitude.z)")
    }
    
    public func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let controller = self.activeController else { return }
            
            // Use raw HID when backgrounded to bypass GameController framework focus restriction
            if !self.isAppInForeground {
                self.applyTriggerSettingsViaHID()
            }
            self.updateConnectionType()
            if let battery = controller.battery {
                DispatchQueue.main.async {
                    self.batteryLevel = battery.batteryLevel
                    self.batteryState = battery.batteryState
                }
            }
            NotificationCenter.default.post(name: NSNotification.Name("DualSenseTStatusChanged"), object: nil)
        }
    }
    
    public func updateConnectionType() {
        guard activeController != nil else {
            DispatchQueue.main.async { self.connectionType = "Unknown" }
            return
        }
        
        let transport = getTransportForDualSense()
        DispatchQueue.main.async {
            if transport != "Unknown" {
                self.connectionType = transport
            } else {
                if self.activeController?.vendorName?.lowercased().contains("bluetooth") == true {
                    self.connectionType = "BT"
                } else {
                    self.connectionType = "USB"
                }
            }
        }
    }
    
    private func getTransportForDualSense() -> String {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match1 = [
            "VendorID": 0x054C,
            "ProductID": 0x0CE6
        ] as CFDictionary
        let match2 = [
            "VendorID": 0x054C,
            "ProductID": 0x0DF2
        ] as CFDictionary
        let matchingArray = [match1, match2] as CFArray
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        var transportType = "Unknown"
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in devices {
                if let transport = IOHIDDeviceGetProperty(device, "Transport" as CFString) as? String {
                    if transport.lowercased().contains("usb") {
                        transportType = "USB"
                    } else if transport.lowercased().contains("bluetooth") || transport.lowercased().contains("bt") {
                        transportType = "BT"
                    }
                }
            }
        }
        return transportType
    }
    
    public func applyTriggerSettings(log: Bool = true) {
        guard let controller = activeController else {
            if log {
                logToFile("applyTriggerSettings skipped: activeController is nil")
            }
            return
        }
        guard let gamepad = controller.extendedGamepad as? GCDualSenseGamepad else {
            if log {
                logToFile("applyTriggerSettings error: gamepad is not GCDualSenseGamepad")
            }
            return
        }
        
        let l2 = gamepad.leftTrigger
        let r2 = gamepad.rightTrigger
        
        if log {
            logToFile("applyTriggerSettings: L2Mode=\(l2Mode) (start=\(l2Start), end=\(l2End), strength=\(l2Strength), amp=\(l2Amplitude), freq=\(l2Frequency)), R2Mode=\(r2Mode) (start=\(r2Start), end=\(r2End), strength=\(r2Strength), amp=\(r2Amplitude), freq=\(r2Frequency))")
        }
        
        // L2 Mode Apply
        switch l2Mode {
        case .off:
            l2.setModeOff()
        case .feedback:
            l2.setModeFeedbackWithStartPosition(l2Start, resistiveStrength: l2Strength)
        case .weapon:
            l2.setModeWeaponWithStartPosition(l2Start, endPosition: l2End, resistiveStrength: l2Strength)
        case .vibration:
            l2.setModeVibrationWithStartPosition(l2Start, amplitude: l2Amplitude, frequency: l2Frequency)
        }
        
        // R2 Mode Apply
        switch r2Mode {
        case .off:
            r2.setModeOff()
        case .feedback:
            r2.setModeFeedbackWithStartPosition(r2Start, resistiveStrength: r2Strength)
        case .weapon:
            r2.setModeWeaponWithStartPosition(r2Start, endPosition: r2End, resistiveStrength: r2Strength)
        case .vibration:
            r2.setModeVibrationWithStartPosition(r2Start, amplitude: r2Amplitude, frequency: r2Frequency)
        }
    }
    
    // MARK: - Raw HID Output for Background Trigger Persistence
    
    private func computeBTCRC32(_ data: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        // Process seed byte 0xA2 (DualSense BT output report seed)
        let seedIndex = Int((crc ^ UInt32(0xA2)) & 0xFF)
        crc = Self.crc32Table[seedIndex] ^ (crc >> 8)
        // Process report data
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = Self.crc32Table[index] ^ (crc >> 8)
        }
        return ~crc
    }
    
    public func findHIDOutputDevice() -> IOHIDDevice? {
        if let device = hidOutputDevice { return device }
        
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match1 = ["VendorID": 0x054C, "ProductID": 0x0CE6] as CFDictionary
        let match2 = ["VendorID": 0x054C, "ProductID": 0x0DF2] as CFDictionary
        IOHIDManagerSetDeviceMatchingMultiple(manager, [match1, match2] as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }
        
        // Find a device that accepts output reports large enough for the DualSense
        for device in devices {
            if let maxOutput = IOHIDDeviceGetProperty(device, kIOHIDMaxOutputReportSizeKey as String as CFString) as? Int, maxOutput >= 48 {
                hidManager = manager
                hidOutputDevice = device
                return device
            }
        }
        
        // Fallback: use first matching device
        if let device = devices.first {
            hidManager = manager
            hidOutputDevice = device
            return device
        }
        return nil
    }
    
    public func clearHIDDevice() {
        hidOutputDevice = nil
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
    }
    
    private func triggerModeToHIDBytes(mode: TriggerMode, start: Float, end: Float, strength: Float, amplitude: Float, frequency: Float) -> (mode: UInt8, params: [UInt8]) {
        var params = [UInt8](repeating: 0, count: 10)
        switch mode {
        case .off:
            return (0x05, params) // DS_TRIGGER_EFFECT_OFF = 0x05
            
        case .feedback:
            let pos = min(9, max(0, Int(round(start * 9.0))))
            let strengthVal = min(8, max(1, Int(round(strength * 7.0)) + 1))
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 {
                strengthArray[i] = UInt8(strengthVal)
            }
            return bitpackTriggerArray(mode: 0x21, strengthArray: strengthArray, frequency: 0)
            
        case .weapon:
            let startPos = min(7, max(2, Int(round(start * 9.0))))
            let endPos = min(8, max(startPos + 1, Int(round(end * 9.0))))
            let strengthVal = min(8, max(1, Int(round(strength * 7.0)) + 1))
            let startStopZones = UInt16((1 << startPos) | (1 << endPos))
            
            params[0] = UInt8(startStopZones & 0xFF)
            params[1] = UInt8((startStopZones >> 8) & 0xFF)
            params[2] = UInt8(strengthVal - 1)
            return (0x25, params)
            
        case .vibration:
            let pos = min(9, max(0, Int(round(start * 9.0))))
            let ampVal = min(8, max(1, Int(round(amplitude * 7.0)) + 1))
            let freqVal = UInt8(clamping: max(1, Int(round(frequency * 255.0))))
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 {
                strengthArray[i] = UInt8(ampVal)
            }
            return bitpackTriggerArray(mode: 0x26, strengthArray: strengthArray, frequency: freqVal)
        }
    }
    
    private func bitpackTriggerArray(mode: UInt8, strengthArray: [UInt8], frequency: UInt8) -> (mode: UInt8, params: [UInt8]) {
        var params = [UInt8](repeating: 0, count: 10)
        var strengthZones: UInt32 = 0
        var activeZones: UInt16 = 0
        
        for i in 0..<10 {
            let val = strengthArray[i]
            if val > 0 {
                let strengthValue = UInt32((val - 1) & 0x07)
                strengthZones |= (strengthValue << (3 * i))
                activeZones |= UInt16(1 << i)
            }
        }
        
        params[0] = UInt8(activeZones & 0xFF)
        params[1] = UInt8((activeZones >> 8) & 0xFF)
        params[2] = UInt8(strengthZones & 0xFF)
        params[3] = UInt8((strengthZones >> 8) & 0xFF)
        params[4] = UInt8((strengthZones >> 16) & 0xFF)
        params[5] = UInt8((strengthZones >> 24) & 0xFF)
        params[6] = 0
        params[7] = 0
        params[8] = frequency
        params[9] = 0
        
        return (mode, params)
    }
    
    public func applyTriggerSettingsViaHID() {
        guard activeController != nil else { return }
        guard let device = findHIDOutputDevice() else {
            if !lastHIDErrorLogged {
                logToFile("HID: Could not find DualSense HID output device")
                lastHIDErrorLogged = true
            }
            return
        }
        
        let r2HID = triggerModeToHIDBytes(mode: r2Mode, start: r2Start, end: r2End, strength: r2Strength, amplitude: r2Amplitude, frequency: r2Frequency)
        let l2HID = triggerModeToHIDBytes(mode: l2Mode, start: l2Start, end: l2End, strength: l2Strength, amplitude: l2Amplitude, frequency: l2Frequency)
        
        // Get LED color components
        var ledR: CGFloat = 0, ledG: CGFloat = 0, ledB: CGFloat = 0, ledA: CGFloat = 0
        if let srgb = ledColor.usingColorSpace(.sRGB) {
            srgb.getRed(&ledR, green: &ledG, blue: &ledB, alpha: &ledA)
        } else {
            ledColor.getRed(&ledR, green: &ledG, blue: &ledB, alpha: &ledA)
        }
        
        let transport = IOHIDDeviceGetProperty(device, "Transport" as CFString) as? String ?? ""
        let isBT = transport.lowercased().contains("bluetooth") || transport.lowercased().contains("bt")
        
        let result: IOReturn
        if isBT {
            result = sendBTOutputReport(device: device, r2: r2HID, l2: l2HID, ledR: UInt8(ledR * 255), ledG: UInt8(ledG * 255), ledB: UInt8(ledB * 255))
        } else {
            result = sendUSBOutputReport(device: device, r2: r2HID, l2: l2HID, ledR: UInt8(ledR * 255), ledG: UInt8(ledG * 255), ledB: UInt8(ledB * 255))
        }
        
        if result != kIOReturnSuccess {
            if !lastHIDErrorLogged {
                logToFile("HID output report failed: \(String(format: "0x%08X", result)) (transport: \(transport))")
                lastHIDErrorLogged = true
                // Device may have become stale, clear cache to retry next cycle
                clearHIDDevice()
            }
        } else {
            lastHIDErrorLogged = false
        }
    }
    
    private func sendUSBOutputReport(device: IOHIDDevice, r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]), ledR: UInt8, ledG: UInt8, ledB: UInt8) -> IOReturn {
        var report = [UInt8](repeating: 0, count: 48)
        report[0] = 0x02  // USB Report ID
        report[1] = 0x04 | 0x08
        report[2] = 0x04
        
        report[11] = r2.mode
        for i in 0..<min(r2.params.count, 10) {
            report[12 + i] = r2.params[i]
        }
        
        report[22] = l2.mode
        for i in 0..<min(l2.params.count, 10) {
            report[23 + i] = l2.params[i]
        }
        
        report[39] = 0x02 | 0x10  // lightbar_setup_control + lightbar
        report[42] = 0x02          // lightbar_setup: enable
        report[45] = ledR
        report[46] = ledG
        report[47] = ledB
        
        return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
    }
    
    private func sendBTOutputReport(device: IOHIDDevice, r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]), ledR: UInt8, ledG: UInt8, ledB: UInt8) -> IOReturn {
        var report = [UInt8](repeating: 0, count: 78)
        report[0] = 0x31  // BT Report ID
        report[1] = (btSequenceNumber << 4) | 0x02
        btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F
        report[2] = 0x10  // BT tag
        
        report[3] = 0x04 | 0x08   // valid_flag0
        report[4] = 0x04           // valid_flag1
        
        report[13] = r2.mode
        for i in 0..<min(r2.params.count, 10) {
            report[14 + i] = r2.params[i]
        }
        
        report[24] = l2.mode
        for i in 0..<min(l2.params.count, 10) {
            report[25 + i] = l2.params[i]
        }
        
        report[41] = 0x02 | 0x10  // valid_flag2
        report[44] = 0x02          // lightbar_setup
        report[47] = ledR
        report[48] = ledG
        report[49] = ledB
        
        let crc = computeBTCRC32(Array(report[0..<74]))
        report[74] = UInt8(crc & 0xFF)
        report[75] = UInt8((crc >> 8) & 0xFF)
        report[76] = UInt8((crc >> 16) & 0xFF)
        report[77] = UInt8((crc >> 24) & 0xFF)
        
        return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
    }
    
    public func updateLed() {
        guard let controller = activeController, let light = controller.light else { return }
        
        pulsingTimer?.invalidate()
        pulsingTimer = nil
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let srgb = ledColor.usingColorSpace(.sRGB) {
            srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            ledColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        
        if isLedPulsing {
            pulsingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let controller = self.activeController, let light = controller.light else { return }
                let t = Date().timeIntervalSince1970
                let breath = (sin(t * 2.5) + 1.0) / 2.0
                let factor = Float(0.15 + breath * 0.85)
                
                light.color = GCColor(red: Float(r) * factor, green: Float(g) * factor, blue: Float(b) * factor)
            }
        } else {
            light.color = GCColor(red: Float(r), green: Float(g), blue: Float(b))
        }
    }
    
    // MARK: - Touchpad Gestures
    
    public func loadTouchpadActions() {
        if let data = UserDefaults.standard.data(forKey: "touchpadActions"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.touchpadActions = decoded
        }
    }
    
    public func saveTouchpadActions() {
        if let data = try? JSONEncoder().encode(touchpadActions) {
            UserDefaults.standard.set(data, forKey: "touchpadActions")
        }
    }
    
    public func handleTouchpadUpdate(x: Float, y: Float) {
        if x == 0 && y == 0 {
            resetTouchpadGesture()
            return
        }
        
        let currentPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
        
        if touchStart == nil {
            touchStart = currentPoint
            hasSwiped = false
            return
        }
        
        guard let start = touchStart, !hasSwiped else { return }
        
        let dx = currentPoint.x - start.x
        let dy = currentPoint.y - start.y
        
        let threshold: CGFloat = 0.5
        
        if abs(dx) > threshold {
            hasSwiped = true
            if dx > 0 {
                triggerTouchpadAction(direction: "Right")
            } else {
                triggerTouchpadAction(direction: "Left")
            }
        } else if abs(dy) > threshold {
            hasSwiped = true
            if dy > 0 {
                triggerTouchpadAction(direction: "Up")
            } else {
                triggerTouchpadAction(direction: "Down")
            }
        }
    }
    
    public func resetTouchpadGesture() {
        touchStart = nil
        hasSwiped = false
    }
    
    public func triggerTouchpadAction(direction: String) {
        let actionSetting = touchpadActions[direction] ?? "None"
        switch actionSetting {
        case "Spacebar":
            simulateKeyPress(key: 49)
        case "Left Arrow":
            simulateKeyPress(key: 123)
        case "Right Arrow":
            simulateKeyPress(key: 124)
        case "Up Arrow":
            simulateKeyPress(key: 126)
        case "Down Arrow":
            simulateKeyPress(key: 125)
        default:
            break
        }
    }
    
    public func simulateKeyPress(key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Per-App Profiles Configuration
    
    public func loadAppProfiles() {
        if let data = UserDefaults.standard.data(forKey: "appProfiles"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.appProfiles = decoded
        }
    }
    
    public func saveAppProfiles() {
        if let data = try? JSONEncoder().encode(appProfiles) {
            UserDefaults.standard.set(data, forKey: "appProfiles")
        }
    }
    
    public func setupAppProfileObserver(presetManager: PresetManager) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            
            if let presetName = self.appProfiles[bundleId] {
                if let preset = self.findPreset(named: presetName, presetManager: presetManager) {
                    self.applyPreset(preset)
                }
            }
        }
    }
    
    public func findPreset(named name: String, presetManager: PresetManager) -> TriggerPreset? {
        if let dp = defaultPresets.first(where: { $0.name == name }) {
            return dp
        }
        return presetManager.customPresets.first(where: { $0.name == name })
    }
    
    public func chooseApplication(presetManager: PresetManager) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Game or Application"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let bundle = Bundle(url: url)
                let bundleId = bundle?.bundleIdentifier ?? url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
                
                DispatchQueue.main.async {
                    self.appProfiles[bundleId] = "Off"
                    self.saveAppProfiles()
                }
            }
        }
    }
}
