import SwiftUI
import SwiftPascalCore

struct ContentView: View {
    @StateObject private var store = TerminalStore()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button("Open .PAS") {
                    store.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                if store.isRunning {
                    Button("Stop") {
                        store.stop()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else if store.sourceCode != nil {
                    Button("Run") {
                        store.run()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }

                Spacer()

                if let fileName = store.fileName {
                    Text(fileName)
                        .foregroundColor(.gray)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.12))

            // Terminal fills the remaining space; cells scale to fit
            TerminalView(buffer: store.buffer, onKeyPress: { key in
                store.handleKey(key)
            })

            // Error bar
            if let error = store.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") { store.errorMessage = nil }
                        .buttonStyle(.plain)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(white: 0.1))
            }
        }
        .frame(width: 800, height: 540)
        .background(.black)
    }
}
