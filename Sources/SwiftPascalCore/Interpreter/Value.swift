import Foundation

public enum PascalValue {
    case integer(Int)
    case real(Double)
    case char(Character)
    case string(String)
    case boolean(Bool)
    case array(PascalArray)
    case none  // for procedure "return" / uninitialized

    public var intValue: Int {
        switch self {
        case .integer(let v): return v
        case .real(let v): return Int(v)
        case .char(let c): return Int(c.asciiValue ?? 0)
        case .boolean(let b): return b ? 1 : 0
        default: return 0
        }
    }

    public var realValue: Double {
        switch self {
        case .real(let v): return v
        case .integer(let v): return Double(v)
        default: return 0.0
        }
    }

    public var boolValue: Bool {
        switch self {
        case .boolean(let v): return v
        case .integer(let v): return v != 0
        default: return false
        }
    }

    public var charValue: Character {
        switch self {
        case .char(let c): return c
        case .string(let s): return s.first ?? " "
        case .integer(let v): return Character(UnicodeScalar(v) ?? UnicodeScalar(0x20))
        default: return " "
        }
    }

    public var stringValue: String {
        switch self {
        case .string(let s): return s
        case .char(let c): return String(c)
        case .integer(let v): return String(v)
        case .real(let v):
            if v == v.rounded() && abs(v) < 1e15 {
                return String(format: "%.1f", v)
            }
            return String(format: " %.10E", v)
        case .boolean(let b): return b ? "TRUE" : "FALSE"
        case .array: return "<array>"
        case .none: return ""
        }
    }
}

public class PascalArray {
    public struct Dimension {
        public let low: Int
        public let high: Int
        public var count: Int { high - low + 1 }
    }

    public let dimensions: [Dimension]
    public var storage: [PascalValue]
    public var isAbsolute: Bool = false
    public var absoluteSegment: Int = 0
    public var absoluteOffset: Int = 0

    public init(dimensions: [Dimension], defaultValue: PascalValue = .integer(0)) {
        self.dimensions = dimensions
        let totalSize = dimensions.reduce(1) { $0 * $1.count }
        self.storage = Array(repeating: defaultValue, count: totalSize)
    }

    public func flatIndex(indices: [Int]) -> Int {
        var index = 0
        var multiplier = 1
        // Row-major order: last dimension varies fastest
        for i in stride(from: dimensions.count - 1, through: 0, by: -1) {
            let offset = indices[i] - dimensions[i].low
            index += offset * multiplier
            multiplier *= dimensions[i].count
        }
        return index
    }

    public func get(indices: [Int]) -> PascalValue {
        let idx = flatIndex(indices: indices)
        guard idx >= 0 && idx < storage.count else { return .integer(0) }
        return storage[idx]
    }

    public func set(indices: [Int], value: PascalValue) {
        let idx = flatIndex(indices: indices)
        guard idx >= 0 && idx < storage.count else { return }
        storage[idx] = value
    }
}
