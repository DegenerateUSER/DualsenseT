import Foundation

public enum TriggerMode: String, CaseIterable, Codable, Identifiable {
    case off = "Off"
    case feedback = "Feedback"
    case weapon = "Weapon"
    case vibration = "Vibration"
    
    public var id: String { self.rawValue }
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
    
    public var r2Mode: TriggerMode
    public var r2Start: Float
    public var r2End: Float
    public var r2Strength: Float
    public var r2Amplitude: Float
    public var r2Frequency: Float
    
    public var ledRed: Float
    public var ledGreen: Float
    public var ledBlue: Float
    public var isLedPulsing: Bool
    
    public init(name: String, l2Mode: TriggerMode, l2Start: Float, l2End: Float, l2Strength: Float, l2Amplitude: Float, l2Frequency: Float, r2Mode: TriggerMode, r2Start: Float, r2End: Float, r2Strength: Float, r2Amplitude: Float, r2Frequency: Float, ledRed: Float, ledGreen: Float, ledBlue: Float, isLedPulsing: Bool) {
        self.name = name
        self.l2Mode = l2Mode
        self.l2Start = l2Start
        self.l2End = l2End
        self.l2Strength = l2Strength
        self.l2Amplitude = l2Amplitude
        self.l2Frequency = l2Frequency
        self.r2Mode = r2Mode
        self.r2Start = r2Start
        self.r2End = r2End
        self.r2Strength = r2Strength
        self.r2Amplitude = r2Amplitude
        self.r2Frequency = r2Frequency
        self.ledRed = ledRed
        self.ledGreen = ledGreen
        self.ledBlue = ledBlue
        self.isLedPulsing = isLedPulsing
    }
}
