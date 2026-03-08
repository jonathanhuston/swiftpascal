import Testing
import Foundation
@testable import SwiftPascalCore

@Test func testColorsSample() async throws {
    let source = """
    PROGRAM Colors;
    USES Crt;
    VAR i : INTEGER;
    BEGIN
        ClrScr;
        FOR i := 0 TO 15 DO BEGIN
            TextColor(i);
            GotoXY(10, i + 3);
            Write('Color ', i, ': This is a test');
        END;
        TextColor(14);
        GotoXY(20, 22);
        Write('Press any key to exit...');
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // Check that color 0 text is at row 3 (0-based: 2), col 10 (0-based: 9)
    let cell = await buffer.getCell(row: 2, col: 9)
    #expect(cell.character == "C")
    #expect(cell.foregroundIndex == 0) // Black text

    // Check that color 14 (Yellow) text is at row 5 (0-based: 4), col 9
    let cell2 = await buffer.getCell(row: 4, col: 9)
    #expect(cell2.character == "C")
    #expect(cell2.foregroundIndex == 2) // Green (color index 2)

    // Check the "Press any key" text at row 22 (0-based: 21)
    let cell3 = await buffer.getCell(row: 21, col: 19)
    #expect(cell3.character == "P")
    #expect(cell3.foregroundIndex == 14) // Yellow
}

@Test func testVideoMemory() async throws {
    // Test direct video memory access like PONG's PrintAt
    let source = """
    PROGRAM T;
    USES Crt;
    VAR
        Video : ARRAY [1..25, 1..80, 1..2] OF CHAR ABSOLUTE $B800:0;

    PROCEDURE PrintAt(X, Y, ASC, Farbe : INTEGER);
    BEGIN
        Video[Y, X, 1] := Chr(ASC);
        Video[Y, X, 2] := Chr(Farbe);
    END;

    BEGIN
        ClrScr;
        PrintAt(10, 5, 65, 14);
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // PrintAt(10, 5, 65, 14) -> col 9 (0-based), row 4 (0-based), char 'A', yellow
    let cell = await buffer.getCell(row: 4, col: 9)
    #expect(cell.character == "A")
    #expect(cell.foregroundIndex == 14)
}

@Test func testNestedFunctions() async throws {
    // Test nested function declarations like PONG's Start procedure
    let source = """
    PROGRAM T;
    VAR c : CHAR;
        result : BOOLEAN;

    FUNCTION GetKey : CHAR;
    BEGIN
        GetKey := 'X';
    END;

    PROCEDURE Start;

        FUNCTION IsX : BOOLEAN;
        BEGIN
            IsX := c = 'X';
        END;

    BEGIN
        c := GetKey;
        result := IsX;
    END;

    BEGIN
        Start;
        IF result THEN
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
    #expect(c0.character == "Y")
}

@Test func testRandomFunction() async throws {
    let source = """
    PROGRAM T;
    VAR x : INTEGER;
    BEGIN
        x := Random(10);
        IF (x >= 0) AND (x < 10) THEN
            Write('OK')
        ELSE
            Write('BAD');
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
    #expect(c0.character == "O")
    #expect(c1.character == "K")
}
