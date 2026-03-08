import Foundation

@MainActor
public class Interpreter {
    public let buffer: TerminalBuffer
    private var environment: Environment
    private var globalEnv: Environment
    private var mockMemory: [Int: UInt8] = [:]  // For Mem[] access (BIOS area etc.)
    private var absoluteArrays: [(PascalArray, Int, Int)] = []  // (array, segment, offset)
    private var soundFrequency: Int = 0

    // Keyboard input
    private var keyBuffer: [Character] = []
    private var keyWaiters: [CheckedContinuation<Character, Never>] = []

    public init(buffer: TerminalBuffer) {
        self.buffer = buffer
        self.environment = Environment()
        self.globalEnv = environment
        setupBuiltinConstants()
    }

    // MARK: - Keyboard input (called from UI)

    public func feedKey(_ ch: Character) {
        if !keyWaiters.isEmpty {
            let waiter = keyWaiters.removeFirst()
            waiter.resume(returning: ch)
        } else {
            keyBuffer.append(ch)
        }
    }

    public func feedString(_ s: String) {
        for ch in s {
            feedKey(ch)
        }
        feedKey("\r") // Enter
    }

    private func readKey() async -> Character {
        if !keyBuffer.isEmpty {
            return keyBuffer.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            keyWaiters.append(continuation)
        }
    }

    private func keyPressed() -> Bool {
        !keyBuffer.isEmpty
    }

    // MARK: - Built-in constants

    private func setupBuiltinConstants() {
        // CGA Colors
        let colors: [(String, Int)] = [
            ("BLACK", 0), ("BLUE", 1), ("GREEN", 2), ("CYAN", 3),
            ("RED", 4), ("MAGENTA", 5), ("BROWN", 6), ("LIGHTGRAY", 7),
            ("DARKGRAY", 8), ("LIGHTBLUE", 9), ("LIGHTGREEN", 10), ("LIGHTCYAN", 11),
            ("LIGHTRED", 12), ("LIGHTMAGENTA", 13), ("YELLOW", 14), ("WHITE", 15),
            ("BLINK", 128),
        ]
        for (name, value) in colors {
            environment.define(name, value: .integer(value), isConstant: true)
        }

        // Text modes
        environment.define("C40", value: .integer(1), isConstant: true)
        environment.define("C80", value: .integer(3), isConstant: true)
        environment.define("BW40", value: .integer(0), isConstant: true)
        environment.define("BW80", value: .integer(2), isConstant: true)

        // Boolean
        environment.define("TRUE", value: .boolean(true), isConstant: true)
        environment.define("FALSE", value: .boolean(false), isConstant: true)

        // MaxInt
        environment.define("MAXINT", value: .integer(32767), isConstant: true)
    }

    // MARK: - Run program

    public func run(_ program: PascalProgram) async throws {
        // Process declarations
        try await processDeclarations(program.declarations)
        // Execute main body
        try await executeStatement(program.body)
    }

    // MARK: - Declarations

    private func processDeclarations(_ decls: [Declaration]) async throws {
        for decl in decls {
            switch decl {
            case .constDecl(let name, let expr):
                let value = try await evalExpression(expr)
                environment.define(name, value: value, isConstant: true)

            case .varDecl(let names, let typeSpec):
                for name in names {
                    let value = try await allocateType(typeSpec, name: name)
                    environment.define(name, value: value)
                }

            case .typeDecl:
                break // Type declarations stored but not actively used in interpretation

            case .procedureDecl(let name, _, _, _):
                environment.procedures[name] = decl

            case .functionDecl(let name, _, _, _, _):
                environment.procedures[name] = decl
            }
        }
    }

    private func allocateType(_ typeSpec: TypeSpec, name: String) async throws -> PascalValue {
        switch typeSpec {
        case .simple(let typeName):
            switch typeName {
            case "INTEGER": return .integer(0)
            case "REAL": return .real(0.0)
            case "CHAR": return .char(" ")
            case "BOOLEAN": return .boolean(false)
            default: return .integer(0)
            }

        case .stringType:
            return .string("")

        case .subrange:
            return .integer(0)

        case .arrayType(let indices, let element):
            var dims: [PascalArray.Dimension] = []
            for indexType in indices {
                guard case .subrange(let lo, let hi) = indexType else {
                    throw PascalError.runtimeError("Array index must be a subrange")
                }
                let loVal = try await evalExpression(lo).intValue
                let hiVal = try await evalExpression(hi).intValue
                dims.append(PascalArray.Dimension(low: loVal, high: hiVal))
            }
            let defaultVal = defaultValueForElement(element)
            let arr = PascalArray(dimensions: dims, defaultValue: defaultVal)
            return .array(arr)

        case .absolute(let innerType, let segment, let offset):
            // Create the array but mark it as absolute-bound to video memory
            let value = try await allocateType(innerType, name: name)
            if case .array(let arr) = value {
                arr.isAbsolute = true
                arr.absoluteSegment = segment
                arr.absoluteOffset = offset
                absoluteArrays.append((arr, segment, offset))
            }
            return value
        }
    }

    private func defaultValueForElement(_ element: TypeSpec) -> PascalValue {
        switch element {
        case .simple(let name):
            switch name {
            case "CHAR": return .char(" ")
            case "INTEGER": return .integer(0)
            case "BOOLEAN": return .boolean(false)
            case "REAL": return .real(0.0)
            default: return .integer(0)
            }
        case .stringType: return .string("")
        case .subrange: return .integer(0)
        default: return .integer(0)
        }
    }

    // MARK: - Statements

    private func executeStatement(_ stmt: Statement) async throws {
        switch stmt {
        case .compound(let stmts):
            for s in stmts {
                try await executeStatement(s)
            }

        case .assign(let target, let expr):
            let value = try await evalExpression(expr)
            try await assignTo(target: target, value: value)

        case .procedureCall(let name, let args):
            try await executeProcedureCall(name, args: args)

        case .ifStmt(let condition, let thenBranch, let elseBranch):
            let cond = try await evalExpression(condition)
            if cond.boolValue {
                try await executeStatement(thenBranch)
            } else if let elseBranch = elseBranch {
                try await executeStatement(elseBranch)
            }

        case .forStmt(let variable, let from, let direction, let to, let body):
            let fromVal = try await evalExpression(from).intValue
            let toVal = try await evalExpression(to).intValue
            try await environment.set(variable, value: .integer(fromVal))

            switch direction {
            case .to:
                var i = fromVal
                while i <= toVal {
                    try await environment.set(variable, value: .integer(i))
                    try await executeStatement(body)
                    i += 1
                }
            case .downTo:
                var i = fromVal
                while i >= toVal {
                    try await environment.set(variable, value: .integer(i))
                    try await executeStatement(body)
                    i -= 1
                }
            }

        case .whileStmt(let condition, let body):
            while try await evalExpression(condition).boolValue {
                try await executeStatement(body)
            }

        case .repeatStmt(let stmts, let until):
            repeat {
                for s in stmts {
                    try await executeStatement(s)
                }
            } while try await !evalExpression(until).boolValue

        case .writeStmt(let args, let newline):
            try await executeWrite(args: args, newline: newline)

        case .readStmt(let vars, let newline, let isKbd):
            try await executeRead(vars: vars, newline: newline, isKbd: isKbd)

        case .empty:
            break
        }
    }

    // MARK: - Assignment

    private func assignTo(target: Expression, value: PascalValue) async throws {
        switch target {
        case .identifier(let name):
            // Check if this is assigning to a function name (return value)
            if let funcName = environment.functionName, funcName == name {
                environment.returnValue = value
            } else {
                try await environment.set(name, value: value)
            }

        case .arrayAccess(let arrayExpr, let indexExprs):
            guard case .identifier(let name) = arrayExpr else {
                throw PascalError.runtimeError("Invalid array access target")
            }
            let arr = try environment.lookupArray(name)
            let indices = try await indexExprs.asyncMap { try await self.evalExpression($0).intValue }

            if arr.isAbsolute && arr.absoluteSegment == 0xB800 {
                // Video memory write
                try await writeVideoMemory(arr: arr, indices: indices, value: value)
            } else {
                arr.set(indices: indices, value: value)
            }

        case .memAccess(let addrExpr):
            let addr = try await evalExpression(addrExpr).intValue
            let byteVal = UInt8(value.intValue & 0xFF)
            mockMemory[addr] = byteVal

        default:
            throw PascalError.runtimeError("Invalid assignment target")
        }
    }

    private func writeVideoMemory(arr: PascalArray, indices: [Int], value: PascalValue) async throws {
        // Video[Y, X, K] where K=1 is character, K=2 is attribute
        // Map to TerminalBuffer
        guard indices.count == 3 else {
            throw PascalError.runtimeError("Video array requires 3 indices")
        }
        let row = indices[0] - 1  // 1-based to 0-based
        let col = indices[1] - 1
        let component = indices[2]  // 1=char, 2=attribute

        if component == 1 {
            // Character
            let ch = value.charValue
            let existing = buffer.getCell(row: row, col: col)
            buffer.setCell(row: row, col: col, character: ch, attribute: existing.attribute)
        } else {
            // Attribute
            let attr = UInt8(value.intValue & 0xFF)
            let existing = buffer.getCell(row: row, col: col)
            buffer.setCell(row: row, col: col, character: existing.character, attribute: attr)
        }
    }

    private func readVideoMemory(arr: PascalArray, indices: [Int]) -> PascalValue {
        guard indices.count == 3 else { return .char(" ") }
        let row = indices[0] - 1
        let col = indices[1] - 1
        let component = indices[2]
        let cell = buffer.getCell(row: row, col: col)
        if component == 1 {
            return .char(cell.character)
        } else {
            return .integer(Int(cell.attribute))
        }
    }

    // MARK: - Write/Read

    private func executeWrite(args: [WriteArg], newline: Bool) async throws {
        for arg in args {
            let value = try await evalExpression(arg.expression)
            var str = value.stringValue
            if let widthExpr = arg.width {
                let width = try await evalExpression(widthExpr).intValue
                if let decimalsExpr = arg.decimals {
                    let decimals = try await evalExpression(decimalsExpr).intValue
                    str = String(format: "%\(width).\(decimals)f", value.realValue)
                } else if width > str.count {
                    str = String(repeating: " ", count: width - str.count) + str
                }
            }
            buffer.writeString(str)
        }
        if newline {
            buffer.writeChar("\n")
        }
    }

    private func executeRead(vars: [Expression], newline: Bool, isKbd: Bool) async throws {
        if isKbd {
            // Read(Kbd, c) — read single char without echo
            let ch = await readKey()
            for v in vars {
                try await assignTo(target: v, value: .char(ch))
            }
        } else if vars.isEmpty && newline {
            // ReadLn with no args — wait for Enter
            var ch: Character = " "
            repeat {
                ch = await readKey()
            } while ch != "\r" && ch != "\n"
        } else {
            // Read/ReadLn — read line of input
            var inputStr = ""
            while true {
                let ch = await readKey()
                if ch == "\r" || ch == "\n" {
                    break
                }
                if ch == "\u{7f}" || ch == "\u{08}" {
                    // Backspace
                    if !inputStr.isEmpty {
                        inputStr.removeLast()
                        // Erase character on screen
                        if buffer.cursorX > 0 {
                            buffer.cursorX -= 1
                            buffer.writeChar(" ")
                            buffer.cursorX -= 1
                        }
                    }
                    continue
                }
                inputStr.append(ch)
                buffer.writeChar(ch)
            }
            if newline {
                buffer.writeChar("\n")
            }

            // Assign the input to variables
            for target in vars {
                let existing = try await resolveCurrentValue(target)
                switch existing {
                case .string:
                    try await assignTo(target: target, value: .string(inputStr))
                case .integer:
                    let val = Int(inputStr.trimmingCharacters(in: .whitespaces)) ?? 0
                    try await assignTo(target: target, value: .integer(val))
                case .char:
                    let ch = inputStr.first ?? " "
                    try await assignTo(target: target, value: .char(ch))
                case .real:
                    let val = Double(inputStr.trimmingCharacters(in: .whitespaces)) ?? 0.0
                    try await assignTo(target: target, value: .real(val))
                default:
                    try await assignTo(target: target, value: .string(inputStr))
                }
            }
        }
    }

    /// Resolve the current value at an expression target (to determine its type)
    private func resolveCurrentValue(_ expr: Expression) async throws -> PascalValue {
        switch expr {
        case .identifier(let name):
            return try environment.get(name)
        case .arrayAccess(let arrayExpr, let indexExprs):
            guard case .identifier(let name) = arrayExpr else {
                return .string("")
            }
            let arr = try environment.lookupArray(name)
            let indices = try await indexExprs.asyncMap { try await self.evalExpression($0).intValue }
            if arr.isAbsolute && arr.absoluteSegment == 0xB800 {
                return readVideoMemory(arr: arr, indices: indices)
            }
            return arr.get(indices: indices)
        default:
            return .string("")
        }
    }

    // MARK: - Procedure/Function calls

    private func executeProcedureCall(_ name: String, args: [Expression]) async throws {
        // Check built-in procedures first
        if try await executeBuiltinProcedure(name, args: args) {
            return
        }

        // Look up user-defined procedure
        guard let decl = environment.lookupProcedure(name) else {
            throw PascalError.runtimeError("Undefined procedure: \(name)")
        }

        switch decl {
        case .procedureDecl(_, let params, let decls, let body):
            let callEnv = Environment(parent: environment)
            // Bind parameters
            let evaluatedArgs = try await args.asyncMap { try await self.evalExpression($0) }
            for (i, param) in params.enumerated() {
                if i < evaluatedArgs.count {
                    callEnv.define(param.name, value: evaluatedArgs[i])
                }
            }
            let savedEnv = environment
            environment = callEnv
            try await processDeclarations(decls)
            try await executeStatement(body)
            environment = savedEnv

        case .functionDecl(let funcName, let params, _, let decls, let body):
            let callEnv = Environment(parent: environment)
            callEnv.functionName = funcName
            let evaluatedArgs = try await args.asyncMap { try await self.evalExpression($0) }
            for (i, param) in params.enumerated() {
                if i < evaluatedArgs.count {
                    callEnv.define(param.name, value: evaluatedArgs[i])
                }
            }
            let savedEnv = environment
            environment = callEnv
            try await processDeclarations(decls)
            try await executeStatement(body)
            environment = savedEnv

        default:
            throw PascalError.runtimeError("\(name) is not a procedure")
        }
    }

    private func callFunction(_ name: String, args: [Expression]) async throws -> PascalValue {
        // Check built-in functions first
        if let result = try await evalBuiltinFunction(name, args: args) {
            return result
        }

        // Look up user-defined function
        guard let decl = environment.lookupProcedure(name) else {
            throw PascalError.runtimeError("Undefined function: \(name)")
        }

        guard case .functionDecl(let funcName, let params, _, let decls, let body) = decl else {
            throw PascalError.runtimeError("\(name) is not a function")
        }

        let callEnv = Environment(parent: environment)
        callEnv.functionName = funcName
        let evaluatedArgs = try await args.asyncMap { try await self.evalExpression($0) }
        for (i, param) in params.enumerated() {
            if i < evaluatedArgs.count {
                callEnv.define(param.name, value: evaluatedArgs[i])
            }
        }
        let savedEnv = environment
        environment = callEnv
        try await processDeclarations(decls)
        try await executeStatement(body)
        let result = environment.returnValue
        environment = savedEnv
        return result
    }

    // MARK: - Built-in procedures

    private func executeBuiltinProcedure(_ name: String, args: [Expression]) async throws -> Bool {
        switch name {
        case "CLRSCR":
            buffer.clear()
            return true

        case "GOTOXY":
            let x = try await evalExpression(args[0]).intValue
            let y = try await evalExpression(args[1]).intValue
            buffer.cursorX = x - 1  // Pascal is 1-based
            buffer.cursorY = y - 1
            return true

        case "TEXTCOLOR":
            let color = try await evalExpression(args[0]).intValue
            buffer.currentTextColor = UInt8(color & 0xFF)
            return true

        case "TEXTBACKGROUND":
            let color = try await evalExpression(args[0]).intValue
            buffer.currentBackground = UInt8(color & 0x07)
            return true

        case "TEXTMODE":
            let mode = try await evalExpression(args[0]).intValue
            switch mode {
            case 0, 1: // BW40, C40
                buffer.resize(columns: 40, rows: 25)
            default: // BW80, C80
                buffer.resize(columns: 80, rows: 25)
            }
            return true

        case "GRAPHBACKGROUND":
            let color = try await evalExpression(args[0]).intValue
            buffer.currentBackground = UInt8(color & 0x07)
            return true

        case "DELAY":
            let ms = try await evalExpression(args[0]).intValue
            try await Task.sleep(nanoseconds: UInt64(max(ms, 1)) * 1_000_000)
            return true

        case "SOUND":
            soundFrequency = try await evalExpression(args[0]).intValue
            // Sound is a no-op visually — could use NSBeep for simple feedback
            return true

        case "NOSOUND":
            soundFrequency = 0
            return true

        case "CAPSLOCKAUS", "CAPSUNDNUMLOCKEEIN", "CAPSUNDNUMLOCKAUS":
            // These manipulate keyboard flags — no-op on macOS
            return true

        case "RANDOMIZE":
            // No-op, Swift's random is already seeded
            return true

        default:
            return false
        }
    }

    // MARK: - Built-in functions

    private func evalBuiltinFunction(_ name: String, args: [Expression]) async throws -> PascalValue? {
        switch name {
        case "CHR":
            let v = try await evalExpression(args[0]).intValue
            return .char(Character(UnicodeScalar(v) ?? UnicodeScalar(0x20)))

        case "ORD":
            let v = try await evalExpression(args[0])
            switch v {
            case .char(let c): return .integer(Int(c.asciiValue ?? 0))
            case .integer(let i): return .integer(i)
            case .boolean(let b): return .integer(b ? 1 : 0)
            default: return .integer(0)
            }

        case "PRED":
            let v = try await evalExpression(args[0]).intValue
            return .integer(v - 1)

        case "SUCC":
            let v = try await evalExpression(args[0]).intValue
            return .integer(v + 1)

        case "RANDOM":
            if args.isEmpty {
                return .real(Double.random(in: 0..<1))
            }
            let max = try await evalExpression(args[0]).intValue
            return .integer(Int.random(in: 0..<max))

        case "KEYPRESSED":
            return .boolean(keyPressed())

        case "READKEY":
            let ch = await readKey()
            return .char(ch)

        case "POS":
            let substr = try await evalExpression(args[0]).stringValue
            let str = try await evalExpression(args[1]).stringValue
            if let range = str.range(of: substr) {
                return .integer(str.distance(from: str.startIndex, to: range.lowerBound) + 1)
            }
            return .integer(0)

        case "COPY":
            let str = try await evalExpression(args[0]).stringValue
            let start = try await evalExpression(args[1]).intValue - 1  // 1-based to 0-based
            let len = try await evalExpression(args[2]).intValue
            let s = Array(str)
            let end = min(start + len, s.count)
            if start >= 0 && start < s.count {
                return .string(String(s[start..<end]))
            }
            return .string("")

        case "LENGTH":
            let str = try await evalExpression(args[0]).stringValue
            return .integer(str.count)

        case "UPCASE":
            let ch = try await evalExpression(args[0]).charValue
            return .char(Character(ch.uppercased()))

        case "ABS":
            let v = try await evalExpression(args[0])
            switch v {
            case .integer(let i): return .integer(abs(i))
            case .real(let r): return .real(abs(r))
            default: return v
            }

        case "SQR":
            let v = try await evalExpression(args[0])
            switch v {
            case .integer(let i): return .integer(i * i)
            case .real(let r): return .real(r * r)
            default: return v
            }

        case "SQRT":
            let v = try await evalExpression(args[0]).realValue
            return .real(sqrt(v))

        case "ROUND":
            let v = try await evalExpression(args[0]).realValue
            return .integer(Int(v.rounded()))

        case "TRUNC":
            let v = try await evalExpression(args[0]).realValue
            return .integer(Int(v))

        case "ODD":
            let v = try await evalExpression(args[0]).intValue
            return .boolean(v % 2 != 0)

        case "CONCAT":
            var result = ""
            for arg in args {
                result += try await evalExpression(arg).stringValue
            }
            return .string(result)

        case "SIZEOF":
            return .integer(0)  // Placeholder

        default:
            return nil
        }
    }

    // MARK: - Expression evaluation

    private func evalExpression(_ expr: Expression) async throws -> PascalValue {
        switch expr {
        case .intLiteral(let v):
            return .integer(v)

        case .realLiteral(let v):
            return .real(v)

        case .stringLiteral(let s):
            if s.count == 1 {
                return .char(s.first!)
            }
            return .string(s)

        case .boolLiteral(let v):
            return .boolean(v)

        case .identifier(let name):
            // First try as a variable
            if let value = try? environment.get(name) {
                return value
            }
            // Then try as a parameterless function call (Pascal allows calling
            // functions without parentheses when they have no parameters)
            if environment.lookupProcedure(name) != nil {
                return try await callFunction(name, args: [])
            }
            // Also check built-in functions
            if let result = try await evalBuiltinFunction(name, args: []) {
                return result
            }
            throw PascalError.runtimeError("Undefined identifier: \(name)")

        case .binary(let left, let op, let right):
            let lVal = try await evalExpression(left)
            let rVal = try await evalExpression(right)
            return evalBinary(lVal, op, rVal)

        case .unary(let op, let operand):
            let val = try await evalExpression(operand)
            switch op {
            case .negate:
                switch val {
                case .integer(let v): return .integer(-v)
                case .real(let v): return .real(-v)
                default: return val
                }
            case .not:
                return .boolean(!val.boolValue)
            }

        case .call(let name, let args):
            return try await callFunction(name, args: args)

        case .arrayAccess(let arrayExpr, let indexExprs):
            guard case .identifier(let name) = arrayExpr else {
                throw PascalError.runtimeError("Invalid array access")
            }
            let arr = try environment.lookupArray(name)
            let indices = try await indexExprs.asyncMap { try await self.evalExpression($0).intValue }

            if arr.isAbsolute && arr.absoluteSegment == 0xB800 {
                return readVideoMemory(arr: arr, indices: indices)
            }
            return arr.get(indices: indices)

        case .memAccess(let addrExpr):
            let addr = try await evalExpression(addrExpr).intValue
            return .integer(Int(mockMemory[addr] ?? 0))

        case .fieldAccess:
            throw PascalError.runtimeError("Record field access not yet implemented")
        }
    }

    private func evalBinary(_ left: PascalValue, _ op: BinaryOp, _ right: PascalValue) -> PascalValue {
        // String operations
        if case .string(let ls) = left, case .string(let rs) = right {
            switch op {
            case .add: return .string(ls + rs)
            case .equal: return .boolean(ls == rs)
            case .notEqual: return .boolean(ls != rs)
            case .less: return .boolean(ls < rs)
            case .greater: return .boolean(ls > rs)
            default: break
            }
        }

        // Char comparisons and addition
        if case .char(let lc) = left {
            if case .char(let rc) = right {
                switch op {
                case .equal: return .boolean(lc == rc)
                case .notEqual: return .boolean(lc != rc)
                case .less: return .boolean(String(lc) < String(rc))
                case .greater: return .boolean(String(lc) > String(rc))
                default: break
                }
            }
            // Char + string or string + char
            if op == .add {
                return .string(String(lc) + right.stringValue)
            }
        }
        if case .char(let rc) = right, op == .add {
            return .string(left.stringValue + String(rc))
        }

        // Boolean operations
        switch op {
        case .and: return .boolean(left.boolValue && right.boolValue)
        case .or: return .boolean(left.boolValue || right.boolValue)
        default: break
        }

        // Numeric operations
        // If either is real, promote to real
        let useReal = (left.isReal || right.isReal)
        if useReal {
            let l = left.realValue
            let r = right.realValue
            switch op {
            case .add: return .real(l + r)
            case .subtract: return .real(l - r)
            case .multiply: return .real(l * r)
            case .realDivide: return .real(r != 0 ? l / r : 0)
            case .intDivide: return .integer(r != 0 ? Int(l) / Int(r) : 0)
            case .modulo: return .integer(r != 0 ? Int(l) % Int(r) : 0)
            case .equal: return .boolean(l == r)
            case .notEqual: return .boolean(l != r)
            case .less: return .boolean(l < r)
            case .lessEqual: return .boolean(l <= r)
            case .greater: return .boolean(l > r)
            case .greaterEqual: return .boolean(l >= r)
            default: return .integer(0)
            }
        }

        let l = left.intValue
        let r = right.intValue
        switch op {
        case .add: return .integer(l + r)
        case .subtract: return .integer(l - r)
        case .multiply: return .integer(l * r)
        case .realDivide: return .real(r != 0 ? Double(l) / Double(r) : 0)
        case .intDivide: return .integer(r != 0 ? l / r : 0)
        case .modulo: return .integer(r != 0 ? l % r : 0)
        case .equal: return .boolean(l == r)
        case .notEqual: return .boolean(l != r)
        case .less: return .boolean(l < r)
        case .lessEqual: return .boolean(l <= r)
        case .greater: return .boolean(l > r)
        case .greaterEqual: return .boolean(l >= r)
        default: return .integer(0)
        }
    }
}

// MARK: - Helpers

extension PascalValue {
    var isReal: Bool {
        if case .real = self { return true }
        return false
    }
}

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
