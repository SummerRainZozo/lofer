import SwiftUI

/// Illustrated, looping movement demonstration: START → MOVE → RETURN → PAUSE, with
/// ghosted start/end poses, a direction arrow, a motion trail and the area to notice glowing.
/// Drawn in a 240×220 box and scaled to fit. (Ported from the prototype's movement.js.)
struct MovementFigure: View {
    let testId: String
    var paused = false
    var onPhase: ((String) -> Void)? = nil
    @State private var t0 = Date()
    @State private var pausedAt: Date?
    @State private var lastPhase = ""

    static let cycle: [(String, Double)] = [("start", 1.2), ("move", 2.4), ("hold", 0.8), ("return", 2.4), ("pause", 0.8)]

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let (k, phase) = Self.progress(at: (pausedAt ?? tl.date).timeIntervalSince(t0))
            Canvas { ctx, size in
                let s = min(size.width / 240, size.height / 220)
                ctx.translateBy(x: (size.width - 240 * s) / 2, y: (size.height - 220 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                draw(&ctx, k: k, phase: phase)
            }
            .onChange(of: phase) { _, p in onPhase?(p) }
        }
        .onChange(of: paused) { _, p in if p { pausedAt = Date() } else if let pa = pausedAt { t0 = t0.addingTimeInterval(Date().timeIntervalSince(pa)); pausedAt = nil } }
        .accessibilityLabel("Movement demonstration")
    }

    static func progress(at elapsed: Double) -> (Double, String) {
        let total = cycle.reduce(0) { $0 + $1.1 }
        var c = elapsed.truncatingRemainder(dividingBy: total)
        for (name, dur) in cycle {
            if c < dur {
                let u = c / dur, e = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
                switch name { case "move": return (e, name); case "hold": return (1, name); case "return": return (1 - e, name); default: return (0, name) }
            }
            c -= dur
        }
        return (0, "start")
    }

    // MARK: drawing
    private let skinA = Color(hex: 0xF1D6C3), skinB = Color(hex: 0xC79A80)
    private func draw(_ ctx: inout GraphicsContext, k: Double, phase: String) {
        ctx.stroke(Path { $0.move(to: CGPoint(x: 10, y: 206)); $0.addLine(to: CGPoint(x: 230, y: 206)) }, with: .color(.loferCream.opacity(0.12)), lineWidth: 2)
        let pose0 = Self.pose(testId, 0), pose1 = Self.pose(testId, 1), now = Self.pose(testId, k)
        for p in now.parts where p.prop { fill(&ctx, p, style: .prop) }
        for p in pose0.parts + pose1.parts where !p.prop { fill(&ctx, p, style: .ghost) }
        // Direction arrow along the path of the moving point
        var arrow = Path(); let pts = (0...14).map { Self.pose(testId, Double($0) / 14).effector }
        arrow.addLines(pts)
        ctx.stroke(arrow, with: .color(.loferPeach.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
        let tip = phase == "return" ? pts[0] : pts[14], prev = phase == "return" ? pts[1] : pts[13]
        drawArrowHead(&ctx, from: prev, to: tip)
        for p in now.parts where !p.prop { fill(&ctx, p, style: .solid) }
        // Glow on the area to notice, and a short motion trail
        let g = now.glow
        ctx.fill(Path(ellipseIn: CGRect(x: g.0.x - g.1, y: g.0.y - g.1, width: g.1 * 2, height: g.1 * 2)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE9D8).opacity(0.95), Color.loferPeach.opacity(0.45), Color.loferPeach.opacity(0)]), center: g.0, startRadius: 0, endRadius: g.1))
        if phase == "move" || phase == "return" {
            for i in 1...3 {
                let kk = phase == "move" ? max(0, k - Double(i) * 0.07) : min(1, k + Double(i) * 0.07)
                let e = Self.pose(testId, kk).effector, r = 3.5 - Double(i) * 0.7
                ctx.fill(Path(ellipseIn: CGRect(x: e.x - r, y: e.y - r, width: r * 2, height: r * 2)), with: .color(.loferPeach.opacity(0.45 - Double(i) * 0.12)))
            }
        }
        if let label = now.label { ctx.draw(Text(label.0).font(.system(size: 9)).foregroundColor(Color(hex: 0xCFC3BA)), at: label.1) }
    }
    private enum Style { case solid, ghost, prop }
    private func fill(_ ctx: inout GraphicsContext, _ p: Part, style: Style) {
        switch style {
        case .prop:
            ctx.fill(p.path, with: .color(.loferCream.opacity(0.10))); ctx.stroke(p.path, with: .color(.loferCream.opacity(0.22)), lineWidth: 1.5)
        case .ghost:
            ctx.stroke(p.path, with: .color(.loferCream.opacity(0.28)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        case .solid:
            if p.line { ctx.stroke(p.path, with: .color(Color(hex: 0x785040).opacity(0.6)), lineWidth: 1) ; return }
            let b = p.path.boundingRect
            ctx.fill(p.path, with: .linearGradient(Gradient(colors: [skinA, skinB]), startPoint: b.origin, endPoint: CGPoint(x: b.maxX, y: b.maxY)))
            ctx.stroke(p.path, with: .color(Color(hex: 0xFFF0E6).opacity(0.35)), lineWidth: 1)
            if let eye = p.eye { ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 1.6, y: eye.y - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: 0x5A3F33))) }
        }
    }
    private func drawArrowHead(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint) {
        let ang = atan2(b.y - a.y, b.x - a.x)
        var p = Path(); p.move(to: b)
        p.addLine(to: CGPoint(x: b.x - 7 * cos(ang - 0.45), y: b.y - 7 * sin(ang - 0.45)))
        p.addLine(to: CGPoint(x: b.x - 7 * cos(ang + 0.45), y: b.y - 7 * sin(ang + 0.45))); p.closeSubpath()
        ctx.fill(p, with: .color(.loferPeach))
    }

    // MARK: poses
    struct Part { var path: Path; var prop = false; var line = false; var eye: CGPoint? = nil }
    struct Pose { var parts: [Part]; var effector: CGPoint; var glow: (CGPoint, CGFloat); var label: (String, CGPoint)? = nil }
    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    /// 0° = straight down, 90° = forward (right), 180° = up
    private static func at(_ p: CGPoint, _ len: Double, _ deg: Double) -> CGPoint { CGPoint(x: p.x + sin(rad(deg)) * len, y: p.y + cos(rad(deg)) * len) }
    private static func capsule(_ a: CGPoint, _ b: CGPoint, _ ra: Double, _ rb: Double) -> Part {
        let ang = atan2(b.y - a.y, b.x - a.x), n = ang + .pi / 2, c = cos(n), s = sin(n)
        var p = Path()
        p.move(to: CGPoint(x: a.x + c * ra, y: a.y + s * ra)); p.addLine(to: CGPoint(x: b.x + c * rb, y: b.y + s * rb))
        p.addArc(center: b, radius: rb, startAngle: .radians(n), endAngle: .radians(n + .pi), clockwise: true)
        p.addLine(to: CGPoint(x: a.x - c * ra, y: a.y - s * ra))
        p.addArc(center: a, radius: ra, startAngle: .radians(n + .pi), endAngle: .radians(n), clockwise: true)
        p.closeSubpath()
        return Part(path: p)
    }
    private static func circle(_ c: CGPoint, _ r: Double, eye: Bool = false) -> Part {
        Part(path: Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), eye: eye ? CGPoint(x: c.x + 8, y: c.y - 3) : nil)
    }
    private static func prop(_ r: CGRect) -> Part { Part(path: Path(roundedRect: r, cornerRadius: 3), prop: true) }

    /// Side-view standing figure facing right.
    private static func standing(arm: Double = 0, trunk: Double = 0, knee: Double = 0, heel: Double = 0, handOn: (CGPoint, CGPoint)? = nil) -> (parts: [Part], hand: CGPoint, shoulder: CGPoint, hip: CGPoint, knee: CGPoint, ankle: CGPoint) {
        let ground = 204.0, toe = CGPoint(x: 128, y: ground), ankle = CGPoint(x: 114, y: ground - 6 - heel)
        let kneeP = at(ankle, 48, 180 - knee * 0.45), hip = at(kneeP, 50, 180 + knee * 0.55)
        let shoulder = at(hip, 56, 180 - trunk), neck = at(shoulder, 10, 180 - trunk * 0.9), head = at(neck, 15, 180 - trunk * 0.8)
        let elbow = handOn?.0 ?? at(shoulder, 30, arm + trunk * 0.15), hand = handOn?.1 ?? at(elbow, 28, arm + trunk * 0.15)
        let parts = [capsule(CGPoint(x: ankle.x - 8, y: ankle.y + 2), CGPoint(x: toe.x, y: ground - 2), 5, 4),
                     capsule(ankle, kneeP, 6, 8), capsule(kneeP, hip, 8, 12), capsule(hip, shoulder, 15, 17), capsule(shoulder, neck, 6, 6),
                     circle(head, 13, eye: true), capsule(shoulder, elbow, 6.5, 5.5), capsule(elbow, hand, 5.5, 4.5), circle(hand, 5.5)]
        return (parts, hand, shoulder, hip, kneeP, ankle)
    }
    static func pose(_ id: String, _ k: Double) -> Pose {
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        switch id {
        case "forward_reach":
            let trunk = lerp(0, 52), base = standing(trunk: trunk)
            let tgt = CGPoint(x: lerp(base.hip.x + 10, base.knee.x + 8), y: lerp(base.hip.y + 8, base.knee.y - 4))
            let elbow = CGPoint(x: (base.shoulder.x + tgt.x) / 2 + 6, y: (base.shoulder.y + tgt.y) / 2)
            let f = standing(trunk: trunk, handOn: (elbow, tgt))
            return Pose(parts: f.parts, effector: tgt, glow: (CGPoint(x: f.hip.x - 6, y: f.hip.y - 22), 16))
        case "heel_raise":
            let heel = lerp(0, 13), f0 = standing(heel: heel)
            let f = standing(heel: heel, handOn: (CGPoint(x: f0.shoulder.x + 22, y: f0.shoulder.y + 14), CGPoint(x: 196, y: f0.shoulder.y + 2)))
            return Pose(parts: [prop(CGRect(x: 200, y: 20, width: 10, height: 186))] + f.parts, effector: CGPoint(x: f.ankle.x - 8, y: f.ankle.y + 2), glow: (CGPoint(x: f.ankle.x - 2, y: f.ankle.y - 22), 13))
        case "mini_squat":
            let knee = lerp(0, 62), trunk = lerp(0, 18), f0 = standing(trunk: trunk, knee: knee)
            let grip = CGPoint(x: f0.shoulder.x + 46, y: 104 + k * 2)
            let f = standing(trunk: trunk, knee: knee, handOn: (CGPoint(x: (f0.shoulder.x + grip.x) / 2, y: f0.shoulder.y + 16), grip))
            var chair = Path(); chair.move(to: CGPoint(x: 172, y: 98)); chair.addLine(to: CGPoint(x: 182, y: 204)); chair.move(to: CGPoint(x: 172, y: 98)); chair.addLine(to: CGPoint(x: 212, y: 98))
            chair.move(to: CGPoint(x: 206, y: 98)); chair.addLine(to: CGPoint(x: 210, y: 204)); chair.move(to: CGPoint(x: 178, y: 150)); chair.addLine(to: CGPoint(x: 210, y: 150))
            return Pose(parts: [Part(path: chair, prop: true)] + f.parts, effector: f.hip, glow: (f.knee, 13))
        case "head_turn":
            let turn = sin(k * .pi) * 0.9, x = 120.0, y = 74.0, r = 22.0 * (1 - abs(turn) * 0.12)
            var face = Part(path: Path(ellipseIn: CGRect(x: x - r, y: y - 25, width: r * 2, height: 50)))
            face.eye = CGPoint(x: x + turn * 12 + 6, y: y - 3)
            let parts = [capsule(CGPoint(x: 120, y: 214), CGPoint(x: 120, y: 136), 34, 30), capsule(CGPoint(x: 86, y: 128), CGPoint(x: 154, y: 128), 11, 11),
                         capsule(CGPoint(x: 120, y: 126), CGPoint(x: 120, y: 98), 9, 9), face, circle(CGPoint(x: x + turn * 12 - 6, y: y - 3), 0.1)]
            return Pose(parts: parts, effector: CGPoint(x: x + turn * 22, y: 44), glow: (CGPoint(x: 120, y: 102), 14))
        case "wrist_lift":
            let tableY = 140.0, edge = 168.0, shoulder = CGPoint(x: 44, y: 78), elbow = CGPoint(x: 74, y: tableY - 8), wrist = CGPoint(x: edge - 2, y: tableY - 8)
            let ang = rad(lerp(18, -40)), dir = CGPoint(x: cos(ang), y: sin(ang)), perp = CGPoint(x: -dir.y, y: dir.x)
            func P(_ u: Double, _ v: Double) -> CGPoint { CGPoint(x: wrist.x + dir.x * u + perp.x * v, y: wrist.y + dir.y * u + perp.y * v) }
            var hand = Path(); hand.move(to: P(0, -8)); hand.addLine(to: P(30, -10)); hand.addQuadCurve(to: P(56, -3), control: P(52, -10))
            hand.addQuadCurve(to: P(48, 8), control: P(57, 6)); hand.addLine(to: P(8, 9)); hand.closeSubpath()
            var thumb = Path(); thumb.move(to: P(10, 9)); thumb.addQuadCurve(to: P(30, 11), control: P(22, 15))
            let parts = [prop(CGRect(x: 60, y: tableY, width: edge - 60, height: 10)), prop(CGRect(x: 74, y: tableY + 10, width: 7, height: 56)), prop(CGRect(x: 10, y: 150, width: 44, height: 8)),
                         capsule(CGPoint(x: 36, y: 150), shoulder, 16, 18), circle(CGPoint(x: 48, y: 50), 14, eye: true),
                         capsule(shoulder, elbow, 8, 7), capsule(elbow, wrist, 8, 6.5), Part(path: hand), Part(path: thumb, line: true)]
            return Pose(parts: parts, effector: P(54, 0), glow: (wrist, 12), label: k < 0.05 ? ("palm faces down", P(26, 26)) : nil)
        default: // arm_raise
            let f = standing(arm: lerp(4, 165))
            return Pose(parts: f.parts, effector: f.hand, glow: (f.shoulder, 15))
        }
    }
}
