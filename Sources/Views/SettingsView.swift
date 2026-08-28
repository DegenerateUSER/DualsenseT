import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @ObservedObject var manager: ControllerManager
    @ObservedObject var presetManager: PresetManager
    
    public init(manager: ControllerManager, presetManager: PresetManager) {
        self.manager = manager
        self.presetManager = presetManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Application Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                        .font(.headline)
                    
                    Text("Automatically starts the menu bar helper in the background when your Mac boots up.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("Touchpad Gesture Remapping")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Map touchpad swipe directions to keyboard shortcuts for media or navigation control.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(["Up", "Down", "Left", "Right"], id: \.self) { direction in
                        HStack {
                            Text("Swipe \(direction):")
                                .font(.body)
                                .frame(width: 100, alignment: .leading)
                            
                            Picker("", selection: Binding(get: {
                                self.manager.touchpadActions[direction] ?? "None"
                            }, set: { newValue in
                                self.manager.touchpadActions[direction] = newValue
                            })) {
                                ForEach(["None", "Spacebar", "Left Arrow", "Right Arrow", "Up Arrow", "Down Arrow"], id: \.self) { action in
                                    Text(action).tag(action)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("Per-App Profiles")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Automatically apply custom trigger and LED profiles when a specific application gains focus.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if manager.appProfiles.isEmpty {
                        Text("No applications configured.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(manager.appProfiles.keys).sorted(), id: \.self) { bundleId in
                            HStack {
                                Text(bundleId.components(separatedBy: ".").last ?? bundleId)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                
                                Picker("", selection: Binding(get: {
                                    self.manager.appProfiles[bundleId] ?? "Off"
                                }, set: { newValue in
                                    self.manager.appProfiles[bundleId] = newValue
                                    self.manager.saveAppProfiles()
                                })) {
                                    ForEach(manager.defaultPresets) { preset in
                                        Text(preset.name).tag(preset.name)
                                    }
                                    ForEach(presetManager.customPresets) { preset in
                                        Text(preset.name).tag(preset.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                                
                                Button(action: {
                                    self.manager.appProfiles.removeValue(forKey: bundleId)
                                    self.manager.saveAppProfiles()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button(action: {
                        self.manager.chooseApplication(presetManager: presetManager)
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Application Profile...")
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("System Info")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("App Version:")
                        Spacer()
                        Text("1.0.0 (Release)")
                    }
                    Divider()
                    HStack {
                        Text("Active Controller:")
                        Spacer()
                        Text(manager.isConnected ? "DualSense (\(manager.connectionType))" : "No controller connected")
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            self.launchAtLogin = isLaunchAtLoginEnabled()
        }
    }
    
    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                print("Failed to register login service: \(error)")
            }
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
