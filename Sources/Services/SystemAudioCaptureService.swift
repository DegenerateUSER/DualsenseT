import Foundation
import Combine
import ScreenCaptureKit
import CoreMedia

public final class SystemAudioCaptureService: NSObject, ObservableObject {
    @Published public private(set) var isCapturing = false
    @Published public private(set) var isStarting = false
    @Published public private(set) var level: Float = 0
    @Published public private(set) var statusMessage = "System audio capture is stopped."
    @Published public private(set) var lastError: String?

    private let audioQueue = DispatchQueue(
        label: "com.tushar.DualSenseT.systemAudioCapture",
        qos: .userInteractive
    )
    private var captureStream: SCStream?
    private var lastLevelDelivery: UInt64 = 0
    private let sampleHandlerLock = NSLock()
    private var sampleHandler: ((CMSampleBuffer) -> Void)?
    private var hasLoggedAudioFormat = false

    /// Installs the synchronous consumer used by the haptic DSP. The callback runs on
    /// `audioQueue`; it must copy or consume the sample before returning.
    public func setSampleHandler(_ handler: ((CMSampleBuffer) -> Void)?) {
        sampleHandlerLock.lock()
        sampleHandler = handler
        sampleHandlerLock.unlock()
    }

    public func start() {
        guard !isCapturing, !isStarting else { return }
        isStarting = true
        lastError = nil
        statusMessage = "Requesting system audio access…"

        Task { [weak self] in
            await self?.startCapture()
        }
    }

    public func stop() {
        let stream = captureStream
        captureStream = nil
        isCapturing = false
        isStarting = false
        level = 0
        statusMessage = "System audio capture is stopped."

        if let stream {
            Task {
                try? await stream.stopCapture()
            }
        }
    }

    private func startCapture() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            guard let display = content.displays.first else {
                await publishFailure("No display is available for the system audio tap.")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2
            // ScreenCaptureKit owns a display-backed stream even when we register only an
            // audio output. Keep any incidental video configuration deliberately tiny.
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.queueDepth = 3

            let stream = SCStream(
                filter: filter,
                configuration: configuration,
                delegate: self
            )
            try stream.addStreamOutput(
                self,
                type: .audio,
                sampleHandlerQueue: audioQueue
            )
            try await stream.startCapture()

            await MainActor.run {
                self.captureStream = stream
                self.isStarting = false
                self.isCapturing = true
                self.lastError = nil
                self.statusMessage = "Capturing system audio at 48 kHz stereo."
            }
        } catch {
            await publishFailure(
                "System audio capture failed: \(error.localizedDescription). Allow DualSenseT in System Settings → Privacy & Security → Screen & System Audio Recording."
            )
        }
    }

    @MainActor
    private func publishFailure(_ message: String) {
        captureStream = nil
        isStarting = false
        isCapturing = false
        level = 0
        lastError = message
        statusMessage = message
        logToFile("SystemAudioCaptureService: \(message)")
    }

    /// Maps linear PCM RMS into a useful 0...1 UI meter. The multiplier exposes quiet
    /// desktop audio without changing the samples that will later feed the DSP.
    public static func meterLevel(forRMS rms: Float) -> Float {
        min(1, max(0, rms * 4))
    }

    private func processLevel(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr,
        let dataPointer,
        totalLength >= MemoryLayout<Float>.size else {
            return
        }

        let samples = UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self)
        let sampleCount = totalLength / MemoryLayout<Float>.size
        let stride = max(1, sampleCount / 2_048)
        var sumSquares: Double = 0
        var measuredCount = 0
        var index = 0
        while index < sampleCount {
            let sample = samples[index]
            if sample.isFinite {
                sumSquares += Double(sample * sample)
                measuredCount += 1
            }
            index += stride
        }
        guard measuredCount > 0 else { return }

        let rms = Float(sqrt(sumSquares / Double(measuredCount)))
        let meter = Self.meterLevel(forRMS: rms)
        let now = DispatchTime.now().uptimeNanoseconds
        guard lastLevelDelivery == 0 || now &- lastLevelDelivery >= 50_000_000 else {
            return
        }
        lastLevelDelivery = now

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCapturing else { return }
            self.level = self.level * 0.68 + meter * 0.32
        }
    }

    private func deliverToProcessor(_ sampleBuffer: CMSampleBuffer) {
        sampleHandlerLock.lock()
        let handler = sampleHandler
        sampleHandlerLock.unlock()
        handler?(sampleBuffer)
    }

    private func logAudioFormatOnce(_ sampleBuffer: CMSampleBuffer) {
        guard !hasLoggedAudioFormat,
              let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
            return
        }
        hasLoggedAudioFormat = true
        logToFile(
            "SystemAudioCaptureService: format id=\(format.mFormatID), flags=0x\(String(format: "%08X", format.mFormatFlags)), rate=\(Int(format.mSampleRate)), channels=\(format.mChannelsPerFrame), bytesPerFrame=\(format.mBytesPerFrame), framesPerPacket=\(format.mFramesPerPacket)"
        )
    }
}

extension SystemAudioCaptureService: SCStreamOutput, SCStreamDelegate {
    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }
        logAudioFormatOnce(sampleBuffer)
        processLevel(sampleBuffer)
        deliverToProcessor(sampleBuffer)
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.publishFailure("System audio stream stopped: \(error.localizedDescription)")
        }
    }
}
