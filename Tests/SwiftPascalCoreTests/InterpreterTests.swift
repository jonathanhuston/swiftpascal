import Testing
import Foundation
@testable import SwiftPascalCore

@Test func testForLoop() async throws {
    let source = """
    PROGRAM T;
    VAR i : INTEGER;
    BEGIN
        FOR i := 1 TO 5 DO
            Write(i);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // Should have written "12345"
    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    let c4 = await buffer.getCell(row: 0, col: 4)
    #expect(c0.character == "1")
    #expect(c1.character == "2")
    #expect(c4.character == "5")
}

@Test func testIfElse() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;
    BEGIN
        x := 10;
        IF x > 5 THEN
            Write('YES')
        ELSE
            Write('NO');
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    let c2 = await buffer.getCell(row: 0, col: 2)
    #expect(c0.character == "Y")
    #expect(c1.character == "E")
    #expect(c2.character == "S")
}

@Test func testProcedureCall() async throws {
    let source = """
    PROGRAM T;
    PROCEDURE Greet;
    BEGIN
        Write('Hi');
    END;
    BEGIN
        Greet;
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    #expect(c0.character == "H")
    #expect(c1.character == "i")
}

@Test func testFunctionReturn() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;

    FUNCTION Double(n : INTEGER) : INTEGER;
    BEGIN
        Double := n * 2;
    END;

    BEGIN
        x := Double(21);
        Write(x);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    #expect(c0.character == "4")
    #expect(c1.character == "2")
}

@Test func testGotoXY() async throws {
    let source = """
    PROGRAM T;
    USES Crt;
    BEGIN
        ClrScr;
        GotoXY(5, 3);
        Write('X');
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // GotoXY(5,3) -> col 4 (0-based), row 2 (0-based)
    let cell = await buffer.getCell(row: 2, col: 4)
    #expect(cell.character == "X")
}

@Test func testTextColor() async throws {
    let source = """
    PROGRAM T;
    USES Crt;
    BEGIN
        ClrScr;
        TextColor(14);
        Write('Y');
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let cell = await buffer.getCell(row: 0, col: 0)
    #expect(cell.character == "Y")
    #expect(cell.foregroundIndex == 14) // Yellow
}

@Test func testArrayAccess() async throws {
    let source = """
    PROGRAM T;
    VAR a : ARRAY [1..5] OF INTEGER;
        i : INTEGER;
    BEGIN
        FOR i := 1 TO 5 DO
            a[i] := i * 10;
        Write(a[3]);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    #expect(c0.character == "3")
    #expect(c1.character == "0")
}

@Test func testRepeatUntil() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;
    BEGIN
        x := 0;
        REPEAT
            x := x + 1;
        UNTIL x = 5;
        Write(x);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    #expect(c0.character == "5")
}

@Test func testWhileLoop() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;
    BEGIN
        x := 1;
        WHILE x < 100 DO
            x := x * 2;
        Write(x);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    let c2 = await buffer.getCell(row: 0, col: 2)
    #expect(c0.character == "1")
    #expect(c1.character == "2")
    #expect(c2.character == "8")
}

@Test func testNestedProcedure() async throws {
    let source = """
    PROGRAM T;
    VAR result : INTEGER;

    PROCEDURE Outer;
    VAR x : INTEGER;

        PROCEDURE Inner;
        BEGIN
            x := 42;
        END;

    BEGIN
        x := 0;
        Inner;
        result := x;
    END;

    BEGIN
        Outer;
        Write(result);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    #expect(c0.character == "4")
    #expect(c1.character == "2")
}

@Test func testStringOperations() async throws {
    let source = """
    PROGRAM T;
    VAR s : STRING;
        p : INTEGER;
    BEGIN
        s := 'Hello World';
        p := Pos(' ', s);
        Write(p);
        Write(Copy(s, 1, 5));
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    #expect(c0.character == "6") // Pos returns 6 (1-based position of space)
    let c1 = await buffer.getCell(row: 0, col: 1)
    #expect(c1.character == "H") // Copy returns "Hello"
}

@Test func testWriteFormat() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;
    BEGIN
        x := 42;
        Write(x:5);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // "   42" - right justified in width 5
    let c0 = await buffer.getCell(row: 0, col: 0)
    let c3 = await buffer.getCell(row: 0, col: 3)
    let c4 = await buffer.getCell(row: 0, col: 4)
    #expect(c0.character == " ")
    #expect(c3.character == "4")
    #expect(c4.character == "2")
}

@Test func testChrOrd() async throws {
    let source = """
    PROGRAM T;
    BEGIN
        Write(Chr(65));
        Write(Ord('B'));
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    let c0 = await buffer.getCell(row: 0, col: 0)
    let c1 = await buffer.getCell(row: 0, col: 1)
    let c2 = await buffer.getCell(row: 0, col: 2)
    #expect(c0.character == "A")
    #expect(c1.character == "6") // Ord('B') = 66
    #expect(c2.character == "6")
}
