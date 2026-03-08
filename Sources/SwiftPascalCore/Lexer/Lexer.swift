public class Lexer {
    private let source: String
    private var chars: [Character]
    private var pos: Int = 0
    private var line: Int = 1
    private var column: Int = 1

    public init(source: String) {
        self.source = source
        self.chars = Array(source)
    }

    private var current: Character? {
        pos < chars.count ? chars[pos] : nil
    }

    private func peek(offset: Int = 1) -> Character? {
        let idx = pos + offset
        return idx < chars.count ? chars[idx] : nil
    }

    private func loc() -> SourceLocation {
        SourceLocation(line: line, column: column)
    }

    private func advance() -> Character {
        let ch = chars[pos]
        pos += 1
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    private func skipWhitespace() {
        while let ch = current, ch.isWhitespace || ch == "\u{1A}" {
            _ = advance()
        }
    }

    private func skipComment() -> Bool {
        // { ... } comments
        if current == "{" {
            _ = advance()
            // Check for compiler directive {$...} - skip it
            while let ch = current, ch != "}" {
                _ = advance()
            }
            if current == "}" { _ = advance() }
            return true
        }
        // (* ... *) comments
        if current == "(" && peek() == "*" {
            _ = advance() // (
            _ = advance() // *
            while pos < chars.count {
                if current == "*" && peek() == ")" {
                    _ = advance() // *
                    _ = advance() // )
                    break
                }
                _ = advance()
            }
            return true
        }
        return false
    }

    private func scanNumber() throws -> Token {
        let startLoc = loc()
        var numStr = ""

        // Hex literal: $XXXX
        if current == "$" {
            _ = advance()
            while let ch = current, ch.isHexDigit {
                numStr.append(advance())
            }
            guard let value = Int(numStr, radix: 16) else {
                throw PascalError.lexerError("Invalid hex literal: $\(numStr)", startLoc)
            }
            return Token(type: .intLiteral(value), location: startLoc)
        }

        while let ch = current, ch.isNumber {
            numStr.append(advance())
        }

        // Check for real number
        if current == "." && peek() != "." {
            numStr.append(advance()) // the dot
            while let ch = current, ch.isNumber {
                numStr.append(advance())
            }
            // Scientific notation
            if let ch = current, ch == "E" || ch == "e" {
                numStr.append(advance())
                if let sign = current, sign == "+" || sign == "-" {
                    numStr.append(advance())
                }
                while let ch = current, ch.isNumber {
                    numStr.append(advance())
                }
            }
            guard let value = Double(numStr) else {
                throw PascalError.lexerError("Invalid real literal: \(numStr)", startLoc)
            }
            return Token(type: .realLiteral(value), location: startLoc)
        }

        guard let value = Int(numStr) else {
            throw PascalError.lexerError("Invalid integer literal: \(numStr)", startLoc)
        }
        return Token(type: .intLiteral(value), location: startLoc)
    }

    private func scanString() throws -> Token {
        let startLoc = loc()
        _ = advance() // opening quote
        var str = ""

        while pos < chars.count {
            if current == "'" {
                _ = advance()
                if current == "'" {
                    // escaped quote
                    str.append("'")
                    _ = advance()
                } else {
                    break
                }
            } else {
                str.append(advance())
            }
        }

        // Single character strings are still string literals in Pascal
        return Token(type: .stringLiteral(str), location: startLoc)
    }

    private func scanIdentifierOrKeyword() -> Token {
        let startLoc = loc()
        var name = ""

        while let ch = current, ch.isLetter || ch.isNumber || ch == "_" {
            name.append(advance())
        }

        let upper = name.uppercased()
        if let keyword = TokenType.keywords[upper] {
            return Token(type: keyword, location: startLoc)
        }

        return Token(type: .identifier(upper), location: startLoc)
    }

    private func scanToken() throws -> Token {
        let startLoc = loc()
        let ch = advance()

        switch ch {
        case "+": return Token(type: .plus, location: startLoc)
        case "-": return Token(type: .minus, location: startLoc)
        case "*": return Token(type: .star, location: startLoc)
        case "/": return Token(type: .slash, location: startLoc)
        case "=": return Token(type: .equal, location: startLoc)
        case ";": return Token(type: .semicolon, location: startLoc)
        case ",": return Token(type: .comma, location: startLoc)
        case "(": return Token(type: .lparen, location: startLoc)
        case ")": return Token(type: .rparen, location: startLoc)
        case "[": return Token(type: .lbracket, location: startLoc)
        case "]": return Token(type: .rbracket, location: startLoc)
        case "^": return Token(type: .caret, location: startLoc)
        case ":":
            if current == "=" {
                _ = advance()
                return Token(type: .assign, location: startLoc)
            }
            return Token(type: .colon, location: startLoc)
        case ".":
            if current == "." {
                _ = advance()
                return Token(type: .dotDot, location: startLoc)
            }
            return Token(type: .dot, location: startLoc)
        case "<":
            if current == ">" {
                _ = advance()
                return Token(type: .notEqual, location: startLoc)
            }
            if current == "=" {
                _ = advance()
                return Token(type: .lessEqual, location: startLoc)
            }
            return Token(type: .less, location: startLoc)
        case ">":
            if current == "=" {
                _ = advance()
                return Token(type: .greaterEqual, location: startLoc)
            }
            return Token(type: .greater, location: startLoc)
        case "#":
            // Character literal by ordinal: #13, #27, etc.
            var numStr = ""
            while let c = self.current, c.isNumber {
                numStr.append(advance())
            }
            guard let value = Int(numStr) else {
                throw PascalError.lexerError("Invalid character literal: #\(numStr)", startLoc)
            }
            return Token(type: .stringLiteral(String(Character(UnicodeScalar(value)!))), location: startLoc)
        default:
            throw PascalError.lexerError("Unexpected character: '\(ch)'", startLoc)
        }
    }

    public func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while pos < chars.count {
            skipWhitespace()
            if pos >= chars.count { break }

            // Skip comments
            if skipComment() { continue }

            guard let ch = current else { break }

            if ch.isLetter || ch == "_" {
                tokens.append(scanIdentifierOrKeyword())
            } else if ch.isNumber || ch == "$" {
                tokens.append(try scanNumber())
            } else if ch == "'" {
                tokens.append(try scanString())
            } else {
                tokens.append(try scanToken())
            }
        }

        tokens.append(Token(type: .eof, location: loc()))
        return tokens
    }
}
