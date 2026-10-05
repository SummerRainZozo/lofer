import Foundation
import Observation

/// BODY MEMORY — every episode, stored on this device (UserDefaults as JSON for now;
/// SwiftData or a synced backend can replace it later without touching the screens).
@Observable
final class BodyMemoryStore {
    private(set) var episodes: [Episode] = []
    private(set) var routines: [String: SavedRoutine] = [:]
    private(set) var profile = UserProfile()
    /// Sample episodes appear in History (marked "Sample") but never inform real decisions:
    /// suggestions, check-in timing, recurrence or paused care. Only the explicit demo modes
    /// (-LoferDemo / -LoferDemoFull, set in AppModel) turn this on.
    @ObservationIgnored var samplesInformDecisions = false
    @ObservationIgnored private let defaults: UserDefaults
    private let kEpisodes = "lofer.memory.v1", kRoutines = "lofer.routines.v1", kProfile = "lofer.profile.v1"
    private let atlas = BodyAtlas.shared

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        episodes = load([Episode].self, kEpisodes) ?? BodyMemoryStore.seed()
        routines = load([String: SavedRoutine].self, kRoutines) ?? [:]
        profile = load(UserProfile.self, kProfile) ?? UserProfile()
        save()
    }
    private func load<T: Decodable>(_ t: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    private func save() {
        if let d = try? JSONEncoder().encode(episodes) { defaults.set(d, forKey: kEpisodes) }
        if let d = try? JSONEncoder().encode(routines) { defaults.set(d, forKey: kRoutines) }
        if let d = try? JSONEncoder().encode(profile) { defaults.set(d, forKey: kProfile) }
    }

    // MARK: episodes
    var all: [Episode] { episodes.sorted { $0.createdAt > $1.createdAt } }
    /// Saves an episode. Saving the same episode again (same id) updates it, so a double tap
    /// or a later safety stop never creates a duplicate.
    func add(_ e: Episode) {
        if let i = episodes.firstIndex(where: { $0.id == e.id }) { episodes[i] = e } else { episodes.append(e) }
        save()
    }
    func remove(_ id: String) { episodes.removeAll { $0.id == id }; save() }
    func clear() { episodes = []; save() }
    func restoreSamples() { episodes = episodes.filter { !$0.sample } + BodyMemoryStore.seed(); save() }
    /// Episodes that may inform decisions (real ones; samples only in demo mode).
    private var decisionEpisodes: [Episode] { all.filter { samplesInformDecisions || !$0.sample } }
    /// Earlier treated episodes for the same joint/segment, newest first.
    func history(for areaId: String) -> [Episode] {
        let g = atlas.group(of: areaId)
        return decisionEpisodes.filter { $0.intervention != nil && atlas.group(of: $0.symptom.areaId) == g }
    }
    /// A few earlier sessions worth sending to Care Intelligence (never the whole history).
    /// V1 relevance: same joint/segment, or the same activity in the last 30 days; within
    /// 90 days; at most 3, most relevant first. Samples only count in demo mode.
    func relevantMemory(for areaId: String?, activity: String?, now: Date = Date(), limit: Int = 3) -> [MemorySummary] {
        let day = 86400.0
        let group = areaId.map { atlas.group(of: $0) }
        func score(_ e: Episode) -> Int {
            let age = now.timeIntervalSince(e.createdAt)
            guard age < 90 * day else { return 0 }
            let sameArea = group != nil && atlas.group(of: e.symptom.areaId) == group
            let sameActivity = activity != nil && e.symptom.activity == activity
            guard sameArea || (sameActivity && age < 30 * day) else { return 0 }
            return (sameArea ? 3 : 0) + (sameActivity ? 2 : 0) + (age < 30 * day ? 1 : 0)
        }
        let ranked: [(episode: Episode, score: Int)] = decisionEpisodes.map { ($0, score($0)) }.filter { $0.score > 0 }
        let sorted = ranked.sorted { a, b in a.score != b.score ? a.score > b.score : a.episode.createdAt > b.episode.createdAt }
        return sorted.prefix(limit).map { summary($0.episode) }
    }
    private func summary(_ e: Episode) -> MemorySummary {
        let movement: String? = e.movement.map { m in "\(m.name): \(m.before?.phrase ?? "–") → \(m.after?.phrase ?? "–")" }
        let intervention: String? = e.intervention.map { i in "\(i.planName), \(i.minutesPlanned) min" }
        return MemorySummary(date: e.createdAt, area: atlas[e.symptom.areaId].label, activity: e.symptom.activity, sensation: e.symptom.type,
                             movement: movement, intervention: intervention, response: e.outcome.response,
                             pausedAutomaticCare: e.outcome.pausesAutomaticCare == true)
    }

    /// The episode that paused automatic sessions for this joint/segment, if any.
    /// There is no automatic expiry yet (an open policy question); clearing Body Memory removes it.
    func automaticCarePause(for areaId: String) -> Episode? {
        let g = atlas.group(of: areaId)
        return decisionEpisodes.first { $0.outcome.pausesAutomaticCare == true && atlas.group(of: $0.symptom.areaId) == g }
    }

    // MARK: routines + profile
    func routine(for areaId: String, activity: String?) -> SavedRoutine? {
        let g = atlas.group(of: areaId)
        return routines["\(g)|\(activity ?? "")"] ?? routines["\(g)|"]
    }
    func saveRoutine(areaId: String, activity: String?, name: String, steps: [TreatmentStep]) {
        routines["\(atlas.group(of: areaId))|\(activity ?? "")"] = SavedRoutine(name: name, steps: steps, savedAt: Date()); save()
    }
    func removeRoutine(_ key: String) { routines[key] = nil; save() }
    func updateProfile(_ change: (inout UserProfile) -> Void) { change(&profile); save() }

    // MARK: "what tends to bother this user, when, and what helps?"
    struct Insight: Identifiable { var id: String { group }; var group: String; var label: String; var count: Int; var topContext: String?; var topContextCount: Int; var best: String?; var trend: Bool; var selfCareFailing: Bool }
    func insights(now: Date = Date()) -> [Insight] {
        let day = 86400.0
        let grouped = Dictionary(grouping: all) { atlas.group(of: $0.symptom.areaId) }
        return grouped.map { g, list in
            var ctx: [String: Int] = [:]; list.compactMap(\.symptom.activity).forEach { ctx[$0, default: 0] += 1 }
            let top = ctx.max { $0.value < $1.value }
            var seq: [String: Int] = [:]
            for e in list where ["much", "little"].contains(e.outcome.response ?? "") {
                if let st = e.intervention?.steps { seq[st.map { $0.modality.label.lowercased() }.joined(separator: " then "), default: 0] += 1 }
            }
            let last30 = list.filter { now.timeIntervalSince($0.createdAt) < 30 * day }.count
            let prev30 = list.filter { let a = now.timeIntervalSince($0.createdAt); return a >= 30 * day && a < 60 * day }.count
            let lastTwo = list.prefix(2).map { $0.outcome.response ?? "" }
            return Insight(group: g, label: atlas[g].label, count: list.count, topContext: top?.key, topContextCount: top?.value ?? 0,
                           best: seq.max { $0.value < $1.value }?.key, trend: last30 > prev30 && prev30 > 0,
                           selfCareFailing: (lastTwo.count == 2 && lastTwo.allSatisfy { $0 == "same" || $0 == "worse" }) || lastTwo.first == "worse")
        }.sorted { $0.count > $1.count }
    }

    // MARK: physiotherapist summary (keeps sources apart, makes no diagnosis)
    struct Report {
        var period: String; var region: String; var episodes: String
        var userReported: [(String, String)]; var quotes: [String]
        var treatment: [(String, String)]; var measured: [(String, String)]; var observations: [String]
        let note = "Generated by Lofer from the user’s own reports and device logs. It is not a diagnosis."
    }
    func report(days: Int = 90, group: String? = nil, now: Date = Date()) -> Report? {
        let list = all.filter { now.timeIntervalSince($0.createdAt) < Double(days) * 86400 && (group == nil || atlas.group(of: $0.symptom.areaId) == group) }
        guard !list.isEmpty else { return nil }
        var counts: [String: Int] = [:]; list.forEach { counts[atlas.group(of: $0.symptom.areaId), default: 0] += 1 }
        let primary = group ?? counts.max { $0.value < $1.value }!.key
        let eps = Array(list.filter { atlas.group(of: $0.symptom.areaId) == primary }.reversed())   // oldest first
        let df = DateFormatter(); df.dateFormat = "d MMM"
        var ctx: [String: Int] = [:]; eps.compactMap(\.symptom.activity).forEach { ctx[$0, default: 0] += 1 }
        let topCtx = ctx.max { $0.value < $1.value }
        let types = Array(Set(eps.map { (SymptomParser.typeLabel($0.symptom.type) ?? "Discomfort").lowercased() })).sorted()
        let trig = Array(Set(eps.flatMap(\.symptom.triggers))).sorted()
        let resp = ["much": "clear improvement", "little": "some improvement", "same": "no change", "worse": "worse"]
        let checks = eps.compactMap { e in e.movement.map { m in "\(m.name): \(m.before?.phrase ?? "–") → \(m.after?.phrase ?? "–")" } }
        let sens = eps.compactMap(\.outcome.sensors)
        let mins = eps.reduce(0) { $0 + ($1.intervention?.durationSec ?? 0) } / 60
        var kinds: [String: Int] = [:]; eps.compactMap { $0.intervention?.planName }.forEach { kinds[$0, default: 0] += 1 }
        let mods = Array(Set(eps.flatMap { ($0.intervention?.steps ?? []).map { $0.modality.label.lowercased() } })).sorted()
        var obs: [String] = []
        if eps.count >= 2 { obs.append("\(eps.count) episodes for this area between \(df.string(from: eps.first!.createdAt)) and \(df.string(from: eps.last!.createdAt)).") }
        if let t = topCtx, t.value >= 2 { obs.append("\(t.value) of \(eps.count) episodes were reported after \(t.key).") }
        let lastTwo = eps.suffix(2).map { $0.outcome.response ?? "" }
        if lastTwo.count == 2, lastTwo[1] == "same", lastTwo[0] != "same" { obs.append("Reported response to self-care has decreased in the most recent session.") }
        if eps.contains(where: { $0.triage.level == "stop" }) { obs.append("Lofer declined to treat at least one episode because of reported warning signs.") }
        var user: [(String, String)] = [("Symptoms", "Recurring \(types.joined(separator: ", "))")]
        if !trig.isEmpty { user.append(("Movement associated with discomfort", trig.joined(separator: ", "))) }
        if let t = topCtx { user.append(("Common context", "\(t.value)/\(eps.count) after \(t.key)")) }
        user.append(("Self-reported severity", eps.map { "\(df.string(from: $0.createdAt)): \($0.symptom.severity.map(String.init) ?? "–")/10" }.joined(separator: "; ")))
        user.append(("Reported response", eps.map { "\(df.string(from: $0.createdAt)) \(resp[$0.outcome.response ?? ""] ?? "not recorded")" }.joined(separator: "; ")))
        if !checks.isEmpty { user.append(("Movement check (before → after)", checks.joined(separator: "; "))) }
        var measured: [(String, String)] = []
        if !sens.isEmpty { measured.append(("Average applied pressure", "\(sens.map(\.avgPressure).reduce(0, +) / sens.count) kPa (simulated device)")) }
        if let peak = sens.compactMap(\.skinPeak).max() { measured.append(("Peak skin temperature during heat", String(format: "%.1f °C (simulated device)", peak))) }
        return Report(period: "\(df.string(from: eps.first!.createdAt)) – \(df.string(from: eps.last!.createdAt))", region: atlas[primary].label,
                      episodes: "\(eps.count) reported episode\(eps.count > 1 ? "s" : "")", userReported: user,
                      quotes: Array(eps.flatMap(\.said).suffix(3)),
                      treatment: [("Sessions", "\(eps.filter { $0.intervention != nil }.count) recovery sessions, \(mins) minutes in total"),
                                  ("Programmes", kinds.map { "\($0.key) ×\($0.value)" }.sorted().joined(separator: ", ")),
                                  ("Modalities", mods.joined(separator: ", "))],
                      measured: measured, observations: obs)
    }
    func reportText(_ r: Report) -> String {
        var L = ["LOFER CARE SUMMARY", "", "Period: \(r.period)", "Primary region: \(r.region)", "Episodes: \(r.episodes)", "", "USER-REPORTED"]
        L += r.userReported.map { "- \($0.0): \($0.1)" }
        if !r.quotes.isEmpty { L.append("- In their words:"); L += r.quotes.map { "  \"\($0)\"" } }
        L += ["", "TREATMENT PERFORMED"] + r.treatment.map { "- \($0.0): \($0.1)" }
        if !r.measured.isEmpty { L += ["", "DEVICE-MEASURED"] + r.measured.map { "- \($0.0): \($0.1)" } }
        if !r.observations.isEmpty { L += ["", "SYSTEM-GENERATED OBSERVATIONS"] + r.observations.map { "- \($0)" } }
        L += ["", r.note]
        return L.joined(separator: "\n")
    }

    static func summarise(_ log: [Episode.LogEntry]) -> Episode.Sensors {
        let p = log.filter { $0.modality != .heat }.map(\.pressure)
        return Episode.Sensors(avgPressure: p.isEmpty ? 0 : Int(p.reduce(0, +) / Double(p.count)), peakPressure: Int(p.max() ?? 0), skinPeak: log.map(\.skinTemp).max())
    }

    // MARK: sample history so the prototype has something to learn from (marked "Sample")
    static func seed() -> [Episode] {
        var rng = SeededRandom(seed: 11)
        func log(_ steps: [TreatmentStep]) -> [Episode.LogEntry] {
            var out: [Episode.LogEntry] = [], t = 0, skin = 32.4
            for st in steps { for _ in 0..<(st.minutes * 6) {
                skin += ((st.modality == .heat ? 34 + Double(st.intensity) * 1.2 : 32.6) - skin) * 0.16
                let p: Double = st.modality == .heat ? Double(4 + st.intensity) : st.modality == .ems ? 6 : Double(8 + st.intensity * 8) * (1 + 0.2 * sin(Double(t) / 2)) + (rng.next() - 0.5) * 2
                out.append(.init(t: t, modality: st.modality, level: st.intensity, pressure: (p * 10).rounded() / 10, skinTemp: (skin * 10).rounded() / 10)); t += 10 } }
            return out
        }
        func mk(_ daysAgo: Int, _ hour: Int, area: String, type: String, sev: Int, act: String, trig: [String] = [], kind: TreatmentPlan.Kind, plan: String,
                steps: [TreatmentStep], resp: String, said: String, check: (MovementResult.Feel, MovementResult.Feel)? = nil, fb: [Episode.Feedback] = [], adj: [String] = []) -> Episode {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(-Double(daysAgo) * 86400)); c.hour = hour; c.minute = 12
            let lg = log(steps)
            return Episode(id: "sample-\(daysAgo)", sample: true, createdAt: Calendar.current.date(from: c)!, said: [said],
                           symptom: .init(areaId: area, side: BodyAtlas.shared.laterality(of: area), type: type, severity: sev, onset: "yesterday", activity: act, triggers: trig),
                           triage: .init(level: "ok", reasons: []),
                           intervention: .init(planName: plan, kind: kind, steps: steps, minutesPlanned: steps.reduce(0) { $0 + $1.minutes }, durationSec: steps.reduce(0) { $0 + $1.minutes * 60 }, patches: ["P1", "P2", "P3"], adjustments: adj, log: lg),
                           feedback: fb.isEmpty ? [.init(t: 240, value: "good", via: "tap")] : fb,
                           movement: check.map { .init(name: "Arm raise", before: MovementResult(feel: $0.0), after: MovementResult(feel: $0.1)) },
                           outcome: .init(response: resp, pathway: resp == "much" ? "positive" : "partial", sensors: summarise(lg)))
        }
        let shoulder = [TreatmentStep(modality: .vibration, intensity: 3, minutes: 3), .init(modality: .compression, intensity: 3, minutes: 4), .init(modality: .heat, intensity: 2, minutes: 3)]
        let back = [TreatmentStep(modality: .vibration, intensity: 2, minutes: 4), .init(modality: .compression, intensity: 2, minutes: 4), .init(modality: .heat, intensity: 2, minutes: 2)]
        return [
            mk(19, 20, area: "r_sh_front", type: "tightness", sev: 7, act: "tennis", trig: ["Raising the arm overhead"], kind: .gentle, plan: "Gentle shoulder recovery", steps: shoulder, resp: "much",
               said: "My right shoulder is really tight after tennis yesterday, it hurts when I lift my arm.", check: (.little, .fine)),
            mk(15, 8, area: "r_lowback", type: "tightness", sev: 5, act: "sitting", kind: .gentle, plan: "Gentle lower back recovery", steps: back, resp: "much", said: "Lower back is stiff from sitting all day."),
            mk(12, 21, area: "r_sh_front", type: "tightness", sev: 6, act: "tennis", trig: ["Raising the arm overhead"], kind: .targeted, plan: "Targeted shoulder relief", steps: shoulder, resp: "little",
               said: "Same shoulder again after tennis. Tight when I serve.", check: (.little, .fine),
               fb: [.init(t: 180, value: "too strong", via: "voice"), .init(t: 420, value: "good", via: "tap")], adj: ["Intensity 3 → 2 (too strong)"]),
            mk(9, 19, area: "l_calf", type: "soreness", sev: 5, act: "running", kind: .targeted, plan: "Targeted lower leg relief", steps: back, resp: "little", said: "My left calf is destroyed after my long run."),
            mk(6, 18, area: "r_lowback", type: "tightness", sev: 4, act: "sitting", kind: .gentle, plan: "Gentle lower back recovery", steps: back, resp: "much", said: "Back is stiff again, long day at the desk."),
            mk(3, 20, area: "r_sh_front", type: "tightness", sev: 6, act: "tennis", trig: ["Raising the arm overhead"], kind: .targeted, plan: "Targeted shoulder relief", steps: shoulder, resp: "same",
               said: "Right shoulder tight again since tennis, sore when I raise my arm.", check: (.little, .little)),
        ]
    }
}

/// Deterministic random numbers, so the sample history looks the same every time.
struct SeededRandom { var s: UInt64; init(seed: UInt64) { s = seed }
    mutating func next() -> Double { s = (s &* 16807) % 2147483647; return Double(s) / 2147483647 } }
