import SwiftUI

/// The ACTION ZONE: the rounded glass sheet at the bottom of the care screen.
/// `solid` makes it opaque when the body has to sit behind it (not enough room).
struct BottomSheet<Content: View>: View {
    var solid = false
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Color.loferCream.opacity(0.2)).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            content
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
        .background {
            let shape = RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
            ZStack {
                if !solid { shape.fill(.ultraThinMaterial) }
                shape.fill(LinearGradient(colors: solid ? [Color(hex: 0x24201E), Color(hex: 0x141211)]
                                                        : [Color(hex: 0x2C2725).opacity(0.72), Color(hex: 0x161312).opacity(0.9)],
                                          startPoint: .top, endPoint: .bottom))
            }
            .overlay(shape.stroke(Color.loferLine2))
            .shadow(color: .black.opacity(0.4), radius: 20, y: -6)
        }
        .padding(.horizontal, 8)
    }
}

/// Uppercase label + title + optional subtitle used at the top of sheets.
struct SheetHeader: View {
    var eyebrow: String? = nil
    var title: String? = nil
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow { Text(eyebrow).eyebrowStyle() }
            if let title { Text(title).font(LoferFont.title).foregroundStyle(Color.loferCream) }
            if let sub { Text(sub).font(LoferFont.ui(13.5)).foregroundStyle(Color.loferMuted).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(.horizontal, 4)
    }
}
