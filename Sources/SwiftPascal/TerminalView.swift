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

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }  // Top-left origin like DOS

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupRefresh()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRefresh()
    }

    private var refreshTimer: Timer?

    private func setupRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    override func becomeFirstResponder() -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let buffer = buffer else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        let cellWidth = bounds.width / CGFloat(buffer.columns)
        let cellHeight = bounds.height / CGFloat(buffer.rows)

        // Use Menlo for a blockier, more DOS-like look
        let fontSize = min(cellHeight * 0.9, cellWidth * 1.6)
        let font = NSFont(name: "Menlo-Bold", size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        // Black background
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)

        for row in 0..<buffer.rows {
            for col in 0..<buffer.columns {
                let cell = buffer.cells[row][col]
                let x = CGFloat(col) * cellWidth
                let y = CGFloat(row) * cellHeight  // flipped view, top-left origin
                let cellRect = CGRect(x: x, y: y, width: cellWidth + 0.5, height: cellHeight + 0.5)

                // Draw background
                let bgIdx = cell.backgroundIndex
                if bgIdx != 0 {
                    ctx.setFillColor(cgaColor(at: bgIdx))
                    ctx.fill(cellRect)
                }

                let ch = cell.character
                if ch == " " { continue }

                // Handle blink
                if cell.blink && !buffer.blinkVisible { continue }

                let fgColor = cgaColor(at: cell.foregroundIndex)

                // Draw block/line characters as geometric shapes for pixel-perfect rendering
                if let scalar = ch.unicodeScalars.first?.value, drawBlockChar(ctx: ctx, scalar: scalar, rect: cellRect, color: fgColor) {
                    continue
                }

                // Draw text character
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

    /// Draw block and box-drawing characters as geometric shapes.
    /// Returns true if the character was handled.
    private func drawBlockChar(ctx: CGContext, scalar: UInt32, rect: CGRect, color: CGColor) -> Bool {
        ctx.setFillColor(color)
        ctx.setStrokeColor(color)

        switch scalar {
        // === Block elements ===
        case 219, 0x2588:  // █ full block
            ctx.fill(rect)
            return true
        case 220, 0x2584:  // ▄ lower half block
            ctx.fill(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2))
            return true
        case 223, 0x2580:  // ▀ upper half block
            ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2))
            return true
        case 221, 0x258C:  // ▌ left half block
            ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
            return true
        case 222, 0x2590:  // ▐ right half block
            ctx.fill(CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
            return true
        case 254, 0x25A0:  // ■ filled square
            let inset = rect.width * 0.15
            ctx.fill(rect.insetBy(dx: inset, dy: inset))
            return true

        // === Shade characters ===
        case 176, 0x2591:  // ░ light shade
            ctx.setFillColor(color.copy(alpha: 0.25)!)
            ctx.fill(rect)
            return true
        case 177, 0x2592:  // ▒ medium shade
            ctx.setFillColor(color.copy(alpha: 0.5)!)
            ctx.fill(rect)
            return true
        case 178, 0x2593:  // ▓ dark shade
            ctx.setFillColor(color.copy(alpha: 0.75)!)
            ctx.fill(rect)
            return true

        // === Box-drawing: horizontal and vertical lines ===
        case 196, 0x2500:  // ─ horizontal line
            let lineH = max(rect.height * 0.15, 1.5)
            ctx.fill(CGRect(x: rect.minX, y: rect.midY - lineH / 2, width: rect.width, height: lineH))
            return true
        case 205, 0x2550:  // ═ double horizontal
            let lineH = max(rect.height * 0.1, 1.0)
            let gap = rect.height * 0.12
            ctx.fill(CGRect(x: rect.minX, y: rect.midY - gap - lineH, width: rect.width, height: lineH))
            ctx.fill(CGRect(x: rect.minX, y: rect.midY + gap, width: rect.width, height: lineH))
            return true
        case 179, 0x2502:  // │ vertical line
            let lineW = max(rect.width * 0.15, 1.5)
            ctx.fill(CGRect(x: rect.midX - lineW / 2, y: rect.minY, width: lineW, height: rect.height))
            return true
        case 186, 0x2551:  // ║ double vertical
            let lineW = max(rect.width * 0.1, 1.0)
            let gap = rect.width * 0.12
            ctx.fill(CGRect(x: rect.midX - gap - lineW, y: rect.minY, width: lineW, height: rect.height))
            ctx.fill(CGRect(x: rect.midX + gap, y: rect.minY, width: lineW, height: rect.height))
            return true

        // === Box-drawing corners and tees ===
        case 218, 0x250C:  // ┌
            drawBoxJoint(ctx: ctx, rect: rect, right: true, down: true)
            return true
        case 191, 0x2510:  // ┐
            drawBoxJoint(ctx: ctx, rect: rect, left: true, down: true)
            return true
        case 192, 0x2514:  // └
            drawBoxJoint(ctx: ctx, rect: rect, right: true, up: true)
            return true
        case 217, 0x2518:  // ┘
            drawBoxJoint(ctx: ctx, rect: rect, left: true, up: true)
            return true
        case 195, 0x251C:  // ├
            drawBoxJoint(ctx: ctx, rect: rect, right: true, up: true, down: true)
            return true
        case 180, 0x2524:  // ┤
            drawBoxJoint(ctx: ctx, rect: rect, left: true, up: true, down: true)
            return true
        case 194, 0x252C:  // ┬
            drawBoxJoint(ctx: ctx, rect: rect, left: true, right: true, down: true)
            return true
        case 193, 0x2534:  // ┴
            drawBoxJoint(ctx: ctx, rect: rect, left: true, right: true, up: true)
            return true
        case 197, 0x253C:  // ┼
            drawBoxJoint(ctx: ctx, rect: rect, left: true, right: true, up: true, down: true)
            return true

        default:
            return false
        }
    }

    private func drawBoxJoint(ctx: CGContext, rect: CGRect,
                               left: Bool = false, right: Bool = false,
                               up: Bool = false, down: Bool = false) {
        let lineW = max(rect.width * 0.15, 1.5)
        let lineH = max(rect.height * 0.15, 1.5)
        let midX = rect.midX
        let midY = rect.midY

        if left {
            ctx.fill(CGRect(x: rect.minX, y: midY - lineH / 2, width: midX - rect.minX, height: lineH))
        }
        if right {
            ctx.fill(CGRect(x: midX, y: midY - lineH / 2, width: rect.maxX - midX, height: lineH))
        }
        if up {
            ctx.fill(CGRect(x: midX - lineW / 2, y: rect.minY, width: lineW, height: midY - rect.minY))
        }
        if down {
            ctx.fill(CGRect(x: midX - lineW / 2, y: midY, width: lineW, height: rect.maxY - midY))
        }
        // Center junction
        ctx.fill(CGRect(x: midX - lineW / 2, y: midY - lineH / 2, width: lineW, height: lineH))
    }

    // MARK: - DOS character mapping (for non-block text chars)

    private func mapDOSChar(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first?.value else { return ch }
        // Block/line chars are handled by drawBlockChar, but just in case:
        switch scalar {
        case 176: return "\u{2591}"
        case 177: return "\u{2592}"
        case 178: return "\u{2593}"
        case 179: return "\u{2502}"
        case 180: return "\u{2524}"
        case 191: return "\u{2510}"
        case 192: return "\u{2514}"
        case 193: return "\u{2534}"
        case 194: return "\u{252C}"
        case 195: return "\u{251C}"
        case 196: return "\u{2500}"
        case 197: return "\u{253C}"
        case 217: return "\u{2518}"
        case 218: return "\u{250C}"
        case 219: return "\u{2588}"
        case 220: return "\u{2584}"
        case 221: return "\u{258C}"
        case 222: return "\u{2590}"
        case 223: return "\u{2580}"
        case 254: return "\u{25A0}"
        default:  return ch
        }
    }

    // MARK: - Keyboard input

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else { return }

        for ch in chars {
            let scalar = ch.unicodeScalars.first?.value ?? 0

            switch scalar {
            case 13:    onKeyPress?("\r")
            case 27:    onKeyPress?("\u{1B}")
            case 127:   onKeyPress?("\u{7F}")
            case 63232: onKeyPress?("\u{48}")  // Up arrow
            case 63233: onKeyPress?("\u{50}")  // Down arrow
            case 63234: onKeyPress?("\u{4B}")  // Left arrow
            case 63235: onKeyPress?("\u{4D}")  // Right arrow
            default:
                if ch.isLetter {
                    onKeyPress?(ch.uppercased().first ?? ch)
                } else {
                    onKeyPress?(ch)
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
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
}
