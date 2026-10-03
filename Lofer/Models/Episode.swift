import Foundation

/// One BODY MEMORY episode = SYMPTOM + STATE + INTERVENTION + FEEDBACK + OUTCOME,
/// always with the user's own words next to the structured summary.
struct Episode: Codable, Identifiable {
    var id: String
    var sample = false
    var createdAt: Date
    var said: [String]
    var point: [Float]? = nil           // exact spot on the body model (x, y, z), if chosen
    var normal: [Float]? = nil

    struct Symptom: Codable {
        var areaId: String
        var pairId: String? = nil
        var side: String? = nil
        var type: String? = nil
        var severity: Int? = nil
        var onset: String? = nil
        var activity: String? = nil
        var triggers: [String] = []
        var atRest: String? = nil
        var previous: Bool? = nil
        var flags: [String] = []
    }
    var symptom: Symptom

    struct Triage: Codable { var level: String; var reasons: [String] }
    var triage: Triage

    struct LogEntry: Codable { var t: Int; var modality: Modality; var level: Int; var pressure: Double; var skinTemp: Double }
    struct Intervention: Codable {
        var planName: String
        var kind: TreatmentPlan.Kind
        var steps: [TreatmentStep]
        var minutesPlanned: Int
        var durationSec: Int
        var patches: [String]
        var adjustments: [String]
        var safetyNotes: [String] = []
        var log: [LogEntry]
    }
    var intervention: Intervention? = nil

    struct Feedback: Codable { var t: Int; var value: String; var via: String }
    var feedback: [Feedback] = []

    struct MovementCheck: Codable { var name: String; var before: MovementResult?; var after: MovementResult? }
    var movement: MovementCheck? = nil

    struct Sensors: Codable { var avgPressure: Int; var peakPressure: Int; var skinPeak: Double? }
    struct Outcome: Codable {
        var response: String?          // much / little / same / worse
        var pathway: String
        var sensors: Sensors? = nil
        var lofersNote: String? = nil  // the hedged "why it might feel this way" (not a diagnosis)
    }
    var outcome: Outcome
}

/// User profile answers (Profile screen) used to tune programmes and safety.
struct UserProfile: Codable {
    var name = ""
    var age: String? = nil
    var sex: String? = nil
    var sports: [String] = []
    var frequency: String? = nil
    var posture: String? = nil
    var pressure = "Moderate"
    var length = "15 min"
    var heat = true
    var goals: [String] = []
    var pregnant = false
    var implant = false
    var recentInjury = false
    var clotting = false

    var hasSafetyFlag: Bool { pregnant || implant || recentInjury || clotting }
    var baseIntensity: Int { ["Gentle": 2, "Moderate": 3, "Firm": 4][pressure] ?? 3 }
    var lengthMinutes: Int { Int(length.prefix(2).trimmingCharacters(in: .whitespaces)) ?? 15 }
}
