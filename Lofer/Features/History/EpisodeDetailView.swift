import SwiftUI
import Charts

/// One episode: the user's words first, then the neutral structured record,
/// device readings (pressure chart) and Lofer's hedged note (never a diagnosis).
struct EpisodeDetailView: View {
    let episodeId: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        if let e = app.memory.episodes.first(where: { $0.id == episodeId }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(BodyAtlas.shared[e.symptom.areaId].label).font(LoferFont.ui(30, .light)).foregroundStyle(Color.loferCream)
                        Text(e.createdAt.formatted(date: .complete, time: .shortened) + (e.sample ? " · sample episode" : "")).font(LoferFont.ui(13.5)).foregroundStyle(Color.loferMuted)
                    }
                    if !e.said.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You said").eyebrowStyle()
                            ForEach(e.said, id: \.self) { s in
                                Text("“\(s)”").font(LoferFont.ui(14.5)).foregroundStyle(Color(hex: 0xEADFD6)).padding(.vertical, 10).padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.loferPeach.opacity(0.06)).overlay(alignment: .leading) { Rectangle().fill(Color.loferPeach).frame(width: 2) }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Structured record").eyebrowStyle()
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                            ForEach(rows(e), id: \.0) { r in
                                GridRow { Text(r.0).font(LoferFont.ui(12.5)).foregroundStyle(Color.loferMuted).frame(width: 120, alignment: .leading); Text(r.1).font(LoferFont.ui(13.5)).foregroundStyle(Color.loferCream) }
                            }
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x282321).opacity(0.55)))
                    }
                    if let log = e.intervention?.log.filter({ $0.modality != .heat }), log.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pressure over the session · device-measured").font(LoferFont.ui(13.5, .medium)).foregroundStyle(Color.loferCream)
                            Chart(log, id: \.t) { p in
                                AreaMark(x: .value("Minutes", Double(p.t) / 60), y: .value("kPa", p.pressure))
                                    .foregroundStyle(LinearGradient(colors: [Color.loferPeach.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Minutes", Double(p.t) / 60), y: .value("kPa", p.pressure)).foregroundStyle(Color.loferPeach).lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            .chartXAxisLabel("min").chartYAxisLabel("kPa").frame(height: 150)
                        }
                        .padding(14).background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x1E1A19).opacity(0.6)))
                    }
                    LoferButton(title: "Treat this area again", primary: true) { app.treatAgain(e) }
                    Button(confirmDelete ? "Tap again to delete" : "Delete this episode") {
                        if confirmDelete { app.memory.remove(e.id); dismiss() } else { confirmDelete = true }
                    }
                    .font(LoferFont.ui(13.5)).foregroundStyle(Color(hex: 0xE7A58F))
                }
                .padding(18)
            }
            .background(LoferBackground())
        }
    }

    private func rows(_ e: Episode) -> [(String, String)] {
        let resp = ["much": "Much better", "little": "A little better", "same": "About the same", "worse": "Worse"]
        var r: [(String, String)] = [("Region", BodyAtlas.shared[e.symptom.areaId].label),
                                     ("Reported symptom", SymptomParser.typeLabel(e.symptom.type) ?? "Not described"),
                                     ("Trigger / context", [e.symptom.activity.map { "After \($0)" }, e.symptom.onset.map { "started \($0)" }].compactMap { $0 }.joined(separator: ", ").ifEmpty("—"))]
        if !e.symptom.triggers.isEmpty { r.append(("Movement associated with discomfort", e.symptom.triggers.joined(separator: ", "))) }
        r.append(("Self-reported severity", e.symptom.severity.map { "\($0)/10" } ?? "Not rated"))
        if !e.symptom.flags.isEmpty { r.append(("Warning signs reported", e.symptom.flags.joined(separator: ", "))) }
        r.append(("Safety check", e.triage.level == "stop" ? "Not treated: " + e.triage.reasons.joined(separator: ", ") : e.triage.level == "caution" ? "Treated conservatively: " + e.triage.reasons.joined(separator: ", ") : "Cleared"))
        if let i = e.intervention { r.append(("Treatment", "\(i.durationSec / 60) min \(i.planName.lowercased()): " + i.steps.map { "\($0.modality.label.lowercased()) L\($0.intensity)" }.joined(separator: " → "))) }
        if let a = e.intervention?.adjustments, !a.isEmpty { r.append(("Adjustments", a.joined(separator: "; "))) }
        if !e.feedback.isEmpty { r.append(("During treatment", e.feedback.map(\.value).joined(separator: ", "))) }
        if let m = e.movement { r.append(("Movement check (\(m.name))", "\(m.before?.phrase ?? "–") before, \(m.after?.phrase ?? "not checked") after")) }
        if let resp = e.outcome.response { r.append(("Response", resp.isEmpty ? "—" : (["much": "Much better", "little": "A little better", "same": "About the same", "worse": "Worse"][resp] ?? resp))) }
        if let note = e.outcome.lofersNote { r.append(("Lofer’s note (not a diagnosis)", note)) }
        _ = resp
        return r
    }
}

extension String { func ifEmpty(_ s: String) -> String { isEmpty ? s : self } }
