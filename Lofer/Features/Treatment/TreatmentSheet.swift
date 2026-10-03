import SwiftUI

/// TREAT: calm session view — time left, what's running, active patches, check-ins.
struct TreatmentSheet: View {
    @Bindable var model: CareFlowModel
    var body: some View {
        let plan = model.validated?.plan
        let rd = model.reading
        let frac = (rd?.t ?? 0) / max(1, model.totalSeconds)
        let left = max(0, model.totalSeconds - (rd?.t ?? 0))
        SheetHeader(eyebrow: model.step == .paused ? "Paused" : "Treating · runs \(Int(CareFlowModel.previewSpeed))× faster in the preview",
                    title: plan.map { "\($0.name)" })
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.loferCream.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: frac).stroke(Color.loferPeach, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)).font(LoferFont.ui(18)).monospacedDigit().foregroundStyle(Color.loferCream)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(rd.map { "\($0.modality.label) · level \($0.level)" } ?? (plan?.steps.first?.modality.label ?? "")).font(LoferFont.ui(17)).foregroundStyle(Color.loferCream)
                FlowLayout(spacing: 5) {
                    ForEach(Array((plan?.steps ?? []).enumerated()), id: \.offset) { i, s in
                        Text("\(s.modality.short) \(s.minutes)′").font(LoferFont.ui(11.5)).padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(i == rd?.stepIndex ? Color.loferCream : Color.loferFaint)
                            .background(Capsule().fill(i == rd?.stepIndex ? Color.loferPeach.opacity(0.12) : .clear))
                            .overlay(Capsule().stroke(i == rd?.stepIndex ? Color.loferPeach.opacity(0.6) : Color.loferLine))
                    }
                }
                Text("Patches \(model.device.activePatches.joined(separator: ", ")) active · simulated device").font(LoferFont.ui(12)).foregroundStyle(Color.loferMuted)
            }
        }
        if model.checkIn {
            VStack(alignment: .leading, spacing: 8) {
                Text("How does this feel?").font(LoferFont.ui(14.5)).foregroundStyle(Color.loferCream)
                HStack { Chip(title: "Too weak") { model.feedback("too weak") }; Chip(title: "Good") { model.feedback("good") }; Chip(title: "Too strong") { model.feedback("too strong") } }
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 18).fill(Color.loferPeach.opacity(0.06))).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.loferPeach.opacity(0.3)))
        }
        if model.step == .paused && model.pausedForWorse {
            HStack(spacing: 8) {
                LoferButton(title: "Stop here") { model.endRun() }
                LoferButton(title: "Carry on gently", primary: true) { model.resumeRun(gentler: true) }
            }
        } else {
            HStack(spacing: 8) {
                LoferButton(title: model.step == .paused ? "Resume" : "Pause") { model.pauseOrResume() }
                LoferButton(title: "Stop") { model.endRun() }
            }
        }
    }
}
