import SwiftUI
import SwiftPascalCore
import UniformTypeIdentifiers

@MainActor
class TerminalStore: ObservableObject {
    @Published var buffer = TerminalBuffer()
    @Published var isRunning = false
    @Published var sourceCode: String?
    @Published var fileName: String?
    @Published var errorMessage: String?

    private var interpreter: Interpreter?
    private var runTask: Task<Void, Never>?
    private var blinkTimer: Timer?

    init() {
        // Start blink timer for blinking text attributes
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.buffer.blinkVisible.toggle()
            }
        }
        showWelcome()
    }

    deinit {
        blinkTimer?.invalidate()
    }

    func showWelcome() {
        buffer.currentTextColor = 7
        buffer.currentBackground = 0
        buffer.clear()

        let lines = [
            (30, 8, "Swift Pascal", UInt8(14)),
            (19, 10, "Pascal ca. 1987 Interpreter", UInt8(7)),
            (22, 14, "Open a .PAS file to begin", UInt8(15)),
            (24, 15, "Press Cmd+O to open file", UInt8(8)),
        ]
        for (x, y, text, color) in lines {
            buffer.cursorX = x
            buffer.cursorY = y
            buffer.currentTextColor = color
            buffer.writeString(text)
        }
        buffer.currentTextColor = 7
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "pas") ?? .plainText,
            .plainText,
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Pascal source file"

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    func loadFile(url: URL) {
        do {
            // Try UTF-8 first, then Windows CP-1252 for old DOS files
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                sourceCode = text
            } else {
                sourceCode = try String(contentsOf: url, encoding: .windowsCP1252)
            }
            fileName = url.lastPathComponent
            errorMessage = nil
            run()
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
        }
    }

    func run() {
        guard let source = sourceCode else { return }
        stop()

        buffer.resize(columns: 80, rows: 25)
        buffer.currentTextColor = 7
        buffer.currentBackground = 0
        buffer.clear()

        interpreter = Interpreter(buffer: buffer)
        isRunning = true
        errorMessage = nil

        runTask = Task {
            do {
                let lexer = Lexer(source: source)
                let tokens = try lexer.tokenize()
                let parser = Parser(tokens: tokens)
                let program = try parser.parseProgram()
                try await interpreter?.run(program)
            } catch {
                errorMessage = "\(error)"
            }
            isRunning = false
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        interpreter = nil
    }

    func handleKey(_ ch: Character) {
        interpreter?.feedKey(ch)
    }
}
