import Foundation

/// How serious a warning sign is. urgent = seek help now, stop = see a professional first,
/// caution = treat conservatively.
enum FlagLevel: String, Codable { case caution, stop, urgent }

struct SafetyFlag: Codable, Hashable {
    var level: FlagLevel
    var label: String
}

/// What the user felt during a movement check, in their own terms.
struct MovementResult: Codable, Hashable {
    enum Feel: String, Codable, CaseIterable { case fine, little, quite, cannot }
    var feel: Feel
    var whereInMovement: String? = nil   // "about halfway"
    var quality: String? = nil           // "pulling"
    var sideOfIt: String? = nil          // "outside"

    var score: Int { [.fine: 1, .little: 3, .quite: 6, .cannot: 9][feel]! }
    var phrase: String { [.fine: "fine", .little: "a little uncomfortable", .quite: "quite uncomfortable", .cannot: "not comfortable"][feel]! }
}

/// How the user responded to a question Lofer asked. Showing a question never answers it:
/// only a reply that addresses it does. "Not sure" and "skip" are kept apart from "no",
/// because neither rules anything out. A field with no entry is still unanswered.
enum AnswerStatus: String, Codable {
    case affirmative   // answered with information ("lifting my arm", "yes, it's happened before", "it's numb")
    case negative      // answered "no" / "nothing" / "none of these"
    case uncertain     // "not sure", "maybe"
    case skipped       // chose not to answer
}

/// ASSESSMENT STATE — everything Lofer currently understands about this episode.
/// The conversation never walks a fixed questionnaire: each answer updates this, and
/// AssessmentService decides the ONE next thing worth asking (or that it's time to confirm).
struct AssessmentState: Codable, Equatable {
    var bodyRegion: String? = nil
    var regionConfirmed = false
    var pair: String? = nil                  // the other side, when both sides are affected
    var laterality: String? = nil            // left / right / both / centre
    var specificArea: String? = nil          // front / back / outer / inner / top, when known
    var userDescription: [String] = []       // the user's own words, always kept
    var onset: String? = nil                 // "yesterday", "a few days ago"…
    var onsetType: String? = nil             // sudden / gradual
    var activityContext: String? = nil       // "tennis"
    var activityDuration: String? = nil      // "about two hours"
    var sensation: String? = nil             // tightness / soreness / ache / sharp / burning / cramp / unclear / pain / other
    var sensationWords: String? = nil        // when the user describes it in their own words
    var severity: Int? = nil                 // 0–10 ("how much it's bothering you")
    var movementTriggers: [String] = []
    var relievingFactors: [String] = []
    var symptomsAtRest: String? = nil        // minimal / present
    var previousEpisodes: Bool? = nil
    var progression: String? = nil           // improving / stable / worsening
    var safetyFlags: [SafetyFlag] = []       // warning signs the user reported (kept with their original level)
    var uncertainSigns: [SafetyFlag] = []    // warning signs the user wasn't sure about ("not sure if it's numb")
    var movementBefore: MovementResult? = nil
    var movementAfter: MovementResult? = nil
    var answers: [String: AnswerStatus] = [:]   // question field → how it was answered (absent = unanswered)
    var questionsAsked = 0
    /// Share of the core fields (region, feeling, triggers, onset, severity) that are filled in.
    /// It measures how complete the description is, NOT confidence in any explanation or decision.
    var fieldCompleteness: Double = 0
    var missingFields: [String] = []

    func isAnswered(_ field: String) -> Bool { answers[field] != nil }
    /// The safety question was answered, but without ruling anything out.
    var safetyUnresolved: Bool { [.uncertain, .skipped].contains(answers["safety"]) }
}
