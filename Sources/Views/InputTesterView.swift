import SwiftUI
import GameController

public struct GyroscopeBoxView: View {
    let attitude: GCQuaternion
    
    public init(attitude: GCQuaternion) {
        self.attitude = attitude
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text("Motion / Gyroscope")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 120, height: 120)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.15), Color.blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan, lineWidth: 1.5))
                    .frame(width: 80, height: 50)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 8)
                    .rotation3DEffect(
                        .radians(angleAxis.angle),
                        axis: (x: angleAxis.x, y: angleAxis.y, z: angleAxis.z)
                    )
            }
            .frame(height: 140)
            
            Text("Attitude Quaternion:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(String(format: "w:%.2f x:%.2f y:%.2f z:%.2f", attitude.w, attitude.x, attitude.y, attitude.z))
                .font(.system(.caption, design: .monospaced))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    var angleAxis: (angle: Double, x: Double, y: Double, z: Double) {
        let w = Double(attitude.w)
        let x = Double(attitude.x)
        let y = Double(attitude.y)
        let z = Double(attitude.z)
        
        let angle = 2.0 * acos(max(-1.0, min(1.0, w)))
        let scale = sqrt(x*x + y*y + z*z)
        
        if scale < 0.001 {
            return (angle: 0.0, x: 1.0, y: 0.0, z: 0.0)
        } else {
            return (angle: angle, x: x / scale, y: y / scale, z: z / scale)
        }
    }
}

public struct InputTesterView: View {
    @ObservedObject var manager: ControllerManager
    
    public init(manager: ControllerManager) {
        self.manager = manager
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sensor Diagnostic & Coordinates")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if manager.isConnected {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analog Sticks")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: "Left Stick X: %.3f", manager.leftStickValue.x))
                                  .font(.system(.body, design: .monospaced))
                                Text(String(format: "Left Stick Y: %.3f", manager.leftStickValue.y))
                                  .font(.system(.body, design: .monospaced))
                                Text(String(format: "Right Stick X: %.3f", manager.rightStickValue.x))
                                  .font(.system(.body, design: .monospaced))
                                Text(String(format: "Right Stick Y: %.3f", manager.rightStickValue.y))
                                  .font(.system(.body, design: .monospaced))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            Text("Touchpad")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Primary Touch: " + (manager.touchpadPrimaryActive ? String(format: "x:%.2f y:%.2f", manager.touchpadPrimary.x, manager.touchpadPrimary.y) : "Inactive"))
                                  .font(.system(.body, design: .monospaced))
                                Text("Secondary Touch: " + (manager.touchpadSecondaryActive ? String(format: "x:%.2f y:%.2f", manager.touchpadSecondary.x, manager.touchpadSecondary.y) : "Inactive"))
                                  .font(.system(.body, design: .monospaced))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        VStack(spacing: 12) {
                            GyroscopeBoxView(attitude: manager.motionAttitude)
                            
                            Button(action: {
                                manager.recenterSensors()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Recenter Sensors")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.blue.opacity(0.35))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Connect a controller to view live diagnostic streams")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                manager.recenterSensors()
            }
        }
    }
}
