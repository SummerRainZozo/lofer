import Foundation

/// What the wearable can do.
enum Modality: String, Codable, CaseIterable {
    case vibration, compression, heat, ems
    var label: String { [.vibration: "Vibration", .compression: "Compression", .heat: "Heat", .ems: "Muscle stimulation"][self]! }
    var short: String { self == .ems ? "Stimulation" : label }
}

/// One step of a session: modality + intensity (1–5) + duration.
struct TreatmentStep: Codable, Hashable {
    var modality: Modality
    var intensity: Int
    var minutes: Int
}

/// A plan = BODY REGION + steps in SEQUENCE. The engine proposes plans; only the
/// SafetyValidator turns a plan into something the device will accept.
struct TreatmentPlan: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case gentle, targeted, routine, custom }
    var id = UUID().uuidString
    var kind: Kind
    var name: String
    var region: String
    var pair: String? = nil
    var focus: String? = nil
    var steps: [TreatmentStep]
    var reason: String? = nil
    var adjusted = false

    var minutes: Int { steps.reduce(0) { $0 + $1.minutes } }
    var sequenceText: String { steps.map { "\($0.modality.short) \($0.minutes) min" }.joined(separator: " → ") }
    var levelText: String {
        let m = steps.filter { $0.modality != .heat }.map(\.intensity).max() ?? 1
        return TreatmentEngine.levels[m]
    }
}

/// Saved routine ("Post-tennis shoulder routine").
struct SavedRoutine: Codable {
    var name: String
    var steps: [TreatmentStep]
    var savedAt: Date
}
