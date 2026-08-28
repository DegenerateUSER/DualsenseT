import Foundation
import Network
import AppKit

public class UDPListener: ObservableObject {
    @Published public var isRunning = false
    @Published public var lastMessage = "No commands received"
    
    private var listener: NWListener?
    private var queue = DispatchQueue(label: "com.dualsenset.udp")
    private var manager: ControllerManager?
    
    public init() {}
    
    public func start(manager: ControllerManager) {
        self.manager = manager
        do {
            let params = NWParameters.udp
            params.allowFastOpen = true
            
            listener = try NWListener(using: params, on: 6969)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastMessage = "Listening on port 6969..."
                        logToFile("UDP Server started listening on port 6969")
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastMessage = "Failed: \(error.localizedDescription)"
                        logToFile("UDP Server failed: \(error.localizedDescription)")
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
        } catch {
            self.lastMessage = "Error: \(error.localizedDescription)"
            logToFile("UDP Server start error: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        self.isRunning = false
        self.lastMessage = "UDP Server stopped"
        logToFile("UDP Server stopped")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNextMessage(on: connection)
    }
    
    private func receiveNextMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (content, _, _, error) in
            if let data = content, !data.isEmpty {
                self?.parsePacket(data)
            }
            if error == nil {
                self?.receiveNextMessage(on: connection)
            } else {
                connection.cancel()
            }
        }
    }
    
    private func parsePacket(_ data: Data) {
        struct DSXInstruction: Codable {
            let type: String
            let parameters: [ParameterValue]
        }
        
        struct DSXPacket: Codable {
            let instructions: [DSXInstruction]
        }
        
        struct FlatPacket: Codable {
            let instruction: String
            let trigger: Int?
            let mode: Int?
            let parameters: [ParameterValue]?
            let r: Int?
            let g: Int?
            let b: Int?
        }
        
        if let str = String(data: data, encoding: .utf8) {
            logToFile("UDP raw packet received: \(str)")
        }
        
        do {
            // 1. Try decoding as standard DSX instructions packet
            if let packet = try? JSONDecoder().decode(DSXPacket.self, from: data) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let manager = self.manager else { return }
                    for instruction in packet.instructions {
                        self.processInstruction(type: instruction.type, parameters: instruction.parameters, manager: manager)
                    }
                    
                    if let str = String(data: data, encoding: .utf8) {
                        self.lastMessage = "Received (DSX): \(str)"
                    }
                }
                return
            }
            
            // 2. Fall back to decoding as legacy/flat packet
            let packet = try JSONDecoder().decode(FlatPacket.self, from: data)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let manager = self.manager else { return }
                
                if packet.instruction == "TriggerUpdate" || packet.instruction == "Trigger" {
                    let trigger = packet.trigger ?? 1 // default R2
                    let mode = packet.mode ?? 0 // default Off
                    let params = packet.parameters?.compactMap { $0.intValue } ?? []
                    logToFile("Legacy/Flat packet Trigger: trigger=\(trigger), mode=\(mode), params=\(params)")
                    self.applyTriggerUpdateLegacy(trigger: trigger, mode: mode, params: params)
                } else if packet.instruction == "RGBUpdate" || packet.instruction == "RGB" {
                    if let r = packet.r, let g = packet.g, let b = packet.b {
                        logToFile("Legacy/Flat packet RGB: R=\(r), G=\(g), B=\(b)")
                        manager.ledColor = NSColor(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
                    }
                }
                
                if let str = String(data: data, encoding: .utf8) {
                    self.lastMessage = "Received (Flat): \(str)"
                }
            }
        } catch {
            logToFile("UDP packet parse error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.lastMessage = "Parse error: \(error.localizedDescription)"
            }
        }
    }
    
    private func processInstruction(type: String, parameters: [ParameterValue], manager: ControllerManager) {
        let isLeftTrigger = type == "LeftTrigger"
        let isRightTrigger = type == "RightTrigger"
        let isTriggerUpdate = type == "TriggerUpdate" || type == "Trigger"
        
        if isTriggerUpdate || isLeftTrigger || isRightTrigger {
            guard parameters.count >= 2 else {
                logToFile("DSX Trigger update error: parameters count < 2 (\(parameters.count))")
                return
            }
            
            let trigger: Int
            let mode: Int
            
            if isLeftTrigger {
                trigger = 0
                guard let m = parameters[1].intValue else {
                    logToFile("DSX LeftTrigger error: invalid mode parameter")
                    return
                }
                mode = m
            } else if isRightTrigger {
                trigger = 1
                guard let m = parameters[1].intValue else {
                    logToFile("DSX RightTrigger error: invalid mode parameter")
                    return
                }
                mode = m
            } else {
                guard let t = parameters[0].intValue, let m = parameters[1].intValue else {
                    logToFile("DSX TriggerUpdate error: invalid trigger/mode parameters")
                    return
                }
                trigger = t
                mode = m
            }
            
            var forceParams: [Int] = []
            if parameters.count > 2 {
                let thirdParam = parameters[2]
                switch thirdParam {
                case .string(let str):
                    forceParams = str.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) }
                default:
                    forceParams = parameters[2...].compactMap { $0.intValue }
                }
            }
            
            logToFile("DSX Trigger update parsed: type=\(type), trigger=\(trigger), mode=\(mode), params=\(forceParams)")
            self.applyTriggerUpdateDSX(trigger: trigger, mode: mode, params: forceParams)
            
        } else if type == "RGBUpdate" || type == "RGB" {
            var r = 0, g = 0, b = 0
            if parameters.count >= 4 {
                r = parameters[1].intValue ?? 0
                g = parameters[2].intValue ?? 0
                b = parameters[3].intValue ?? 0
            } else if parameters.count >= 3 {
                r = parameters[0].intValue ?? 0
                g = parameters[1].intValue ?? 0
                b = parameters[2].intValue ?? 0
            } else {
                logToFile("DSX RGB update error: invalid parameters count (\(parameters.count))")
                return
            }
            logToFile("DSX RGB update parsed: R=\(r), G=\(g), B=\(b)")
            manager.ledColor = NSColor(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
        }
    }
    
    private func applyTriggerUpdateDSX(trigger: Int, mode: Int, params: [Int]) {
        guard let manager = manager else { return }
        
        var tMode: TriggerMode = .off
        var start: Float = 0.0
        var end: Float = 0.0
        var strength: Float = 0.0
        var amplitude: Float = 0.0
        var frequency: Float = 0.0
        
        switch mode {
        case 0: // Normal
            tMode = .off
            
        case 1: // CustomTriggerValue
            let customMode = params.count > 0 ? params[0] : 0
            let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.0
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.0
            let p3 = params.count > 3 ? Float(params[3]) / 255.0 : 0.0
            
            if customMode == 0 {
                tMode = .off
            } else if customMode == 1 || customMode == 2 {
                tMode = .feedback
                start = p1
                strength = p2
            } else { // 3 or 4
                tMode = .vibration
                start = p1
                amplitude = p2
                frequency = p3
            }
            
        case 2: // GameCube
            tMode = .feedback
            start = 0.1
            strength = 0.5
            
        case 3: // Resistance
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.0
            tMode = .feedback
            start = p0
            strength = p1
            
        case 4: // Bow
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.5
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.5
            tMode = .weapon
            start = p0
            end = max(p0 + 0.05, p1)
            strength = p2
            
        case 5: // Galloping
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.5
            let p3 = params.count > 3 ? Float(params[3]) / 255.0 : 0.5
            tMode = .multiPositionVibration
            start = p0
            amplitude = p2
            frequency = p3
            
        case 6: // SemiAutomaticGun
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.5
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.5
            tMode = .semiAutomatic
            start = p0
            end = max(p0 + 0.05, p1)
            strength = p2
            
        case 7, 8: // AutomaticGun / Machine
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.5
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.5
            tMode = .automatic
            start = p0
            end = max(p0 + 0.05, p1)
            strength = p2
            frequency = 0.3
            
        case 9: // Choppy
            let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
            let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.5
            tMode = .multiPositionFeedback
            start = p0
            strength = p2
            
        case 10: // VerySoft
            tMode = .feedback
            start = 0.0
            strength = 0.1
            
        case 11: // Soft
            tMode = .feedback
            start = 0.0
            strength = 0.25
            
        case 12: // Medium
            tMode = .feedback
            start = 0.0
            strength = 0.5
            
        case 13: // Hard
            tMode = .feedback
            start = 0.0
            strength = 0.75
            
        case 14: // VeryHard
            tMode = .feedback
            start = 0.0
            strength = 0.9
            
        case 15: // Hardest
            tMode = .feedback
            start = 0.0
            strength = 1.0
            
        case 16: // Rigid
            tMode = .fullPress
            
        case 17: // VibrateTriggerPulse
            tMode = .vibration
            start = 0.0
            amplitude = 0.5
            frequency = 0.5
            
        case 18: // VibrateTrigger
            tMode = .vibration
            start = 0.0
            amplitude = 0.8
            frequency = 0.8
            
        default:
            tMode = .off
        }
        
        manager.batchUpdate {
            if trigger == 0 { // L2
                manager.l2Mode = tMode
                manager.l2Start = start
                manager.l2End = end
                manager.l2Strength = strength
                manager.l2Amplitude = amplitude
                manager.l2Frequency = frequency
            } else { // R2
                manager.r2Mode = tMode
                manager.r2Start = start
                manager.r2End = end
                manager.r2Strength = strength
                manager.r2Amplitude = amplitude
                manager.r2Frequency = frequency
            }
        }
    }
    
    private func applyTriggerUpdateLegacy(trigger: Int, mode: Int, params: [Int]) {
        guard let manager = manager else { return }
        
        let tMode: TriggerMode
        switch mode {
        case 0: tMode = .off
        case 1: tMode = .feedback
        case 2: tMode = .weapon
        case 3: tMode = .vibration
        case 4: tMode = .sectionResistance
        case 5: tMode = .semiAutomatic
        case 6: tMode = .automatic
        case 7: tMode = .slopeFeedback
        case 8: tMode = .multiPositionFeedback
        case 9: tMode = .multiPositionVibration
        case 10: tMode = .fullPress
        default: tMode = .off
        }
        
        let p0 = params.count > 0 ? Float(params[0]) / 255.0 : 0.0
        let p1 = params.count > 1 ? Float(params[1]) / 255.0 : 0.0
        let p2 = params.count > 2 ? Float(params[2]) / 255.0 : 0.0
        
        manager.batchUpdate {
            if trigger == 0 { // L2
                manager.l2Mode = tMode
                if tMode == .feedback {
                    manager.l2Start = p0
                    manager.l2Strength = p1
                } else if tMode == .weapon {
                    manager.l2Start = p0
                    manager.l2End = max(p0 + 0.05, p1)
                    manager.l2Strength = p2
                } else if tMode == .vibration {
                    manager.l2Start = p0
                    manager.l2Amplitude = p1
                    manager.l2Frequency = p2
                }
            } else { // R2
                manager.r2Mode = tMode
                if tMode == .feedback {
                    manager.r2Start = p0
                    manager.r2Strength = p1
                } else if tMode == .weapon {
                    manager.r2Start = p0
                    manager.r2End = max(p0 + 0.05, p1)
                    manager.r2Strength = p2
                } else if tMode == .vibration {
                    manager.r2Start = p0
                    manager.r2Amplitude = p1
                    manager.r2Frequency = p2
                }
            }
        }
    }
}
