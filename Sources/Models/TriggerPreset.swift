import Foundation

public enum TriggerMode: String, CaseIterable, Codable, Identifiable {
    case off = "Off"
    case feedback = "Feedback"
    case weapon = "Weapon"
    case vibration = "Vibration"
    case sectionResistance = "Section Resistance"
    case semiAutomatic = "Semi-Automatic"
    case automatic = "Automatic"
    case slopeFeedback = "Slope Feedback"
    case multiPositionFeedback = "Multi-Position Feedback"
    case multiPositionVibration = "Multi-Position Vibration"
    case fullPress = "Full Press"
    
    public var id: String { self.rawValue }
    
    /// Group for UI categorization
    public var category: String {
        switch self {
        case .off: return "Basic"
        case .feedback, .weapon, .vibration: return "Basic"
        case .sectionResistance, .semiAutomatic, .automatic: return "Advanced"
        case .slopeFeedback, .multiPositionFeedback, .multiPositionVibration, .fullPress: return "Expert"
        }
    }
}

public struct TriggerPreset: Codable, Identifiable, Equatable {
    public var id: String { name }
    public var name: String
    
    public var l2Mode: TriggerMode
    public var l2Start: Float
    public var l2End: Float
    public var l2Strength: Float
    public var l2Amplitude: Float
    public var l2Frequency: Float
    public var l2EndStrength: Float
    
    public var r2Mode: TriggerMode
    public var r2Start: Float
    public var r2End: Float
    public var r2Strength: Float
    public var r2Amplitude: Float
    public var r2Frequency: Float
    public var r2EndStrength: Float
    
    public var ledRed: Float
    public var ledGreen: Float
    public var ledBlue: Float
    public var isLedPulsing: Bool
    
    public init(name: String, l2Mode: TriggerMode, l2Start: Float, l2End: Float, l2Strength: Float, l2Amplitude: Float, l2Frequency: Float, r2Mode: TriggerMode, r2Start: Float, r2End: Float, r2Strength: Float, r2Amplitude: Float, r2Frequency: Float, ledRed: Float, ledGreen: Float, ledBlue: Float, isLedPulsing: Bool, l2EndStrength: Float = 0, r2EndStrength: Float = 0) {
        self.name = name
        self.l2Mode = l2Mode
        self.l2Start = l2Start
        self.l2End = l2End
        self.l2Strength = l2Strength
        self.l2Amplitude = l2Amplitude
        self.l2Frequency = l2Frequency
        self.l2EndStrength = l2EndStrength
        self.r2Mode = r2Mode
        self.r2Start = r2Start
        self.r2End = r2End
        self.r2Strength = r2Strength
        self.r2Amplitude = r2Amplitude
        self.r2Frequency = r2Frequency
        self.r2EndStrength = r2EndStrength
        self.ledRed = ledRed
        self.ledGreen = ledGreen
        self.ledBlue = ledBlue
        self.isLedPulsing = isLedPulsing
    }
    
    // Custom decoding for backward compatibility with presets saved before endStrength was added
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        l2Mode = try container.decode(TriggerMode.self, forKey: .l2Mode)
        l2Start = try container.decode(Float.self, forKey: .l2Start)
        l2End = try container.decode(Float.self, forKey: .l2End)
        l2Strength = try container.decode(Float.self, forKey: .l2Strength)
        l2Amplitude = try container.decode(Float.self, forKey: .l2Amplitude)
        l2Frequency = try container.decode(Float.self, forKey: .l2Frequency)
        l2EndStrength = try container.decodeIfPresent(Float.self, forKey: .l2EndStrength) ?? 0
        r2Mode = try container.decode(TriggerMode.self, forKey: .r2Mode)
        r2Start = try container.decode(Float.self, forKey: .r2Start)
        r2End = try container.decode(Float.self, forKey: .r2End)
        r2Strength = try container.decode(Float.self, forKey: .r2Strength)
        r2Amplitude = try container.decode(Float.self, forKey: .r2Amplitude)
        r2Frequency = try container.decode(Float.self, forKey: .r2Frequency)
        r2EndStrength = try container.decodeIfPresent(Float.self, forKey: .r2EndStrength) ?? 0
        ledRed = try container.decode(Float.self, forKey: .ledRed)
        ledGreen = try container.decode(Float.self, forKey: .ledGreen)
        ledBlue = try container.decode(Float.self, forKey: .ledBlue)
        isLedPulsing = try container.decode(Bool.self, forKey: .isLedPulsing)
    }
}

