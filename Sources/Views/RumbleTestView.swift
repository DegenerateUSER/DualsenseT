import SwiftUI

public struct RumbleTestView: View {
    @ObservedObject var manager: ControllerManager
    @State private var leftIntensity: Double = 0
    @State private var rightIntensity: Double = 0
    @State private var isPulseRunning: Bool = false
    @State private var pulseTimer: Timer? = nil
    
    public init(manager: ControllerManager) {
        self.manager = manager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Haptic Motor Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Left Motor
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "l.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Left Motor")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(leftIntensity))%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Slider(value: $leftIntensity, in: 0...100, step: 1) { editing in
                            if !editing {
                                manager.rumbleLeftIntensity = UInt8(leftIntensity * 2.55)
                            }
                        }
                        .onChange(of: leftIntensity) { _, newValue in
                            manager.rumbleLeftIntensity = UInt8(newValue * 2.55)
                        }
                        
                        // Intensity bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [.blue, .blue.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * CGFloat(leftIntensity / 100))
                            }
                        }
                        .frame(width: 80, height: 8)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Right Motor
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "r.circle.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        Text("Right Motor")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(rightIntensity))%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Slider(value: $rightIntensity, in: 0...100, step: 1) { editing in
                            if !editing {
                                manager.rumbleRightIntensity = UInt8(rightIntensity * 2.55)
                            }
                        }
                        .onChange(of: rightIntensity) { _, newValue in
                            manager.rumbleRightIntensity = UInt8(newValue * 2.55)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [.purple, .purple.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * CGFloat(rightIntensity / 100))
                            }
                        }
                        .frame(width: 80, height: 8)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Quick Actions
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    Button(action: {
                        // Test Pulse: ramp up and down
                        startPulse()
                    }) {
                        HStack {
                            Image(systemName: "waveform.path")
                            Text("Test Pulse")
                            Spacer()
                        }
                        .padding()
                        .background(isPulseRunning ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        // Stop all
                        stopPulse()
                        leftIntensity = 0
                        rightIntensity = 0
                        manager.rumbleLeftIntensity = 0
                        manager.rumbleRightIntensity = 0
                    }) {
                        HStack {
                            Image(systemName: "stop.circle")
                            Text("Stop All")
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        // Heartbeat pattern
                        runPattern(name: "heartbeat")
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Heartbeat")
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        // Max both
                        leftIntensity = 100
                        rightIntensity = 100
                        manager.rumbleLeftIntensity = 255
                        manager.rumbleRightIntensity = 255
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Max Power")
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // Mic LED Control
                Text("Microphone LED")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(manager.micLEDState == 0 ? .secondary : .orange)
                        Text("Mic Mute Indicator")
                            .font(.headline)
                        Spacer()
                        Text(micLEDLabel)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Mic LED", selection: Binding(
                        get: { Int(manager.micLEDState) },
                        set: { manager.micLEDState = UInt8($0) }
                    )) {
                        Text("Off").tag(0)
                        Text("On").tag(1)
                        Text("Pulse").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                // Player Indicator LEDs
                Text("Player Indicator LEDs")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "light.max")
                            .font(.title3)
                            .foregroundColor(.cyan)
                        Text("5 LEDs below the touchpad")
                            .font(.headline)
                        Spacer()
                    }
                    
                    // 5 LED toggles
                    HStack(spacing: 20) {
                        ForEach(0..<5) { i in
                            Button(action: {
                                manager.playerLEDs ^= UInt8(1 << i)
                            }) {
                                Circle()
                                    .fill((manager.playerLEDs & UInt8(1 << i)) != 0 ? Color.cyan : Color.white.opacity(0.15))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Player number presets
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { playerNum in
                            Button("P\(playerNum)") {
                                manager.playerLEDs = playerLEDPattern(for: playerNum)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                        
                        Button("All Off") {
                            manager.playerLEDs = 0
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private var micLEDLabel: String {
        switch manager.micLEDState {
        case 0: return "Off"
        case 1: return "On"
        case 2: return "Pulse"
        default: return "Unknown"
        }
    }
    
    /// Standard PlayStation player LED patterns
    private func playerLEDPattern(for player: Int) -> UInt8 {
        switch player {
        case 1: return 0b00100  // Center LED
        case 2: return 0b01010  // Two inner LEDs
        case 3: return 0b10101  // Alternating
        case 4: return 0b11011  // Four outer
        case 5: return 0b11111  // All five
        default: return 0
        }
    }
    
    private func startPulse() {
        stopPulse()
        isPulseRunning = true
        var step = 0
        let totalSteps = 20
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
            let progress = Float(step) / Float(totalSteps)
            let intensity: Float
            if progress < 0.5 {
                intensity = progress * 2.0 // Ramp up
            } else {
                intensity = (1.0 - progress) * 2.0 // Ramp down
            }
            let value = UInt8(intensity * 255)
            DispatchQueue.main.async {
                self.leftIntensity = Double(intensity * 100)
                self.rightIntensity = Double(intensity * 100)
                self.manager.rumbleLeftIntensity = value
                self.manager.rumbleRightIntensity = value
            }
            step += 1
            if step > totalSteps {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.isPulseRunning = false
                    self.leftIntensity = 0
                    self.rightIntensity = 0
                    self.manager.rumbleLeftIntensity = 0
                    self.manager.rumbleRightIntensity = 0
                }
            }
        }
    }
    
    private func runPattern(name: String) {
        stopPulse()
        isPulseRunning = true
        // Heartbeat: two quick pulses then pause
        let pattern: [(left: UInt8, right: UInt8, duration: TimeInterval)] = [
            (200, 200, 0.1), (0, 0, 0.08),
            (255, 255, 0.12), (0, 0, 0.5),
            (200, 200, 0.1), (0, 0, 0.08),
            (255, 255, 0.12), (0, 0, 0.0)
        ]
        var delay: TimeInterval = 0
        for step in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.manager.rumbleLeftIntensity = step.left
                self.manager.rumbleRightIntensity = step.right
                self.leftIntensity = Double(step.left) / 2.55
                self.rightIntensity = Double(step.right) / 2.55
            }
            delay += step.duration
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
            self.isPulseRunning = false
            self.manager.rumbleLeftIntensity = 0
            self.manager.rumbleRightIntensity = 0
            self.leftIntensity = 0
            self.rightIntensity = 0
        }
    }
    
    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        isPulseRunning = false
    }
}
