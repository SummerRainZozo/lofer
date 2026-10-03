import SwiftUI

/// SUGGEST: name, length, one-line reason, then Customise / Start session.
struct SuggestionSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        if let v = model.validated?.plan, let p = model.plan {
            SheetHeader(eyebrow: "Suggested care", title: v.name)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(v.minutes) minutes · \(v.levelText)\(v.steps.contains { $0.modality == .heat } ? " · with warmth" : "")").font(LoferFont.ui(13)).foregroundStyle(Color.loferMuted)
                Text(p.reason ?? "Shaped around what you’ve told me.").font(LoferFont.ui(14)).foregroundStyle(Color(hex: 0xE6DBD2)).padding(.top, 4)
                let notes = ([model.tri?.level == .caution ? "Kept gentle to be safe." : nil] + (model.validated?.notes ?? []).map { Optional($0) }).compactMap { $0 }
                if !notes.isEmpty { Text(notes.joined(separator: " ")).font(LoferFont.ui(12)).foregroundStyle(Color.loferFaint) }
            }
            .padding(.horizontal, 4)
            if let other = model.options.first(where: { $0.name != p.name }) {
                Button("Or: \(other.name)") { model.pick(other); model.say(other.reason ?? other.name) }.modifier(SmallPill())
            }
            HStack(spacing: 8) {
                LoferButton(title: "Customise") { model.openCustomise() }
                LoferButton(title: "Start session", primary: true) { model.startTreatment() }
            }
        }
    }
}

/// Change modalities, minutes and levels. The safety layer still validates everything.
struct CustomiseSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        if let p = model.plan {
            SheetHeader(eyebrow: "Customise", title: "\(model.validated?.plan.minutes ?? p.minutes) min · \(model.validated?.plan.sequenceText ?? p.sequenceText)")
            ForEach(Modality.allCases, id: \.self) { m in
                let step = p.steps.first { $0.modality == m }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(m.label, isOn: Binding(get: { step != nil }, set: { _ in model.toggle(m) })).font(LoferFont.ui(14.5)).tint(Color(hex: 0xD9AE92))
                    if let s = step {
                        HStack(spacing: 14) {
                            Stepper("\(s.minutes) min", onIncrement: { model.adjust(m, minutes: s.minutes + 1) }, onDecrement: { model.adjust(m, minutes: s.minutes - 1) })
                            Stepper("Level \(s.intensity)", onIncrement: { model.adjust(m, intensity: s.intensity + 1) }, onDecrement: { model.adjust(m, intensity: s.intensity - 1) })
                        }
                        .font(LoferFont.ui(13)).foregroundStyle(Color.loferMuted)
                    }
                }
            }
            if let notes = model.validated?.notes, !notes.isEmpty { Text(notes.joined(separator: " ")).font(LoferFont.ui(12)).foregroundStyle(Color.loferWarning) }
            HStack(spacing: 8) {
                LoferButton(title: "Done") { model.closeCustomise() }
                LoferButton(title: "Start", primary: true) { model.startTreatment() }
            }
        }
    }
}
