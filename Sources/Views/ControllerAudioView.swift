import SwiftUI

public struct ControllerAudioView: View {
    @ObservedObject var service: ControllerAudioService
    @ObservedObject var captureService: SystemAudioCaptureService
    @ObservedObject var manager: ControllerManager
    @State private var hapticsStartWorkItem: DispatchWorkItem?
    @State private var hapticsRestoreWorkItem: DispatchWorkItem?
    @State private var streamStartWorkItem: DispatchWorkItem?

    public init(
        service: ControllerAudioService,
        captureService: SystemAudioCaptureService,
        manager: ControllerManager
    ) {
        self.service = service
        self.captureService = captureService
        self.manager = manager
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Controller Audio & Haptics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("USB audio interface diagnostics and setup")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        service.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(service.isRefreshing)
                }

                if let info = service.deviceInfo {
                    connectionCard(info)
                    channelMapCard(info)
                    setupCard(info)
                    hardwareControlCard(info)
                    channelTestCard(info)
                    captureValidationCard
                } else {
                    disconnectedCard
                }

                implementationProgress
            }
            .padding()
        }
        .onAppear {
            service.refresh()
        }
        .onDisappear {
            // Audio haptics are an app-wide background feature, not an Audio-tab preview.
            // Navigating to configure triggers must not tear down capture/DSP or restore
            // classic rumble mode. Only a short isolated channel test is tab-scoped.
            if service.isPlayingTestTone || hapticsStartWorkItem != nil {
                stopChannelTest()
            }
        }
    }

    private func playChannelTest(_ channel: Int) {
        hapticsStartWorkItem?.cancel()
        hapticsStartWorkItem = nil
        hapticsRestoreWorkItem?.cancel()
        hapticsRestoreWorkItem = nil

        guard channel >= 3 else {
            manager.audioHapticsModeEnabled = false
            service.playTestTone(channel: channel)
            return
        }

        // A normal controller report selects classic rumble. Give the USB output report a
        // brief head start to switch back to PCM actuator mode before starting channel audio.
        manager.audioHapticsModeEnabled = true
        let start = DispatchWorkItem {
            hapticsStartWorkItem = nil
            service.playTestTone(channel: channel)

            let restore = DispatchWorkItem {
                manager.audioHapticsModeEnabled = false
                hapticsRestoreWorkItem = nil
            }
            hapticsRestoreWorkItem = restore
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: restore)
        }
        hapticsStartWorkItem = start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: start)
    }

    private func stopChannelTest() {
        hapticsStartWorkItem?.cancel()
        hapticsStartWorkItem = nil
        hapticsRestoreWorkItem?.cancel()
        hapticsRestoreWorkItem = nil
        service.stopTestTone()
        manager.audioHapticsModeEnabled = false
    }

    private func startAudioHaptics() {
        stopChannelTest()
        streamStartWorkItem?.cancel()
        manager.audioHapticsModeEnabled = true

        let start = DispatchWorkItem {
            streamStartWorkItem = nil
            service.startAudioHaptics(captureService: captureService)
        }
        streamStartWorkItem = start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: start)
    }

    private func stopAudioHaptics() {
        streamStartWorkItem?.cancel()
        streamStartWorkItem = nil
        service.stopAudioHaptics()
        captureService.stop()
        manager.audioHapticsModeEnabled = false
    }

    private var captureValidationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Audio Haptics")
                        .font(.headline)
                    Text("Convert game, music, and video audio into independent left/right grip feedback.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if service.isAudioHapticsRunning {
                    Button("Stop Haptics") {
                        stopAudioHaptics()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(captureService.isStarting ? "Starting…" : "Start Audio Haptics") {
                        startAudioHaptics()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(captureService.isStarting)
                }
            }

            HStack {
                Text("Captured Audio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(captureService.level * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.22))
                    Capsule()
                        .fill(captureService.isCapturing ? Color.cyan : Color.secondary)
                        .frame(width: geometry.size.width * CGFloat(captureService.level))
                }
            }
            .frame(height: 10)

            HStack(spacing: 12) {
                Image(systemName: "waveform.path")
                    .foregroundColor(.cyan)
                    .frame(width: 20)
                Text("Haptic Intensity")
                    .font(.subheadline)
                    .frame(width: 132, alignment: .leading)
                Slider(value: $service.audioHapticsIntensity, in: 0...1)
                Text("\(Int(round(service.audioHapticsIntensity * 100)))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            HStack {
                Text("Processed Haptic Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(service.hapticOutputLevel * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.22))
                    Capsule()
                        .fill(service.hapticOutputLevel > 0.001 ? Color.green : Color.secondary)
                        .frame(width: geometry.size.width * CGFloat(service.hapticOutputLevel))
                }
            }
            .frame(height: 10)

            HStack {
                Label(
                    service.isAudioHapticsRunning
                        ? service.audioHapticsStatus
                        : captureService.statusMessage,
                    systemImage: service.isAudioHapticsRunning
                        ? "waveform.circle.fill"
                        : "record.circle"
                )
                .font(.subheadline)
                .foregroundColor(service.isAudioHapticsRunning ? .cyan : .secondary)
            }

            if service.isAudioHapticsRunning {
                HStack(spacing: 16) {
                    Text("Processed: \(service.hapticProcessedBuffers)")
                    Text("Dropped: \(service.hapticDroppedBuffers)")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

                Text(service.hapticInputFormat)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            if let error = captureService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let error = service.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if service.isAudioHapticsRunning {
                Text("Play music, a video, or a game. Bass and transients are streamed to the left/right haptic actuators; your normal Mac audio output is unchanged.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func channelTestCard(_ info: ControllerAudioDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Isolated Channel Tests")
                        .font(.headline)
                    Text("Short tones are sent directly to the controller, never to the system default output.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if service.isPlayingTestTone {
                    Button("Stop") {
                        stopChannelTest()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            HStack(spacing: 10) {
                AudioTestButton(
                    title: "Speaker L",
                    subtitle: "Channel 1 · 440 Hz",
                    icon: "speaker.wave.1.fill",
                    isActive: service.activeTestChannel == 1
                ) { playChannelTest(1) }
                AudioTestButton(
                    title: "Speaker R",
                    subtitle: "Channel 2 · 440 Hz",
                    icon: "speaker.wave.1.fill",
                    isActive: service.activeTestChannel == 2
                ) { playChannelTest(2) }
                AudioTestButton(
                    title: "Haptic L",
                    subtitle: "Channel 3 · 120 Hz",
                    icon: "waveform.path",
                    isActive: service.activeTestChannel == 3
                ) { playChannelTest(3) }
                AudioTestButton(
                    title: "Haptic R",
                    subtitle: "Channel 4 · 120 Hz",
                    icon: "waveform.path",
                    isActive: service.activeTestChannel == 4
                ) { playChannelTest(4) }
            }

            if let error = service.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Hold the controller during Haptic L/R tests. The two grips should vibrate independently.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func hardwareControlCard(_ info: ControllerAudioDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Controller Audio Controls")
                        .font(.headline)
                    Text("Applied through the DualSense USB HID audio fields")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $manager.controllerAudioControlsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Output Route")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $manager.controllerAudioOutputRoute) {
                        ForEach(ControllerAudioOutputRoute.allCases) { route in
                            Text(route.title).tag(route)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Microphone Source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $manager.controllerAudioInputRoute) {
                        ForEach(ControllerAudioInputRoute.allCases) { route in
                            Text(route.title).tag(route)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }

            AudioVolumeRow(
                title: "Headset Volume",
                icon: "headphones",
                value: $manager.controllerHeadphoneVolume
            )
            AudioVolumeRow(
                title: "Controller Speaker",
                icon: "speaker.wave.2.fill",
                value: $manager.controllerSpeakerVolume
            )
            AudioVolumeRow(
                title: "Microphone Gain",
                icon: "mic.fill",
                value: $manager.controllerMicrophoneVolume
            )

            Toggle(isOn: $manager.controllerMicrophoneMuted) {
                Label("Mute controller microphone", systemImage: "mic.slash.fill")
            }

            Text("The headset + speaker route follows the controller protocol's split mode: the left channel goes to the headset and the right channel to the controller speaker.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!info.isQuadraphonic)
        .overlay(alignment: .topTrailing) {
            if !manager.controllerAudioControlsEnabled {
                Text("OFF")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.top, 18)
                    .padding(.trailing, 54)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func connectionCard(_ info: ControllerAudioDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "cable.connector")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.headline)
                    Text(info.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("USB AUDIO")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.13))
                    .clipShape(Capsule())
            }

            Divider()

            HStack(spacing: 12) {
                AudioCapabilityTile(
                    title: "Output",
                    value: "\(info.outputChannels) channels",
                    icon: "speaker.wave.2.fill"
                )
                AudioCapabilityTile(
                    title: "Input",
                    value: "\(info.inputChannels) channels",
                    icon: "mic.fill"
                )
                AudioCapabilityTile(
                    title: "Sample Rate",
                    value: "\(Int(info.sampleRate / 1000)) kHz",
                    icon: "waveform"
                )
            }

            Text(info.outputUID)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func channelMapCard(_ info: ControllerAudioDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Four-Channel Output Map")
                    .font(.headline)
                Spacer()
                Image(systemName: info.isQuadraphonic ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(info.isQuadraphonic ? .green : .yellow)
            }

            HStack(spacing: 10) {
                AudioChannelTile(number: 1, name: "Front Left", role: "Audible L", color: .blue)
                AudioChannelTile(number: 2, name: "Front Right", role: "Audible R", color: .blue)
                AudioChannelTile(number: 3, name: "Surround Left", role: "Haptic L", color: .cyan)
                AudioChannelTile(number: 4, name: "Surround Right", role: "Haptic R", color: .cyan)
            }

            Text(info.channelLayoutName)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(info.isQuadraphonic ? .green : .yellow)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func setupCard(_ info: ControllerAudioDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speaker Configuration")
                .font(.headline)

            Text("Audio haptics require macOS to expose channels 3 and 4 as surround channels. This changes only the DualSense speaker layout—it does not change your default Mac output device.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Label(
                    service.statusMessage,
                    systemImage: info.isQuadraphonic ? "checkmark.circle.fill" : "info.circle.fill"
                )
                .font(.subheadline)
                .foregroundColor(info.isQuadraphonic ? .green : .secondary)

                Spacer()

                if !info.isQuadraphonic {
                    Button("Configure Quadraphonic") {
                        service.configureQuadraphonic()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!info.channelLayoutSettable)
                }
            }

            if let error = service.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var disconnectedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
            Text("DualSense USB audio not found")
                .font(.headline)
            Text("Connect the controller with a data-capable USB cable. Bluetooth does not expose the controller's audio interface.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Scan Again") {
                service.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var implementationProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Implementation Stages")
                .font(.headline)
            StageRow(number: 1, title: "USB discovery & Quadraphonic setup", state: .complete)
            StageRow(number: 2, title: "Speaker, headset and microphone controls", state: .complete)
            StageRow(number: 3, title: "Per-channel audio output tests", state: .complete)
            StageRow(number: 4, title: "Permission-aware system audio capture", state: .complete)
            StageRow(number: 5, title: "Audio-to-haptics DSP and streaming", state: .next)
        }
        .padding()
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AudioTestButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.cyan.opacity(0.16) : Color.black.opacity(0.14))
            .foregroundColor(isActive ? .cyan : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.cyan.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity)
    }
}

private struct AudioVolumeRow: View {
    let title: String
    let icon: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .frame(width: 132, alignment: .leading)
            Slider(value: $value, in: 0...1)
            Text("\(Int(round(value * 100)))%")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

private struct AudioCapabilityTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct AudioChannelTile: View {
    let number: Int
    let name: String
    let role: String
    let color: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Text(name)
                .font(.caption)
                .lineLimit(1)
            Text(role)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StageRow: View {
    enum State {
        case complete
        case next
        case planned
    }

    let number: Int
    let title: String
    let state: State

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.16))
                    .frame(width: 24, height: 24)
                if state == .complete {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(stateColor)
                } else {
                    Text("\(number)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(stateColor)
                }
            }
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(stateLabel)
                .font(.caption)
                .foregroundColor(stateColor)
        }
    }

    private var stateColor: Color {
        switch state {
        case .complete: return .green
        case .next: return .cyan
        case .planned: return .secondary
        }
    }

    private var stateLabel: String {
        switch state {
        case .complete: return "Ready"
        case .next: return "Next"
        case .planned: return "Planned"
        }
    }
}
