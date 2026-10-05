import SwiftUI

/// "All done. How does that feel now?" — just the four answers.
struct ReassessSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        if let b = model.A.movementBefore, let a = model.A.movementAfter {
            SheetHeader(sub: "Movement check: \(b.phrase) before, \(a.phrase) now.")
        }
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow { AnswerButton(title: "Much better") { model.reassess("much") }; AnswerButton(title: "A little better") { model.reassess("little") } }
            GridRow { AnswerButton(title: "About the same") { model.reassess("same") }; AnswerButton(title: "Worse") { model.reassess("worse") } }
        }
    }
}

/// Result: "Why it might feel this way" (hedged, never a diagnosis) + what happens next.
struct OutcomeSheet: View {
    @Bindable var model: CareFlowModel
    @Environment(AppModel.self) private var app
    var body: some View {
        if let r = model.result {
            if !model.why.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why it might feel this way").eyebrowStyle()
                    Text(model.why).font(LoferFont.ui(14)).foregroundStyle(Color(hex: 0xE6DBD2)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.loferPeach.opacity(0.06))).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.loferPeach.opacity(0.16)))
            }
            if !r.body.isEmpty { Text(r.body).font(LoferFont.ui(13.5)).foregroundStyle(Color.loferMuted).padding(.horizontal, 4).fixedSize(horizontal: false, vertical: true) }
            HStack(spacing: 8) {
                LoferButton(title: "Done", primary: !r.escalate && !(r.offerRoutine && !model.routineSaved)) { app.goHome() }
                if r.escalate { LoferButton(title: "Physio summary", primary: true) { model.onOpenReport?(BodyAtlas.shared.group(of: model.A.bodyRegion ?? "body")) } }
                if r.offerRoutine && !model.routineSaved { LoferButton(title: "Save routine", primary: !r.escalate) { model.saveRoutine() } }
            }
        }
    }
}

/// Safety stop: Lofer shouldn't treat this. Explains why and what to do instead.
/// Also shows investigations that ended without care ("not enough information",
/// "better looked at by a professional").
struct StopSheet: View {
    @Bindable var model: CareFlowModel
    @Environment(AppModel.self) private var app
    var body: some View {
        if let c = model.conclusion {
            let professional = c.type == "recommendProfessionalAssessment"
            SheetHeader(eyebrow: professional ? "Worth a professional look" : "Not enough information",
                        title: professional ? "Let’s not start a session" : "Let’s not start a session yet",
                        sub: professional ? "Here’s what we checked. A GP or physiotherapist can take it from here." : "Tell me a little more, or show me where it is, and we can look again.")
            let checks = model.investigation.checks.compactMap { ck in ck.response.map { "\(ck.prompt): \($0)" } }
            if !checks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What we checked").eyebrowStyle()
                    ForEach(checks.suffix(4), id: \.self) { Text("• \($0)").font(LoferFont.ui(13)).foregroundStyle(Color.loferCream).lineLimit(2) }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x282321).opacity(0.55)))
            }
            HStack(spacing: 8) {
                if professional, let r = model.A.bodyRegion { LoferButton(title: "Summary for a professional") { model.onOpenReport?(BodyAtlas.shared.group(of: r)) } }
                LoferButton(title: "Done", primary: true) { app.goHome() }
            }
        } else if let t = model.tri {
            // Three cases: urgent help, a reported warning sign, or not enough information (deferred).
            SheetHeader(eyebrow: t.urgent ? "Get medical help" : t.deferred ? "Not enough information" : "Not one for Lofer",
                        title: t.urgent ? "Please get urgent help" : t.deferred ? "Let’s not start a session yet" : "Lofer shouldn’t treat this",
                        sub: t.guidance + (t.urgent || t.deferred ? "" : " Lofer is for everyday tightness and recovery, not for possible injuries."))
            VStack(alignment: .leading, spacing: 4) {
                Text(t.deferred ? "What’s still unclear" : "Because you mentioned").eyebrowStyle()
                ForEach(t.reasons, id: \.self) { Text("• \($0)").font(LoferFont.ui(13.5)).foregroundStyle(Color.loferCream) }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x282321).opacity(0.55)))
            HStack(spacing: 8) {
                if t.deferred { LoferButton(title: "Answer the check") { model.revisitSafety() } }
                else if let r = model.A.bodyRegion { LoferButton(title: "Summary for a professional") { model.onOpenReport?(BodyAtlas.shared.group(of: r)) } }
                LoferButton(title: "Done", primary: true) { app.goHome() }
            }
        }
    }
}
