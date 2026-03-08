public enum TokenType: Equatable, Sendable {
    // Literals
    case intLiteral(Int)
    case realLiteral(Double)
    case stringLiteral(String)

    // Identifier (always uppercased)
    case identifier(String)

    // Keywords
    case kwProgram, kwUses, kwConst, kwVar, kwType
    case kwProcedure, kwFunction
    case kwBegin, kwEnd
    case kwIf, kwThen, kwElse
    case kwFor, kwTo, kwDownto, kwDo
    case kwWhile, kwRepeat, kwUntil
    case kwArray, kwOf, kwString
    case kwRecord, kwNil
    case kwAnd, kwOr, kwNot
    case kwDiv, kwMod
    case kwAbsolute
    case kwTrue, kwFalse
    case kwIn

    // Operators
    case assign        // :=
    case plus          // +
    case minus         // -
    case star          // *
    case slash         // /
    case equal         // =
    case notEqual      // <>
    case less          // <
    case lessEqual     // <=
    case greater       // >
    case greaterEqual  // >=
    case dotDot        // ..

    // Delimiters
    case lparen        // (
    case rparen        // )
    case lbracket      // [
    case rbracket      // ]
    case semicolon     // ;
    case colon         // :
    case comma         // ,
    case dot           // .
    case caret         // ^

    // Special
    case eof

    static let keywords: [String: TokenType] = [
        "PROGRAM": .kwProgram, "USES": .kwUses, "CONST": .kwConst,
        "VAR": .kwVar, "TYPE": .kwType,
        "PROCEDURE": .kwProcedure, "FUNCTION": .kwFunction,
        "BEGIN": .kwBegin, "END": .kwEnd,
        "IF": .kwIf, "THEN": .kwThen, "ELSE": .kwElse,
        "FOR": .kwFor, "TO": .kwTo, "DOWNTO": .kwDownto, "DO": .kwDo,
        "WHILE": .kwWhile, "REPEAT": .kwRepeat, "UNTIL": .kwUntil,
        "ARRAY": .kwArray, "OF": .kwOf, "STRING": .kwString,
        "RECORD": .kwRecord, "NIL": .kwNil,
        "AND": .kwAnd, "OR": .kwOr, "NOT": .kwNot,
        "DIV": .kwDiv, "MOD": .kwMod,
        "ABSOLUTE": .kwAbsolute,
        "TRUE": .kwTrue, "FALSE": .kwFalse,
        "IN": .kwIn,
    ]
}

public struct Token: Sendable {
    public let type: TokenType
    public let location: SourceLocation

    public init(type: TokenType, location: SourceLocation) {
        self.type = type
        self.location = location
    }
}
