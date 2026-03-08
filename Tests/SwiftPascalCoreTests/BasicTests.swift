import Testing
@testable import SwiftPascalCore

@Test func testLexerSimple() throws {
    let source = "PROGRAM Hello; BEGIN WriteLn('Hello, World!') END."
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()

    #expect(tokens[0].type == .kwProgram)
    #expect(tokens[1].type == .identifier("HELLO"))
    #expect(tokens[2].type == .semicolon)
    #expect(tokens[3].type == .kwBegin)
    #expect(tokens[4].type == .identifier("WRITELN"))
}

@Test func testLexerHexLiteral() throws {
    let source = "$B800"
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    #expect(tokens[0].type == .intLiteral(0xB800))
}

@Test func testLexerComment() throws {
    let source = "{$R+}\nBEGIN END."
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    #expect(tokens[0].type == .kwBegin)
}

@Test func testParserSimple() throws {
    let source = "PROGRAM Hello; BEGIN END."
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.name == "HELLO")
}

@Test func testParserConst() throws {
    let source = """
    PROGRAM Test;
    CONST
        X = 42;
        Y = 100;
    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count == 2)
}

@Test func testParserVar() throws {
    let source = """
    PROGRAM Test;
    VAR
        i, j : INTEGER;
        c : CHAR;
    BEGIN
    END.
    """
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    #expect(program.declarations.count == 2)
}

@Test func testInterpreterWrite() async throws {
    let source = """
    PROGRAM Hello;
    BEGIN
        Write('Hello')
    END.
    """
    let buffer = await TerminalBuffer()
    let interp = await Interpreter(buffer: buffer)
    let lexer = Lexer(source: source)
    let tokens = try lexer.tokenize()
    let parser = Parser(tokens: tokens)
    let program = try parser.parseProgram()
    try await interp.run(program)

    // Check that "Hello" was written to the buffer
    let cell0 = await buffer.getCell(row: 0, col: 0)
    let cell4 = await buffer.getCell(row: 0, col: 4)
    #expect(cell0.character == "H")
    #expect(cell4.character == "o")
}
