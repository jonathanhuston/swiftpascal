import Foundation

public class Environment {
    public var values: [String: PascalValue] = [:]
    public var constants: Set<String> = []
    public var parent: Environment?
    public var functionName: String?  // for function return value assignment
    public var returnValue: PascalValue = .none
    // Store procedure/function declarations for lookup
    public var procedures: [String: Declaration] = [:]

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    public func define(_ name: String, value: PascalValue, isConstant: Bool = false) {
        values[name] = value
        if isConstant { constants.insert(name) }
    }

    public func get(_ name: String) throws -> PascalValue {
        if let value = values[name] {
            return value
        }
        if let parent = parent {
            return try parent.get(name)
        }
        throw PascalError.runtimeError("Undefined identifier: \(name)")
    }

    public func set(_ name: String, value: PascalValue) throws {
        if values[name] != nil {
            values[name] = value
            return
        }
        if let parent = parent {
            try parent.set(name, value: value)
            return
        }
        throw PascalError.runtimeError("Undefined variable: \(name)")
    }

    public func lookupProcedure(_ name: String) -> Declaration? {
        if let decl = procedures[name] {
            return decl
        }
        return parent?.lookupProcedure(name)
    }

    public func lookupArray(_ name: String) throws -> PascalArray {
        let val = try get(name)
        guard case .array(let arr) = val else {
            throw PascalError.runtimeError("\(name) is not an array")
        }
        return arr
    }
}
