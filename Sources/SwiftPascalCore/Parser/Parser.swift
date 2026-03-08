public class Parser {
    private var tokens: [Token]
    private var pos: Int = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    private var current: Token {
        tokens[pos]
    }

    private func peek(offset: Int = 1) -> Token {
        let idx = pos + offset
        return idx < tokens.count ? tokens[idx] : tokens[tokens.count - 1]
    }

    @discardableResult
    private func advance() -> Token {
        let tok = tokens[pos]
        if pos < tokens.count - 1 { pos += 1 }
        return tok
    }

    private func expect(_ type: TokenType) throws -> Token {
        if current.type == type {
            return advance()
        }
        throw PascalError.parserError("Expected \(type), got \(current.type)", current.location)
    }

    private func match(_ type: TokenType) -> Bool {
        if current.type == type {
            advance()
            return true
        }
        return false
    }

    private func isIdentifier(_ name: String? = nil) -> Bool {
        if case .identifier(let n) = current.type {
            if let name = name { return n == name }
            return true
        }
        return false
    }

    private func expectIdentifier() throws -> String {
        if case .identifier(let name) = current.type {
            advance()
            return name
        }
        throw PascalError.parserError("Expected identifier, got \(current.type)", current.location)
    }

    // MARK: - Program

    public func parseProgram() throws -> PascalProgram {
        var name = "UNNAMED"
        var uses: [String] = []

        // Optional PROGRAM header
        if current.type == .kwProgram {
            advance()
            name = try expectIdentifier()
            try expect(.semicolon)
        }

        // Optional USES clause
        if current.type == .kwUses {
            advance()
            uses.append(try expectIdentifier())
            while match(.comma) {
                uses.append(try expectIdentifier())
            }
            try expect(.semicolon)
        }

        let decls = try parseDeclarations()
        let body = try parseCompoundStatement()
        try expect(.dot)

        return PascalProgram(name: name, uses: uses, declarations: decls, body: body)
    }

    // MARK: - Declarations

    private func parseDeclarations() throws -> [Declaration] {
        var decls: [Declaration] = []

        while true {
            switch current.type {
            case .kwConst:
                advance()
                while isIdentifier() && peek().type == .equal {
                    let name = try expectIdentifier()
                    try expect(.equal)
                    let value = try parseExpression()
                    try expect(.semicolon)
                    decls.append(.constDecl(name: name, value: value))
                }
            case .kwVar:
                advance()
                while isIdentifier() {
                    // Check this is a var declaration (name : type) not a keyword
                    var names = [try expectIdentifier()]
                    while match(.comma) {
                        names.append(try expectIdentifier())
                    }
                    try expect(.colon)
                    let typeSpec = try parseTypeSpec()

                    // Check for ABSOLUTE
                    if current.type == .kwAbsolute {
                        advance()
                        let seg = try parseIntValue()
                        try expect(.colon)
                        let off = try parseIntValue()
                        try expect(.semicolon)
                        let absType = TypeSpec.absolute(typeSpec, segment: seg, offset: off)
                        decls.append(.varDecl(names: names, type: absType))
                    } else {
                        try expect(.semicolon)
                        decls.append(.varDecl(names: names, type: typeSpec))
                    }
                }
            case .kwType:
                advance()
                while isIdentifier() && peek().type == .equal {
                    let name = try expectIdentifier()
                    try expect(.equal)
                    let typeSpec = try parseTypeSpec()
                    try expect(.semicolon)
                    decls.append(.typeDecl(name: name, type: typeSpec))
                }
            case .kwProcedure:
                decls.append(try parseProcedureDecl())
            case .kwFunction:
                decls.append(try parseFunctionDecl())
            default:
                return decls
            }
        }
    }

    private func parseIntValue() throws -> Int {
        // Parse a literal integer or hex value
        if case .intLiteral(let v) = current.type {
            advance()
            return v
        }
        throw PascalError.parserError("Expected integer literal", current.location)
    }

    private func parseTypeSpec() throws -> TypeSpec {
        switch current.type {
        case .kwArray:
            advance()
            try expect(.lbracket)
            var indices: [TypeSpec] = []
            indices.append(try parseIndexType())
            while match(.comma) {
                indices.append(try parseIndexType())
            }
            try expect(.rbracket)
            try expect(.kwOf)
            let element = try parseTypeSpec()
            return .arrayType(indices: indices, element: element)

        case .kwString:
            advance()
            if match(.lbracket) {
                let len = try parseIntValue()
                try expect(.rbracket)
                return .stringType(len)
            }
            return .stringType(nil)

        case .identifier(let name):
            advance()
            return .simple(name)

        case .intLiteral, .minus:
            // Subrange: lo..hi
            let lo = try parseExpression()
            try expect(.dotDot)
            let hi = try parseExpression()
            return .subrange(lo, hi)

        default:
            throw PascalError.parserError("Expected type specification, got \(current.type)", current.location)
        }
    }

    private func parseIndexType() throws -> TypeSpec {
        let lo = try parseSimpleExpression()
        try expect(.dotDot)
        let hi = try parseSimpleExpression()
        return .subrange(lo, hi)
    }

    private func parseProcedureDecl() throws -> Declaration {
        try expect(.kwProcedure)
        let name = try expectIdentifier()
        var params: [Parameter] = []
        if match(.lparen) {
            params = try parseParameterList()
            try expect(.rparen)
        }
        try expect(.semicolon)
        let decls = try parseDeclarations()
        let body = try parseCompoundStatement()
        try expect(.semicolon)
        return .procedureDecl(name: name, params: params, decls: decls, body: body)
    }

    private func parseFunctionDecl() throws -> Declaration {
        try expect(.kwFunction)
        let name = try expectIdentifier()
        var params: [Parameter] = []
        if match(.lparen) {
            params = try parseParameterList()
            try expect(.rparen)
        }
        try expect(.colon)
        let retType = try parseTypeSpec()
        try expect(.semicolon)
        let decls = try parseDeclarations()
        let body = try parseCompoundStatement()
        try expect(.semicolon)
        return .functionDecl(name: name, params: params, returnType: retType, decls: decls, body: body)
    }

    private func parseParameterList() throws -> [Parameter] {
        var params: [Parameter] = []

        func parseParamGroup() throws {
            let isVar = match(.kwVar)
            var names = [try expectIdentifier()]
            while match(.comma) {
                names.append(try expectIdentifier())
            }
            try expect(.colon)
            let type = try parseTypeSpec()
            for name in names {
                params.append(Parameter(name: name, type: type, isVar: isVar))
            }
        }

        try parseParamGroup()
        while match(.semicolon) {
            try parseParamGroup()
        }
        return params
    }

    // MARK: - Statements

    private func parseCompoundStatement() throws -> Statement {
        try expect(.kwBegin)
        var stmts: [Statement] = []
        stmts.append(try parseStatement())
        while match(.semicolon) {
            if current.type == .kwEnd { break }
            stmts.append(try parseStatement())
        }
        try expect(.kwEnd)
        return .compound(stmts)
    }

    private func parseStatement() throws -> Statement {
        switch current.type {
        case .kwBegin:
            return try parseCompoundStatement()

        case .kwIf:
            return try parseIfStatement()

        case .kwFor:
            return try parseForStatement()

        case .kwWhile:
            return try parseWhileStatement()

        case .kwRepeat:
            return try parseRepeatStatement()

        case .identifier(let name):
            let upper = name.uppercased()
            // Check for Write/WriteLn/Read/ReadLn
            if upper == "WRITE" || upper == "WRITELN" {
                return try parseWriteStatement(newline: upper == "WRITELN")
            }
            if upper == "READ" || upper == "READLN" {
                return try parseReadStatement(newline: upper == "READLN")
            }

            // Look ahead: could be assignment (x := ...) or procedure call (x(...)) or array assign
            advance()

            // Assignment to simple variable
            if current.type == .assign {
                advance()
                let value = try parseExpression()
                return .assign(.identifier(upper), value)
            }

            // Mem[seg:offset] := value
            if upper == "MEM" && current.type == .lbracket {
                advance()
                let addr = try parseExpression()
                var memExpr: Expression
                if current.type == .colon {
                    advance()
                    let offset = try parseExpression()
                    memExpr = .memAccess(.binary(
                        .binary(addr, .multiply, .intLiteral(16)),
                        .add,
                        offset
                    ))
                } else {
                    memExpr = .memAccess(addr)
                }
                try expect(.rbracket)
                if current.type == .assign {
                    advance()
                    let value = try parseExpression()
                    return .assign(memExpr, value)
                }
                throw PascalError.parserError("Expected := after Mem[] access", current.location)
            }

            // Array access followed by assignment
            if current.type == .lbracket {
                advance()
                var indices: [Expression] = []
                indices.append(try parseExpression())
                while match(.comma) {
                    indices.append(try parseExpression())
                }
                try expect(.rbracket)
                if current.type == .assign {
                    advance()
                    let value = try parseExpression()
                    return .assign(.arrayAccess(.identifier(upper), indices), value)
                }
                // Shouldn't happen in well-formed Pascal
                throw PascalError.parserError("Expected := after array access", current.location)
            }

            // Procedure call with arguments
            if current.type == .lparen {
                advance()
                var args: [Expression] = []
                if current.type != .rparen {
                    args.append(try parseExpression())
                    while match(.comma) {
                        args.append(try parseExpression())
                    }
                }
                try expect(.rparen)
                return .procedureCall(upper, args)
            }

            // Procedure call with no arguments
            return .procedureCall(upper, [])

        default:
            // Empty statement
            return .empty
        }
    }

    private func parseIfStatement() throws -> Statement {
        try expect(.kwIf)
        let condition = try parseExpression()
        try expect(.kwThen)
        let thenBranch = try parseStatement()
        var elseBranch: Statement? = nil
        if match(.kwElse) {
            elseBranch = try parseStatement()
        }
        return .ifStmt(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
    }

    private func parseForStatement() throws -> Statement {
        try expect(.kwFor)
        let varName = try expectIdentifier()
        try expect(.assign)
        let from = try parseExpression()
        let direction: ForDirection
        if match(.kwTo) {
            direction = .to
        } else if match(.kwDownto) {
            direction = .downTo
        } else {
            throw PascalError.parserError("Expected TO or DOWNTO", current.location)
        }
        let to = try parseExpression()
        try expect(.kwDo)
        let body = try parseStatement()
        return .forStmt(variable: varName, from: from, direction: direction, to: to, body: body)
    }

    private func parseWhileStatement() throws -> Statement {
        try expect(.kwWhile)
        let condition = try parseExpression()
        try expect(.kwDo)
        let body = try parseStatement()
        return .whileStmt(condition: condition, body: body)
    }

    private func parseRepeatStatement() throws -> Statement {
        try expect(.kwRepeat)
        var stmts: [Statement] = []
        stmts.append(try parseStatement())
        while match(.semicolon) {
            if current.type == .kwUntil { break }
            stmts.append(try parseStatement())
        }
        try expect(.kwUntil)
        let condition = try parseExpression()
        return .repeatStmt(body: stmts, until: condition)
    }

    private func parseWriteStatement(newline: Bool) throws -> Statement {
        advance() // consume WRITE/WRITELN
        var args: [WriteArg] = []
        if match(.lparen) {
            if current.type != .rparen {
                args.append(try parseWriteArg())
                while match(.comma) {
                    args.append(try parseWriteArg())
                }
            }
            try expect(.rparen)
        }
        return .writeStmt(args: args, newline: newline)
    }

    private func parseWriteArg() throws -> WriteArg {
        let expr = try parseExpression()
        var width: Expression? = nil
        var decimals: Expression? = nil
        if match(.colon) {
            width = try parseExpression()
            if match(.colon) {
                decimals = try parseExpression()
            }
        }
        return WriteArg(expression: expr, width: width, decimals: decimals)
    }

    private func parseReadStatement(newline: Bool) throws -> Statement {
        advance() // consume READ/READLN
        var vars: [Expression] = []
        var isKbd = false
        if match(.lparen) {
            if current.type != .rparen {
                // Check for Read(Kbd, c) — Turbo Pascal 3.0 syntax
                if isIdentifier("KBD") {
                    isKbd = true
                    advance()
                    if match(.comma) {
                        vars.append(try parseExpression())
                        while match(.comma) {
                            vars.append(try parseExpression())
                        }
                    }
                } else {
                    vars.append(try parseExpression())
                    while match(.comma) {
                        vars.append(try parseExpression())
                    }
                }
            }
            try expect(.rparen)
        }
        return .readStmt(variables: vars, newline: newline, isKbd: isKbd)
    }

    // MARK: - Expressions (precedence climbing)

    private func parseExpression() throws -> Expression {
        try parseOrExpression()
    }

    private func parseOrExpression() throws -> Expression {
        var left = try parseAndExpression()
        while current.type == .kwOr {
            advance()
            let right = try parseAndExpression()
            left = .binary(left, .or, right)
        }
        return left
    }

    private func parseAndExpression() throws -> Expression {
        var left = try parseNotExpression()
        while current.type == .kwAnd {
            advance()
            let right = try parseNotExpression()
            left = .binary(left, .and, right)
        }
        return left
    }

    private func parseNotExpression() throws -> Expression {
        if current.type == .kwNot {
            advance()
            let expr = try parseNotExpression()
            return .unary(.not, expr)
        }
        return try parseRelational()
    }

    private func parseRelational() throws -> Expression {
        var left = try parseSimpleExpression()

        while true {
            let op: BinaryOp
            switch current.type {
            case .equal: op = .equal
            case .notEqual: op = .notEqual
            case .less: op = .less
            case .lessEqual: op = .lessEqual
            case .greater: op = .greater
            case .greaterEqual: op = .greaterEqual
            default: return left
            }
            advance()
            let right = try parseSimpleExpression()
            left = .binary(left, op, right)
        }
    }

    private func parseSimpleExpression() throws -> Expression {
        // Handle leading + or -
        var negate = false
        if current.type == .minus {
            negate = true
            advance()
        } else if current.type == .plus {
            advance()
        }

        var left = try parseTerm()
        if negate {
            left = .unary(.negate, left)
        }

        while true {
            let op: BinaryOp
            switch current.type {
            case .plus: op = .add
            case .minus: op = .subtract
            default: return left
            }
            advance()
            let right = try parseTerm()
            left = .binary(left, op, right)
        }
    }

    private func parseTerm() throws -> Expression {
        var left = try parseFactor()

        while true {
            let op: BinaryOp
            switch current.type {
            case .star: op = .multiply
            case .slash: op = .realDivide
            case .kwDiv: op = .intDivide
            case .kwMod: op = .modulo
            default: return left
            }
            advance()
            let right = try parseFactor()
            left = .binary(left, op, right)
        }
    }

    private func parseFactor() throws -> Expression {
        switch current.type {
        case .intLiteral(let v):
            advance()
            return .intLiteral(v)

        case .realLiteral(let v):
            advance()
            return .realLiteral(v)

        case .stringLiteral(let s):
            advance()
            // Check for string concatenation with # (char literal)
            return .stringLiteral(s)

        case .kwTrue:
            advance()
            return .boolLiteral(true)

        case .kwFalse:
            advance()
            return .boolLiteral(false)

        case .lparen:
            advance()
            let expr = try parseExpression()
            try expect(.rparen)
            return expr

        case .kwNot:
            advance()
            let expr = try parseFactor()
            return .unary(.not, expr)

        case .identifier(let name):
            advance()
            let upper = name.uppercased()

            // MEM[seg:offset] special syntax
            if upper == "MEM" && current.type == .lbracket {
                advance()
                let addr = try parseExpression()
                // In PONG, Mem[0:1047] — the segment:offset is parsed as 0:1047
                // The expression parser sees 0, then we check for colon
                // Actually we need to handle this differently since : is not an operator
                // The addr expression parsed "0", now check for colon
                if current.type == .colon {
                    advance()
                    let offset = try parseExpression()
                    try expect(.rbracket)
                    // Combine seg*16 + offset
                    return .memAccess(.binary(
                        .binary(addr, .multiply, .intLiteral(16)),
                        .add,
                        offset
                    ))
                }
                try expect(.rbracket)
                return .memAccess(addr)
            }

            // Function call
            if current.type == .lparen {
                advance()
                var args: [Expression] = []
                if current.type != .rparen {
                    args.append(try parseExpression())
                    while match(.comma) {
                        args.append(try parseExpression())
                    }
                }
                try expect(.rparen)
                return .call(upper, args)
            }

            // Array access
            if current.type == .lbracket {
                advance()
                var indices: [Expression] = []
                indices.append(try parseExpression())
                while match(.comma) {
                    indices.append(try parseExpression())
                }
                try expect(.rbracket)
                return .arrayAccess(.identifier(upper), indices)
            }

            return .identifier(upper)

        default:
            throw PascalError.parserError("Unexpected token in expression: \(current.type)", current.location)
        }
    }
}
