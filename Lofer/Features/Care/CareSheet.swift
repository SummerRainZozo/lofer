import SwiftUI

/// Picks the sheet for the current step. Each feature folder owns its own sheets.
struct CareSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        switch model.step {
        case .locate, .listening: LocateSheet(model: model)
        case .clarify: ClarifySheet(model: model)
        case .confirm: ConfirmSheet(model: model)
        case .correct: CorrectSheet(model: model)
        case .movement: MovementCheckSheet(model: model)
        case .suggest: SuggestionSheet(model: model)
        case .custom: CustomiseSheet(model: model)
        case .treat, .paused: TreatmentSheet(model: model)
        case .reassess: ReassessSheet(model: model)
        case .outcome: OutcomeSheet(model: model)
        case .stop: StopSheet(model: model)
        }
    }
}

/// Choosing the place on the body (touch or voice).
struct LocateSheet: View {
    @Bindable var model: CareFlowModel
    private let atlas = BodyAtlas.shared
    var body: some View {
        if let ps = model.pendingSide {
            FlowLayout {
                if ps.both { Chip(title: "Both") { model.confirmBoth(ps.template) } }
                Chip(title: "Left") { model.chooseSide(.left) }
                Chip(title: "Right") { model.chooseSide(.right) }
            }
        } else if let s = model.sel {
            // A spot is selected: one clear control to move it (+ tap anywhere on the body).
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(atlas[s.id].label).font(LoferFont.ui(18, .medium)).foregroundStyle(Color.loferCream)
                    Text("Tap the body, or use the arrows").font(LoferFont.caption).foregroundStyle(Color.loferMuted)
                }
                Spacer()
                SpotPad(model: model)
            }
            .padding(.horizontal, 4)
            LoferButton(title: "That’s the spot", primary: true) { model.confirmSpot() }
        } else if let c = model.cand {
            SheetHeader(title: atlas[c].label)
            HStack(spacing: 8) {
                LoferButton(title: "Whole \(atlas[c].shortName.lowercased())") { model.confirmArea(c) }
                LoferButton(title: "Zoom in", primary: true) { model.zoomIn(c) }
            }
        } else if model.focus == "body" {
            SheetHeader(sub: "Tap the body, or just tell me. Drag to turn it.")
        } else {
            SheetHeader(title: atlas[model.focus].label)
            FlowLayout {
                ForEach(atlas[model.focus].children.filter { model.body.mesh?.hasArea($0) ?? true }, id: \.self) { id in
                    Chip(title: atlas[id].shortName) { model.pickChild(id) }
                }
            }
            LoferButton(title: "Whole \(atlas[model.focus].shortName.lowercased())") { model.confirmArea(model.focus) }
        }
    }
}

/// ↑ ↓ ← → in screen directions, so the spot moves the way the user sees it.
struct SpotPad: View {
    let model: CareFlowModel
    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow { Color.clear.frame(width: 40, height: 40); arrow("chevron.up", 0, 1, "Move up"); Color.clear.frame(width: 40, height: 40) }
            GridRow { arrow("chevron.left", -1, 0, "Move left"); Circle().fill(Color.loferPeach).frame(width: 10, height: 10).shadow(color: .loferPeach, radius: 5).frame(width: 40, height: 40); arrow("chevron.right", 1, 0, "Move right") }
            GridRow { Color.clear.frame(width: 40, height: 40); arrow("chevron.down", 0, -1, "Move down"); Color.clear.frame(width: 40, height: 40) }
        }
    }
    private func arrow(_ icon: String, _ dx: Float, _ dy: Float, _ label: String) -> some View {
        Button { model.nudge(dx: dx, dy: dy) } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).foregroundStyle(Color.loferCream)
                .background(Circle().fill(Color(hex: 0x3A3431).opacity(0.4))).overlay(Circle().stroke(Color.loferLine2))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// One question at a time. The question is Lofer's line (top); here are quick answers.
struct ClarifySheet: View {
    @Bindable var model: CareFlowModel
    @State private var picked: Set<String> = []
    var body: some View {
        if let q = model.question {
            if q.field == "story" {
                SheetHeader(sub: "Talk or type, however feels natural. Or start with how it feels:")
                FlowLayout { ForEach([("Tight", "tightness"), ("Sore", "soreness"), ("Achy", "ache"), ("Sharp", "sharp")], id: \.1) { o in Chip(title: o.0) { model.answerChip("sensation", o.1) } } }
            } else if q.multi {
                // The safety check. "None of these" is a "no"; "Not sure" and "Skip" are kept separate
                // and never count as a "no". Continue needs at least one sign picked.
                FlowLayout { ForEach(q.options, id: \.1) { o in Chip(title: o.0, selected: picked.contains(o.1)) { if picked.contains(o.1) { picked.remove(o.1) } else { picked.insert(o.1) } } } }
                HStack(spacing: 8) {
                    LoferButton(title: "None of these") { model.answerSafety([]) }
                    LoferButton(title: "Continue", primary: true) { model.answerSafety(Array(picked)) }
                        .disabled(picked.isEmpty).opacity(picked.isEmpty ? 0.45 : 1)
                }
                HStack(spacing: 8) {
                    Button("Not sure") { model.answerSafetyUnsure() }.modifier(SmallPill())
                    Button("Skip") { model.skipSafety() }.modifier(SmallPill())
                }
                .frame(maxWidth: .infinity)
            } else {
                FlowLayout { ForEach(q.options, id: \.1) { o in Chip(title: o.0) { model.answerChip(q.field, o.1) } } }
            }
        }
    }
}

/// The summary is Lofer's line (top). The sheet only holds the answer, so the body stays visible.
struct ConfirmSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        SheetHeader(sub: "Tap the body to move the spot.")
        HStack(spacing: 8) {
            LoferButton(title: "Not quite") { model.correction() }
            LoferButton(title: "Yes, that’s right", primary: true) { model.confirmYes() }
        }
    }
}

struct CorrectSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        FlowLayout {
            Chip(title: "The place") { model.correct("place") }
            Chip(title: "How it feels") { model.correct("feel") }
            Chip(title: "When it started") { model.correct("when") }
            Chip(title: "What brings it on") { model.correct("trigger") }
        }
        LoferButton(title: "Back to summary") { model.backToSummary() }
    }
}
