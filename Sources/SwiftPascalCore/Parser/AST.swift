// MARK: - Expressions

public enum BinaryOp: Sendable {
    case add, subtract, multiply, realDivide, intDivide, modulo
    case equal, notEqual, less, lessEqual, greater, greaterEqual
    case and, or
}

public enum UnaryOp: Sendable {
    case negate, not
}

public indirect enum Expression: Sendable {
    case intLiteral(Int)
    case realLiteral(Double)
    case stringLiteral(String)
    case boolLiteral(Bool)
    case identifier(String)
    case binary(Expression, BinaryOp, Expression)
    case unary(UnaryOp, Expression)
    case call(String, [Expression])
    case arrayAccess(Expression, [Expression])
    case memAccess(Expression)           // Mem[addr] — segment:offset combined
    case fieldAccess(Expression, String)
}

// MARK: - Write arguments with optional format specifiers

public struct WriteArg: Sendable {
    public let expression: Expression
    public let width: Expression?
    public let decimals: Expression?

    public init(expression: Expression, width: Expression? = nil, decimals: Expression? = nil) {
        self.expression = expression
        self.width = width
        self.decimals = decimals
    }
}

// MARK: - Statements

public enum ForDirection: Sendable {
    case to, downTo
}

public indirect enum Statement: Sendable {
    case compound([Statement])
    case assign(Expression, Expression)
    case procedureCall(String, [Expression])
    case ifStmt(condition: Expression, thenBranch: Statement, elseBranch: Statement?)
    case forStmt(variable: String, from: Expression, direction: ForDirection, to: Expression, body: Statement)
    case whileStmt(condition: Expression, body: Statement)
    case repeatStmt(body: [Statement], until: Expression)
    case writeStmt(args: [WriteArg], newline: Bool)
    case readStmt(variables: [Expression], newline: Bool, isKbd: Bool)
    case empty
}

// MARK: - Type specifications

public indirect enum TypeSpec: Sendable {
    case simple(String)                               // INTEGER, CHAR, BOOLEAN, etc.
    case stringType(Int?)                             // STRING or STRING[n]
    case subrange(Expression, Expression)             // lo..hi
    case arrayType(indices: [TypeSpec], element: TypeSpec)  // ARRAY [idx1, idx2] OF type
    case absolute(TypeSpec, segment: Int, offset: Int)     // type ABSOLUTE seg:offset
}

// MARK: - Parameters

public struct Parameter: Sendable {
    public let name: String
    public let type: TypeSpec
    public let isVar: Bool

    public init(name: String, type: TypeSpec, isVar: Bool = false) {
        self.name = name
        self.type = type
        self.isVar = isVar
    }
}

// MARK: - Declarations

public indirect enum Declaration: Sendable {
    case constDecl(name: String, value: Expression)
    case varDecl(names: [String], type: TypeSpec)
    case typeDecl(name: String, type: TypeSpec)
    case procedureDecl(name: String, params: [Parameter], decls: [Declaration], body: Statement)
    case functionDecl(name: String, params: [Parameter], returnType: TypeSpec, decls: [Declaration], body: Statement)
}

// MARK: - Program

public struct PascalProgram: Sendable {
    public let name: String
    public let uses: [String]
    public let declarations: [Declaration]
    public let body: Statement

    public init(name: String, uses: [String], declarations: [Declaration], body: Statement) {
        self.name = name
        self.uses = uses
        self.declarations = declarations
        self.body = body
    }
}
