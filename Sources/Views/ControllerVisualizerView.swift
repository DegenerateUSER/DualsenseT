import SwiftUI
import AppKit

public struct ControllerVisualizerView: View {
    @ObservedObject var manager: ControllerManager
    
    public init(manager: ControllerManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack {
            Text("Live Input Map")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .leading])
            
            if manager.activeController != nil {
                Spacer()
                ZStack {
                    DualSenseSilhouette()
                        .fill(Color.white.opacity(0.04))
                        .overlay(DualSenseSilhouette().stroke(Color.white.opacity(0.15), lineWidth: 1.5))
                        .frame(width: 380, height: 260)
                    
                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: manager.connectionType == "USB" ? "cable.connector" : "bolt.horizontal.wireframe.fill")
                                .font(.system(size: 10))
                            Text(manager.connectionType)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                        Spacer()
                    }
                    .padding(.top, 16)
                    .frame(width: 380, height: 260)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(manager.buttonsPressed["touchpad"] == true ? Color.blue.opacity(0.2) : Color.white.opacity(0.02))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(manager.buttonsPressed["touchpad"] == true ? Color.blue : Color.white.opacity(0.15), lineWidth: 1.2))
                        .frame(width: 120, height: 60)
                        .offset(y: -45)
                    
                    Group {
                        DpadButton(direction: "Up", isPressed: manager.buttonsPressed["dpadUp"] == true)
                            .offset(x: -95, y: -25)
                        DpadButton(direction: "Down", isPressed: manager.buttonsPressed["dpadDown"] == true)
                            .offset(x: -95, y: 15)
                        DpadButton(direction: "Left", isPressed: manager.buttonsPressed["dpadLeft"] == true)
                            .offset(x: -115, y: -5)
                        DpadButton(direction: "Right", isPressed: manager.buttonsPressed["dpadRight"] == true)
                            .offset(x: -75, y: -5)
                    }
                    
                    Group {
                        ActionButtonLabel(label: "triangle", isPressed: manager.buttonsPressed["triangle"] == true)
                            .offset(x: 95, y: -25)
                        ActionButtonLabel(label: "cross", isPressed: manager.buttonsPressed["cross"] == true)
                            .offset(x: 95, y: 15)
                        ActionButtonLabel(label: "square", isPressed: manager.buttonsPressed["square"] == true)
                            .offset(x: 75, y: -5)
                        ActionButtonLabel(label: "circle", isPressed: manager.buttonsPressed["circle"] == true)
                            .offset(x: 115, y: -5)
                    }
                    
                    ShoulderButton(side: "L", isPressed: manager.buttonsPressed["l1"] == true)
                        .offset(x: -110, y: -90)
                    ShoulderButton(side: "R", isPressed: manager.buttonsPressed["r1"] == true)
                        .offset(x: 110, y: -90)
                    
                    TriggerButtonVisual(side: "L", value: manager.leftTriggerValue, isPressed: manager.buttonsPressed["l2"] == true)
                        .offset(x: -110, y: -125)
                    TriggerButtonVisual(side: "R", value: manager.rightTriggerValue, isPressed: manager.buttonsPressed["r2"] == true)
                        .offset(x: 110, y: -125)
                    
                    StickVisual(value: manager.leftStickValue, isPressed: manager.buttonsPressed["l3"] == true)
                        .offset(x: -55, y: 40)
                    
                    StickVisual(value: manager.rightStickValue, isPressed: manager.buttonsPressed["r3"] == true)
                        .offset(x: 55, y: 40)
                    
                    SmallButton(label: "create", isPressed: manager.buttonsPressed["create"] == true)
                        .offset(x: -65, y: -50)
                    SmallButton(label: "options", isPressed: manager.buttonsPressed["options"] == true)
                        .offset(x: 65, y: -50)
                    
                    SmallButton(label: "ps", isPressed: manager.buttonsPressed["ps"] == true)
                        .offset(x: 0, y: 15)
                    
                    if manager.touchpadPrimaryActive {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                            .offset(x: manager.touchpadPrimary.x * 50, y: -45 - (manager.touchpadPrimary.y * 25))
                            .shadow(color: .cyan, radius: 4)
                    }
                    if manager.touchpadSecondaryActive {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 8, height: 8)
                            .offset(x: manager.touchpadSecondary.x * 50, y: -45 - (manager.touchpadSecondary.y * 25))
                            .shadow(color: .purple, radius: 4)
                    }
                }
                .frame(width: 380, height: 260)
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Connect a DualSense controller to view live mapping")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

public struct DpadButton: View {
    let direction: String
    let isPressed: Bool
    
    public init(direction: String, isPressed: Bool) {
        self.direction = direction
        self.isPressed = isPressed
    }
    
    public var body: some View {
        Rectangle()
            .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
            .frame(width: 16, height: 16)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isPressed ? .cyan.opacity(0.5) : .clear, radius: 4)
    }
}

public struct ActionButtonLabel: View {
    let label: String
    let isPressed: Bool
    
    public init(label: String, isPressed: Bool) {
        self.label = label
        self.isPressed = isPressed
    }
    
    public var body: some View {
        Circle()
            .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
            )
            .overlay(symbolView)
            .shadow(color: isPressed ? .cyan.opacity(0.5) : .clear, radius: 4)
    }
    
    @ViewBuilder
    var symbolView: some View {
        switch label {
        case "triangle":
            Image(systemName: "triangle")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.green)
        case "cross":
            Image(systemName: "multiply")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.blue)
        case "square":
            Image(systemName: "square")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.pink)
        case "circle":
            Image(systemName: "circle")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.red)
        default:
            EmptyView()
        }
    }
}

public struct ShoulderButton: View {
    let side: String
    let isPressed: Bool
    
    public init(side: String, isPressed: Bool) {
        self.side = side
        self.isPressed = isPressed
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
            .frame(width: 45, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Text(side + "1")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            )
            .shadow(color: isPressed ? .cyan.opacity(0.5) : .clear, radius: 4)
    }
}

public struct TriggerButtonVisual: View {
    let side: String
    let value: Float
    let isPressed: Bool
    
    public init(side: String, value: Float, isPressed: Bool) {
        self.side = side
        self.value = value
        self.isPressed = isPressed
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 35, height: 25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    .frame(width: 35, height: 25 * CGFloat(value))
                    .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: value)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(side + "2")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

public struct StickVisual: View {
    let value: CGPoint
    let isPressed: Bool
    
    public init(value: CGPoint, isPressed: Bool) {
        self.value = value
        self.isPressed = isPressed
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                .frame(width: 44, height: 44)
            
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 40, height: 40)
            
            Circle()
                .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.15))
                .overlay(
                    Circle()
                        .stroke(isPressed ? Color.cyan : Color.white.opacity(0.4), lineWidth: 1.5)
                )
                .frame(width: 26, height: 26)
                .offset(x: value.x * 12, y: -value.y * 12)
                .shadow(color: isPressed ? .cyan.opacity(0.5) : .clear, radius: 4)
                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: value)
        }
    }
}

public struct SmallButton: View {
    let label: String
    let isPressed: Bool
    
    public init(label: String, isPressed: Bool) {
        self.label = label
        self.isPressed = isPressed
    }
    
    public var body: some View {
        Group {
            if label == "ps" {
                Circle()
                    .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    )
            } else {
                Capsule()
                    .fill(isPressed ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
                    .frame(width: 14, height: 6)
                    .rotationEffect(.degrees(label == "create" ? -30 : 30))
                    .overlay(
                        Capsule()
                            .stroke(isPressed ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
                            .rotationEffect(.degrees(label == "create" ? -30 : 30))
                    )
            }
        }
        .shadow(color: isPressed ? .cyan.opacity(0.5) : .clear, radius: 4)
    }
}

public struct DualSenseSilhouette: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.3, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.15))
        
        path.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.4), control: CGPoint(x: w * 0.85, y: h * 0.2))
        path.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.9), control: CGPoint(x: w * 0.95, y: h * 0.65))
        path.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.85), control: CGPoint(x: w * 0.8, y: h * 0.95))
        
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.75), control: CGPoint(x: w * 0.6, y: h * 0.75))
        path.addQuadCurve(to: CGPoint(x: w * 0.3, y: h * 0.85), control: CGPoint(x: w * 0.4, y: h * 0.75))
        path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.9), control: CGPoint(x: w * 0.2, y: h * 0.95))
        
        path.addQuadCurve(to: CGPoint(x: w * 0.1, y: h * 0.4), control: CGPoint(x: w * 0.05, y: h * 0.65))
        path.addQuadCurve(to: CGPoint(x: w * 0.3, y: h * 0.15), control: CGPoint(x: w * 0.15, y: h * 0.2))
        
        path.closeSubpath()
        return path
    }
}
