import SwiftUI

/// The outline of the Lofer device, which is also the logo and the app icon.
///
/// The shape is one 60° "petal" repeated six times around the centre. `petal`
/// lists the distance from the centre to the edge every 3° across one petal,
/// measured from the official icon artwork (the shape is 1 unit wide).
/// The website uses the same numbers (`website/src/deviceShape.js`), so if the
/// shape ever changes, update both.
struct LoferShape: Shape {
    static let petal: [CGFloat] = [
        0.4911, 0.4640, 0.4351, 0.4180, 0.4090, 0.4034, 0.4029, 0.4065, 0.4122, 0.4213,
        0.4333, 0.4464, 0.4609, 0.4751, 0.4860, 0.4942, 0.4996, 0.5005, 0.5008, 0.5016,
    ]
    static let petals = 6

    func path(in rect: CGRect) -> Path {
        // 1. The edge points, going clockwise from 3 o'clock.
        let count = Self.petal.count * Self.petals
        let raw = (0..<count).map { i -> CGPoint in
            let angle = CGFloat(i) * (360 / CGFloat(count)) * .pi / 180
            let radius = Self.petal[i % Self.petal.count]
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }

        // 2. Scale and centre them to fit `rect`, keeping the proportions.
        let xs = raw.map(\.x), ys = raw.map(\.y)
        let width = xs.max()! - xs.min()!, height = ys.max()! - ys.min()!
        let scale = min(rect.width / width, rect.height / height)
        let midX = (xs.max()! + xs.min()!) / 2, midY = (ys.max()! + ys.min()!) / 2
        let points = raw.map { CGPoint(x: rect.midX + ($0.x - midX) * scale, y: rect.midY + ($0.y - midY) * scale) }

        // 3. A smooth curve: each point becomes the control point of a curve
        //    between the midpoints on either side of it, so there are no corners.
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: midpoint(points[count - 1], points[0]))
        for i in 0..<count {
            path.addQuadCurve(to: midpoint(points[i], points[(i + 1) % count]), control: points[i])
        }
        path.closeSubpath()
        return path
    }
}

/// The Lofer mark, filled. Defaults to the dark icon's stone colour, which
/// suits the app's dark screens.
struct LoferMark: View {
    var color: Color = Color(hex: 0xD8D3CA)

    var body: some View {
        LoferShape()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// Logo + wordmark + tagline, as on the brand board.
struct LoferLockup: View {
    var body: some View {
        VStack(spacing: 6) {
            LoferMark().frame(width: 92).padding(.bottom, 14)
            Text("Lofer").font(LoferFont.brand(50)).foregroundStyle(Color.loferCream)
            Text("MOVE  RECOVER  LIVE BETTER").font(LoferFont.ui(9.5)).tracking(4).foregroundStyle(Color(hex: 0xCFC3BA)).padding(.top, 12)
        }
    }
}
