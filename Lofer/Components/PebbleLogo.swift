import SwiftUI

/// The Lofer mark: two overlapping translucent pebbles (peach and lilac-grey).
struct PebbleLogo: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 200, size.height / 150)
            ctx.translateBy(x: (size.width - 200 * s) / 2, y: (size.height - 150 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            func pebble(cx: Double, cy: Double, rx: Double, ry: Double) -> Path {
                Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                    .applying(CGAffineTransform(rotationAngle: -17 * .pi / 180).concatenating(CGAffineTransform(translationX: cx, y: cy)))
            }
            let a = pebble(cx: 86, cy: 62, rx: 60, ry: 41), b = pebble(cx: 126, cy: 92, rx: 52, ry: 37)
            ctx.fill(a, with: .radialGradient(Gradient(stops: [.init(color: Color(hex: 0xFBF1E8), location: 0), .init(color: Color(hex: 0xEDCDB6), location: 0.45),
                                                                .init(color: Color(hex: 0xB58B74), location: 0.85), .init(color: Color(hex: 0x8E6A58), location: 1)]),
                                              center: CGPoint(x: 64, y: 40), startRadius: 0, endRadius: 90))
            var top = ctx; top.opacity = 0.72
            top.fill(b, with: .radialGradient(Gradient(stops: [.init(color: Color(hex: 0xF1EEF4), location: 0), .init(color: Color(hex: 0xC3BDD0), location: 0.5),
                                                                .init(color: Color(hex: 0x6E6A7C), location: 1)]),
                                              center: CGPoint(x: 110, y: 74), startRadius: 0, endRadius: 80))
            ctx.stroke(a, with: .color(Color(hex: 0xFFF6EE).opacity(0.35)), lineWidth: 1)
        }
        .aspectRatio(200 / 150, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Logo + wordmark + tagline, as on the brand board.
struct LoferLockup: View {
    var body: some View {
        VStack(spacing: 6) {
            PebbleLogo().frame(width: 128)
            Text("Lofer").font(LoferFont.brand(50)).foregroundStyle(Color.loferCream)
            Text("MOVE  RECOVER  LIVE BETTER").font(LoferFont.ui(9.5)).tracking(4).foregroundStyle(Color(hex: 0xCFC3BA)).padding(.top, 12)
        }
    }
}
