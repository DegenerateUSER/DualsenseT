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
                        let startX = CGFloat(startPos) * width
                        let endX = mode == .weapon ? CGFloat(endPos) * width : width
                        
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
        }
    }
    
    var indicatorColor: Color {
        if mode == .off { return .white }
        if virtualPull >= startPos {
            if mode == .weapon && !isFired { return .red }
            return activeZoneColor
        }
        return .white
    }
    
    func updatePull(_ newValue: Float) {
        if mode == .weapon {
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
            if mode == .vibration {
                let time = Date().timeIntervalSince1970
                let freqFactor = Double(frequency) * 50.0 + 10.0
                let ampFactor = Double(amplitude) * 5.0
                shakeOffset = CGFloat(sin(time * freqFactor * 2 * .pi) * ampFactor)
            } else if mode == .weapon && !isFired {
                let time = Date().timeIntervalSince1970
                let ampFactor = Double(strength) * 2.0
                shakeOffset = CGFloat(sin(time * 30.0 * 2 * .pi) * ampFactor)
            } else if mode == .feedback {
                let time = Date().timeIntervalSince1970
                let ampFactor = Double(strength) * 0.8
                shakeOffset = CGFloat(sin(time * 20.0 * 2 * .pi) * ampFactor)
            } else {
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
    let livePull: Float
    
    public init(manager: ControllerManager, title: String, mode: Binding<TriggerMode>, start: Binding<Float>, end: Binding<Float>, strength: Binding<Float>, amplitude: Binding<Float>, frequency: Binding<Float>, livePull: Float) {
        self.manager = manager
        self.title = title
        self._mode = mode
        self._start = start
        self._end = end
        self._strength = strength
        self._amplitude = amplitude
        self._frequency = frequency
        self.livePull = livePull
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
                
                Picker("Trigger Mode", selection: $mode) {
                    ForEach(TriggerMode.allCases) { modeCase in
                        Text(modeCase.rawValue).tag(modeCase)
                    }
                }
                .pickerStyle(.segmented)
                
                if mode != .off {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Start Position")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.2f", start))
                                .font(.system(.body, design: .monospaced))
                        }
                        Slider(value: $start, in: 0...1)
                        
                        if mode == .weapon {
                            HStack {
                                Text("End Position")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", end))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $end, in: (start + 0.05)...1.0)
                        }
                        
                        if mode == .feedback || mode == .weapon {
                            HStack {
                                Text("Resistance Strength")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", strength * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $strength, in: 0...1)
                        }
                        
                        if mode == .vibration {
                            HStack {
                                Text("Vibration Amplitude")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.0f%%", amplitude * 100))
                                    .font(.system(.body, design: .monospaced))
                            }
                            Slider(value: $amplitude, in: 0...1)
                            
                            HStack {
                                Text("Vibration Frequency")
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
}
