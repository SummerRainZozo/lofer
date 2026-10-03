import SwiftUI

/// CARE RECORD: what has bothered the user, what Lofer did, how it went.
/// Their own words are always kept next to each structured record.
struct BodyHistoryView: View {
    @Environment(AppModel.self) private var app
    @State private var filter: String?
    private let atlas = BodyAtlas.shared

    var body: some View {
        let all = app.memory.all
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Body history").font(LoferFont.ui(32, .light)).foregroundStyle(Color.loferCream)
                    Text("What has bothered you, what Lofer did, and how it went. Your own words are kept next to each record.")
                        .font(LoferFont.ui(14)).foregroundStyle(Color.loferMuted)
                }
                if all.isEmpty {
                    Text("Nothing here yet. Tell Lofer how your body feels and each episode will appear here.").font(LoferFont.body).foregroundStyle(Color.loferMuted)
                } else {
                    section("What Lofer has learned") {
                        ForEach(app.memory.insights().prefix(3)) { i in InsightCard(insight: i) }
                    }
                    LoferButton(title: "Share with a physiotherapist") { app.path.append(.report(nil)) }
                    section("Where it’s been") {
                        BodyMap2D(episodes: all, mesh: app.body.mesh, highlightGroup: filter) { g in filter = filter == g ? nil : g }
                        if let f = filter { Chip(title: "Showing \(atlas[f].label) ✕") { filter = nil } }
                    }
                    section("Episodes") {
                        ForEach(all.filter { filter == nil || atlas.group(of: $0.symptom.areaId) == filter }) { e in
                            Button { app.path.append(.episode(e.id)) } label: { EpisodeRow(episode: e) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(LoferBackground())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).eyebrowStyle(); c() }
    }
}

struct InsightCard: View {
    let insight: BodyMemoryStore.Insight
    @Environment(AppModel.self) private var app
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(insight.label) · \(insight.count) episode\(insight.count > 1 ? "s" : "")").font(LoferFont.ui(15, .medium)).foregroundStyle(Color.loferCream)
            let bits = [insight.topContext.flatMap { insight.topContextCount >= 2 ? "Usually after \($0) (\(insight.topContextCount) of \(insight.count))." : nil },
                        insight.best.map { "Responds best to \($0)." }, insight.trend ? "Happening more often lately." : nil,
                        insight.selfCareFailing ? "Recent sessions haven’t helped. Worth a professional opinion." : nil].compactMap { $0 }
            Text(bits.isEmpty ? "Not enough history yet to see a pattern." : bits.joined(separator: " ")).font(LoferFont.ui(13)).foregroundStyle(Color.loferMuted)
            if insight.selfCareFailing { Button("Prepare a physio summary") { app.path.append(.report(insight.group)) }.font(LoferFont.ui(13.5)).foregroundStyle(Color.loferPeach) }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(RadialGradient(colors: [Color.loferPeach.opacity(0.16), Color(hex: 0x282321).opacity(0.5)], center: .topLeading, startRadius: 0, endRadius: 300)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.loferPeach.opacity(0.22)))
    }
}

struct EpisodeRow: View {
    let episode: Episode
    var body: some View {
        let e = episode
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(BodyAtlas.shared[e.symptom.areaId].label).font(LoferFont.ui(15, .medium)).foregroundStyle(Color.loferCream)
                    if e.sample { Text("SAMPLE").font(LoferFont.ui(9.5)).tracking(1).foregroundStyle(Color.loferFaint).padding(.horizontal, 5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.loferLine2)) }
                }
                if let s = e.said.first { Text("“\(s)”").font(LoferFont.ui(13).italic()).foregroundStyle(Color(hex: 0xCFC3BA)).lineLimit(2) }
                Text([e.createdAt.formatted(date: .abbreviated, time: .shortened), SymptomParser.typeLabel(e.symptom.type),
                      e.intervention.map { "\($0.durationSec / 60) min" } ?? "Not treated",
                      ["much": "Much better", "little": "A little better", "same": "About the same", "worse": "Worse"][e.outcome.response ?? ""]].compactMap { $0 }.joined(separator: " · "))
                    .font(LoferFont.caption).foregroundStyle(Color.loferMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.loferFaint)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.loferLine).frame(height: 1) }
    }
}
