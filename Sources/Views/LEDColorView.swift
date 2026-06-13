import SwiftUI
import AppKit

public struct LEDColorView: View {
    @ObservedObject var manager: ControllerManager
    
    let quickColors: [(name: String, color: NSColor)] = [
        ("PlayStation Blue", NSColor(red: 0.0, green: 0.44, blue: 0.82, alpha: 1.0)),
        ("Neon Cyan", NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)),
        ("Neon Purple", NSColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 1.0)),
        ("Red Team", NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)),
        ("Green Light", NSColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 1.0)),
        ("Solid White", NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    ]
    
    public init(manager: ControllerManager) {
        self.manager = manager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("LED Lightbar Control")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    ColorPicker("Custom Color", selection: Binding(get: {
                        Color(self.manager.ledColor)
                    }, set: { newColor in
                        if let nsCol = NSColor(newColor).usingColorSpace(.sRGB) {
                            self.manager.ledColor = nsCol
                        }
                    }))
                    .font(.headline)
                    
                    Toggle("Breathing Light Effect", isOn: $manager.isLedPulsing)
                        .font(.headline)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("Quick Color Presets")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(quickColors, id: \.name) { preset in
                        Button(action: {
                            self.manager.ledColor = preset.color
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(preset.color))
                                    .frame(width: 16, height: 16)
                                Text(preset.name)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}
