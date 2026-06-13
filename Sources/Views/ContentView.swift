import SwiftUI

public enum AppTab {
    case triggersL2
    case triggersR2
    case led
    case visualizer
    case sensors
    case server
    case presets
    case settings
}

public struct ContentView: View {
    @ObservedObject var manager: ControllerManager
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var udpListener: UDPListener
    @State private var activeTab: AppTab = .visualizer
    
    public init(manager: ControllerManager, presetManager: PresetManager, udpListener: UDPListener) {
        self.manager = manager
        self.presetManager = presetManager
        self.udpListener = udpListener
    }
    
    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -180, y: -130)
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 180, y: 130)
            
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 12) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DualSenseT")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        
                        if manager.activeController != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "battery.100")
                                    .foregroundColor(.green)
                                Text(String(format: "%.0f%%", manager.batteryLevel * 100))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No controller")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 24)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Sidebar Navigation Items
                    VStack(spacing: 6) {
                        SidebarButton(title: "Left Trigger (L2)", icon: "slider.horizontal.3", isActive: activeTab == .triggersL2) {
                            activeTab = .triggersL2
                        }
                        SidebarButton(title: "Right Trigger (R2)", icon: "slider.horizontal.3", isActive: activeTab == .triggersR2) {
                            activeTab = .triggersR2
                        }
                        SidebarButton(title: "Lightbar", icon: "paintpalette", isActive: activeTab == .led) {
                            activeTab = .led
                        }
                        SidebarButton(title: "Live Map", icon: "gamecontroller", isActive: activeTab == .visualizer) {
                            activeTab = .visualizer
                        }
                        SidebarButton(title: "Sensors", icon: "waveform.path.ecg", isActive: activeTab == .sensors) {
                            activeTab = .sensors
                        }
                        SidebarButton(title: "UDP Server", icon: "network", isActive: activeTab == .server) {
                            activeTab = .server
                        }
                        SidebarButton(title: "Presets", icon: "doc.text", isActive: activeTab == .presets) {
                            activeTab = .presets
                        }
                        SidebarButton(title: "Settings", icon: "gearshape", isActive: activeTab == .settings) {
                            activeTab = .settings
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                }
                .frame(width: 200)
                .background(Color.black.opacity(0.15))
                
                Divider()
                
                // Detail view
                VStack(spacing: 0) {
                    switch activeTab {
                    case .triggersL2:
                        TriggerConfigView(
                            manager: manager,
                            title: "Left Trigger (L2)",
                            mode: $manager.l2Mode,
                            start: $manager.l2Start,
                            end: $manager.l2End,
                            strength: $manager.l2Strength,
                            amplitude: $manager.l2Amplitude,
                            frequency: $manager.l2Frequency,
                            livePull: manager.leftTriggerValue
                        )
                    case .triggersR2:
                        TriggerConfigView(
                            manager: manager,
                            title: "Right Trigger (R2)",
                            mode: $manager.r2Mode,
                            start: $manager.r2Start,
                            end: $manager.r2End,
                            strength: $manager.r2Strength,
                            amplitude: $manager.r2Amplitude,
                            frequency: $manager.r2Frequency,
                            livePull: manager.rightTriggerValue
                        )
                    case .led:
                        LEDColorView(manager: manager)
                    case .visualizer:
                        ControllerVisualizerView(manager: manager)
                    case .sensors:
                        InputTesterView(manager: manager)
                    case .server:
                        UDPListenerView(manager: manager, listener: udpListener)
                    case .presets:
                        PresetsView(manager: manager, presetManager: presetManager)
                    case .settings:
                        SettingsView(manager: manager, presetManager: presetManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: activeTab) { _, newValue in
            manager.isSensorsTabActive = (newValue == .sensors)
        }
        .onAppear {
            manager.isSensorsTabActive = (activeTab == .sensors)
        }
    }
}

public struct SidebarButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    public init(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20, alignment: .center)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isActive ? Color.blue.opacity(0.2) : Color.clear)
            .foregroundColor(isActive ? .white : .white.opacity(0.7))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
