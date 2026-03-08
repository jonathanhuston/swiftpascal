public struct SourceLocation: Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public enum PascalError: Error, CustomStringConvertible {
    case lexerError(String, SourceLocation)
    case parserError(String, SourceLocation)
    case runtimeError(String)

    public var description: String {
        switch self {
        case .lexerError(let msg, let loc):
            return "Lexer error at line \(loc.line), column \(loc.column): \(msg)"
        case .parserError(let msg, let loc):
            return "Parser error at line \(loc.line), column \(loc.column): \(msg)"
        case .runtimeError(let msg):
            return "Runtime error: \(msg)"
        }
    }
}
