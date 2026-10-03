import SwiftUI
import CoreText

/// Fonts. Figtree is the UI face, Quicksand the wordmark (both bundled in Resources/Fonts).
/// The final UI font is still being chosen on the Typography Lab screen; change `uiFamily`
/// here when it's decided and the whole app follows.
enum LoferFont {
    static var uiFamily = "Figtree"
    static let brandFamily = "Quicksand"

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(uiFamily, size: size).weight(weight)
    }
    static func brand(_ size: CGFloat) -> Font { .custom(brandFamily, size: size).weight(.light) }

    // Named roles so screens stay consistent (computed, so a font preview applies everywhere).
    static var greeting: Font { ui(30, .light) }          // "How is your body feeling today?"
    static var agentLine: Font { ui(19, .light) }         // Lofer's line in the information zone
    static var title: Font { ui(20, .medium) }
    static var body: Font { ui(15) }
    static var caption: Font { ui(12.5) }
    static var eyebrow: Font { ui(10.5, .medium) }        // used uppercased with tracking

    /// Registers every font file in the app bundle. Called once at launch.
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }
}

extension View {
    /// Small uppercase label above titles ("SUGGESTED CARE").
    func eyebrowStyle() -> some View {
        self.font(LoferFont.eyebrow).tracking(1.8).textCase(.uppercase).foregroundStyle(Color.loferMuted)
    }
}
