import SwiftUI
import AppKit

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct TriggerPreviewView: View {
    let isUIVisible: Bool
    let mode: TriggerMode
    let startPos: Float
    let endPos: Float
    let strength: Float
    let amplitude: Float
    let frequency: Float
    
    @State private var virtualPull: Float = 0.0
    @State private var isFired: Bool = false
    @State private var shakeOffset: CGFloat = 0.0
    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    public init(isUIVisible: Bool, mode: TriggerMode, startPos: Float, endPos: Float, strength: Float, amplitude: Float, frequency: Float) {
        self.isUIVisible = isUIVisible
        self.mode = mode
        self.startPos = startPos
        self.endPos = endPos
        self.strength = strength
        self.amplitude = amplitude
        self.frequency = frequency
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual Feedback Preview")
                .font(.headline)
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 24
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: height)
                    
                    if mode != .off {
                        let isBounded = (mode == .weapon || mode == .semiAutomatic || mode == .sectionResistance || mode == .automatic || mode == .slopeFeedback)
                        let startX = CGFloat(startPos) * width
                        let endX = isBounded ? CGFloat(endPos) * width : width

                        RoundedRectangle(cornerRadius: 12)
                            .fill(activeZoneColor.opacity(0.3))
                            .frame(width: max(0, endX - startX), height: height)
                            .offset(x: startX)
                    }
                    
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 32, height: 32)
                        .shadow(color: indicatorColor.opacity(0.6), radius: 8)
                        .offset(x: min(max(0, CGFloat(virtualPull) * (width - 32) + shakeOffset), width - 32))
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: virtualPull)
                }
                .frame(height: height)
            }
            .frame(height: 32)
            
            HStack {
                Text("Test Pull:")
                    .font(.subheadline)
                    .frame(width: 70, alignment: .leading)
                Slider(value: Binding(get: {
                    self.virtualPull
                }, set: { newValue in
                    self.updatePull(newValue)
                }), in: 0...1)
                Text(String(format: "%.0f%%", virtualPull * 100))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 45, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onReceive(timer) { _ in
            self.tickVibration()
        }
    }
    
    var activeZoneColor: Color {
        switch mode {
        case .off: return .clear
        case .feedback: return .orange
        case .weapon: return .red
        case .vibration: return .blue
        case .sectionResistance: return .yellow
        case .semiAutomatic: return .red
        case .automatic: return .pink
        case .slopeFeedback: return .orange
        case .multiPositionFeedback: return .purple
        case .multiPositionVibration: return .indigo
        case .fullPress: return .red
        }
    }
    
    var indicatorColor: Color {
        if mode == .off { return .white }
        if virtualPull >= startPos {
            if (mode == .weapon || mode == .semiAutomatic) && !isFired { return .red }
            return activeZoneColor
        }
        return .white
    }
    
    func updatePull(_ newValue: Float) {
        // Weapon and Semi-Automatic (Bow) both hold against the pull until the break point,
        // then "fire"/snap once pushed past the end.
        if mode == .weapon || mode == .semiAutomatic {
            if newValue < startPos {
                virtualPull = newValue
                isFired = false
            } else if newValue >= startPos && newValue < endPos {
                if isFired {
                    virtualPull = newValue
                } else {
                    let resistanceReduction = 1.0 - strength
                    let delta = newValue - startPos
                    virtualPull = startPos + delta * resistanceReduction * 0.1
                }
            } else {
                virtualPull = newValue
                isFired = true
            }
        } else {
            virtualPull = newValue
        }
    }
    
    func tickVibration() {
        guard isUIVisible && mode != .off else {
            shakeOffset = 0
            return
        }
        
        let isInActiveZone = virtualPull >= startPos
        if isInActiveZone {
            let time = Date().timeIntervalSince1970
            switch mode {
            case .vibration, .multiPositionVibration:
                let freqFactor = Double(frequency) * 50.0 + 10.0
                let ampFactor = Double(amplitude) * 5.0
                shakeOffset = CGFloat(sin(time * freqFactor * 2 * .pi) * ampFactor)
            case .automatic:
                // Automatic-weapon bucking: rate scales with the Frequency slider.
                let rate = Double(frequency) * 25.0 + 6.0
                let ampFactor = Double(strength) * 4.0
                shakeOffset = CGFloat(sin(time * rate * 2 * .pi) * ampFactor)
            case .weapon where !isFired:
                let ampFactor = Double(strength) * 2.0
                shakeOffset = CGFloat(sin(time * 30.0 * 2 * .pi) * ampFactor)
            case .feedback:
                let ampFactor = Double(strength) * 0.8
                shakeOffset = CGFloat(sin(time * 20.0 * 2 * .pi) * ampFactor)
            default:
                shakeOffset = 0
            }
        } else {
            shakeOffset = 0
        }
    }
}

public struct TriggerConfigView: View {
    @ObservedObject var manager: ControllerManager
    let title: String
    
    @Binding var mode: TriggerMode
    @Binding var start: Float
    @Binding var end: Float
    @Binding var strength: Float
    @Binding var amplitude: Float
    @Binding var frequency: Float
    @Binding var endStrength: Float
    let livePull: Float
    
    public init(manager: ControllerManager, title: String, mode: Binding<TriggerMode>, start: Binding<Float>, end: Binding<Float>, strength: Binding<Float>, amplitude: Binding<Float>, frequency: Binding<Float>, endStrength: Binding<Float>, livePull: Float) {
        self.manager = manager
        self.title = title
        self._mode = mode
        self._start = start
        self._end = end
        self._strength = strength
        self._amplitude = amplitude
        self._frequency = frequency
        self._endStrength = endStrength
        self.livePull = livePull
    }
    
    /// Whether this mode uses a start position
    private var showStart: Bool {
        mode != .off && mode != .fullPress
    }
    
    /// Whether this mode uses an end position
    private var showEnd: Bool {
        switch mode {
        case .weapon, .semiAutomatic, .sectionResistance, .slopeFeedback, .automatic:
            return true
        default:
            return false
        }
    }

    /// Whether this mode uses resistance strength
    private var showStrength: Bool {
        switch mode {
        case .feedback, .weapon, .sectionResistance, .semiAutomatic, .automatic, .slopeFeedback, .multiPositionFeedback:
            return true
        default:
            return false
        }
    }

    /// Whether this mode uses end strength.
    /// Slope Feedback uses it as the ending resistance; Semi-Automatic uses it as snap force.
    private var showEndStrength: Bool {
        mode == .slopeFeedback || mode == .semiAutomatic
    }

    /// Label for the end-strength slider, which means different things per mode.
    private var endStrengthLabel: String {
        mode == .semiAutomatic ? "Snap Force" : "End Strength (Slope)"
    }
    
    /// Whether this mode uses vibration amplitude
    private var showAmplitude: Bool {
        switch mode {
        case .vibration, .multiPositionVibration:
            return true
        default:
            return false
        }
    }
    
    /// Whether this mode uses frequency
    private var showFrequency: Bool {
        switch mode {
        case .vibration, .multiPositionVibration, .automatic:
            return true
        default:
            return false
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Physical Pull")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 100, height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: CGFloat(livePull) * 100, height: 8)
                        }
                    }
                }
                
                // Mode picker — grouped by category
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger Mode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Trigger Mode", selection: $mode) {
                        ForEach(["Basic", "Advanced", "Expert"], id: \.self) { category in
                            Section(header: Text(category)) {
                                ForEach(TriggerMode.allCases.filter { $0.category == category }) { modeCase in
                                    Text(modeCase.rawValue).tag(modeCase)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Mode description
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                if mode != .off {
                    VStack(spacing: 16) {
                        if showStart {
                            HStack {
                                Text("Start Position")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", start))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $start, in: 0...1)
                        }
                        
                        if showEnd {
                            HStack {
                                Text("End Position")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", end))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $end, in: (start + 0.05)...1.0)
                        }
                        
                        if showStrength {
                            HStack {
                                Text("Resistance Strength")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", strength * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $strength, in: 0...1)
                        }
                        
                        if showEndStrength {
                            HStack {
                                Text(endStrengthLabel)
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", endStrength * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $endStrength, in: 0...1)
                        }
                        
                        if showAmplitude {
                            HStack {
                                Text("Vibration Amplitude")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", amplitude * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $amplitude, in: 0...1)
                        }
                        
                        if showFrequency {
                            HStack {
                                Text(mode == .automatic ? "Effect Frequency" : "Vibration Frequency")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", frequency * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $frequency, in: 0...1)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    TriggerPreviewView(isUIVisible: manager.isUIVisible, mode: mode, startPos: start, endPos: end, strength: strength, amplitude: amplitude, frequency: frequency)
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        Text("Trigger resistance is disabled.")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    private var modeDescription: String {
        switch mode {
        case .off: return "No adaptive trigger effect."
        case .feedback: return "Continuous resistance from the start position onward."
        case .weapon: return "A resistance wall between start and end that breaks when pushed past — a firearm trigger pull."
        case .vibration: return "Vibration from the start position with configurable amplitude and frequency."
        case .sectionResistance: return "Resistance only within the start–end zone — no effect outside it."
        case .semiAutomatic: return "Holds firm, then snaps back hard once pushed past the end — bow-draw / semi-auto feel. Use Snap Force to tune the kick."
        case .automatic: return "Continuous automatic-weapon bucking between start and end — set Frequency for the fire rate."
        case .slopeFeedback: return "Resistance ramps from the start strength to the end strength across the range — a progressive brake."
        case .multiPositionFeedback: return "Alternating strong/weak resistance zones for a bumpy, textured feel."
        case .multiPositionVibration: return "Alternating vibration intensities for a textured vibration."
        case .fullPress: return "Maximum resistance across the entire trigger travel."
        }
    }
}
