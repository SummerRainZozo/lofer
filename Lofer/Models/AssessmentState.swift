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

/// ASSESSMENT STATE — everything Lofer currently understands about this episode.
/// The conversation never walks a fixed questionnaire: each answer updates this, and
/// AssessmentService decides the ONE next thing worth asking (or that it's time to confirm).
struct AssessmentState: Codable {
    var bodyRegion: String? = nil
    var regionConfirmed = false
    var pair: String? = nil                  // the other side, when both sides are affected
    var laterality: String? = nil            // left / right / both / centre
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
    var safetyFlags: [SafetyFlag] = []
    var movementBefore: MovementResult? = nil
    var movementAfter: MovementResult? = nil
    var asked: Set<String> = []
    var questionsAsked = 0
    var confidence: Double = 0
    var missingFields: [String] = []
}
