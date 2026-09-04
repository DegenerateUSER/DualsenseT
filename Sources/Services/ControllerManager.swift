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
    /// Transport-agnostic "is a controller connected" flag: true if either a USB
    /// controller is active via GameController, or the raw-HID Bluetooth connection
    /// is up. Use this instead of `activeController != nil` for connection UI, since
    /// Bluetooth no longer goes through GameController at all.
    @Published public var isConnected: Bool = false
    
    // Trigger Settings
    @Published public var l2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Start: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2End: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Strength: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Amplitude: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2Frequency: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var l2EndStrength: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    
    @Published public var r2Mode: TriggerMode = .off { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Start: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2End: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Strength: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Amplitude: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2Frequency: Float = 0.5 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    @Published public var r2EndStrength: Float = 0.0 { didSet { if !isBatchUpdating { applyTriggerSettings() } } }
    
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
    
    // Mic LED State: 0 = off, 1 = on, 2 = pulse
    @Published public var micLEDState: UInt8 = 0 { didSet { applyHardwareState() } }
    
    // Player Indicator LEDs: 5-bit bitmask (bit 0 = leftmost, bit 4 = rightmost)
    @Published public var playerLEDs: UInt8 = 0 { didSet { applyHardwareState() } }
    
    // Rumble Motor Intensity (0-255)
    @Published public var rumbleLeftIntensity: UInt8 = 0 { didSet { applyHardwareState() } }
    @Published public var rumbleRightIntensity: UInt8 = 0 { didSet { applyHardwareState() } }

    // USB controller audio controls. These map to the audio fields in the same 0x02
    // output report as triggers/LEDs; Bluetooth never receives these flags.
    @Published public var controllerAudioControlsEnabled = false { didSet { applyHardwareState() } }
    @Published public var controllerAudioOutputRoute: ControllerAudioOutputRoute = .controllerSpeaker {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    @Published public var controllerAudioInputRoute: ControllerAudioInputRoute = .automatic {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    @Published public var controllerHeadphoneVolume: Double = 0.8 {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    @Published public var controllerSpeakerVolume: Double = 0.8 {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    @Published public var controllerMicrophoneVolume: Double = 0.8 {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    @Published public var controllerMicrophoneMuted = false {
        didSet { if controllerAudioControlsEnabled { applyHardwareState() } }
    }
    /// USB-only selector between classic rumble emulation and raw PCM haptic actuators.
    /// Default false preserves the hardware-verified normal rumble behavior.
    @Published public var audioHapticsModeEnabled = false {
        didSet { applyHardwareState() }
    }
    
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
    /// Owns the entire Bluetooth connection: raw-HID exclusive open, input report
    /// parsing, and output writes, via vendored hidapi (Sources/CHidapi). See
    /// BluetoothHIDController's doc comment for why exclusive access is required.
    private let bluetoothHID = BluetoothHIDController()
    private var touchpadPrimaryTimeout: Timer?
    private var touchpadSecondaryTimeout: Timer?
    private var motionUpdateCount = 0
    private var filteredPitch: Double = 0.0
    private var filteredRoll: Double = 0.0
    private var filteredYaw: Double = 0.0
    private var lastMotionTimestamp: TimeInterval = 0.0
    private var lastMotionUIPublishTimestamp: TimeInterval = 0.0
    private var rawMotionAttitude: GCQuaternion = GCQuaternion(x: 0, y: 0, z: 0, w: 1)
    private var sensorReferenceOrientation: GCQuaternion = GCQuaternion(x: 0, y: 0, z: 0, w: 1)

    private struct ControllerAudioHIDState {
        let outputRoute: ControllerAudioOutputRoute
        let inputRoute: ControllerAudioInputRoute
        let headphoneVolume: Double
        let speakerVolume: Double
        let microphoneVolume: Double
        let microphoneMuted: Bool
    }
    
    // Raw HID output state for background trigger persistence
    private var hidManager: IOHIDManager?
    private var hidOutputDevice: IOHIDDevice?
    /// Dedicated, continuously-pumped background thread + run loop that the HID device is
    /// scheduled on, mirroring hidapi's approach (which is proven to get Bluetooth DualSense
    /// rumble working on macOS). IOHIDDeviceSetReport presents as a simple synchronous call,
    /// but its actual completion over Bluetooth may depend on IOKit's async transport-
    /// completion machinery, which needs the device registered on an ACTIVE run loop to fire —
    /// a plain GCD queue (what `backgroundQueue` is) isn't a continuously-pumped run loop the
    /// way a dedicated thread is, so without this, SetReport could report success from a
    /// weaker/local completion path while never actually reaching the transport.
    private var hidRunLoopThread: Thread?
    private var hidCFRunLoop: CFRunLoop?
    private let hidRunLoopReadySemaphore = DispatchSemaphore(value: 0)
    private var hidRunLoopShouldStop = false
    private var btSequenceNumber: UInt8 = 0
    /// The DualSense keeps hardware ownership of its LEDs after startup. The Linux driver
    /// releases that ownership with one dedicated LIGHT_OUT setup report, then sends normal
    /// RGB/player-LED updates in a separate report. These flags are owned by backgroundQueue
    /// and reset whenever the corresponding HID connection is reopened.
    private var usbLEDControlInitialized = false
    private var btLEDControlInitialized = false
    private var lastHIDErrorLogged: Bool = false
    /// Consecutive failed SetReport calls. A single failure is normal (transient
    /// 0xE00002BC etc.) and the data usually still lands; only after several in a row do we
    /// treat the device handle as stale and re-discover it. Touched only on backgroundQueue.
    private var consecutiveHIDFailures: Int = 0
    private let maxConsecutiveHIDFailures = 5
    /// Number of HID writes currently queued or in flight on `backgroundQueue`. We coalesce:
    /// if writes are already backed up (e.g. a Bluetooth write is stalling), we drop new ones
    /// rather than let them pile up unbounded — trigger/LED reports are idempotent
    /// re-applications, so the next tick simply sends the latest state.
    private let pendingSendLock = NSLock()
    private var pendingSendCount = 0
    private let maxPendingSends = 2
    
    private let backgroundQueue = DispatchQueue(label: "com.degenerateuser.stickyfingers.background", qos: .userInteractive)
    private var backgroundTimer: DispatchSourceTimer?
    private var appNapActivity: NSObjectProtocol?
    private var backgroundTimerStartDate: Date?
    /// Tracks whether we've ever successfully connected to a controller in this session.
    /// Used to keep background HID writes active even after GameController nils activeController.
    private var hasHadController: Bool = false
    
    public var isAppInForeground: Bool = true {
        didSet {
            updateBackgroundState()
        }
    }
    
    /// Sends an exponential backoff burst of HID reports when the app loses focus.
    /// This aggressively re-applies settings to win the race against macOS/GameController resets.
    ///
    /// Only relevant for USB: that race exists because GameController's own BT rumble/light
    /// channel would get reclaimed/reset around focus changes. Bluetooth now goes through our
    /// own exclusive raw-HID connection (`bluetoothHID`), which keeps working regardless of app
    /// focus — spraying it with a burst of redundant writes right as the app backgrounds does
    /// nothing useful and has been observed to flood/congest the BT link badly enough to trip
    /// `hid_read_timeout` failures and force a disconnect. Skip it when BT is the live transport.
    public func sendBackgroundBurst() {
        guard !bluetoothHID.isConnected else { return }
        let delays = [0, 30, 60, 100, 200, 500, 1000, 2000] // ms - exponential backoff
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
                guard let self = self, !self.isAppInForeground else { return }
                self.applyTriggerSettingsViaHID()
            }
        }
        logToFile("Background burst: 8 HID reports scheduled (0-2000ms exponential backoff).")
    }

    private func startBackgroundTimer() {
        backgroundTimer?.cancel()
        backgroundTimerStartDate = Date()
        let timer = DispatchSource.makeTimerSource(queue: backgroundQueue)
        // Start fast (50ms) for the first 3 seconds, then settle to 500ms
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Same reasoning as `sendBackgroundBurst`: this periodic resend exists only to
                // fight GameController's BT ownership, which no longer applies once our own
                // exclusive raw-HID BT connection is up — resending every 50ms over that link
                // instead risks congesting/dropping it.
                if !self.isAppInForeground && !self.bluetoothHID.isConnected {
                    self.applyTriggerSettingsViaHID()
                    // After 3 seconds, switch to a slower interval to reduce CPU
                    if let startDate = self.backgroundTimerStartDate,
                       Date().timeIntervalSince(startDate) > 3.0,
                       self.backgroundTimer != nil {
                        self.backgroundTimer?.cancel()
                        let slowTimer = DispatchSource.makeTimerSource(queue: self.backgroundQueue)
                        slowTimer.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
                        slowTimer.setEventHandler { [weak self] in
                            DispatchQueue.main.async {
                                guard let self = self, !self.isAppInForeground, !self.bluetoothHID.isConnected else { return }
                                self.applyTriggerSettingsViaHID()
                            }
                        }
                        self.backgroundTimer = slowTimer
                        slowTimer.resume()
                        logToFile("Background timer settled to 500ms interval.")
                    }
                }
            }
        }
        backgroundTimer = timer
        timer.resume()
        logToFile("Background HID Dispatch Timer started (50ms fast phase).")
    }

    private func stopBackgroundTimer() {
        backgroundTimer?.cancel()
        backgroundTimer = nil
        backgroundTimerStartDate = nil
        logToFile("Background HID Dispatch Timer stopped.")
    }

    private func preventAppNap() {
        guard appNapActivity == nil else { return }
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.latencyCritical, .idleSystemSleepDisabled],
            reason: "Sticky Fingers Background Keep-Alive"
        )
        logToFile("App Nap prevention activated.")
    }

    private func allowAppNap() {
        if let activity = appNapActivity {
            ProcessInfo.processInfo.endActivity(activity)
            appNapActivity = nil
            logToFile("App Nap prevention deactivated.")
        }
    }

    private func updateBackgroundState() {
        // Use hasHadController instead of activeController != nil.
        // When the app goes to background, GameController framework may nil activeController
        // (especially over BT), but we still need the timer to keep sending HID reports.
        if !isAppInForeground && hasHadController {
            preventAppNap()
            startBackgroundTimer()
        } else if isAppInForeground {
            allowAppNap()
            stopBackgroundTimer()
        }
        // Note: if !isAppInForeground && !hasHadController, we do nothing (no controller ever connected)
    }
    
    #if TESTING
    public var mockHIDMode = false
    public var mockHIDTransport = "USB"
    public var capturedUSBReport: [UInt8]?
    public var capturedBTReport: [UInt8]?
    public var mockBTSequenceNumber: UInt8 {
        get { return btSequenceNumber }
        set { btSequenceNumber = newValue }
    }
    public func testComputeBTCRC32(_ data: [UInt8]) -> UInt32 {
        return computeBTCRC32(data)
    }
    public func testTriggerModeToHIDBytes(mode: TriggerMode, start: Float, end: Float, strength: Float, amplitude: Float, frequency: Float, endStrength: Float = 0) -> (mode: UInt8, params: [UInt8]) {
        return triggerModeToHIDBytes(mode: mode, start: start, end: end, strength: strength, amplitude: amplitude, frequency: frequency, endStrength: endStrength)
    }

    public func testPointChanged(from old: CGPoint, to new: CGPoint) -> Bool {
        pointChanged(from: old, to: new)
    }
    
    private func captureUSBReport(r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]),
                                  ledR: UInt8, ledG: UInt8, ledB: UInt8,
                                  rumbleR: UInt8, rumbleL: UInt8, mic: UInt8, players: UInt8,
                                  audio: ControllerAudioHIDState?,
                                  audioHapticsEnabled: Bool) -> IOReturn {
        // Capture the production builder itself. Keeping a second hand-written TESTING
        // serializer previously let its flags drift away from the report sent to hardware.
        self.capturedUSBReport = buildUSBOutputReport(
            r2: r2, l2: l2, ledR: ledR, ledG: ledG, ledB: ledB,
            rumbleR: rumbleR, rumbleL: rumbleL, mic: mic, players: players,
            audio: audio, audioHapticsEnabled: audioHapticsEnabled
        )
        return kIOReturnSuccess
    }
    
    private func captureBTReport(r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]),
                                 ledR: UInt8, ledG: UInt8, ledB: UInt8,
                                 rumbleR: UInt8, rumbleL: UInt8, mic: UInt8, players: UInt8) -> IOReturn {
        self.capturedBTReport = buildBTOutputReport(
            r2: r2, l2: l2, ledR: ledR, ledG: ledG, ledB: ledB,
            rumbleR: rumbleR, rumbleL: rumbleL, mic: mic, players: players
        )
        return kIOReturnSuccess
    }

    public func testBuildUSBLEDSetupReport() -> [UInt8] {
        buildUSBLEDSetupReport()
    }

    public func testBuildBTLEDSetupReport() -> [UInt8] {
        buildBTLEDSetupReport()
    }
    #endif
    
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
        // Original presets
        TriggerPreset(name: "Bow & Arrow", l2Mode: .feedback, l2Start: 0.1, l2End: 0.8, l2Strength: 0.4, l2Amplitude: 0, l2Frequency: 0, r2Mode: .weapon, r2Start: 0.2, r2End: 0.6, r2Strength: 0.8, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.0, ledGreen: 0.5, ledBlue: 1.0, isLedPulsing: false),
        TriggerPreset(name: "Heavy Rifle", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .weapon, r2Start: 0.1, r2End: 0.4, r2Strength: 0.9, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.1, ledBlue: 0.1, isLedPulsing: true),
        TriggerPreset(name: "Racing Brake", l2Mode: .slopeFeedback, l2Start: 0.0, l2End: 0.9, l2Strength: 0.2, l2Amplitude: 0, l2Frequency: 0, r2Mode: .off, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.5, ledBlue: 0.0, isLedPulsing: false, l2EndStrength: 1.0),
        TriggerPreset(name: "Soft Click", l2Mode: .feedback, l2Start: 0.2, l2End: 0, l2Strength: 0.3, l2Amplitude: 0, l2Frequency: 0, r2Mode: .feedback, r2Start: 0.2, r2End: 0, r2Strength: 0.3, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.5, ledGreen: 0.0, ledBlue: 0.5, isLedPulsing: false),
        // New presets showcasing advanced modes
        TriggerPreset(name: "Galloping", l2Mode: .multiPositionVibration, l2Start: 0.0, l2End: 0, l2Strength: 0, l2Amplitude: 0.6, l2Frequency: 0.15, r2Mode: .multiPositionVibration, r2Start: 0.0, r2End: 0, r2Strength: 0, r2Amplitude: 0.6, r2Frequency: 0.15, ledRed: 0.6, ledGreen: 0.3, ledBlue: 0.1, isLedPulsing: false),
        TriggerPreset(name: "Machine Gun", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .vibration, r2Start: 0.05, r2End: 0, r2Strength: 0, r2Amplitude: 0.9, r2Frequency: 0.8, ledRed: 0.9, ledGreen: 0.0, ledBlue: 0.0, isLedPulsing: true),
        TriggerPreset(name: "Heavy Spring", l2Mode: .fullPress, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .fullPress, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.8, ledBlue: 0.0, isLedPulsing: false),
        TriggerPreset(name: "Semi-Auto Pistol", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .semiAutomatic, r2Start: 0.3, r2End: 0.7, r2Strength: 0.7, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.2, ledGreen: 0.2, ledBlue: 0.2, isLedPulsing: false, r2EndStrength: 0.9),
        TriggerPreset(name: "Automatic Rifle", l2Mode: .sectionResistance, l2Start: 0.1, l2End: 0.5, l2Strength: 0.5, l2Amplitude: 0, l2Frequency: 0, r2Mode: .automatic, r2Start: 0.15, r2End: 0.85, r2Strength: 0.7, r2Amplitude: 0, r2Frequency: 0.6, ledRed: 0.0, ledGreen: 0.6, ledBlue: 0.1, isLedPulsing: false),
        TriggerPreset(name: "Bumpy Road", l2Mode: .multiPositionFeedback, l2Start: 0.0, l2End: 0, l2Strength: 0.5, l2Amplitude: 0, l2Frequency: 0, r2Mode: .multiPositionFeedback, r2Start: 0.0, r2End: 0, r2Strength: 0.5, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.4, ledGreen: 0.2, ledBlue: 0.0, isLedPulsing: false),
        TriggerPreset(name: "Slope Brake", l2Mode: .slopeFeedback, l2Start: 0.0, l2End: 1.0, l2Strength: 0.1, l2Amplitude: 0, l2Frequency: 0, r2Mode: .off, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 1.0, ledGreen: 0.3, ledBlue: 0.0, isLedPulsing: false, l2EndStrength: 0.9),
        // Reset preset
        TriggerPreset(name: "Off", l2Mode: .off, l2Start: 0, l2End: 0, l2Strength: 0, l2Amplitude: 0, l2Frequency: 0, r2Mode: .off, r2Start: 0, r2End: 0, r2Strength: 0, r2Amplitude: 0, r2Frequency: 0, ledRed: 0.0, ledGreen: 0.44, ledBlue: 0.82, isLedPulsing: false)
    ]
    
    public init() {
        GCController.shouldMonitorBackgroundEvents = true
        setupControllerDiscovery()
        setupBluetoothHID()
        startPolling()
        loadTouchpadActions()
        loadAppProfiles()
    }

    /// Graceful teardown for app termination: stops the background keep-alive and
    /// releases the exclusive Bluetooth HID session so the controller is immediately
    /// usable by the rest of the system again.
    public func shutdown() {
        stopBackgroundTimer()
        allowAppNap()
        bluetoothHID.disconnect()
    }

    // MARK: - Bluetooth (raw HID via hidapi)

    private func setupBluetoothHID() {
        bluetoothHID.onInput = { [weak self] sample in
            self?.handleBluetoothInput(sample)
        }
        bluetoothHID.onDisconnect = { [weak self] in
            guard let self = self else { return }
            logToFile("Bluetooth HID disconnected.")
            self.backgroundQueue.async { [weak self] in
                self?.btLEDControlInitialized = false
                self?.btSequenceNumber = 0
            }
            self.buttonsPressed.removeAll()
            self.motionAttitude = GCQuaternion(x: 0, y: 0, z: 0, w: 1)
            self.refreshConnectionType()
            NotificationCenter.default.post(name: .stickyFingersStatusChanged, object: nil)
        }
    }

    /// Called every poll tick. Connects/disconnects the raw-HID Bluetooth session based
    /// on whether a BT-transport DualSense is currently enumerable — mirrors the same
    /// cadence `startPolling()` already uses for USB battery/connection refresh.
    private func refreshBluetoothConnection() {
        if bluetoothHID.isConnected {
            // Still enumerable? If not, the controller went out of range/was turned
            // off; hid_read_timeout will have already fired onDisconnect in that case.
            return
        }
        guard let path = BluetoothHIDController.findBluetoothPath() else { return }
        if bluetoothHID.connect(path: path) {
            // Queue this before the state report below so the new physical session always
            // receives the one-time LED ownership handshake and starts its sequence at zero.
            backgroundQueue.async { [weak self] in
                self?.btLEDControlInitialized = false
                self?.btSequenceNumber = 0
            }
            hasHadController = true
            refreshConnectionType()
            updateBackgroundState()
            applyTriggerSettings(log: false)
            NotificationCenter.default.post(name: .stickyFingersStatusChanged, object: nil)
        }
    }

    /// Single source of truth for `connectionType`/`isConnected`, since USB (GameController)
    /// and Bluetooth (raw HID) are now two fully independent connection paths.
    private func refreshConnectionType() {
        if bluetoothHID.isConnected {
            connectionType = "BT"
        } else if activeController != nil {
            connectionType = "USB"
        } else {
            connectionType = "Unknown"
        }
        isConnected = (activeController != nil) || bluetoothHID.isConnected
    }

    private func handleBluetoothInput(_ sample: BluetoothHIDController.InputSample) {
        if isUIVisible {
            // Publish one dictionary change per frame instead of one change per button.
            // At the controller's native report rate, the old loop could invalidate SwiftUI
            // dozens of times for a single physical sample.
            var latestButtons = sample.buttons
            latestButtons["l2"] = sample.leftTrigger > 0.05
            latestButtons["r2"] = sample.rightTrigger > 0.05
            if buttonsPressed != latestButtons {
                buttonsPressed = latestButtons
            }

            if pointChanged(from: leftStickValue, to: sample.leftStick) {
                leftStickValue = sample.leftStick
            }
            if pointChanged(from: rightStickValue, to: sample.rightStick) {
                rightStickValue = sample.rightStick
            }
            if abs(leftTriggerValue - sample.leftTrigger) >= 0.004 {
                leftTriggerValue = sample.leftTrigger
            }
            if abs(rightTriggerValue - sample.rightTrigger) >= 0.004 {
                rightTriggerValue = sample.rightTrigger
            }
            if touchpadPrimaryActive != sample.touchpadPrimaryActive {
                touchpadPrimaryActive = sample.touchpadPrimaryActive
            }
            if sample.touchpadPrimaryActive,
               pointChanged(from: touchpadPrimary, to: sample.touchpadPrimary) {
                touchpadPrimary = sample.touchpadPrimary
            }
            if touchpadSecondaryActive != sample.touchpadSecondaryActive {
                touchpadSecondaryActive = sample.touchpadSecondaryActive
            }
            if sample.touchpadSecondaryActive,
               pointChanged(from: touchpadSecondary, to: sample.touchpadSecondary) {
                touchpadSecondary = sample.touchpadSecondary
            }
        }

        // Gesture recognition remains active when the dashboard is hidden, but it no longer
        // forces the visualizer's @Published state to refresh in the background.
        if sample.touchpadPrimaryActive {
            // BT has an explicit contact bit (handled by the else branch), and (0, 0)
            // is the valid touchpad center pixel — don't treat it as a release.
            handleTouchpadUpdate(x: Float(sample.touchpadPrimary.x), y: Float(sample.touchpadPrimary.y), resetOnZero: false)
        } else if touchStart != nil {
            resetTouchpadGesture()
        }

        if batteryLevel != sample.batteryLevel {
            batteryLevel = sample.batteryLevel
        }
        let latestBatteryState: GCDeviceBattery.State =
            sample.batteryFull ? .full : (sample.batteryCharging ? .charging : .discharging)
        if batteryState != latestBatteryState {
            batteryState = latestBatteryState
        }

        // Sensors tab over Bluetooth: feed the same complementary filter the
        // GameController motion callback uses. DualSense gyro full scale is
        // ±2000 dps (16.384 LSB per dps); accel is ±4g (8192 LSB/g). Axis mapping
        // follows dualsense_input_report (x=pitch, y=yaw, z=roll) — if the on-screen
        // orientation looks mirrored on hardware, flip the offending axis sign here.
        if isSensorsTabActive && isUIVisible {
            let dpsToRad = Double.pi / 180.0
            processMotionSample(gyroX: sample.gyro.x / 16.384 * dpsToRad,
                                gyroY: sample.gyro.y / 16.384 * dpsToRad,
                                gyroZ: sample.gyro.z / 16.384 * dpsToRad,
                                accX: sample.accel.x / 8192.0,
                                accY: sample.accel.y / 8192.0,
                                accZ: sample.accel.z / 8192.0)
        }
    }

    /// Ignore one-count 8-bit stick jitter (roughly 0.0078 normalized) so an idle
    /// controller does not continuously rebuild SwiftUI.
    private func pointChanged(from old: CGPoint, to new: CGPoint) -> Bool {
        abs(old.x - new.x) >= 0.008 || abs(old.y - new.y) >= 0.008
    }

    /// A DualSense-family GCController connecting while our own raw-HID enumeration also
    /// sees a Bluetooth-transport DualSense is that same physical device — Bluetooth is now
    /// handled exclusively by `BluetoothHIDController`, so GameController must not also
    /// claim it as `activeController` (that would race for ownership). Non-DualSense
    /// controllers (Xbox, third-party, …) are never ours to ignore and must keep working
    /// through GameController even while a BT DualSense is connected.
    private func isLikelyBluetoothGCController(_ controller: GCController) -> Bool {
        // GCProductCategoryDualSenseEdge isn't exposed by the SDK we build against;
        // its productCategory string is "DualSense Edge".
        let isDualSense = controller.productCategory == GCProductCategoryDualSense
            || controller.productCategory == "DualSense Edge"
        return isDualSense && BluetoothHIDController.findBluetoothPath() != nil
    }

    public func setupControllerDiscovery() {
        if let firstController = GCController.controllers().first, !isLikelyBluetoothGCController(firstController) {
            controllerConnected(firstController)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let controller = notification.object as? GCController else { return }
            if self.isLikelyBluetoothGCController(controller) {
                self.controllers = GCController.controllers()
                return
            }
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
                self.refreshConnectionType()
                self.buttonsPressed.removeAll()
                // Always clear the cached HID device on disconnect, even in the background.
                // GameController's disconnect is often "spurious" over Bluetooth (the physical
                // connection is fine), but the underlying BT HID session frequently DOES cycle
                // at the same moment — writes against the stale cached handle right after this
                // fire and fail at the IOKit level (observed: 0x10000003 within ~30ms of the
                // background timer restarting), requiring 5 failed attempts before the old
                // failure-counter path rediscovered it. Clearing here forces the next write to
                // look the device up fresh — cheap, and immune to that staleness window.
                self.clearHIDDevice()
                self.updateBackgroundState()
                if let nextController = GCController.controllers().first(where: { $0 != controller && !self.isLikelyBluetoothGCController($0) }) {
                    self.controllerConnected(nextController)
                }
            }
            self.controllers = GCController.controllers()
            NotificationCenter.default.post(name: .stickyFingersStatusChanged, object: nil)
        }
    }
    
    public func controllerConnected(_ controller: GCController) {
        logToFile("Controller connected: \(controller.vendorName ?? "Unknown") [Category: \(controller.productCategory)]")
        self.activeController = controller
        self.hasHadController = true
        
        // Clear stale HID device cache so it's re-discovered fresh for this connection
        clearHIDDevice()
        
        updateBackgroundState()
        setupHandlers(for: controller)
        
        if controller.light == nil {
            logToFile("WARNING: controller.light is nil! App needs to run as signed macOS App Bundle (.app).")
        }
        
        // Auto-reconnect: Apply settings
        applyTriggerSettings()
        updateLed()
        
        NotificationCenter.default.post(name: .stickyFingersStatusChanged, object: nil)
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
            l2EndStrength = preset.l2EndStrength
            
            r2Mode = preset.r2Mode
            r2Start = preset.r2Start
            r2End = preset.r2End
            r2Strength = preset.r2Strength
            r2Amplitude = preset.r2Amplitude
            r2Frequency = preset.r2Frequency
            r2EndStrength = preset.r2EndStrength
        }
        
        ledColor = NSColor(red: CGFloat(preset.ledRed), green: CGFloat(preset.ledGreen), blue: CGFloat(preset.ledBlue), alpha: 1.0)
        isLedPulsing = preset.isLedPulsing
        updateLed()
    }
    
    public func setupHandlers(for controller: GCController) {
        refreshConnectionType()
        
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
                if self.buttonsPressed["l2"] != pressed {
                    self.buttonsPressed["l2"] = pressed
                }
                if abs(self.leftTriggerValue - value) >= 0.004 {
                    self.leftTriggerValue = value
                }
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, pressed) in
            guard let self = self, self.isUIVisible else { return }
            DispatchQueue.main.async {
                if self.buttonsPressed["r2"] != pressed {
                    self.buttonsPressed["r2"] = pressed
                }
                if abs(self.rightTriggerValue - value) >= 0.004 {
                    self.rightTriggerValue = value
                }
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
            let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
            DispatchQueue.main.async {
                if self.pointChanged(from: self.leftStickValue, to: point) {
                    self.leftStickValue = point
                }
            }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, x, y) in
            guard let self = self, self.isUIVisible else { return }
            let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
            DispatchQueue.main.async {
                if self.pointChanged(from: self.rightStickValue, to: point) {
                    self.rightStickValue = point
                }
            }
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
                        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                        if self.pointChanged(from: self.touchpadPrimary, to: point) {
                            self.touchpadPrimary = point
                        }
                        if !self.touchpadPrimaryActive {
                            self.touchpadPrimaryActive = true
                        }
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
                    let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    if self.pointChanged(from: self.touchpadSecondary, to: point) {
                        self.touchpadSecondary = point
                    }
                    if !self.touchpadSecondaryActive {
                        self.touchpadSecondaryActive = true
                    }
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
        let shouldBeActive = isSensorsTabActive && isUIVisible

        if shouldBeActive {
            // Reset filter states when activating. Done before the GCController guard
            // so it also applies over Bluetooth, where there is no motion object and
            // parsed input reports feed processMotionSample directly.
            self.filteredPitch = 0.0
            self.filteredRoll = 0.0
            self.filteredYaw = 0.0
            self.lastMotionTimestamp = 0.0
            self.lastMotionUIPublishTimestamp = 0.0
        }

        guard let controller = activeController else { return }
        guard let motion = controller.motion else { return }

        logToFile("updateMotionSensorsState: shouldBeActive=\(shouldBeActive), sensorsActive=\(motion.sensorsActive), hasAttitude=\(motion.hasAttitude), hasRotationRate=\(motion.hasRotationRate), hasGravity=\(motion.hasGravityAndUserAcceleration)")

        if shouldBeActive {
            motion.valueChangedHandler = { [weak self] m in
                guard let self = self else { return }
                self.processMotionSample(gyroX: Double(m.rotationRate.x),
                                         gyroY: Double(m.rotationRate.y),
                                         gyroZ: Double(m.rotationRate.z),
                                         accX: Double(m.acceleration.x),
                                         accY: Double(m.acceleration.y),
                                         accZ: Double(m.acceleration.z))
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

    /// Shared complementary-filter pipeline for motion data. Fed by either the
    /// GameController motion callback (USB) or parsed BT 0x31 input reports
    /// (Bluetooth, via `handleBluetoothInput`). `gyro*` in rad/s, `acc*` in g.
    /// Filter state is owned by whichever transport is live; only one feeds it at
    /// a time under the single-active-controller policy.
    private func processMotionSample(gyroX: Double, gyroY: Double, gyroZ: Double, accX: Double, accY: Double, accZ: Double) {
                let now: Double = ProcessInfo.processInfo.systemUptime
                let dt: Double
                if self.lastMotionTimestamp == 0.0 {
                    dt = 0.004 // Default to 250Hz dt (4ms)
                } else {
                    dt = min(0.1, now - self.lastMotionTimestamp)
                }
                self.lastMotionTimestamp = now

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
                if self.motionUpdateCount % 1000 == 0 {
                    logToFile("Motion callback \(self.motionUpdateCount): rotX=\(String(format: "%.3f", gyroX)), rotY=\(String(format: "%.3f", gyroY)), rotZ=\(String(format: "%.3f", gyroZ)) | calculatedAttitude: w=\(String(format: "%.3f", qwNorm)), x=\(String(format: "%.3f", qxNorm)), y=\(String(format: "%.3f", qyNorm)), z=\(String(format: "%.3f", qzNorm))")
                }

                // Keep the high-rate samples for filter accuracy, but do not ask SwiftUI to
                // render faster than the display. This is especially important on USB, where
                // GameController motion callbacks commonly arrive around 250 Hz.
                guard self.lastMotionUIPublishTimestamp == 0.0
                        || now - self.lastMotionUIPublishTimestamp >= (1.0 / 60.0) else {
                    return
                }
                self.lastMotionUIPublishTimestamp = now
                DispatchQueue.main.async {
                    self.motionAttitude = finalAttitude
                }
    }

    public func recenterSensors() {
        sensorReferenceOrientation = rawMotionAttitude
        logToFile("Sensors recentered to w=\(rawMotionAttitude.w), x=\(rawMotionAttitude.x), y=\(rawMotionAttitude.y), z=\(rawMotionAttitude.z)")
    }
    
    public func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.refreshBluetoothConnection()

            if let controller = self.activeController {
                // Use raw HID when backgrounded to bypass GameController framework focus restriction
                if !self.isAppInForeground {
                    self.applyTriggerSettingsViaHID()
                }
                self.refreshConnectionType()
                if let battery = controller.battery {
                    DispatchQueue.main.async {
                        self.batteryLevel = battery.batteryLevel
                        self.batteryState = battery.batteryState
                    }
                }
            }
            NotificationCenter.default.post(name: .stickyFingersStatusChanged, object: nil)
        }
    }
    
    /// Reads `device`'s own IOKit "Transport" property directly — the ground truth for which
    /// wire format (USB vs BT) an output report write must use. Returns nil if the property is
    /// missing or an unrecognized value, so the caller can fall back to its own heuristic.
    private func deviceTransportIsBluetooth(_ device: IOHIDDevice) -> Bool? {
        guard let transport = IOHIDDeviceGetProperty(device, "Transport" as CFString) as? String else { return nil }
        let t = transport.lowercased()
        if t.contains("bluetooth") || t.contains("bt") { return true }
        if t.contains("usb") { return false }
        return nil
    }

    /// Applies the current trigger (and LED) configuration to the controller.
    ///
    /// We deliberately use a SINGLE code path — raw HID output reports — for both the
    /// foreground and background cases. Apple's `GCDualSenseAdaptiveTrigger.setMode*`
    /// API only exposes three effect types (Feedback/Weapon/Vibration), so it cannot
    /// faithfully represent the full set of modes this app offers; relying on it in the
    /// foreground and on raw HID in the background made the trigger feel *change* the
    /// instant the app lost focus. Driving everything through raw HID guarantees the
    /// exact same effect whether or not the app is frontmost. (On recent macOS the
    /// `setMode*` API is additionally reported to silently no-op.)
    public func applyTriggerSettings(log: Bool = true) {
        if log {
            logToFile("applyTriggerSettings (raw HID): L2Mode=\(l2Mode) (start=\(l2Start), end=\(l2End), strength=\(l2Strength), amp=\(l2Amplitude), freq=\(l2Frequency)), R2Mode=\(r2Mode) (start=\(r2Start), end=\(r2End), strength=\(r2Strength), amp=\(r2Amplitude), freq=\(r2Frequency))")
        }
        applyTriggerSettingsViaHID()
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

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return nil
        }

        // VendorID/ProductID matching can surface more than one IOHIDDevice entry for the same
        // physical controller (e.g. a stale/ghost entry left behind by a prior connection), and
        // Set iteration order is unspecified — so blindly taking "the first one with a big
        // enough output report" can silently latch onto the WRONG entry and write into a void
        // forever (IOHIDDeviceSetReport still returns success; nothing physically happens).
        // Log every candidate so a wrong pick is visible, and prefer whichever candidate's own
        // live Transport property matches what we currently believe the connection to be.
        var candidates: [(device: IOHIDDevice, transport: String, maxOutput: Int)] = []
        for device in devices {
            let transport = (IOHIDDeviceGetProperty(device, "Transport" as CFString) as? String) ?? "?"
            let maxOutput = (IOHIDDeviceGetProperty(device, kIOHIDMaxOutputReportSizeKey as String as CFString) as? Int) ?? 0
            candidates.append((device, transport, maxOutput))
        }
        logToFile("findHIDOutputDevice: \(candidates.count) candidate(s) — " +
                  candidates.map { "[transport=\($0.transport), maxOutput=\($0.maxOutput)]" }.joined(separator: ", "))

        let eligible = candidates.filter { $0.maxOutput >= 48 }
        guard !eligible.isEmpty else {
            // No candidate declares a large-enough output report; fall back to the first match.
            guard let first = candidates.first else { return nil }
            return openAndCache(first.device, manager: manager)
        }

        let wantsBT = connectionType == "BT"
        let preferred = eligible.first { candidate in
            let t = candidate.transport.lowercased()
            return wantsBT ? (t.contains("bluetooth") || t.contains("bt")) : t.contains("usb")
        }
        let chosen = preferred ?? eligible[0]
        if eligible.count > 1 {
            logToFile("findHIDOutputDevice: chose transport=\(chosen.transport) (wantsBT=\(wantsBT)) among \(eligible.count) eligible candidates.")
        }
        return openAndCache(chosen.device, manager: manager)
    }

    /// Explicitly opens the device before caching it. IOHIDManagerOpen() only opens the
    /// MANAGER (the enumeration/matching object); it does NOT claim the individual device for
    /// I/O. Reference implementations that reliably get Bluetooth HID output working (e.g.
    /// hidapi, which SDL uses) always call IOHIDDeviceOpen() on the specific device before
    /// writing to it. Without this, IOHIDDeviceSetReport can return kIOReturnSuccess (the call
    /// itself is accepted) while the underlying transport — plausibly stricter over Bluetooth
    /// than USB's more forgiving control-transfer path — never actually delivers the report to
    /// the physical controller.
    private func openAndCache(_ device: IOHIDDevice, manager: IOHIDManager) -> IOHIDDevice? {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            logToFile("findHIDOutputDevice: IOHIDDeviceOpen failed: \(String(format: "0x%08X", result))")
        }
        if let runLoop = ensureHIDRunLoopThread() {
            IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        } else {
            logToFile("findHIDOutputDevice: failed to obtain dedicated HID run loop; writes may be unreliable over Bluetooth.")
        }
        hidManager = manager
        hidOutputDevice = device
        usbLEDControlInitialized = false
        return device
    }

    /// Starts (once) a dedicated background thread that continuously pumps its own CFRunLoop,
    /// and returns that run loop so the HID device can be scheduled on it. Blocks briefly on
    /// first call until the thread has actually captured its run loop reference.
    private func ensureHIDRunLoopThread() -> CFRunLoop? {
        if let existing = hidCFRunLoop { return existing }
        hidRunLoopShouldStop = false
        let thread = Thread { [weak self] in
            self?.hidRunLoopThreadMain()
        }
        thread.name = "com.degenerateuser.stickyfingers.hidRunLoop"
        thread.start()
        hidRunLoopThread = thread
        hidRunLoopReadySemaphore.wait()
        return hidCFRunLoop
    }

    private func hidRunLoopThreadMain() {
        hidCFRunLoop = CFRunLoopGetCurrent()
        hidRunLoopReadySemaphore.signal()
        while !hidRunLoopShouldStop {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1.0, false)
        }
    }

    /// Releases the cached HID device handle. The device handle, manager and BT sequence
    /// number are all owned by `backgroundQueue`, so teardown is serialized there to avoid
    /// racing with an in-flight `sendOutputReportOnQueue`. Safe to call from any thread.
    public func clearHIDDevice() {
        backgroundQueue.async { [weak self] in
            self?.clearHIDDeviceOnQueue()
        }
    }

    /// Queue-local teardown. MUST be called on `backgroundQueue`.
    private func clearHIDDeviceOnQueue() {
        if let device = hidOutputDevice {
            if let runLoop = hidCFRunLoop {
                IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
            }
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidOutputDevice = nil
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
        usbLEDControlInitialized = false
    }
    
    // MARK: Trigger effect byte encoding
    //
    // Mode bytes and parameter layouts follow Nielk1's `TriggerEffectGenerator.cs`
    // (Rev 6) — the de-facto reference also used by the Linux `hid-playstation`
    // driver. Positions are quantised to 10 zones (0–9). Per-zone strengths are 1–8
    // stored as `(v-1) & 0x07`. Galloping feet and Machine amplitudes are stored RAW
    // (`& 0x07`, no minus-one). Frequency/period are raw bytes (0–255).
    //
    // `params` indices here are zero-based relative to the FIRST byte after the mode
    // byte, i.e. `params[0]` is reference block byte [1].

    /// Quantises a 0…1 slider into a 0…9 trigger zone, clamped to [lo, hi].
    private func zone(_ value: Float, lo: Int = 0, hi: Int = 9) -> Int {
        return min(hi, max(lo, Int(round(value * 9.0))))
    }

    /// Quantises a 0…1 slider into a 1…8 strength level (1 = lightest, 8 = strongest).
    private func level(_ value: Float) -> Int {
        return min(8, max(1, Int(round(value * 7.0)) + 1))
    }

    /// Quantises a 0…1 slider into a raw frequency/period byte (1…255).
    private func freqByte(_ value: Float) -> UInt8 {
        return UInt8(clamping: max(1, Int(round(value * 255.0))))
    }

    /// Packs a start and end zone into the little-endian uint16 "start & stop" bitmask
    /// used by Weapon/Bow/Galloping/Machine effects: one bit set at `start`, one at `end`.
    private func startStopZones(start: Int, end: Int) -> (UInt8, UInt8) {
        let zones = (1 << start) | (1 << end)
        return (UInt8(zones & 0xFF), UInt8((zones >> 8) & 0xFF))
    }

    private func triggerModeToHIDBytes(mode: TriggerMode, start: Float, end: Float, strength: Float, amplitude: Float, frequency: Float, endStrength: Float = 0) -> (mode: UInt8, params: [UInt8]) {
        var params = [UInt8](repeating: 0, count: 10)
        switch mode {
        case .off:
            return (0x05, params) // DS_TRIGGER_EFFECT_OFF

        case .feedback:
            // 0x21: continuous resistance from `start` to the end of travel.
            let pos = zone(start)
            let strengthVal = level(strength)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 { strengthArray[i] = UInt8(strengthVal) }
            return bitpackTriggerArray(mode: 0x21, strengthArray: strengthArray, frequency: 0)

        case .weapon:
            // 0x25: a resistance wall between start and end that "breaks" (snaps) when
            // pushed past end — a firearm trigger pull. start∈[2,7], end∈[start+1,8].
            let startPos = zone(start, lo: 2, hi: 7)
            let endPos = min(8, max(startPos + 1, zone(end)))
            let strengthVal = level(strength)
            (params[0], params[1]) = startStopZones(start: startPos, end: endPos)
            params[2] = UInt8(strengthVal - 1)
            return (0x25, params)

        case .vibration:
            // 0x26: zone-based vibration from `start` onward; frequency at block byte 9.
            let pos = zone(start)
            let ampVal = level(amplitude)
            let freqVal = freqByte(frequency)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 { strengthArray[i] = UInt8(ampVal) }
            return bitpackTriggerArray(mode: 0x26, strengthArray: strengthArray, frequency: freqVal)

        case .sectionResistance:
            // 0x21: resistance only within the start..end zone — none outside it.
            let startPos = zone(start)
            let endPos = max(startPos, zone(end))
            let strengthVal = level(strength)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in startPos...endPos { strengthArray[i] = UInt8(strengthVal) }
            return bitpackTriggerArray(mode: 0x21, strengthArray: strengthArray, frequency: 0)

        case .semiAutomatic:
            // 0x22 (Bow): a resistance wall that holds, then snaps back hard once past
            // end — the semi-auto / bow-draw feel. start∈[0,8], end∈[start+1,8].
            // params[2] packs resistance strength (low 3 bits) | snap force (next 3 bits).
            // `endStrength` slider doubles as snap force here.
            let startPos = zone(start, lo: 0, hi: 8)
            let endPos = min(8, max(startPos + 1, zone(end)))
            let strengthVal = level(strength)
            let snapVal = level(endStrength == 0 ? strength : endStrength)
            (params[0], params[1]) = startStopZones(start: startPos, end: endPos)
            params[2] = UInt8(((strengthVal - 1) & 0x07) | (((snapVal - 1) & 0x07) << 3))
            return (0x22, params)

        case .automatic:
            // 0x27 (Machine): continuous two-state oscillation between start and end —
            // the automatic-weapon bucking. amplitudes are raw 0–7 (no minus-one).
            // params[3]=frequency, params[4]=period.
            let startPos = zone(start, lo: 0, hi: 8)
            let endPos = min(9, max(startPos + 1, zone(end)))
            let ampA = min(7, max(0, Int(round(strength * 7.0))))
            let ampB = max(0, ampA - 2) // softer return stroke for a bucking texture
            let freqVal = freqByte(frequency)
            let periodVal: UInt8 = 0x0A // ~1.0s default cadence (tenths of a second)
            (params[0], params[1]) = startStopZones(start: startPos, end: endPos)
            params[2] = UInt8((ampA & 0x07) | ((ampB & 0x07) << 3))
            params[3] = freqVal
            params[4] = periodVal
            return (0x27, params)

        case .slopeFeedback:
            // 0x21 with a gradient: strength ramps from `strength` to `endStrength`
            // across the start..end range — a progressive brake.
            let startPos = zone(start, lo: 0, hi: 8)
            let endPos = min(9, max(startPos + 1, zone(end)))
            let startStrengthVal = level(strength)
            let endStrengthVal = level(endStrength)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            let range = endPos - startPos
            for i in startPos...endPos {
                let t = range > 0 ? Float(i - startPos) / Float(range) : 1.0
                let interpolated = Float(startStrengthVal) + t * Float(endStrengthVal - startStrengthVal)
                strengthArray[i] = UInt8(max(1, min(8, Int(round(interpolated)))))
            }
            return bitpackTriggerArray(mode: 0x21, strengthArray: strengthArray, frequency: 0)

        case .multiPositionFeedback:
            // 0x21 with alternating strong/weak zones — a bumpy, textured resistance.
            let pos = zone(start)
            let strengthVal = level(strength)
            let weakVal = max(1, strengthVal / 2)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 { strengthArray[i] = (i % 2 == 0) ? UInt8(strengthVal) : UInt8(weakVal) }
            return bitpackTriggerArray(mode: 0x21, strengthArray: strengthArray, frequency: 0)

        case .multiPositionVibration:
            // 0x26 with alternating amplitude zones — a textured vibration.
            let pos = zone(start)
            let ampVal = level(amplitude)
            let weakAmp = max(1, ampVal / 2)
            let freqVal = freqByte(frequency)
            var strengthArray = [UInt8](repeating: 0, count: 10)
            for i in pos..<10 { strengthArray[i] = (i % 2 == 0) ? UInt8(ampVal) : UInt8(weakAmp) }
            return bitpackTriggerArray(mode: 0x26, strengthArray: strengthArray, frequency: freqVal)

        case .fullPress:
            // 0x21 at maximum strength across the whole travel.
            return bitpackTriggerArray(mode: 0x21, strengthArray: [8, 8, 8, 8, 8, 8, 8, 8, 8, 8], frequency: 0)
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
        
        // Layout per ExtendInput reference (Nielk1/TriggerEffectGenerator.cs):
        // params[0]   = activeZones low byte
        // params[1]   = activeZones high byte
        // params[2-5] = strengthZones packed (10 zones × 3 bits = 30 bits in UInt32)
        // params[6]   = 0x00 (unused upper strength bits)
        // params[7]   = 0x00 (unused upper strength bits)
        // params[8]   = frequency (for Vibration mode 0x26; 0 for Feedback mode 0x21)
        // params[9]   = 0x00
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
        let r2HID = triggerModeToHIDBytes(mode: r2Mode, start: r2Start, end: r2End, strength: r2Strength, amplitude: r2Amplitude, frequency: r2Frequency, endStrength: r2EndStrength)
        let l2HID = triggerModeToHIDBytes(mode: l2Mode, start: l2Start, end: l2End, strength: l2Strength, amplitude: l2Amplitude, frequency: l2Frequency, endStrength: l2EndStrength)
        
        // Get LED color components
        var ledR: CGFloat = 0, ledG: CGFloat = 0, ledB: CGFloat = 0, ledA: CGFloat = 0
        if let srgb = ledColor.usingColorSpace(.sRGB) {
            srgb.getRed(&ledR, green: &ledG, blue: &ledB, alpha: &ledA)
        } else {
            ledColor.getRed(&ledR, green: &ledG, blue: &ledB, alpha: &ledA)
        }
        
        var finalR = UInt8(clamping: Int(round(ledR * 255)))
        var finalG = UInt8(clamping: Int(round(ledG * 255)))
        var finalB = UInt8(clamping: Int(round(ledB * 255)))
        
        if isLedPulsing {
            let t = Date().timeIntervalSince1970
            let breath = (sin(t * 2.5) + 1.0) / 2.0
            let factor = CGFloat(0.15 + breath * 0.85)
            finalR = UInt8(clamping: Int(round(ledR * factor * 255)))
            finalG = UInt8(clamping: Int(round(ledG * factor * 255)))
            finalB = UInt8(clamping: Int(round(ledB * factor * 255)))
        }

        // Snapshot all remaining @Published hardware state on the caller's thread. TESTING
        // captures and production reports deliberately consume the exact same values.
        let rumbleR = rumbleRightIntensity
        let rumbleL = rumbleLeftIntensity
        let mic = micLEDState
        let players = playerLEDs & 0x1F
        let connType = connectionType
        let audioHapticsEnabled = audioHapticsModeEnabled
        let audioState: ControllerAudioHIDState? = controllerAudioControlsEnabled
            ? ControllerAudioHIDState(
                outputRoute: controllerAudioOutputRoute,
                inputRoute: controllerAudioInputRoute,
                headphoneVolume: controllerHeadphoneVolume,
                speakerVolume: controllerSpeakerVolume,
                microphoneVolume: controllerMicrophoneVolume,
                microphoneMuted: controllerMicrophoneMuted
            )
            : nil
        
        #if TESTING
        if mockHIDMode {
            if mockHIDTransport.lowercased().contains("bluetooth") || mockHIDTransport.lowercased().contains("bt") {
                _ = captureBTReport(r2: r2HID, l2: l2HID,
                                    ledR: finalR, ledG: finalG, ledB: finalB,
                                    rumbleR: rumbleR, rumbleL: rumbleL,
                                    mic: mic, players: players)
            } else {
                _ = captureUSBReport(r2: r2HID, l2: l2HID,
                                     ledR: finalR, ledG: finalG, ledB: finalB,
                                     rumbleR: rumbleR, rumbleL: rumbleL,
                                     mic: mic, players: players, audio: audioState,
                                     audioHapticsEnabled: audioHapticsEnabled)
            }
            return
        }
        #endif
        
        // Snapshot the remaining @Published hardware state on the caller's thread, then
        // hand the blocking IOHIDDeviceSetReport off to the serial backgroundQueue so a
        // stalled Bluetooth write can never freeze the UI. All device-handle access and
        // btSequenceNumber mutation happen exclusively on backgroundQueue.
        //
        // Note: we intentionally do NOT guard on activeController. When backgrounded,
        // GameController may nil it out, but the IOKit HID device is independent and we
        // still need to keep re-applying settings.
        // Coalesce: skip if writes are already backed up (stalled BT write), so we never
        // grow an unbounded backlog. The next tick will send the latest state.
        pendingSendLock.lock()
        if pendingSendCount >= maxPendingSends {
            pendingSendLock.unlock()
            return
        }
        pendingSendCount += 1
        pendingSendLock.unlock()

        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.pendingSendLock.lock()
                self.pendingSendCount -= 1
                self.pendingSendLock.unlock()
            }
            self.sendOutputReportOnQueue(r2: r2HID, l2: l2HID,
                                         ledR: finalR, ledG: finalG, ledB: finalB,
                                         rumbleR: rumbleR, rumbleL: rumbleL,
                                         mic: mic, players: players, audio: audioState,
                                         audioHapticsEnabled: audioHapticsEnabled,
                                         connectionType: connType)
        }
    }

    /// Performs the actual blocking HID write. MUST be called on `backgroundQueue` only —
    /// it owns the device handle, the BT sequence counter, and the failure-tolerance state.
    private func sendOutputReportOnQueue(r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]),
                                         ledR: UInt8, ledG: UInt8, ledB: UInt8,
                                         rumbleR: UInt8, rumbleL: UInt8, mic: UInt8, players: UInt8,
                                         audio: ControllerAudioHIDState?,
                                         audioHapticsEnabled: Bool,
                                         connectionType: String) {
        if bluetoothHID.isConnected {
            if !btLEDControlInitialized {
                // Sony's startup animation owns the LEDs. Match hid-playstation: send a
                // dedicated LIGHT_OUT setup packet first, then program RGB/player LEDs in
                // a separate normal state packet. Combining both commands makes firmware
                // process setup and ignore the LED values.
                let setupReport = buildBTLEDSetupReport()
                guard bluetoothHID.write(setupReport) else {
                    logToFile("HID LED setup report failed over Bluetooth (hidapi hid_write).")
                    return
                }
                btLEDControlInitialized = true
                logToFile("HID: Bluetooth LED control initialized.")
                usleep(10_000)
            }

            let report = buildBTOutputReport(r2: r2, l2: l2, ledR: ledR, ledG: ledG, ledB: ledB, rumbleR: rumbleR, rumbleL: rumbleL, mic: mic, players: players)
            if !bluetoothHID.write(report) {
                logToFile("HID output report failed over Bluetooth (hidapi hid_write).")
            }
            return
        }

        guard let device = findHIDOutputDevice() else {
            if !lastHIDErrorLogged {
                logToFile("HID: Could not find DualSense HID output device")
                lastHIDErrorLogged = true
            }
            return
        }

        // Bluetooth is handled earlier (via `bluetoothHID`) and returns before reaching here, so
        // in practice `device` is always the USB IOKit handle. This transport check is kept as a
        // safety net for the brief window before our exclusive hidapi BT connection is
        // established, where a BT device might still be visible through the old shared
        // IOHIDManager enumeration below.
        let isBT = deviceTransportIsBluetooth(device) ?? (connectionType == "BT")

        // IOHIDDeviceSetReport returns transient errors, especially over Bluetooth, where the
        // L2CAP output channel briefly congests (0xE00002BC kIOReturnError / 0xE00002BD
        // kIOReturnNoMemory). In the foreground a setting change fires exactly ONE write with
        // no re-send, so a single transient failure silently drops the (idempotent) trigger/
        // LED/rumble report — which is why these felt dead over BT while USB, whose writes
        // essentially never fail, worked. Retry a few times with a tiny backoff so a transient
        // error doesn't lose the report. Runs on the serial backgroundQueue, so the short
        // usleep never touches the main thread. On USB this succeeds on attempt 1 (no change).
        func writeWithRetry(_ report: [UInt8], purpose: String) -> IOReturn {
            var result: IOReturn = kIOReturnError
            let maxAttempts = 4
            for attempt in 1...maxAttempts {
                result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
                if result == kIOReturnSuccess {
                    if attempt > 1 {
                        logToFile("HID \(purpose) write recovered on attempt \(attempt) (connType: \(connectionType)).")
                    }
                    return result
                }
                if attempt < maxAttempts {
                    usleep(useconds_t(attempt * 2000)) // 2ms, 4ms, 6ms backoff
                }
            }
            return result
        }

        var failedPurpose = "state"
        var result: IOReturn = kIOReturnSuccess
        let needsLEDSetup = isBT ? !btLEDControlInitialized : !usbLEDControlInitialized
        if needsLEDSetup {
            failedPurpose = "LED setup"
            let setupReport = isBT ? buildBTLEDSetupReport() : buildUSBLEDSetupReport()
            result = writeWithRetry(setupReport, purpose: failedPurpose)
            if result == kIOReturnSuccess {
                if isBT {
                    btLEDControlInitialized = true
                } else {
                    usbLEDControlInitialized = true
                }
                logToFile("HID: \(isBT ? "Bluetooth" : "USB") LED control initialized.")
                usleep(10_000)
            }
        }

        if result == kIOReturnSuccess {
            failedPurpose = "state"
            let report = isBT
                ? buildBTOutputReport(r2: r2, l2: l2, ledR: ledR, ledG: ledG, ledB: ledB, rumbleR: rumbleR, rumbleL: rumbleL, mic: mic, players: players)
                : buildUSBOutputReport(r2: r2, l2: l2, ledR: ledR, ledG: ledG, ledB: ledB, rumbleR: rumbleR, rumbleL: rumbleL, mic: mic, players: players, audio: audio, audioHapticsEnabled: audioHapticsEnabled)
            result = writeWithRetry(report, purpose: failedPurpose)
        }

        if result == kIOReturnSuccess {
            consecutiveHIDFailures = 0
            lastHIDErrorLogged = false
            return
        }

        // A single failed SetReport is normal — transient errors like 0xE00002BC occur a
        // few percent of the time and the data usually still lands. Only after several
        // CONSECUTIVE failures do we assume the handle is stale and re-discover it. We do
        // NOT reset btSequenceNumber on a transient failure (only on a real re-discovery),
        // because gratuitously resetting the sequence makes the controller drop reports.
        consecutiveHIDFailures += 1
        if !lastHIDErrorLogged {
            logToFile("HID \(failedPurpose) report failed: \(String(format: "0x%08X", result)) (connType: \(connectionType), consecutive: \(consecutiveHIDFailures))")
        }

        if consecutiveHIDFailures >= maxConsecutiveHIDFailures {
            logToFile("HID: \(consecutiveHIDFailures) consecutive failures — re-discovering device.")
            clearHIDDeviceOnQueue()
            btSequenceNumber = 0
            consecutiveHIDFailures = 0
        }
        lastHIDErrorLogged = true
    }

    private func buildUSBOutputReport(r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]), ledR: UInt8, ledG: UInt8, ledB: UInt8, rumbleR: UInt8, rumbleL: UInt8, mic: UInt8, players: UInt8, audio: ControllerAudioHIDState?, audioHapticsEnabled: Bool) -> [UInt8] {
        // macOS exposes IOHIDMaxOutputReportSize=48 for DualSense USB. Every used field
        // ends at byte 47, so sending Linux's padded 63-byte buffer violates the descriptor
        // for no benefit and can make IOHIDDeviceSetReport reject an otherwise valid packet.
        var report = [UInt8](repeating: 0, count: 48)
        report[0] = 0x02  // USB Report ID
        // valid_flag0: compatible vibration + HAPTICS_SELECT + R2/L2 trigger motors.
        // Linux explicitly describes HAPTICS_SELECT as "Select classic rumble style haptics
        // and enable it." Removing bit 1 caused the confirmed USB rumble regression.
        // Bit 1 selects classic rumble instead of PCM haptics. Clear it only while a
        // USB audio-haptics stream is active; bit 0 performs the graceful handoff.
        report[1] = 0x01 | (audioHapticsEnabled ? 0x00 : 0x02) | 0x04 | 0x08
        // valid_flag1: bit 0 = mic LED, bit 2 = lightbar RGB, bit 4 = player LEDs.
        report[2] = 0x01 | 0x04 | 0x10

        // Rumble motors (bytes 3-4)
        report[3] = audioHapticsEnabled ? 0 : rumbleR
        report[4] = audioHapticsEnabled ? 0 : rumbleL

        // Mic LED (byte 9): 0x00 = off, 0x01 = on, 0x02 = pulse
        report[9] = mic

        report[11] = r2.mode
        for i in 0..<min(r2.params.count, 10) {
            report[12 + i] = r2.params[i]
        }

        report[22] = l2.mode
        for i in 0..<min(l2.params.count, 10) {
            report[23 + i] = l2.params[i]
        }

        // valid_flag2: COMPATIBLE_VIBRATION2. LED setup is intentionally absent here:
        // firmware requires it as a separate one-time report before normal LED state.
        report[39] = audioHapticsEnabled ? 0x00 : 0x04
        // Player indicator LEDs (byte 44)
        report[44] = players
        report[45] = ledR
        report[46] = ledG
        report[47] = ledB

        if let audio = audio {
            // valid_flag0 audio bits: headphone volume, speaker volume, microphone
            // volume, and route control. Existing rumble/trigger flags remain set.
            report[1] |= 0x10 | 0x20 | 0x40 | 0x80
            // Power-save control lets an explicit zero clear a previous microphone mute.
            // Audio-control2 enables the controller speaker pre-gain byte at offset 38.
            report[2] |= 0x02 | 0x80

            let headphone = max(0.0, min(1.0, audio.headphoneVolume))
            let speaker = max(0.0, min(1.0, audio.speakerVolume))
            let microphone = max(0.0, min(1.0, audio.microphoneVolume))
            report[5] = UInt8(clamping: Int(round(headphone * 127.0)))
            report[6] = UInt8(clamping: Int(round(speaker * 100.0)))
            report[7] = UInt8(clamping: Int(round(microphone * 64.0)))
            report[8] = audio.outputRoute.rawValue | audio.inputRoute.rawValue
            report[10] = audio.microphoneMuted ? 0x10 : 0x00
            report[38] = 0x02
        }

        return report
    }

    /// One-time software-LED ownership handshake, matching dualsense_reset_leds() in
    /// Linux hid-playstation. It must be sent separately from RGB/player LED state.
    private func buildUSBLEDSetupReport() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 48)
        report[0] = 0x02
        report[39] = 0x02  // LIGHTBAR_SETUP_CONTROL_ENABLE
        report[42] = 0x02  // LIGHT_OUT: end hardware startup animation/release LED control
        return report
    }

    private func buildBTOutputReport(r2: (mode: UInt8, params: [UInt8]), l2: (mode: UInt8, params: [UInt8]), ledR: UInt8, ledG: UInt8, ledB: UInt8, rumbleR: UInt8, rumbleL: UInt8, mic: UInt8, players: UInt8) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 78)
        report[0] = 0x31  // BT Report ID
        // seq_tag: high nibble = sequence number (increments every report), low nibble =
        // tag, which must be 0 per hid-playstation.c / dualsensectl ("Lowest 4-bit is tag
        // and can be zero for now"). A nonzero tag risks the firmware dropping the report.
        report[1] = btSequenceNumber << 4
        btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F
        report[2] = 0x10  // BT tag (DS_OUTPUT_TAG — required, exact meaning unclear)

        // Preserve the hardware-confirmed trigger flags and enable classic rumble haptics.
        report[3] = 0x01 | 0x02 | 0x04 | 0x08
        // valid_flag1: bit 0 = mic LED, bit 2 = lightbar RGB, bit 4 = player LEDs.
        // bit 2 (0x04, LIGHTBAR_CONTROL_ENABLE) is REQUIRED for the RGB bytes below to take effect.
        report[4] = 0x01 | 0x04 | 0x10

        // Rumble motors (bytes 5-6 in BT, offset +2 from USB)
        report[5] = rumbleR
        report[6] = rumbleL

        // Mic LED (byte 11 in BT)
        report[11] = mic

        report[13] = r2.mode
        for i in 0..<min(r2.params.count, 10) {
            report[14 + i] = r2.params[i]
        }

        report[24] = l2.mode
        for i in 0..<min(l2.params.count, 10) {
            report[25 + i] = l2.params[i]
        }

        // COMPATIBLE_VIBRATION2 only. LED setup is a separate one-time report.
        report[41] = 0x04
        // Player indicator LEDs (byte 46 in BT)
        report[46] = players
        report[47] = ledR
        report[48] = ledG
        report[49] = ledB

        let crc = computeBTCRC32(Array(report[0..<74]))
        report[74] = UInt8(crc & 0xFF)
        report[75] = UInt8((crc >> 8) & 0xFF)
        report[76] = UInt8((crc >> 16) & 0xFF)
        report[77] = UInt8((crc >> 24) & 0xFF)

        return report
    }

    private func buildBTLEDSetupReport() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 78)
        report[0] = 0x31
        report[1] = btSequenceNumber << 4
        btSequenceNumber = (btSequenceNumber &+ 1) & 0x0F
        report[2] = 0x10
        report[41] = 0x02  // LIGHTBAR_SETUP_CONTROL_ENABLE
        report[44] = 0x02  // LIGHT_OUT: end hardware startup animation/release LED control

        let crc = computeBTCRC32(Array(report[0..<74]))
        report[74] = UInt8(crc & 0xFF)
        report[75] = UInt8((crc >> 8) & 0xFF)
        report[76] = UInt8((crc >> 16) & 0xFF)
        report[77] = UInt8((crc >> 24) & 0xFF)
        return report
    }
    
    /// Sends a HID report carrying the current rumble, mic LED, and player LED state. Raw HID
    /// now handles both transports directly (see `sendOutputReportOnQueue`), so there's no
    /// separate Bluetooth path anymore.
    public func applyHardwareState() {
        applyTriggerSettingsViaHID()
    }

    /// Re-applies the lightbar colour via the same raw-HID output report used for triggers/
    /// rumble/player LEDs, on whichever transport is currently connected.
    public func updateLed() {
        pulsingTimer?.invalidate()
        pulsingTimer = nil

        if isLedPulsing {
            // The breathing factor is computed from the wall clock each tick, so we just need
            // to re-send on a cadence to animate it. Ten updates/second is smooth for a slow
            // light fade and halves the previous HID/CRC workload.
            pulsingTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
                self?.applyTriggerSettingsViaHID()
            }
        }
        // Send one update immediately so a static colour change applies at once.
        applyTriggerSettingsViaHID()
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
    
    /// `resetOnZero` exists for the GameController path, which has no explicit
    /// finger-lift event and treats a (0, 0) report as release. The Bluetooth path
    /// has a real contact bit, and (0, 0) is the valid touchpad center pixel there.
    public func handleTouchpadUpdate(x: Float, y: Float, resetOnZero: Bool = true) {
        if resetOnZero && x == 0 && y == 0 {
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
