import SwiftUI

/// Brain Breaking brand tokens shared by tray popover and mini-console.
enum BrainBreakingTheme {
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 8 / 255)
    static let surface = Color(red: 18 / 255, green: 18 / 255, blue: 16 / 255)
    static let sand = Color(red: 247 / 255, green: 246 / 255, blue: 242 / 255)
    static let muted = Color(red: 120 / 255, green: 120 / 255, blue: 112 / 255)
    static let accent = Color(red: 217 / 255, green: 59 / 255, blue: 45 / 255)
    static let accentHover = Color(red: 232 / 255, green: 71 / 255, blue: 42 / 255)
    static let border = sand.opacity(0.12)
    static let rowHeight: CGFloat = 30
}
