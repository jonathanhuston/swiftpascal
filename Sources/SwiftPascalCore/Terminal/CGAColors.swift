import SwiftUI

public struct CGAColors {
    public static let palette: [(red: Double, green: Double, blue: Double)] = [
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

    public static func color(at index: Int) -> Color {
        let i = index & 0x0F
        let c = palette[i]
        return Color(red: c.red, green: c.green, blue: c.blue)
    }
}
