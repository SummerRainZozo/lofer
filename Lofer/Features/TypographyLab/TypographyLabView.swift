import SwiftUI

/// TEMPORARY development screen: the same Lofer content in each candidate font.
/// Nothing changes permanently — "Preview in app" only lasts until the app restarts.
/// When a font is chosen, set `LoferFont.uiFamily` in DesignSystem/Typography.swift.
struct TypographyLabView: View {
    @State private var preview: String?
    private let candidates: [(key: String, name: String, family: String, note: String)] = [
        ("A", "Avenir Next", "Avenir Next", "Warm, premium, human. Built into iOS."),
        ("B", "Manrope", "Manrope", "Modern, a little technological, still soft."),
        ("C", "DM Sans", "DM Sans", "Friendly, readable, approachable."),
        ("D", "Söhne → Hanken Grotesk", "Hanken Grotesk", "Söhne is a paid font. Hanken Grotesk is the closest free stand-in."),
        ("E", "Circular → Plus Jakarta Sans", "Plus Jakarta Sans", "Circular is a paid font. Plus Jakarta Sans is the closest free stand-in."),
        ("F", "Instrument Sans", "Instrument Sans", "Modern and distinctive, not aggressively technical."),
        ("·", "Figtree (current)", "Figtree", "What the app uses today, for comparison."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Typography").font(LoferFont.ui(32, .light)).foregroundStyle(Color.loferCream)
                Text("The same Lofer content in each candidate. Nothing is changed permanently.").font(LoferFont.ui(14)).foregroundStyle(Color.loferMuted)
                ForEach(candidates, id: \.key) { c in card(c) }
            }
            .padding(18)
        }
        .background(LoferBackground())
    }

    private func card(_ c: (key: String, name: String, family: String, note: String)) -> some View {
        let f = { (size: CGFloat, w: Font.Weight) in Font.custom(c.family, size: size).weight(w) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(c.key). \(c.name)").font(LoferFont.ui(12, .semibold)).tracking(1.4).textCase(.uppercase).foregroundStyle(Color.loferPeach)
                Spacer()
                Text(c.note).font(LoferFont.ui(11.5)).foregroundStyle(Color.loferFaint).multilineTextAlignment(.trailing)
            }
            Text("LOFER").font(f(11, .medium)).tracking(3.5).foregroundStyle(Color.loferMuted)
            Text("How is your body feeling today?").font(f(27, .light)).foregroundStyle(Color.loferCream)
            Text("Right shoulder").font(f(20, .medium)).foregroundStyle(Color.loferCream)
            Text("Tell me what’s been going on. You can describe it however feels natural.").font(f(14.5, .regular)).foregroundStyle(Color(hex: 0xDCD1C8))
            HStack {
                Text("Continue").font(f(15, .medium)).foregroundStyle(Color(hex: 0x1A1210)).padding(.horizontal, 22).frame(height: 44)
                    .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xF6E6D8), Color(hex: 0xE4C0A6)], startPoint: .top, endPoint: .bottom)))
                Spacer()
                Text("10 min · Gentle recovery").font(f(12.5, .regular)).foregroundStyle(Color.loferMuted)
            }
            Button(preview == c.family ? "Previewing in app · tap to undo" : "Preview in app") {
                preview = preview == c.family ? nil : c.family
                LoferFont.uiFamily = preview ?? "Figtree"
            }
            .font(LoferFont.ui(13.5)).foregroundStyle(Color.loferPeach)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x24201E).opacity(0.55))).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.loferLine))
    }
}
