import SwiftUI

/// Lofer's palette (from the brand board): near-black, charcoal, mocha, peach, cream,
/// plus the lilac-grey of the second logo pebble. Use these names, not raw hex, in views.
extension Color {
    static let loferInk = Color(hex: 0x0B0A0A)        // app background
    static let loferCharcoal = Color(hex: 0x171514)
    static let loferCharcoal2 = Color(hex: 0x23201F)
    static let loferMocha = Color(hex: 0x6B5345)
    static let loferPeach = Color(hex: 0xE4B598)      // the one accent
    static let loferCream = Color(hex: 0xF3EBE2)      // primary text
    static let loferLilac = Color(hex: 0xB8B2C6)
    static let loferMuted = Color(hex: 0xA39690)      // secondary text
    static let loferFaint = Color(hex: 0x6F6560)      // tertiary text
    static let loferLine = Color(hex: 0xF3EBE2).opacity(0.09)
    static let loferLine2 = Color(hex: 0xF3EBE2).opacity(0.17)
    static let loferWarning = Color(hex: 0xEBD3B2)

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// The warm background used behind most screens.
struct LoferBackground: View {
    var body: some View {
        ZStack {
            Color.loferInk
            RadialGradient(colors: [Color(hex: 0x231B17), Color(hex: 0x120F0E), Color(hex: 0x0A0909)],
                           center: UnitPoint(x: 0.5, y: 0.2), startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}
