// Hallmark · pre-emit critique: P4 H5 E4 S5 R4 V4
import SwiftUI
import AppKit
import GameController

public struct ControllerVisualizerView: View {
    @ObservedObject var manager: ControllerManager

    @State private var pulseOpacity: Double = 1.0

    public init(manager: ControllerManager) {
        self.manager = manager
    }

    /// The controller is drawn on a fixed 1.45 : 1 canvas so its proportions never distort.
    /// Every element is positioned through `ControllerLayout`, which maps normalized
    /// coordinates (0…1 across the canvas) to absolute points.
    private static let aspectRatio: CGFloat = 1.45

    public var body: some View {
        VStack(spacing: 0) {
            Text("Live Input Map")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .leading])

            if manager.isConnected {
                GeometryReader { geo in
                    // Fit the fixed-aspect canvas inside the available area, centered.
                    // Bleed margin so shadows/glows don't clip at the edges.
                    let shadowBleed: CGFloat = 36
                    let available = CGSize(width: geo.size.width - shadowBleed,
                                           height: geo.size.height - shadowBleed)
                    let canvasW = min(available.width, available.height * Self.aspectRatio)
                    let canvasH = canvasW / Self.aspectRatio
                    let layout = ControllerLayout(width: canvasW, height: canvasH)

                    controllerCanvas(layout)
                        .frame(width: canvasW, height: canvasH)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(20)
                .onAppear { startPulsingAnimation() }
                .onReceive(manager.$isLedPulsing) { _ in startPulsingAnimation() }
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

    /// Builds the full controller from a single proportional `layout`. Scale-derived sizes
    /// keep every element proportional to the canvas.
    @ViewBuilder
    private func controllerCanvas(_ layout: ControllerLayout) -> some View {
        let s = layout.scale          // 1.0 at the reference 380pt-wide canvas
        let tpPressed = manager.buttonsPressed["touchpad"] == true
        let led = Color(manager.ledColor)
        let touchpadRect = layout.touchpadRect

        ZStack(alignment: .topLeading) {
            // 1. Outer shell — solid body so it reads on any window background.
            DualSenseShell()
                .fill(LinearGradient(colors: [Color(white: 0.86), Color(white: 0.52)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    DualSenseShell().stroke(
                        LinearGradient(colors: [Color.white.opacity(0.72), Color.black.opacity(0.30)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.25 * s)
                )
                .shadow(color: Color.black.opacity(0.58), radius: 18 * s, x: 0, y: 11 * s)

            // 2. The DualSense's dark central chassis. The light wings remain visible around
            //    the D-pad/action clusters while this plate anchors the pad, sticks and PS key.
            DualSenseAccentPlate()
                .fill(LinearGradient(colors: [Color(white: 0.14), Color(white: 0.035)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(DualSenseAccentPlate().stroke(Color.white.opacity(0.10), lineWidth: 1.0 * s))
                .shadow(color: Color.black.opacity(0.30), radius: 4 * s, y: 2 * s)

            // 3. Lightbar — glowing strip framing the sides & bottom of the touchpad.
            //    Drawn before the touchpad so the pad sits cleanly inside the glow.
            DualSenseLightbar()
                .stroke(led, style: StrokeStyle(lineWidth: 3.0 * s, lineCap: .round, lineJoin: .round))
                .shadow(color: led.opacity(0.9),
                        radius: (manager.isLedPulsing ? 3.0 + CGFloat((1.0 - pulseOpacity) * 5.0) : 4.0) * s)
                .shadow(color: led.opacity(0.5),
                        radius: (manager.isLedPulsing ? 6.0 + CGFloat((1.0 - pulseOpacity) * 8.0) : 9.0) * s)
                .opacity(manager.isLedPulsing ? 0.35 + (pulseOpacity * 0.65) : 1.0)

            // 4. Touchpad.
            // Use a standard RoundedRectangle in its own local frame. The old custom Shape
            // occupied the entire controller canvas while returning an offset sub-path; on
            // macOS SwiftUI its gradient backing leaked from the touchpad's top-left corner
            // to the canvas edges, producing the giant rectangle that hid the right/lower body.
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(LinearGradient(
                    colors: tpPressed ? [Color(white: 0.12), Color(white: 0.055)] : [Color(white: 0.22), Color(white: 0.11)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: touchpadRect.width, height: touchpadRect.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * s)
                        .stroke(tpPressed ? led.opacity(0.9) : Color.white.opacity(0.14),
                                lineWidth: (tpPressed ? 1.6 : 1.0) * s)
                )
                .shadow(color: Color.black.opacity(tpPressed ? 0.5 : 0.3),
                        radius: (tpPressed ? 1.0 : 4.0) * s, y: (tpPressed ? 0.5 : 2.5) * s)
                .position(x: touchpadRect.midX, y: touchpadRect.midY)
                .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: tpPressed)

            // 5. Triggers seated on the shoulders, shoulder buttons below them.
            TriggerButtonVisual(side: "L", value: manager.leftTriggerValue, isPressed: manager.buttonsPressed["l2"] == true)
                .scaleEffect(s).position(layout.point(0.215, 0.12))
            TriggerButtonVisual(side: "R", value: manager.rightTriggerValue, isPressed: manager.buttonsPressed["r2"] == true)
                .scaleEffect(s).position(layout.point(0.785, 0.12))
            ShoulderButton(side: "L", isPressed: manager.buttonsPressed["l1"] == true)
                .scaleEffect(s).position(layout.point(0.215, 0.225))
            ShoulderButton(side: "R", isPressed: manager.buttonsPressed["r1"] == true)
                .scaleEffect(s).position(layout.point(0.785, 0.225))

            // 6. D-pad cluster (upper-left face) on a unifying plus-shaped backing.
            ClusterBacking(kind: .plus)
                .scaleEffect(s).position(layout.point(0.255, 0.47))
            DpadButton(direction: "Up", isPressed: manager.buttonsPressed["dpadUp"] == true)
                .scaleEffect(s).position(layout.point(0.255, 0.395))
            DpadButton(direction: "Down", isPressed: manager.buttonsPressed["dpadDown"] == true)
                .scaleEffect(s).position(layout.point(0.255, 0.545))
            DpadButton(direction: "Left", isPressed: manager.buttonsPressed["dpadLeft"] == true)
                .scaleEffect(s).position(layout.point(0.213, 0.47))
            DpadButton(direction: "Right", isPressed: manager.buttonsPressed["dpadRight"] == true)
                .scaleEffect(s).position(layout.point(0.297, 0.47))

            // 7. Action button cluster (upper-right face) on a circular backing.
            ClusterBacking(kind: .circle)
                .scaleEffect(s).position(layout.point(0.745, 0.47))
            ActionButtonLabel(label: "triangle", isPressed: manager.buttonsPressed["triangle"] == true)
                .scaleEffect(s).position(layout.point(0.745, 0.395))
            ActionButtonLabel(label: "cross", isPressed: manager.buttonsPressed["cross"] == true)
                .scaleEffect(s).position(layout.point(0.745, 0.545))
            ActionButtonLabel(label: "square", isPressed: manager.buttonsPressed["square"] == true)
                .scaleEffect(s).position(layout.point(0.703, 0.47))
            ActionButtonLabel(label: "circle", isPressed: manager.buttonsPressed["circle"] == true)
                .scaleEffect(s).position(layout.point(0.787, 0.47))

            // 8. Create / Options.
            SmallButton(label: "create", isPressed: manager.buttonsPressed["create"] == true)
                .scaleEffect(s).position(layout.point(0.345, 0.30))
            SmallButton(label: "options", isPressed: manager.buttonsPressed["options"] == true)
                .scaleEffect(s).position(layout.point(0.655, 0.30))

            // 9. Player indicator LEDs just under the touchpad. Driven by the same
            //    `playerLEDs` bitmask the Haptics tab sets — transport-agnostic, so it
            //    works over Bluetooth (where there is no GCController playerIndex).
            PlayerIndicatorLEDs(litMask: manager.playerLEDs)
                .scaleEffect(s).position(layout.point(0.5, 0.385))

            // Speaker grille, PS and mute buttons down the center spine.
            HStack(spacing: 3 * s) {
                ForEach(0..<7) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 2.2 * s, height: 2.2 * s)
                }
            }
            .position(layout.point(0.5, 0.465))

            // 10. PlayStation and mute buttons, centered between the sticks.
            SmallButton(label: "ps", isPressed: manager.buttonsPressed["ps"] == true)
                .scaleEffect(s).position(layout.point(0.5, 0.555))
            SmallButton(label: "mute", isPressed: manager.buttonsPressed["mute"] == true)
                .scaleEffect(s).position(layout.point(0.5, 0.635))

            // 11. Thumbsticks (symmetric, lower face).
            StickVisual(value: manager.leftStickValue, isPressed: manager.buttonsPressed["l3"] == true)
                .scaleEffect(s).position(layout.point(0.36, 0.715))
            StickVisual(value: manager.rightStickValue, isPressed: manager.buttonsPressed["r3"] == true)
                .scaleEffect(s).position(layout.point(0.64, 0.715))

            // 12. Live touch markers, mapped into the touchpad rectangle.
            if manager.touchpadPrimaryActive {
                TouchpadMarker(position: layout.touchpadPoint(manager.touchpadPrimary), color: .cyan)
            }
            if manager.touchpadSecondaryActive {
                TouchpadMarker(position: layout.touchpadPoint(manager.touchpadSecondary), color: .purple)
            }

            // 13. Connection status pill, top-center.
            HStack(spacing: 4) {
                Image(systemName: manager.connectionType == "USB" ? "cable.connector" : "bolt.horizontal.wireframe.fill")
                    .font(.system(size: 9 * s))
                Text(manager.connectionType)
                    .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 6 * s)
            .padding(.vertical, 3 * s)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .cornerRadius(6 * s)
            .overlay(RoundedRectangle(cornerRadius: 6 * s).stroke(Color.green.opacity(0.4), lineWidth: 1))
            .position(layout.point(0.5, 0.045))
        }
        .frame(width: layout.width, height: layout.height)
    }

    private func startPulsingAnimation() {
        if manager.isLedPulsing {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Cluster backing plates

/// Dark backing plate that visually unifies a button cluster.
public struct ClusterBacking: View {
    public enum Kind { case plus, circle }
    let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        let fill = LinearGradient(colors: [Color(white: 0.10), Color(white: 0.06)],
                                  startPoint: .top, endPoint: .bottom)
        let stroke = Color.white.opacity(0.08)
        ZStack {
            switch kind {
            case .plus:
                RoundedRectangle(cornerRadius: 5)
                    .fill(fill)
                    .frame(width: 54, height: 20)
                RoundedRectangle(cornerRadius: 5)
                    .fill(fill)
                    .frame(width: 20, height: 54)
                RoundedRectangle(cornerRadius: 5)
                    .stroke(stroke, lineWidth: 1)
                    .frame(width: 54, height: 20)
                RoundedRectangle(cornerRadius: 5)
                    .stroke(stroke, lineWidth: 1)
                    .frame(width: 20, height: 54)
            case .circle:
                Circle()
                    .fill(fill)
                    .frame(width: 62, height: 62)
                    .overlay(Circle().stroke(stroke, lineWidth: 1))
            }
        }
        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 2)
    }
}

// MARK: - Premium DualSense UI Components

public struct DpadButton: View {
    let direction: String
    let isPressed: Bool

    public init(direction: String, isPressed: Bool) {
        self.direction = direction
        self.isPressed = isPressed
    }

    public var body: some View {
        let activeGlow = Color.cyan

        RoundedRectangle(cornerRadius: 4)
            .fill(isPressed ? LinearGradient(colors: [Color(white: 0.30), Color(white: 0.24)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.22), Color(white: 0.15)], startPoint: .top, endPoint: .bottom))
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isPressed ? activeGlow : Color.white.opacity(0.16), lineWidth: 1.2)
            )
            .overlay(
                arrowImage
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(isPressed ? .white : Color.white.opacity(0.75))
                    .shadow(color: isPressed ? activeGlow : Color.clear, radius: isPressed ? 3 : 0)
            )
            .shadow(color: isPressed ? activeGlow.opacity(0.6) : Color.black.opacity(0.35),
                    radius: isPressed ? 1.0 : 3.0,
                    x: 0,
                    y: isPressed ? 0.5 : 2.5)
            .offset(y: isPressed ? 1.2 : 0)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
    }

    @ViewBuilder
    private var arrowImage: some View {
        switch direction {
        case "Up":
            Image(systemName: "chevron.up")
        case "Down":
            Image(systemName: "chevron.down")
        case "Left":
            Image(systemName: "chevron.left")
        case "Right":
            Image(systemName: "chevron.right")
        default:
            EmptyView()
        }
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
        let glyphColor = isPressed ? Color.white : Color.white.opacity(0.75)
        let activeGlow = Color.cyan

        Circle()
            .fill(isPressed ? LinearGradient(colors: [Color(white: 0.30), Color(white: 0.24)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.22), Color(white: 0.15)], startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(isPressed ? activeGlow : Color.white.opacity(0.16), lineWidth: 1.2)
            )
            .overlay(
                symbolView
                    .foregroundColor(glyphColor)
                    .shadow(color: isPressed ? activeGlow : Color.clear, radius: isPressed ? 3 : 0)
            )
            .shadow(color: isPressed ? activeGlow.opacity(0.6) : Color.black.opacity(0.35),
                    radius: isPressed ? 1.0 : 3.0,
                    x: 0,
                    y: isPressed ? 0.5 : 2.5)
            .offset(y: isPressed ? 1.2 : 0)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
    }

    @ViewBuilder
    private var symbolView: some View {
        switch label {
        case "triangle": Image(systemName: "triangle").font(.system(size: 10, weight: .bold))
        case "cross": Image(systemName: "multiply").font(.system(size: 12, weight: .bold))
        case "square": Image(systemName: "square").font(.system(size: 10, weight: .bold))
        case "circle": Image(systemName: "circle").font(.system(size: 10, weight: .bold))
        default: EmptyView()
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
        let activeGlow = Color.cyan

        RoundedRectangle(cornerRadius: 6)
            .fill(isPressed ? LinearGradient(colors: [Color(white: 0.30), Color(white: 0.24)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.22), Color(white: 0.15)], startPoint: .top, endPoint: .bottom))
            .frame(width: 58, height: 17)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPressed ? activeGlow : Color.white.opacity(0.16), lineWidth: 1.2)
            )
            .overlay(
                Text(side + "1")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isPressed ? .white : .white.opacity(0.7))
                    .shadow(color: isPressed ? activeGlow : Color.clear, radius: isPressed ? 3 : 0)
            )
            .shadow(color: isPressed ? activeGlow.opacity(0.6) : Color.black.opacity(0.35),
                    radius: isPressed ? 1.0 : 3.0,
                    x: 0,
                    y: isPressed ? 0.5 : 2.5)
            .offset(y: isPressed ? 1.2 : 0)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
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
        let level = CGFloat(max(0, min(1, value)))

        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(
                    colors: [Color(white: 0.24), Color(white: 0.075)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPressed ? Color.cyan.opacity(0.9) : Color.white.opacity(0.18), lineWidth: 1.2)
                )

            Text(side + "2")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(isPressed ? .white : .white.opacity(0.78))

            VStack {
                Spacer()
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 44, height: 2.5)
                    Capsule()
                        .fill(Color.cyan)
                        .frame(width: 44 * level, height: 2.5)
                        .shadow(color: Color.cyan.opacity(0.75), radius: 2)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(width: 54, height: 28)
        .offset(y: level * 3.0)
        .scaleEffect(y: 1.0 - (level * 0.08), anchor: .top)
        .rotation3DEffect(
            .degrees(Double(-level * 7.0)),
            axis: (x: 1.0, y: 0.0, z: 0.0),
            anchor: .top
        )
        .shadow(color: isPressed ? Color.cyan.opacity(0.35) : Color.black.opacity(0.35),
                radius: isPressed ? 2 : 4, y: isPressed ? 1 : 3)
        .frame(width: 54, height: 34, alignment: .top)
        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: value)
    }
}

public struct StickVisual: View {
    let value: CGPoint
    let isPressed: Bool

    // Limits the max visual displacement to prevent clipping
    private let maxDisplacement: CGFloat = 6.5

    public init(value: CGPoint, isPressed: Bool) {
        self.value = value
        self.isPressed = isPressed
    }

    public var body: some View {
        ZStack {
            // Joystick Outer Housing/Well
            Circle()
                .fill(Color(white: 0.04))
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.5))

            // Joystick Stem Shadow - dynamically shift in opposite direction of tilt
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 32, height: 32)
                .blur(radius: isPressed ? 1.0 : 2.5)
                .offset(
                    x: -value.x * maxDisplacement * 0.35,
                    y: value.y * maxDisplacement * 0.35
                )

            // Joystick Moving Cap
            ZStack {
                // Outer rubber grip cap
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 34, height: 34)

                // Textured concentric rings
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 1.0)
                    .frame(width: 26, height: 26)

                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    .frame(width: 18, height: 18)

                // Thumb depression dome
                Circle()
                    .fill(Color(white: 0.14))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.6))

                // L3/R3 clicked glow ring
                if isPressed {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 1.2)
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.cyan.opacity(0.8), radius: 4)
                }
            }
            .offset(
                x: value.x * maxDisplacement,
                y: -value.y * maxDisplacement
            )
            .scaleEffect(isPressed ? 0.90 : 1.0) // L3/R3 physical compression
            .rotation3DEffect(
                .degrees(Double(value.x * 15.0)),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .rotation3DEffect(
                .degrees(Double(-value.y * 15.0)),
                axis: (x: 1.0, y: 0.0, z: 0.0)
            )
            .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: value)
            .animation(.interactiveSpring(response: 0.10, dampingFraction: 0.8), value: isPressed)
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
        let activeGlow = Color.cyan

        Group {
            if label == "ps" {
                Circle()
                    .fill(isPressed ? LinearGradient(colors: [Color(white: 0.30), Color(white: 0.24)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.18), Color(white: 0.10)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(isPressed ? activeGlow : Color.white.opacity(0.16), lineWidth: 1.2)
                    )
                    .overlay(
                        Text("PS")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(isPressed ? .white : .white.opacity(0.8))
                            .shadow(color: isPressed ? activeGlow : Color.clear, radius: isPressed ? 3 : 0)
                    )
                    .shadow(color: isPressed ? activeGlow.opacity(0.6) : Color.black.opacity(0.35),
                            radius: isPressed ? 1.0 : 3.0,
                            x: 0,
                            y: isPressed ? 0.5 : 2.5)
                    .offset(y: isPressed ? 1.2 : 0)
                    .scaleEffect(isPressed ? 0.96 : 1.0)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
            } else if label == "mute" {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? Color(white: 0.30) : Color(white: 0.13))
                    .frame(width: 20, height: 11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isPressed ? Color.orange : Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 6.5, weight: .bold))
                            .foregroundColor(isPressed ? .orange : .white.opacity(0.65))
                    )
                    .shadow(color: isPressed ? Color.orange.opacity(0.45) : Color.black.opacity(0.30),
                            radius: isPressed ? 2 : 3, y: isPressed ? 1 : 2)
                    .offset(y: isPressed ? 1.2 : 0)
                    .scaleEffect(isPressed ? 0.96 : 1.0)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
            } else {
                Capsule()
                    .fill(isPressed ? LinearGradient(colors: [Color(white: 0.30), Color(white: 0.24)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.22), Color(white: 0.13)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 19, height: 9)
                    .overlay(
                        Capsule()
                            .stroke(isPressed ? activeGlow : Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .overlay(
                        Image(systemName: label == "create" ? "line.3.horizontal" : "ellipsis")
                            .font(.system(size: 6.5, weight: .bold))
                            .foregroundColor(isPressed ? .white : .white.opacity(0.62))
                    )
                    .shadow(color: isPressed ? activeGlow.opacity(0.6) : Color.black.opacity(0.35),
                            radius: isPressed ? 1.0 : 3.0,
                            x: 0,
                            y: isPressed ? 0.5 : 2.5)
                    .offset(y: isPressed ? 1.2 : 0)
                    .scaleEffect(isPressed ? 0.96 : 1.0)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: isPressed)
            }
        }
    }
}

public struct TouchpadMarker: View {
    let position: CGPoint
    let color: Color

    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0.8

    public init(position: CGPoint, color: Color) {
        self.position = position
        self.color = color
    }

    public var body: some View {
        ZStack {
            // Ripple Ring
            Circle()
                .stroke(color, lineWidth: 1.2)
                .frame(width: 16, height: 16)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .onAppear {
                    withAnimation(Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        rippleScale = 2.0
                        rippleOpacity = 0.0
                    }
                }

            // Core Dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color, radius: 4)
        }
        .position(position)
    }
}

/// Five player indicator LEDs driven directly by the controller's LED bitmask
/// (bit 0 = leftmost … bit 4 = rightmost), matching the Haptics tab toggles.
public struct PlayerIndicatorLEDs: View {
    let litMask: UInt8

    public init(litMask: UInt8) {
        self.litMask = litMask
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                let lit = (litMask & UInt8(1 << index)) != 0
                Circle()
                    .fill(lit ? Color(red: 1.0, green: 0.73, blue: 0.2) : Color.white.opacity(0.14))
                    .frame(width: 2.4, height: 2.4)
                    .shadow(color: lit ? Color(red: 1.0, green: 0.73, blue: 0.2).opacity(0.8) : Color.clear, radius: 1.5)
            }
        }
    }
}

// MARK: - Proportional Layout

/// Maps normalized controller coordinates (0…1 across the canvas) to absolute points, and
/// derives a uniform `scale` so leaf components size proportionally to the canvas. The whole
/// Live Map is built from this single source of truth, so nothing drifts or clips on resize.
///
/// Touchpad bounds (`tpMinX`…`tpMaxY`) are shared by the touchpad shape, the lightbar shape,
/// and the live touch markers, guaranteeing they stay perfectly aligned.
public struct ControllerLayout {
    public let width: CGFloat
    public let height: CGFloat
    /// 1.0 at the 380pt reference width that the leaf components were authored against.
    public let scale: CGFloat

    // Touchpad rectangle in normalized coordinates.
    public let tpMinX: CGFloat = 0.375
    public let tpMaxX: CGFloat = 0.625
    public let tpMinY: CGFloat = 0.14
    public let tpMaxY: CGFloat = 0.34

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        self.scale = width / 380.0
    }

    /// Normalized (nx, ny) → absolute point.
    public func point(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
        CGPoint(x: nx * width, y: ny * height)
    }

    /// Absolute touchpad bounds inside the controller canvas.
    public var touchpadRect: CGRect {
        CGRect(x: tpMinX * width,
               y: tpMinY * height,
               width: (tpMaxX - tpMinX) * width,
               height: (tpMaxY - tpMinY) * height)
    }

    /// Maps a touchpad reading (x,y ∈ roughly -1…1) into the on-screen touchpad rectangle.
    public func touchpadPoint(_ value: CGPoint) -> CGPoint {
        let cx = (tpMinX + tpMaxX) / 2
        let cy = (tpMinY + tpMaxY) / 2
        let halfW = (tpMaxX - tpMinX) / 2
        let halfH = (tpMaxY - tpMinY) / 2
        let nx = cx + max(-1, min(1, value.x)) * halfW
        let ny = cy - max(-1, min(1, value.y)) * halfH
        return point(nx, ny)
    }
}

// MARK: - Custom Vector Shapes representing DualSense Geometry
//
// All shapes derive their key landmarks from the same normalized fractions used to position
// the buttons in `controllerCanvas`, so the silhouette and the live elements stay in register.

/// The outer body: shoulder peaks at the top corners, a gentle dip over the touchpad,
/// sides sweeping out and down into the two grips. Symmetric about x = 0.5.
public struct DualSenseShell: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: h * y) }
        var path = Path()

        path.move(to: p(0.50, 0.045))
        // Top edge rising to the right shoulder peak.
        path.addCurve(to: p(0.74, 0.09),
                      control1: p(0.60, 0.025), control2: p(0.68, 0.03))
        // Right shoulder rounding outward.
        path.addCurve(to: p(0.94, 0.30),
                      control1: p(0.86, 0.06), control2: p(0.94, 0.16))
        // Outer right edge sweeping down into the grip.
        path.addCurve(to: p(0.78, 0.93),
                      control1: p(0.99, 0.55), control2: p(0.88, 0.88))
        // Right grip tip.
        path.addQuadCurve(to: p(0.66, 0.86), control: p(0.72, 0.99))
        // Inner right grip rising toward the center.
        path.addQuadCurve(to: p(0.56, 0.64), control: p(0.62, 0.74))
        // Central underside arch.
        path.addQuadCurve(to: p(0.44, 0.64), control: p(0.50, 0.60))
        // Inner left grip descending.
        path.addQuadCurve(to: p(0.34, 0.86), control: p(0.38, 0.74))
        // Left grip tip.
        path.addQuadCurve(to: p(0.22, 0.93), control: p(0.28, 0.99))
        // Outer left edge sweeping back up.
        path.addCurve(to: p(0.06, 0.30),
                      control1: p(0.12, 0.88), control2: p(0.01, 0.55))
        // Left shoulder rounding inward.
        path.addCurve(to: p(0.26, 0.09),
                      control1: p(0.06, 0.16), control2: p(0.14, 0.06))
        // Top edge back to center.
        path.addCurve(to: p(0.50, 0.045),
                      control1: p(0.32, 0.03), control2: p(0.40, 0.025))
        path.closeSubpath()
        return path
    }
}

/// The darker central chassis: broad around the touchpad, narrowing through the sticks
/// and extending into the space between the two light outer grip shells.
public struct DualSenseAccentPlate: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: h * y) }
        var path = Path()

        path.move(to: p(0.34, 0.14))
        path.addQuadCurve(to: p(0.66, 0.14), control: p(0.50, 0.095))
        // Sweep around the right face and stick.
        path.addCurve(to: p(0.73, 0.54),
                      control1: p(0.71, 0.23), control2: p(0.76, 0.40))
        path.addCurve(to: p(0.62, 0.78),
                      control1: p(0.73, 0.65), control2: p(0.68, 0.74))
        // Central lower point fills the old empty triangular gap between grips.
        path.addQuadCurve(to: p(0.50, 0.86), control: p(0.57, 0.80))
        path.addQuadCurve(to: p(0.38, 0.78), control: p(0.43, 0.80))
        // Mirror the left face back to the top edge.
        path.addCurve(to: p(0.27, 0.54),
                      control1: p(0.32, 0.74), control2: p(0.27, 0.65))
        path.addCurve(to: p(0.34, 0.14),
                      control1: p(0.24, 0.40), control2: p(0.29, 0.23))
        path.closeSubpath()
        return path
    }
}

/// The rounded-rectangle touchpad, derived from `ControllerLayout`'s shared bounds.
public struct DualSenseTouchpad: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let l = ControllerLayout(width: w, height: h)
        let tp = CGRect(x: l.tpMinX * w, y: l.tpMinY * h,
                        width: (l.tpMaxX - l.tpMinX) * w, height: (l.tpMaxY - l.tpMinY) * h)
        return Path(roundedRect: tp, cornerRadius: 6 * l.scale)
    }
}

/// The lightbar: a glowing line tracing the left, bottom and right edges of the touchpad.
public struct DualSenseLightbar: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let l = ControllerLayout(width: w, height: h)
        let r = 6 * l.scale
        // Inset slightly outward so the glow frames the touchpad instead of hiding under it.
        let inset = 2.0 * l.scale
        let minX = l.tpMinX * w - inset, maxX = l.tpMaxX * w + inset
        let minY = l.tpMinY * h - inset, maxY = l.tpMaxY * h + inset
        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY + r))
        path.addLine(to: CGPoint(x: minX, y: maxY - r))
        path.addQuadCurve(to: CGPoint(x: minX + r, y: maxY), control: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: maxX - r, y: maxY))
        path.addQuadCurve(to: CGPoint(x: maxX, y: maxY - r), control: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: minY + r))
        return path
    }
}
