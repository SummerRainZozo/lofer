import SwiftUI

/// Primary (peach, filled) or secondary (outlined) full-width button.
struct LoferButton: View {
    let title: String
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(LoferFont.ui(15, .medium)).frame(maxWidth: .infinity).frame(height: 48)
                .foregroundStyle(primary ? Color(hex: 0x1A1210) : Color.loferCream)
                .background {
                    if primary { Capsule().fill(LinearGradient(colors: [Color(hex: 0xF6E6D8), Color(hex: 0xE4C0A6)], startPoint: .top, endPoint: .bottom)).shadow(color: .loferPeach.opacity(0.25), radius: 13) }
                    else { Capsule().fill(Color(hex: 0x3A3431).opacity(0.3)).overlay(Capsule().stroke(Color.loferLine2)) }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Small rounded choice ("Tight", "Left", "Lifting it overhead").
struct Chip: View {
    let title: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(LoferFont.ui(13)).padding(.horizontal, 13).frame(height: 34)
                .foregroundStyle(selected ? Color(hex: 0x1A1210) : Color(hex: 0xE6DBD2))
                .background(Capsule().fill(selected ? Color(hex: 0xE4C0A6) : Color(hex: 0x3A3431).opacity(0.35)))
                .overlay(Capsule().stroke(selected ? .clear : Color.loferLine2))
        }
        .buttonStyle(.plain)
    }
}

/// Larger answer button used in 2×2 grids ("Much better", "Feels fine").
struct AnswerButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(LoferFont.ui(14)).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 46).padding(.horizontal, 6)
                .foregroundStyle(Color.loferCream)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x3A3431).opacity(0.3)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.loferLine2))
        }
        .buttonStyle(.plain)
    }
}

/// Lays chips out in rows that wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 340; var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > w, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }; x += sz.width + spacing; rowH = max(rowH, sz.height) }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > b.maxX, x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz)); x += sz.width + spacing; rowH = max(rowH, sz.height) }
    }
}

/// Round icon button (back, keyboard…).
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 15, weight: .medium)).frame(width: 36, height: 36)
                .foregroundStyle(Color.loferCream).background(Circle().fill(Color(hex: 0x23201F).opacity(0.6))).overlay(Circle().stroke(Color.loferLine))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}
