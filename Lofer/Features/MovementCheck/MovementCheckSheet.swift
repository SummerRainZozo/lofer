import SwiftUI

/// BEFORE treatment: a clear illustrated demonstration with one instruction line that
/// follows the animation. AFTER treatment: a quick comparison (small loop + how it felt before).
struct MovementCheckSheet: View {
    @Bindable var model: CareFlowModel
    @State private var phase = "start"
    @State private var paused = false
    @State private var replayToken = 0

    var body: some View {
        if let test = model.movementTest {
            let side = model.A.laterality.flatMap { ["left", "right"].contains($0) ? $0 : nil }
            let move = test.move.replacingOccurrences(of: "{side} ", with: side.map { "\($0) " } ?? "")
            if model.movementPhase == "after" {
                HStack(spacing: 12) {
                    MovementFigure(testId: test.id).frame(width: 92, height: 92)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x14110F).opacity(0.5))).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.loferLine))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(move).font(LoferFont.ui(14.5)).foregroundStyle(Color.loferCream)
                        if let b = model.A.movementBefore {
                            Text("Before: \(b.phrase)\(b.whereInMovement.map { ", \($0)" } ?? "")").font(LoferFont.caption).foregroundStyle(Color.loferPeach)
                        }
                    }
                }
                answers
                Button("Skip") { model.skipMovementCheck() }.font(LoferFont.caption).foregroundStyle(Color.loferMuted).buttonStyle(.plain).frame(maxWidth: .infinity)
            } else {
                HStack {
                    Text(test.name).font(LoferFont.title).foregroundStyle(Color.loferCream)
                    Spacer()
                    Button(paused ? "Play" : "Pause") { paused.toggle() }.modifier(SmallPill())
                    Button("Replay") { paused = false; replayToken += 1 }.modifier(SmallPill())
                }
                MovementFigure(testId: test.id, paused: paused) { phase = $0 }
                    .id(replayToken)
                    .frame(height: 190)
                    .background(RoundedRectangle(cornerRadius: 20).fill(RadialGradient(colors: [Color.loferPeach.opacity(0.08), Color(hex: 0x14110F).opacity(0.4)], center: .center, startRadius: 0, endRadius: 200)))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.loferLine))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(["move": "Move", "hold": "Move", "return": "Return"][phase] ?? "Start").font(LoferFont.eyebrow).tracking(1.8).textCase(.uppercase).foregroundStyle(Color.loferPeach)
                    Text(["move": move, "hold": move, "return": test.back][phase] ?? test.start).font(LoferFont.ui(14)).foregroundStyle(Color.loferCream)
                }
                .frame(minHeight: 38, alignment: .top)
                Text("Move only as far as feels comfortable. How does it feel?").font(LoferFont.ui(13)).foregroundStyle(Color.loferMuted)
                answers
                Button("Skip this check") { model.skipMovementCheck() }.font(LoferFont.caption).foregroundStyle(Color.loferMuted).buttonStyle(.plain).frame(maxWidth: .infinity)
            }
        }
    }
    private var answers: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow { AnswerButton(title: "Feels fine") { model.movementAnswer(.init(feel: .fine)) }; AnswerButton(title: "A little uncomfortable") { model.movementAnswer(.init(feel: .little)) } }
            GridRow { AnswerButton(title: "Quite uncomfortable") { model.movementAnswer(.init(feel: .quite)) }; AnswerButton(title: "Can’t do it comfortably") { model.movementAnswer(.init(feel: .cannot)) } }
        }
    }
}

struct SmallPill: ViewModifier {
    func body(content: Content) -> some View {
        content.font(LoferFont.ui(12)).foregroundStyle(Color.loferMuted).padding(.horizontal, 11).padding(.vertical, 5)
            .overlay(Capsule().stroke(Color.loferLine2)).buttonStyle(.plain)
    }
}
