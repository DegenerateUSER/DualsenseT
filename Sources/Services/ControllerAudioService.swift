import Foundation
import Combine
import CoreAudio
import AudioToolbox
import AVFAudio
import CoreMedia

public enum ControllerAudioOutputRoute: UInt8, CaseIterable, Identifiable {
    case headphones = 0x00
    case monoHeadphones = 0x10
    case splitHeadphonesAndSpeaker = 0x20
    case controllerSpeaker = 0x30

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .headphones: return "Headset (Stereo)"
        case .monoHeadphones: return "Headset (Mono)"
        case .splitHeadphonesAndSpeaker: return "Headset L + Speaker R"
        case .controllerSpeaker: return "Controller Speaker"
        }
    }
}

public enum ControllerAudioInputRoute: UInt8, CaseIterable, Identifiable {
    case automatic = 0x00
    case headsetMicrophone = 0x40
    case controllerMicrophone = 0x80

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic / Both"
        case .headsetMicrophone: return "Headset Microphone"
        case .controllerMicrophone: return "Controller Microphone"
        }
    }
}

public struct ControllerAudioDeviceInfo: Equatable {
    public let outputDeviceID: AudioDeviceID
    public let inputDeviceID: AudioDeviceID?
    public let outputUID: String
    public let inputUID: String?
    public let name: String
    public let manufacturer: String
    public let outputChannels: Int
    public let inputChannels: Int
    public let sampleRate: Double
    public let channelLayoutTag: AudioChannelLayoutTag?
    public let channelLayoutSettable: Bool

    public var isQuadraphonic: Bool {
        channelLayoutTag == kAudioChannelLayoutTag_Quadraphonic
    }

    public var channelLayoutName: String {
        guard let tag = channelLayoutTag else { return "Not reported" }
        switch tag {
        case kAudioChannelLayoutTag_Quadraphonic:
            return "Quadraphonic (L, R, Haptic L, Haptic R)"
        case kAudioChannelLayoutTag_Stereo:
            return "Stereo (haptic channels unavailable)"
        default:
            return String(format: "CoreAudio tag 0x%08X", tag)
        }
    }
}

public final class ControllerAudioService: ObservableObject {
    @Published public private(set) var deviceInfo: ControllerAudioDeviceInfo?
    @Published public private(set) var statusMessage = "Connect the controller by USB, then refresh."
    @Published public private(set) var lastError: String?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var activeTestChannel: Int?
    @Published public private(set) var isAudioHapticsRunning = false
    @Published public private(set) var audioHapticsStatus = "Audio haptics are stopped."
    @Published public var audioHapticsIntensity: Double = 0.72
    @Published public private(set) var hapticInputFormat = "Waiting for captured PCM…"
    @Published public private(set) var hapticProcessedBuffers = 0
    @Published public private(set) var hapticDroppedBuffers = 0
    @Published public private(set) var hapticOutputLevel: Float = 0

    private var testEngine: AVAudioEngine?
    private var testSourceNode: AVAudioSourceNode?
    private var testStopWorkItem: DispatchWorkItem?
    private var hapticsEngine: AVAudioEngine?
    private var hapticsPlayer: AVAudioPlayerNode?
    private var hapticsFormat: AVAudioFormat?
    private weak var hapticsCaptureService: SystemAudioCaptureService?
    private let scheduledBufferLock = NSLock()
    private var scheduledBufferCount = 0
    private var hapticLowPassHigh: (Float, Float) = (0, 0)
    private var hapticLowPassLow: (Float, Float) = (0, 0)
    private var processedBufferCounter = 0
    private var droppedBufferCounter = 0
    private var hapticInputFormatSnapshot = "Waiting for captured PCM…"
    private var lastHapticDiagnosticsDelivery: UInt64 = 0
    private var hasReportedHapticPipelineError = false

    public init() {
        refresh()
    }

    public var isConnected: Bool {
        deviceInfo != nil
    }

    public var isPlayingTestTone: Bool {
        activeTestChannel != nil
    }

    /// Re-enumerates CoreAudio. macOS publishes the DualSense input and output endpoints as
    /// separate AudioDeviceIDs with the same display name, so we pair them by Sony/name/USB.
    public func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }

        lastError = nil
        guard let deviceIDs = Self.allAudioDeviceIDs() else {
            deviceInfo = nil
            statusMessage = "CoreAudio device enumeration failed."
            lastError = statusMessage
            return
        }

        var outputMatch: AudioDeviceID?
        var inputMatch: AudioDeviceID?

        for deviceID in deviceIDs {
            let name = Self.stringProperty(
                deviceID,
                selector: kAudioObjectPropertyName
            ) ?? ""
            let manufacturer = Self.stringProperty(
                deviceID,
                selector: kAudioObjectPropertyManufacturer
            ) ?? ""
            let transport = Self.uint32Property(
                deviceID,
                selector: kAudioDevicePropertyTransportType
            ) ?? 0
            let outputChannels = Self.channelCount(deviceID, scope: kAudioDevicePropertyScopeOutput)
            let inputChannels = Self.channelCount(deviceID, scope: kAudioDevicePropertyScopeInput)

            guard Self.isDualSenseAudioDevice(
                name: name,
                manufacturer: manufacturer,
                transportType: transport
            ) else { continue }

            if outputChannels >= 4 {
                outputMatch = deviceID
            }
            if inputChannels >= 1 {
                inputMatch = deviceID
            }
        }

        guard let outputDeviceID = outputMatch else {
            deviceInfo = nil
            statusMessage = "No four-channel DualSense USB audio output found."
            return
        }

        let name = Self.stringProperty(
            outputDeviceID,
            selector: kAudioObjectPropertyName
        ) ?? "DualSense Wireless Controller"
        let manufacturer = Self.stringProperty(
            outputDeviceID,
            selector: kAudioObjectPropertyManufacturer
        ) ?? "Sony Interactive Entertainment"
        let outputUID = Self.stringProperty(
            outputDeviceID,
            selector: kAudioDevicePropertyDeviceUID
        ) ?? "unknown-output-uid"
        let inputUID = inputMatch.flatMap {
            Self.stringProperty($0, selector: kAudioDevicePropertyDeviceUID)
        }
        let outputChannels = Self.channelCount(
            outputDeviceID,
            scope: kAudioDevicePropertyScopeOutput
        )
        let inputChannels = inputMatch.map {
            Self.channelCount($0, scope: kAudioDevicePropertyScopeInput)
        } ?? 0
        let sampleRate = Self.float64Property(
            outputDeviceID,
            selector: kAudioDevicePropertyNominalSampleRate
        ) ?? 0
        let layoutTag = Self.preferredChannelLayoutTag(outputDeviceID)
        let settable = Self.isPreferredChannelLayoutSettable(outputDeviceID)

        deviceInfo = ControllerAudioDeviceInfo(
            outputDeviceID: outputDeviceID,
            inputDeviceID: inputMatch,
            outputUID: outputUID,
            inputUID: inputUID,
            name: name,
            manufacturer: manufacturer,
            outputChannels: outputChannels,
            inputChannels: inputChannels,
            sampleRate: sampleRate,
            channelLayoutTag: layoutTag,
            channelLayoutSettable: settable
        )
        statusMessage = layoutTag == kAudioChannelLayoutTag_Quadraphonic
            ? "DualSense USB audio is ready for four-channel output."
            : "DualSense found. Configure Quadraphonic mode before enabling audio haptics."
    }

    /// Matches the four-channel USB endpoint without depending on a localized exact name.
    public static func isDualSenseAudioDevice(
        name: String,
        manufacturer: String,
        transportType: UInt32
    ) -> Bool {
        let normalizedName = name.lowercased()
        let normalizedManufacturer = manufacturer.lowercased()
        let isSonyController =
            normalizedName.contains("dualsense")
            && (normalizedManufacturer.contains("sony")
                || normalizedManufacturer.contains("interactive entertainment"))
        return isSonyController && transportType == kAudioDeviceTransportTypeUSB
    }

    /// Sets the persistent Audio MIDI speaker configuration to L/R/Ls/Rs. Channels 3 and 4
    /// are the DualSense left/right haptic actuators. This changes no system default device.
    public func configureQuadraphonic() {
        guard let info = deviceInfo else {
            lastError = "Connect a DualSense controller through USB first."
            return
        }
        guard info.outputChannels >= 4 else {
            lastError = "The selected controller endpoint does not expose four output channels."
            return
        }
        guard info.channelLayoutSettable else {
            lastError = "macOS reports that this device's speaker layout is read-only. Configure it in Audio MIDI Setup."
            return
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelLayout,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            info.outputDeviceID, &address, 0, nil, &dataSize
        ) == noErr, dataSize >= MemoryLayout<AudioChannelLayout>.size else {
            lastError = "CoreAudio did not provide a writable channel-layout size."
            return
        }

        // AppleUSBAudio requires the property's advertised buffer size (which includes its
        // current channel descriptions), even when the replacement uses a predefined tag
        // with zero descriptions. Passing only MemoryLayout<AudioChannelLayout>.size returns
        // kAudioHardwareBadPropertySizeError ('!siz').
        let memory = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioChannelLayout>.alignment
        )
        defer { memory.deallocate() }
        memory.initializeMemory(as: UInt8.self, repeating: 0, count: Int(dataSize))
        let layout = memory.bindMemory(to: AudioChannelLayout.self, capacity: 1)
        layout.pointee.mChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic
        layout.pointee.mChannelBitmap = AudioChannelBitmap(rawValue: 0)
        layout.pointee.mNumberChannelDescriptions = 0

        let status = AudioObjectSetPropertyData(
            info.outputDeviceID,
            &address,
            0,
            nil,
            dataSize,
            memory
        )

        guard status == noErr else {
            let message = "Failed to set Quadraphonic layout (\(Self.describe(status)))."
            lastError = message
            statusMessage = message
            return
        }

        lastError = nil
        statusMessage = "Quadraphonic layout applied. Verifying with CoreAudio…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refresh()
        }
    }

    /// Sends a short isolated tone directly to one physical output without changing the
    /// system default device. Channels are one-based: 1/2 audible, 3/4 haptic actuators.
    public func playTestTone(channel: Int) {
        stopTestTone()
        logToFile("ControllerAudioService: requested isolated output channel \(channel) test.")

        guard let info = deviceInfo else {
            lastError = "Connect a DualSense controller through USB first."
            return
        }
        guard info.isQuadraphonic else {
            lastError = "Configure Quadraphonic output before testing individual channels."
            return
        }
        guard (1...4).contains(channel) else {
            lastError = "Test channel must be between 1 and 4."
            return
        }

        let engine = AVAudioEngine()
        let outputNode = engine.outputNode
        guard let outputUnit = outputNode.audioUnit else {
            lastError = "CoreAudio did not create an output AudioUnit."
            return
        }

        var outputDeviceID = info.outputDeviceID
        let deviceStatus = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &outputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard deviceStatus == noErr else {
            lastError = "Could not select the DualSense audio output (\(Self.describe(deviceStatus)))."
            return
        }

        guard let layout = AVAudioChannelLayout(
            layoutTag: kAudioChannelLayoutTag_Quadraphonic
        ) else {
            lastError = "Could not create the Quadraphonic channel layout."
            return
        }
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            interleaved: false,
            channelLayout: layout
        )

        let state = TestToneState(channelIndex: channel - 1)
        let sourceNode = AVAudioSourceNode(format: format) {
            _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }

            guard state.channelIndex < buffers.count,
                  let samples = buffers[state.channelIndex].mData?
                    .assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            var phase = state.phase
            var renderedFrames = state.renderedFrames
            for frame in 0..<Int(frameCount) {
                let attack = min(1.0, Float(renderedFrames) / 480.0)
                let remaining = max(0, state.totalFrames - renderedFrames)
                let release = min(1.0, Float(remaining) / 960.0)
                samples[frame] = sin(Float(phase)) * state.amplitude * attack * release
                phase += state.phaseIncrement
                if phase >= 2.0 * Double.pi {
                    phase -= 2.0 * Double.pi
                }
                renderedFrames += 1
            }
            state.phase = phase
            state.renderedFrames = renderedFrames
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: outputNode, format: format)
        engine.prepare()

        do {
            try engine.start()
        } catch {
            lastError = "Could not start the channel test: \(error.localizedDescription)"
            logToFile("ControllerAudioService: channel \(channel) test failed: \(error.localizedDescription)")
            return
        }

        testEngine = engine
        testSourceNode = sourceNode
        activeTestChannel = channel
        lastError = nil
        statusMessage = channel <= 2
            ? "Playing audible test on channel \(channel)…"
            : "Playing haptic actuator test on channel \(channel)…"
        logToFile("ControllerAudioService: playing channel \(channel) on AudioDeviceID \(info.outputDeviceID).")

        let stopItem = DispatchWorkItem { [weak self] in
            self?.stopTestTone()
        }
        testStopWorkItem = stopItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: stopItem)
    }

    public func stopTestTone() {
        testStopWorkItem?.cancel()
        testStopWorkItem = nil
        testEngine?.stop()
        testEngine?.reset()
        testSourceNode = nil
        testEngine = nil
        if activeTestChannel != nil {
            activeTestChannel = nil
            statusMessage = deviceInfo?.isQuadraphonic == true
                ? "DualSense USB audio is ready for four-channel output."
                : "Channel test stopped."
        }
    }

    public func startAudioHaptics(captureService: SystemAudioCaptureService) {
        guard !isAudioHapticsRunning else { return }
        stopTestTone()

        guard let info = deviceInfo else {
            lastError = "Connect a DualSense controller through USB first."
            return
        }
        guard info.isQuadraphonic else {
            lastError = "Configure Quadraphonic output before starting audio haptics."
            return
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let outputNode = engine.outputNode
        guard let outputUnit = outputNode.audioUnit else {
            lastError = "CoreAudio did not create a haptic output AudioUnit."
            return
        }

        var outputDeviceID = info.outputDeviceID
        let deviceStatus = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &outputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard deviceStatus == noErr else {
            lastError = "Could not select the DualSense haptic output (\(Self.describe(deviceStatus)))."
            return
        }

        guard let layout = AVAudioChannelLayout(
            layoutTag: kAudioChannelLayoutTag_Quadraphonic
        ) else {
            lastError = "Could not create the Quadraphonic haptic layout."
            return
        }
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            interleaved: false,
            channelLayout: layout
        )

        engine.attach(player)
        engine.connect(player, to: outputNode, format: format)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            lastError = "Could not start the haptic output engine: \(error.localizedDescription)"
            return
        }
        player.play()

        hapticLowPassHigh = (0, 0)
        hapticLowPassLow = (0, 0)
        scheduledBufferCount = 0
        processedBufferCounter = 0
        droppedBufferCounter = 0
        hapticInputFormatSnapshot = "Waiting for captured PCM…"
        lastHapticDiagnosticsDelivery = 0
        hasReportedHapticPipelineError = false
        hapticInputFormat = hapticInputFormatSnapshot
        hapticProcessedBuffers = 0
        hapticDroppedBuffers = 0
        hapticOutputLevel = 0
        hapticsEngine = engine
        hapticsPlayer = player
        hapticsFormat = format
        hapticsCaptureService = captureService
        captureService.setSampleHandler { [weak self] sampleBuffer in
            self?.processAudioHaptics(sampleBuffer)
        }
        if !captureService.isCapturing {
            captureService.start()
        }

        isAudioHapticsRunning = true
        audioHapticsStatus = "Streaming system audio to haptic channels 3 and 4."
        lastError = nil
        logToFile("ControllerAudioService: audio haptics started on AudioDeviceID \(info.outputDeviceID).")
    }

    public func stopAudioHaptics() {
        hapticsCaptureService?.setSampleHandler(nil)
        hapticsCaptureService = nil
        hapticsPlayer?.stop()
        hapticsEngine?.stop()
        hapticsEngine?.reset()
        hapticsPlayer = nil
        hapticsEngine = nil
        hapticsFormat = nil
        scheduledBufferLock.lock()
        scheduledBufferCount = 0
        scheduledBufferLock.unlock()
        if isAudioHapticsRunning {
            logToFile("ControllerAudioService: audio haptics stopped.")
        }
        isAudioHapticsRunning = false
        audioHapticsStatus = "Audio haptics are stopped."
        hapticOutputLevel = 0
    }

    private func processAudioHaptics(_ sampleBuffer: CMSampleBuffer) {
        guard isAudioHapticsRunning,
              let player = hapticsPlayer,
              let format = hapticsFormat,
              let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let inputFormat = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              inputFormat.mFormatID == kAudioFormatLinearPCM,
              (inputFormat.mFormatFlags & kAudioFormatFlagIsFloat) != 0,
              inputFormat.mBitsPerChannel == 32 else {
            reportHapticPipelineError(
                "Captured audio is not 32-bit Float PCM; streaming cannot continue."
            )
            return
        }

        scheduledBufferLock.lock()
        let queueIsFull = scheduledBufferCount >= 12
        if !queueIsFull {
            scheduledBufferCount += 1
        }
        scheduledBufferLock.unlock()
        guard !queueIsFull else {
            droppedBufferCounter += 1
            publishHapticDiagnostics(outputPeak: 0)
            return
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let outputChannels = outputBuffer.floatChannelData else {
            decrementScheduledBufferCount()
            return
        }

        for channel in 0..<4 {
            memset(outputChannels[channel], 0, frameCount * MemoryLayout<Float>.size)
        }

        let intensity = Float(max(0, min(1, audioHapticsIntensity)))
        let gain = 4.0 + intensity * 14.0
        // Difference between 220 Hz and 20 Hz one-pole low passes gives a stable
        // bass/transient band while removing DC and harsh high-frequency content.
        let highAlpha: Float = 0.02839
        let lowAlpha: Float = 0.002615

        var highL = hapticLowPassHigh.0
        var highR = hapticLowPassHigh.1
        var lowL = hapticLowPassLow.0
        var lowR = hapticLowPassLow.1
        var outputPeak: Float = 0
        let processedFrames: Int

        do {
            processedFrames = try sampleBuffer.withAudioBufferList {
                inputBuffers, _ -> Int in
                if hapticInputFormatSnapshot == "Waiting for captured PCM…" {
                    let channelGroups = inputBuffers.map {
                        String($0.mNumberChannels)
                    }.joined(separator: "+")
                    let planar = inputBuffers.count > 1 ? "planar" : "interleaved"
                    hapticInputFormatSnapshot =
                        "\(Int(inputFormat.mSampleRate)) Hz Float32 · \(inputFormat.mChannelsPerFrame) ch · \(planar) buffers \(channelGroups)"
                    logToFile(
                        "ControllerAudioService: haptic input \(hapticInputFormatSnapshot)."
                    )
                }

                return Self.forEachStereoFrame(
                    in: inputBuffers,
                    requestedFrameCount: frameCount
                ) { frame, left, right in
                    highL += highAlpha * (left - highL)
                    highR += highAlpha * (right - highR)
                    lowL += lowAlpha * (left - lowL)
                    lowR += lowAlpha * (right - lowR)

                    let hapticLeft = max(-1, min(1, (highL - lowL) * gain))
                    let hapticRight = max(-1, min(1, (highR - lowR) * gain))
                    outputChannels[2][frame] = hapticLeft
                    outputChannels[3][frame] = hapticRight
                    outputPeak = max(
                        outputPeak,
                        max(abs(hapticLeft), abs(hapticRight))
                    )
                }
            }
        } catch {
            decrementScheduledBufferCount()
            droppedBufferCounter += 1
            reportHapticPipelineError(
                "Could not access captured AudioBufferList: \(error.localizedDescription)"
            )
            return
        }

        guard processedFrames > 0 else {
            decrementScheduledBufferCount()
            droppedBufferCounter += 1
            reportHapticPipelineError(
                "Captured AudioBufferList contained no readable Float32 frames."
            )
            return
        }

        outputBuffer.frameLength = AVAudioFrameCount(processedFrames)
        hapticLowPassHigh = (highL, highR)
        hapticLowPassLow = (lowL, lowR)
        processedBufferCounter += 1
        publishHapticDiagnostics(outputPeak: outputPeak)
        player.scheduleBuffer(outputBuffer) { [weak self] in
            self?.decrementScheduledBufferCount()
        }
    }

    /// Iterates the first two logical channels using the AudioBufferList as the source of
    /// truth. This handles one interleaved buffer, separate planar buffers, and mono input.
    /// The prior CMBlockBuffer-contiguous assumption fails on macOS 27 Golden Gate.
    private static func forEachStereoFrame(
        in buffers: UnsafeMutableAudioBufferListPointer,
        requestedFrameCount: Int,
        body: (_ frame: Int, _ left: Float, _ right: Float) -> Void
    ) -> Int {
        guard requestedFrameCount > 0, !buffers.isEmpty else { return 0 }

        func sample(logicalChannel: Int, frame: Int) -> Float? {
            var firstLogicalChannel = 0
            for buffer in buffers {
                let channelsInBuffer = max(1, Int(buffer.mNumberChannels))
                let nextLogicalChannel = firstLogicalChannel + channelsInBuffer
                defer { firstLogicalChannel = nextLogicalChannel }
                guard logicalChannel >= firstLogicalChannel,
                      logicalChannel < nextLogicalChannel,
                      let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                    continue
                }

                let channelInBuffer = logicalChannel - firstLogicalChannel
                let sampleIndex = frame * channelsInBuffer + channelInBuffer
                let availableSamples =
                    Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                guard sampleIndex < availableSamples else { return nil }
                return data[sampleIndex]
            }
            return nil
        }

        var processed = 0
        for frame in 0..<requestedFrameCount {
            guard let left = sample(logicalChannel: 0, frame: frame) else {
                break
            }
            let right = sample(logicalChannel: 1, frame: frame) ?? left
            guard left.isFinite, right.isFinite else { continue }
            body(frame, left, right)
            processed = frame + 1
        }
        return processed
    }

    #if TESTING
    public static func testDecodePlanarStereo(
        left: [Float],
        right: [Float]
    ) -> [Float] {
        var left = left
        var right = right
        return left.withUnsafeMutableBufferPointer { leftBuffer in
            right.withUnsafeMutableBufferPointer { rightBuffer in
                let buffers = AudioBufferList.allocate(maximumBuffers: 2)
                defer { buffers.unsafeMutablePointer.deallocate() }
                buffers.unsafeMutablePointer.pointee.mNumberBuffers = 2
                buffers[0] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(leftBuffer.count * MemoryLayout<Float>.size),
                    mData: leftBuffer.baseAddress
                )
                buffers[1] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(rightBuffer.count * MemoryLayout<Float>.size),
                    mData: rightBuffer.baseAddress
                )

                var decoded: [Float] = []
                _ = forEachStereoFrame(
                    in: buffers,
                    requestedFrameCount: min(leftBuffer.count, rightBuffer.count)
                ) { _, l, r in
                    decoded.append(l)
                    decoded.append(r)
                }
                return decoded
            }
        }
    }

    public static func testDecodeInterleavedStereo(_ samples: [Float]) -> [Float] {
        var samples = samples
        return samples.withUnsafeMutableBufferPointer { sampleBuffer in
            let buffers = AudioBufferList.allocate(maximumBuffers: 1)
            defer { buffers.unsafeMutablePointer.deallocate() }
            buffers.unsafeMutablePointer.pointee.mNumberBuffers = 1
            buffers[0] = AudioBuffer(
                mNumberChannels: 2,
                mDataByteSize: UInt32(sampleBuffer.count * MemoryLayout<Float>.size),
                mData: sampleBuffer.baseAddress
            )

            var decoded: [Float] = []
            _ = forEachStereoFrame(
                in: buffers,
                requestedFrameCount: sampleBuffer.count / 2
            ) { _, l, r in
                decoded.append(l)
                decoded.append(r)
            }
            return decoded
        }
    }
    #endif

    private func publishHapticDiagnostics(outputPeak: Float) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard lastHapticDiagnosticsDelivery == 0
                || now &- lastHapticDiagnosticsDelivery >= 100_000_000 else {
            return
        }
        lastHapticDiagnosticsDelivery = now
        let processed = processedBufferCounter
        let dropped = droppedBufferCounter
        let inputFormat = hapticInputFormatSnapshot

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isAudioHapticsRunning else { return }
            self.hapticProcessedBuffers = processed
            self.hapticDroppedBuffers = dropped
            self.hapticInputFormat = inputFormat
            self.hapticOutputLevel =
                self.hapticOutputLevel * 0.65 + outputPeak * 0.35
        }
    }

    private func reportHapticPipelineError(_ message: String) {
        guard !hasReportedHapticPipelineError else { return }
        hasReportedHapticPipelineError = true
        logToFile("ControllerAudioService: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
            self?.audioHapticsStatus = message
        }
    }

    private func decrementScheduledBufferCount() {
        scheduledBufferLock.lock()
        scheduledBufferCount = max(0, scheduledBufferCount - 1)
        scheduledBufferLock.unlock()
    }

    private static func allAudioDeviceIDs() -> [AudioDeviceID]? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: AudioDeviceID(kAudioObjectUnknown), count: count)
        let status = devices.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                bytes.baseAddress!
            )
        }
        return status == noErr ? devices : nil
    }

    private static func channelCount(
        _ deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID, &address, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return 0 }

        let memory = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { memory.deallocate() }
        memory.initializeMemory(as: UInt8.self, repeating: 0, count: Int(dataSize))

        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, memory
        ) == noErr else { return 0 }

        let audioBufferList = memory.bindMemory(to: AudioBufferList.self, capacity: 1)
        return UnsafeMutableAudioBufferListPointer(audioBufferList).reduce(0) {
            $0 + Int($1.mNumberChannels)
        }
    }

    private static func preferredChannelLayoutTag(
        _ deviceID: AudioDeviceID
    ) -> AudioChannelLayoutTag? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelLayout,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID, &address, 0, nil, &dataSize
        ) == noErr, dataSize >= MemoryLayout<AudioChannelLayout>.size else {
            return nil
        }

        let memory = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioChannelLayout>.alignment
        )
        defer { memory.deallocate() }
        memory.initializeMemory(as: UInt8.self, repeating: 0, count: Int(dataSize))

        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, memory
        ) == noErr else { return nil }
        return memory.assumingMemoryBound(to: AudioChannelLayout.self)
            .pointee.mChannelLayoutTag
    }

    private static func isPreferredChannelLayoutSettable(
        _ deviceID: AudioDeviceID
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelLayout,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(
            deviceID, &address, &settable
        ) == noErr && settable.boolValue
    }

    private static func stringProperty(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        guard let value: CFString = scalarProperty(
            deviceID,
            selector: selector,
            scope: kAudioObjectPropertyScopeGlobal,
            initialValue: "" as CFString
        ) else { return nil }
        return value as String
    }

    private static func uint32Property(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> UInt32? {
        scalarProperty(
            deviceID,
            selector: selector,
            scope: kAudioObjectPropertyScopeGlobal,
            initialValue: UInt32(0)
        )
    }

    private static func float64Property(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> Float64? {
        scalarProperty(
            deviceID,
            selector: selector,
            scope: kAudioObjectPropertyScopeGlobal,
            initialValue: Float64(0)
        )
    }

    private static func scalarProperty<T>(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        initialValue: T
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = initialValue
        var dataSize = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                pointer
            )
        }
        return status == noErr ? value : nil
    }

    private static func describe(_ status: OSStatus) -> String {
        let bigEndian = UInt32(bitPattern: status).bigEndian
        let characters: [UInt8] = [
            UInt8((bigEndian >> 24) & 0xFF),
            UInt8((bigEndian >> 16) & 0xFF),
            UInt8((bigEndian >> 8) & 0xFF),
            UInt8(bigEndian & 0xFF)
        ]
        if characters.allSatisfy({ $0 >= 32 && $0 <= 126 }) {
            return "'\(String(bytes: characters, encoding: .ascii) ?? "?")'"
        }
        return String(format: "%d", status)
    }
}

/// Mutable state intentionally owned by the real-time render callback. It is allocated before
/// playback begins; the callback performs no allocation, locking, logging, or UI work.
private final class TestToneState {
    let channelIndex: Int
    let phaseIncrement: Double
    let amplitude: Float
    let totalFrames = 24_000 // 0.5 seconds at 48 kHz
    var phase = 0.0
    var renderedFrames = 0

    init(channelIndex: Int) {
        self.channelIndex = channelIndex
        let frequency = channelIndex >= 2 ? 120.0 : 440.0
        self.phaseIncrement = 2.0 * Double.pi * frequency / 48_000.0
        self.amplitude = channelIndex >= 2 ? 0.35 : 0.08
    }
}
