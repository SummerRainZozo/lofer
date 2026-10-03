import SwiftUI

/// The agent: a peach glass sphere with a waveform running through it.
/// It breathes when idle, the waveform swells while listening/speaking, and two arcs
/// orbit while thinking. Driven by the voice agent's state.
struct VoiceOrb: View {
    var state: VoiceState
    var size: CGFloat = 300

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, sz in
                let t = tl.date.timeIntervalSinceReferenceDate
                draw(&ctx, sz, t)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Lofer. Tap to talk.")
    }

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize, _ t: Double) {
        let W = sz.width, c = CGPoint(x: W / 2, y: W / 2), R = W * 0.2
        let active = state == .listening || state == .speaking
        let energy: Double = [.idle: 0.12, .listening: 0.7, .thinking: 0.65, .speaking: 0.6][state] ?? 0.12
        let level = active ? 0.5 + 0.5 * abs(sin(t * 7.3) * sin(t * 2.1)) : 0.1
        let r = R * (1 + sin(t * 2 * .pi / 5) * (state == .idle ? 0.03 : 0.012) + energy * 0.025)
        // halo
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 2.2, y: c.y - r * 2.2, width: r * 4.4, height: r * 4.4)),
                 with: .radialGradient(Gradient(colors: [Color.loferPeach.opacity(0.16 + energy * 0.12), .clear]), center: c, startRadius: r * 0.5, endRadius: r * 2.2))
        // sphere
        let sphere = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.fill(sphere, with: .radialGradient(Gradient(stops: [.init(color: Color(hex: 0xF8E9DC), location: 0), .init(color: Color(hex: 0xE2B79C), location: 0.35),
                                                                 .init(color: Color(hex: 0x8C6553), location: 0.75), .init(color: Color(hex: 0x3E2B23), location: 1)]),
                                               center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.42), startRadius: r * 0.05, endRadius: r * 1.05))
        // drifting inner light
        var inner = ctx; inner.clip(to: sphere); inner.blendMode = .plusLighter
        let sp = t * (0.2 + energy * 0.8)
        for (i, col) in [Color(hex: 0xFFE2CC), Color(hex: 0xC49680), Color(hex: 0xBEB8CE)].enumerated() {
            let a = sp * (1 + Double(i) * 0.3) + Double(i) * 2.1
            let bc = CGPoint(x: c.x + cos(a) * r * 0.3, y: c.y + sin(a * 1.3) * r * 0.28 + r * 0.15), br = r * (0.5 + 0.1 * sin(sp * 2 + Double(i)))
            inner.fill(Path(ellipseIn: CGRect(x: bc.x - br, y: bc.y - br, width: br * 2, height: br * 2)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.12 + energy * 0.14), .clear]), center: bc, startRadius: 0, endRadius: br))
        }
        let hl = CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.5)
        ctx.fill(sphere, with: .radialGradient(Gradient(colors: [Color.white.opacity(0.5), .clear]), center: hl, startRadius: 0, endRadius: r * 0.55))
        ctx.stroke(sphere, with: .color(Color(hex: 0xFFECDC).opacity(0.3 + energy * 0.25)), lineWidth: W / 280)
        // waveform through the orb
        var wave = Path(); let amp = r * (0.05 + level * 0.32 * (active ? 1 : 0.2))
        for k in 0...200 {
            let u = Double(k) / 200, x = W * 0.06 + u * W * 0.88, xn = (x - c.x) / (r * 2.2), env = exp(-xn * xn * 2.2)
            let y = c.y + r * 0.12 + env * amp * (sin(u * 38 + t * 5) * 0.6 + sin(u * 17 - t * 3.3) * 0.4)
            k == 0 ? wave.move(to: CGPoint(x: x, y: y)) : wave.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.stroke(wave, with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0xFFF4EA).opacity(0.55 + energy * 0.3), .clear]),
                                               startPoint: CGPoint(x: W * 0.06, y: 0), endPoint: CGPoint(x: W * 0.94, y: 0)), lineWidth: W / 260)
        if state == .thinking {
            for o in [0.0, Double.pi] {
                var arc = Path(); arc.addArc(center: c, radius: r * 1.14, startAngle: .radians(t * 2.6 + o), endAngle: .radians(t * 2.6 + o + 1.1), clockwise: false)
                ctx.stroke(arc, with: .color(Color(hex: 0xFFECDC).opacity(0.65)), style: StrokeStyle(lineWidth: W / 260, lineCap: .round))
            }
        }
    }
}
