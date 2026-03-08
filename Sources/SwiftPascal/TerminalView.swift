import SwiftUI
import SwiftPascalCore
import AppKit

struct TerminalView: NSViewRepresentable {
    @ObservedObject var buffer: TerminalBuffer
    var onKeyPress: (Character) -> Void

    func makeNSView(context: Context) -> TerminalNSView {
        let view = TerminalNSView()
        view.buffer = buffer
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: TerminalNSView, context: Context) {
        nsView.buffer = buffer
        nsView.onKeyPress = onKeyPress
        nsView.needsDisplay = true
    }
}

class TerminalNSView: NSView {
    var buffer: TerminalBuffer?
    var onKeyPress: ((Character) -> Void)?
    private var observation: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupObservation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupObservation()
    }

    private var refreshTimer: Timer?

    private func setupObservation() {
        // Refresh at 30fps for smooth animation
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let buffer = buffer else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        let cellWidth = bounds.width / CGFloat(buffer.columns)
        let cellHeight = bounds.height / CGFloat(buffer.rows)
        let fontSize = cellHeight * 0.78

        // Use a monospaced font
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Draw black background
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        for row in 0..<buffer.rows {
            for col in 0..<buffer.columns {
                let cell = buffer.cells[row][col]
                let x = CGFloat(col) * cellWidth
                // NSView has flipped-y compared to what we want
                let y = bounds.height - CGFloat(row + 1) * cellHeight

                // Draw background
                let bgColor = cgaColor(at: cell.backgroundIndex)
                context.setFillColor(bgColor)
                context.fill(CGRect(x: x, y: y, width: cellWidth + 0.5, height: cellHeight + 0.5))

                // Draw character
                let ch = cell.character
                if ch != " " {
                    // Handle blink
                    if cell.blink && !(buffer.blinkVisible) {
                        continue
                    }

                    let fgColor = cgaColor(at: cell.foregroundIndex)
                    let displayChar = mapDOSChar(ch)
                    let attrStr = NSAttributedString(
                        string: String(displayChar),
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor(cgColor: fgColor) ?? .white,
                        ]
                    )
                    let strSize = attrStr.size()
                    let drawX = x + (cellWidth - strSize.width) / 2
                    let drawY = y + (cellHeight - strSize.height) / 2
                    attrStr.draw(at: NSPoint(x: drawX, y: drawY))
                }
            }
        }
    }

    // MARK: - Keyboard input

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else { return }

        for ch in chars {
            let scalar = ch.unicodeScalars.first?.value ?? 0

            // Map special keys
            switch scalar {
            case 13:  // Return
                onKeyPress?("\r")
            case 27:  // Escape
                onKeyPress?("\u{1B}")
            case 127: // Delete/Backspace
                onKeyPress?("\u{7F}")
            case 63232: // Up arrow
                onKeyPress?("\u{48}") // Could map to something useful
            case 63233: // Down arrow
                onKeyPress?("\u{50}")
            case 63234: // Left arrow
                onKeyPress?("\u{4B}")
            case 63235: // Right arrow
                onKeyPress?("\u{4D}")
            default:
                // Send uppercase for letters (Turbo Pascal keyboard)
                if ch.isLetter {
                    onKeyPress?(ch.uppercased().first ?? ch)
                } else {
                    onKeyPress?(ch)
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Grab focus when clicked
        window?.makeFirstResponder(self)
    }

    // MARK: - CGA Colors

    private func cgaColor(at index: Int) -> CGColor {
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.0,   0.0,   0.0),     // 0  Black
            (0.0,   0.0,   0.667),   // 1  Blue
            (0.0,   0.667, 0.0),     // 2  Green
            (0.0,   0.667, 0.667),   // 3  Cyan
            (0.667, 0.0,   0.0),     // 4  Red
            (0.667, 0.0,   0.667),   // 5  Magenta
            (0.667, 0.333, 0.0),     // 6  Brown
            (0.667, 0.667, 0.667),   // 7  Light Gray
            (0.333, 0.333, 0.333),   // 8  Dark Gray
            (0.333, 0.333, 1.0),     // 9  Light Blue
            (0.333, 1.0,   0.333),   // 10 Light Green
            (0.333, 1.0,   1.0),     // 11 Light Cyan
            (1.0,   0.333, 0.333),   // 12 Light Red
            (1.0,   0.333, 1.0),     // 13 Light Magenta
            (1.0,   1.0,   0.333),   // 14 Yellow
            (1.0,   1.0,   1.0),     // 15 White
        ]
        let i = index & 0x0F
        let c = palette[i]
        return CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
    }

    /// Map DOS code page 437 character codes to Unicode equivalents
    private func mapDOSChar(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first?.value else { return ch }
        switch scalar {
        case 176: return "\u{2591}"  // ░ light shade
        case 177: return "\u{2592}"  // ▒ medium shade
        case 178: return "\u{2593}"  // ▓ dark shade
        case 179: return "\u{2502}"  // │ vertical line
        case 180: return "\u{2524}"  // ┤ right tee
        case 191: return "\u{2510}"  // ┐ top-right corner
        case 192: return "\u{2514}"  // └ bottom-left corner
        case 193: return "\u{2534}"  // ┴ bottom tee
        case 194: return "\u{252C}"  // ┬ top tee
        case 195: return "\u{251C}"  // ├ left tee
        case 196: return "\u{2500}"  // ─ horizontal line
        case 197: return "\u{253C}"  // ┼ cross
        case 217: return "\u{2518}"  // ┘ bottom-right corner
        case 218: return "\u{250C}"  // ┌ top-left corner
        case 219: return "\u{2588}"  // █ full block
        case 220: return "\u{2584}"  // ▄ lower half block
        case 221: return "\u{258C}"  // ▌ left half block
        case 222: return "\u{2590}"  // ▐ right half block
        case 223: return "\u{2580}"  // ▀ upper half block
        case 254: return "\u{25A0}"  // ■ filled square
        default:  return ch
        }
    }
}
