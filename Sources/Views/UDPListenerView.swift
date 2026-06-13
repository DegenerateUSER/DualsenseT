import SwiftUI

public struct UDPListenerView: View {
    @ObservedObject var manager: ControllerManager
    @ObservedObject var listener: UDPListener
    
    public init(manager: ControllerManager, listener: UDPListener) {
        self.manager = manager
        self.listener = listener
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("DualSenseX UDP Emulation")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Emulates DualSenseX UDP server on localhost port 6969. Applications, compatibility wrappers (Wine, CrossOver, GPTK), or game mods can send JSON instruction packets to dynamically update adaptive triggers and LEDs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Toggle("Start UDP Server Automatically", isOn: Binding(get: {
                        UserDefaults.standard.bool(forKey: "autoStartUdp")
                    }, set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoStartUdp")
                    }))
                    .padding(.bottom, 4)
                    
                    HStack {
                        if listener.isRunning {
                            Button("Stop UDP Server") {
                                listener.stop()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button("Start UDP Server") {
                                listener.start(manager: manager)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(listener.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(listener.isRunning ? "Online" : "Offline")
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                Text("UDP Console & Logs")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    Text(listener.lastMessage)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}
