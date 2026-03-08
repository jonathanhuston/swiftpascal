import Testing
import Foundation
@testable import SwiftPascalCore

@Test func testParsePong() throws {
    let url = URL(fileURLWithPath: "/Users/jonathanhuston/Documents/Programs/Swift Pascal/sample programs/PONG.PAS")
    let source = try String(contentsOf: url, encoding: .utf8)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.name == "PONG")
    #expect(program.uses.count == 3)
    #expect(program.uses.contains("CRT"))
}

@Test func testParsePongProcs() throws {
    let source = """
    PROGRAM T;
    VAR c : CHAR;

    FUNCTION GetKey : CHAR;
    BEGIN
        Read(Kbd, c);
        GetKey := c;
    END;

    PROCEDURE Start;
    VAR s : STRING [3];

        FUNCTION Return : BOOLEAN;
        BEGIN
            Return := c = Chr(13);
        END;

        FUNCTION Left : BOOLEAN;
        BEGIN
            Left := c = '4';
        END;

    BEGIN
        c := GetKey;
    END;

    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count == 3) // c var, GetKey func, Start proc
}

@Test func testParsePongVars() throws {
    let source = """
    PROGRAM T;
    VAR
       Laenge      : ARRAY [1..2] OF 1..12;
       Punkte      : ARRAY [1..2] OF 0..100;
       Farbe       : ARRAY [1..2] OF 0..15;
       Name        : ARRAY [1..2] OF STRING [15];
       Position    : ARRAY [1..2] OF 2..24;
       Video       : ARRAY [1..25, 1..40, 1..2] OF CHAR ABSOLUTE $B800:0;
       Punktemax   : 0..100;
       Zeile,
       Spalte      : -1..1;
       X           : 1..40;
       Y           : 2..24;
       Tempo       : -1..25;
       Geraeusch   : BOOLEAN;
       i,j,k       : INTEGER;
       c           : CHAR;
    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count > 5)
}

@Test func testParseSubrangeElementType() throws {
    let source = """
    PROGRAM T;
    VAR
        Laenge : ARRAY [1..2] OF 1..12;
    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count == 1)
}

@Test func testParseAbsoluteArray() throws {
    let source = """
    PROGRAM T;
    VAR
        Video : ARRAY [1..25, 1..40, 1..2] OF CHAR ABSOLUTE $B800:0;
    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count == 1)
}

@Test func testLexPong() throws {
    let url = URL(fileURLWithPath: "/Users/jonathanhuston/Documents/Programs/Swift Pascal/sample programs/PONG.PAS")
    let source = try String(contentsOf: url, encoding: .utf8)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    // Should have many tokens without error
    #expect(tokens.count > 100)
}
