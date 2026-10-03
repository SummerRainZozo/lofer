import SwiftUI

/// SHARE WITH A PHYSIOTHERAPIST: a short factual summary. Keeps user-reported,
/// treatment, device-measured and system-generated information apart. Not a diagnosis.
struct CareSummaryView: View {
    var initialGroup: String?
    @Environment(AppModel.self) private var app
    @State private var days = 90
    @State private var group: String?

    var body: some View {
        let groups = app.memory.insights().map(\.group)
        let g = group ?? initialGroup ?? groups.first
        let report = app.memory.report(days: days, group: g)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Care summary").font(LoferFont.ui(32, .light)).foregroundStyle(Color.loferCream)
                    Text("A short, factual summary to share with a physiotherapist or other healthcare professional.").font(LoferFont.ui(14)).foregroundStyle(Color.loferMuted)
                }
                FlowLayout { ForEach([(30, "30 days"), (90, "90 days"), (3650, "All")], id: \.0) { d in Chip(title: d.1, selected: days == d.0) { days = d.0 } } }
                if groups.count > 1 { FlowLayout { ForEach(groups, id: \.self) { x in Chip(title: BodyAtlas.shared[x].label, selected: g == x) { group = x } } } }
                if let r = report {
                    SummaryDocument(report: r)
                    ShareLink(item: app.memory.reportText(r), subject: Text("Lofer care summary")) {
                        Text("Share summary").font(LoferFont.ui(15, .medium)).frame(maxWidth: .infinity).frame(height: 48)
                            .foregroundStyle(Color(hex: 0x1A1210)).background(Capsule().fill(Color(hex: 0xE4C0A6)))
                    }
                    Button("Copy as text") { UIPasteboard.general.string = app.memory.reportText(r) }.font(LoferFont.ui(13.5)).foregroundStyle(Color.loferPeach)
                } else {
                    Text("No episodes in this period.").foregroundStyle(Color.loferMuted)
                }
            }
            .padding(18)
        }
        .background(LoferBackground())
    }
}

/// The summary rendered like a printed document (cream paper, dark text).
struct SummaryDocument: View {
    let report: BodyMemoryStore.Report
    private let ink = Color(hex: 0x211816), soft = Color(hex: 0x7A655A)
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LOFER CARE SUMMARY").font(LoferFont.ui(10.5, .semibold)).tracking(1.8).foregroundStyle(soft)
            rows([("Period", report.period), ("Primary region", report.region), ("Episodes", report.episodes)])
            section("User-reported", tag: "from the user") { rows(report.userReported) }
            if !report.quotes.isEmpty { section("In their words") { ForEach(report.quotes, id: \.self) { Text("“\($0)”").font(LoferFont.ui(13.5)).foregroundStyle(ink) } } }
            section("Treatment performed", tag: "Lofer sessions") { rows(report.treatment) }
            if !report.measured.isEmpty { section("Device-measured", tag: "sensors") { rows(report.measured) } }
            if !report.observations.isEmpty { section("System-generated observations", tag: "Lofer") { ForEach(report.observations, id: \.self) { Text("• \($0)").font(LoferFont.ui(13.5)).foregroundStyle(ink) } } }
            Text(report.note).font(LoferFont.ui(12)).foregroundStyle(soft)
        }
        .padding(18).background(RoundedRectangle(cornerRadius: 22).fill(Color.loferCream))
    }
    private func rows(_ r: [(String, String)]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(r, id: \.0) { x in GridRow { Text(x.0).font(LoferFont.ui(12)).foregroundStyle(soft).frame(width: 110, alignment: .leading); Text(x.1).font(LoferFont.ui(13)).foregroundStyle(ink) } }
        }
    }
    private func section<C: View>(_ title: String, tag: String? = nil, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(ink.opacity(0.12))
            HStack { Text(title.uppercased()).font(LoferFont.ui(11.5, .semibold)).tracking(1.4).foregroundStyle(ink); Spacer(); if let tag { Text(tag).font(LoferFont.ui(11)).foregroundStyle(soft) } }
            c()
        }
    }
}
