import SwiftUI

/// Brand moment from the board: the logo appears, gently breathes, becomes transparent
/// and floats away with a trail of light, then the app appears. Tap to skip.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var phase = 0          // 0 hidden, 1 shown, 2 breathing, 3 floating away
    @State private var start = Date()

    private var hiddenNow: Bool { phase == 0 || phase == 3 }
    private var scale: CGFloat { [0: 0.95, 2: 1.025, 3: 1.04][phase] ?? 1 }

    var body: some View {
        ZStack {
            Color(hex: 0x0A0909).opacity(phase >= 3 ? 0 : 1).ignoresSafeArea()
                .animation(.easeOut(duration: 1.2), value: phase)
            LoferLockup()
                .scaleEffect(scale)
                .blur(radius: hiddenNow ? 10 : 0)
                .opacity(hiddenNow ? 0 : 1)
                .offset(y: phase == 3 ? -80 : -40)
                .shadow(color: Color.loferPeach.opacity(phase == 2 ? 0.35 : 0), radius: 22)
            // particle trail arcing up and away (frame 4 of the board)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in drawTrail(&ctx, size, elapsed: tl.date.timeIntervalSince(start) - 2.25) }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
        .task {
            start = Date()
            withAnimation(.timingCurve(0.22, 0.7, 0.12, 1, duration: 1.1)) { phase = 1 }
            try? await Task.sleep(for: .seconds(1.2)); withAnimation(.easeInOut(duration: 1.0)) { phase = 2 }
            try? await Task.sleep(for: .seconds(1.0)); withAnimation(.timingCurve(0.45, 0, 0.25, 1, duration: 1.3)) { phase = 3 }
            try? await Task.sleep(for: .seconds(1.3)); onFinish()
        }
    }

    private func drawTrail(_ ctx: inout GraphicsContext, _ size: CGSize, elapsed el: Double) {
        guard el > 0, el < 2.6 else { return }
        let a = CGPoint(x: size.width * 0.5, y: size.height * 0.44)
        let b = CGPoint(x: size.width * 0.45, y: size.height * 0.2)
        let c = CGPoint(x: size.width * 0.92, y: size.height * 0.12)
        for i in 0..<60 {
            let u: Double = min(1, el / 1.3) * Double(i) / 60
            let life: Double = 1 - (el - Double(i) / 60 * 1.3)
            guard life > 0 else { continue }
            let m = 1 - u
            let x: Double = m * m * a.x + 2 * m * u * b.x + u * u * c.x
            let y: Double = m * m * a.y + 2 * m * u * b.y + u * u * c.y - (1 - life) * 10
            let r: Double = (1 + Double(i % 3)) * 2.5
            let p = CGPoint(x: x, y: y)
            let glow = Gradient(colors: [Color(hex: 0xFFE8D6).opacity(life * 0.9), .clear])
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .radialGradient(glow, center: p, startRadius: 0, endRadius: r))
        }
    }
}
