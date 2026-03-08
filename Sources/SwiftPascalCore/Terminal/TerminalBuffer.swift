import Foundation

public struct TerminalCell: Sendable {
    public var character: Character = " "
    public var attribute: UInt8 = 0x07  // light gray on black

    public var foregroundIndex: Int { Int(attribute & 0x0F) }
    public var backgroundIndex: Int { Int((attribute >> 4) & 0x07) }
    public var blink: Bool { attribute & 0x80 != 0 }

    public init(character: Character = " ", attribute: UInt8 = 0x07) {
        self.character = character
        self.attribute = attribute
    }
}

@MainActor
public class TerminalBuffer: ObservableObject {
    @Published public var columns: Int = 80
    @Published public var rows: Int = 25
    @Published public var cells: [[TerminalCell]]
    @Published public var cursorX: Int = 0   // 0-based
    @Published public var cursorY: Int = 0   // 0-based
    @Published public var blinkVisible: Bool = true

    public var currentTextColor: UInt8 = 7
    public var currentBackground: UInt8 = 0

    public var currentAttribute: UInt8 {
        (currentBackground << 4) | (currentTextColor & 0x0F) | (currentTextColor & 0x80)
    }

    public init(columns: Int = 80, rows: Int = 25) {
        self.columns = columns
        self.rows = rows
        self.cells = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
    }

    public func resize(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.cells = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
        cursorX = 0
        cursorY = 0
    }

    public func clear() {
        let attr = currentAttribute
        for row in 0..<rows {
            for col in 0..<columns {
                cells[row][col] = TerminalCell(character: " ", attribute: attr)
            }
        }
        cursorX = 0
        cursorY = 0
    }

    public func writeChar(_ ch: Character, attribute: UInt8? = nil) {
        let attr = attribute ?? currentAttribute
        if ch == "\n" || ch == "\r" {
            cursorX = 0
            cursorY += 1
            if cursorY >= rows {
                scrollUp()
                cursorY = rows - 1
            }
            return
        }

        if cursorX < columns && cursorY < rows {
            cells[cursorY][cursorX] = TerminalCell(character: ch, attribute: attr)
            cursorX += 1
            if cursorX >= columns {
                cursorX = 0
                cursorY += 1
                if cursorY >= rows {
                    scrollUp()
                    cursorY = rows - 1
                }
            }
        }
    }

    public func writeString(_ s: String, attribute: UInt8? = nil) {
        for ch in s {
            writeChar(ch, attribute: attribute)
        }
    }

    public func setCell(row: Int, col: Int, character: Character, attribute: UInt8) {
        guard row >= 0 && row < rows && col >= 0 && col < columns else { return }
        cells[row][col] = TerminalCell(character: character, attribute: attribute)
    }

    public func getCell(row: Int, col: Int) -> TerminalCell {
        guard row >= 0 && row < rows && col >= 0 && col < columns else {
            return TerminalCell()
        }
        return cells[row][col]
    }

    // Video memory access for ABSOLUTE $B800:0
    // In CGA text mode, offset = (row * columns + col) * 2
    // Even offsets = character, odd offsets = attribute
    public func videoWrite(offset: Int, value: UInt8) {
        let cellIndex = offset / 2
        let row = cellIndex / columns
        let col = cellIndex % columns
        guard row >= 0 && row < rows && col >= 0 && col < columns else { return }
        if offset % 2 == 0 {
            // Character byte
            cells[row][col].character = Character(UnicodeScalar(value))
        } else {
            // Attribute byte
            cells[row][col].attribute = value
        }
    }

    public func videoRead(offset: Int) -> UInt8 {
        let cellIndex = offset / 2
        let row = cellIndex / columns
        let col = cellIndex % columns
        guard row >= 0 && row < rows && col >= 0 && col < columns else { return 0 }
        if offset % 2 == 0 {
            let ch = cells[row][col].character
            return UInt8(ch.asciiValue ?? 0x20)
        } else {
            return cells[row][col].attribute
        }
    }

    private func scrollUp() {
        let attr = currentAttribute
        for row in 0..<(rows - 1) {
            cells[row] = cells[row + 1]
        }
        cells[rows - 1] = Array(repeating: TerminalCell(character: " ", attribute: attr), count: columns)
    }
}
