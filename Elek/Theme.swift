import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Elek color palette for light and dark, straight from the design spec.
struct Palette {
    let background: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let faceTop: Color
    let faceBottom: Color

    static let light = Palette(
        background: Color(hex: 0xF6F5F2),
        text: Color(hex: 0x26271F),
        secondary: Color(.sRGB, red: 60 / 255, green: 60 / 255, blue: 67 / 255, opacity: 0.55),
        accent: Color(hex: 0x3E9B86),
        faceTop: .white,
        faceBottom: Color(hex: 0xEEF3F1))

    static let dark = Palette(
        background: Color(hex: 0x0D0E0E),
        text: Color(hex: 0xF4F5F3),
        secondary: Color(.sRGB, red: 235 / 255, green: 235 / 255, blue: 245 / 255, opacity: 0.55),
        accent: Color(hex: 0x57B79E),
        faceTop: Color(hex: 0x1C1E1F),
        faceBottom: Color(hex: 0x131414))

    static func resolve(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
