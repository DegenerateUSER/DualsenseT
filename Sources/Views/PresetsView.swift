import SwiftUI

public struct PresetsView: View {
    @ObservedObject var manager: ControllerManager
    @ObservedObject var presetManager: PresetManager
    
    @State private var newPresetName: String = ""
    
    public init(manager: ControllerManager, presetManager: PresetManager) {
        self.manager = manager
        self.presetManager = presetManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Controller Presets")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Save Current Preset
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save Current Configuration")
                        .font(.headline)
                    
                    HStack {
                        TextField("Preset Name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Save") {
                            guard !newPresetName.isEmpty else { return }
                            let newPreset = TriggerPreset(
                                name: newPresetName,
                                l2Mode: manager.l2Mode,
                                l2Start: manager.l2Start,
                                l2End: manager.l2End,
                                l2Strength: manager.l2Strength,
                                l2Amplitude: manager.l2Amplitude,
                                l2Frequency: manager.l2Frequency,
                                r2Mode: manager.r2Mode,
                                r2Start: manager.r2Start,
                                r2End: manager.r2End,
                                r2Strength: manager.r2Strength,
                                r2Amplitude: manager.r2Amplitude,
                                r2Frequency: manager.r2Frequency,
                                ledRed: Float(manager.ledColor.redComponent),
                                ledGreen: Float(manager.ledColor.greenComponent),
                                ledBlue: Float(manager.ledColor.blueComponent),
                                isLedPulsing: manager.isLedPulsing
                            )
                            presetManager.savePreset(preset: newPreset)
                            newPresetName = ""
                        }
                        .disabled(newPresetName.isEmpty)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("Default Built-in Presets")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ForEach(manager.defaultPresets) { preset in
                        HStack {
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button("Apply") {
                                manager.applyPreset(preset)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                
                if !presetManager.customPresets.isEmpty {
                    Text("Custom Saved Presets")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    VStack(spacing: 8) {
                        ForEach(presetManager.customPresets) { preset in
                            HStack {
                                Text(preset.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Apply") {
                                    manager.applyPreset(preset)
                                }
                                Button("Delete") {
                                    presetManager.deletePreset(preset: preset)
                                }
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
