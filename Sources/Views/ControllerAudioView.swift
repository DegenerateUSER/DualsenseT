import SwiftUI

public struct ControllerAudioView: View {
    @ObservedObject var service: ControllerAudioService
    @ObservedObject var captureService: SystemAudioCaptureService
    @ObservedObject var manager: ControllerManager
    @State private var hapticsStartWorkItem: DispatchWorkItem?
    @State private var hapticsRestoreWorkItem: DispatchWorkItem?
    @State private var streamStartWorkItem: DispatchWorkItem?
    @State private var showsDiagnostics = false

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
                        Text("Audio")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Controller sound, microphone, and game-responsive haptics")
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
                    if !info.isQuadraphonic {
                        setupCard(info)
                    }
                    captureValidationCard
                    hardwareControlCard(info)
                    advancedDiagnostics(info)
                } else {
                    disconnectedCard
                }
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
                    Text("Feel game, music, and video audio through both controller grips.")
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
                Text("Live Haptic Response")
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
                        : (captureService.isStarting ? "Starting audio capture…" : "Ready"),
                    systemImage: service.isAudioHapticsRunning
                        ? "waveform.circle.fill"
                        : "checkmark.circle"
                )
                .font(.subheadline)
                .foregroundColor(
                    service.isAudioHapticsRunning || captureService.isStarting
                        ? .cyan
                        : .secondary
                )
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
                Text("Your normal Mac audio output remains unchanged while haptics run in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("USB only · Requires Screen & System Audio Recording permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func advancedDiagnostics(_ info: ControllerAudioDeviceInfo) -> some View {
        DisclosureGroup(isExpanded: $showsDiagnostics) {
            VStack(alignment: .leading, spacing: 14) {
                channelMapCard(info)
                channelTestCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("Device Details")
                        .font(.headline)
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

                    if service.isAudioHapticsRunning {
                        Divider()
                        Text("Stream Diagnostics")
                            .font(.headline)
                        HStack(spacing: 16) {
                            Text("Captured \(Int(captureService.level * 100))%")
                            Text("Output \(Int(service.hapticOutputLevel * 100))%")
                            Text("Processed \(service.hapticProcessedBuffers)")
                            Text("Dropped \(service.hapticDroppedBuffers)")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Text("Rendered \(service.hapticRenderedFrames)")
                            Text("Buffered \(service.hapticBufferedFrames)")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                        Text(service.hapticInputFormat)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 14)
        } label: {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Advanced Diagnostics")
                        .font(.headline)
                    Text("Channel tests, device details, and stream counters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var channelTestCard: some View {
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
                    Text("Controller Audio")
                        .font(.headline)
                    Text("Choose where controller sound and microphone input are routed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(manager.controllerAudioControlsEnabled ? "On" : "Off")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            if manager.controllerAudioOutputRoute == .splitHeadphonesAndSpeaker {
                Text("Split mode sends the left channel to the headset and the right channel to the controller speaker.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!info.isQuadraphonic)
    }

    @ViewBuilder
    private func connectionCard(_ info: ControllerAudioDeviceInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.title2)
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.headline)
                Text("USB connected · \(Int(info.sampleRate / 1000)) kHz · \(info.outputChannels)-channel audio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: info.isQuadraphonic ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(info.isQuadraphonic ? "Ready" : "Setup required")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(info.isQuadraphonic ? .green : .yellow)
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
            Text("One-time Audio Setup")
                .font(.headline)

            Text("Prepare the controller's two grip actuators for audio haptics. This changes only the controller layout, not your Mac's normal audio output.")
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
                    Button("Configure Audio") {
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
