import Foundation

extension UDPListener {
    public enum ParameterValue: Codable {
        case int(Int)
        case double(Double)
        case string(String)
        case bool(Bool)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let i = try? container.decode(Int.self) {
                self = .int(i)
            } else if let d = try? container.decode(Double.self) {
                self = .double(d)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else if let b = try? container.decode(Bool.self) {
                self = .bool(b)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported parameter value type")
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .int(let i): try container.encode(i)
            case .double(let d): try container.encode(d)
            case .string(let s): try container.encode(s)
            case .bool(let b): try container.encode(b)
            }
        }
        
        public var intValue: Int? {
            switch self {
            case .int(let i): return i
            case .double(let d): return Int(d)
            case .string(let s): return Int(s)
            default: return nil
            }
        }
    }
}
