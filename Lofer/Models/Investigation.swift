import Foundation

/// INVESTIGATION STATE — what Lofer has learned during one care session, beyond the
/// assessment fields: what's still uncertain, which patterns might be contributing,
/// the evidence for and against them, and every check done so far.
///
/// Internal only: none of this is shown to the user as-is. Known facts live in
/// `AssessmentState` (not duplicated here). It is sent to Care Intelligence each turn,
/// and saved with the episode in Body Memory.
struct InvestigationState: Codable, Equatable {
    var patterns: [ContributingPattern] = []      // possible contributing patterns (never diagnoses)
    var uncertainties: [Uncertainty] = []         // what matters that we don't know yet
    var evidence: [Evidence] = []                 // observations, with what they support or weaken
    var checks: [Check] = []                      // questions, location refinements, movements, observations
    var movementObservations: [MovementObservation] = []
    var nextAction: InvestigationAction? = nil    // what the engine decided to do next
    var readiness = Readiness(informationSufficiency: .insufficient, reason: "Nothing gathered yet.")
    var cycles = 0                                // investigation rounds so far (bounded)
    var intelligenceSources: [String] = []        // which provider answered each round ("mock", "local", …)
    var conclusion: String? = nil                 // how the investigation ended, in plain words

    mutating func addEvidence(_ source: Evidence.Source, _ summary: String, field: String? = nil, value: String? = nil,
                              supports: [String] = [], weakens: [String] = []) {
        evidence.append(Evidence(id: "ev-\(evidence.count + 1)", source: source, summary: summary, field: field, value: value,
                                 supports: supports, weakens: weakens, at: Date()))
    }
    mutating func addCheck(_ kind: Check.Kind, purpose: String, prompt: String, response: String?, status: Check.Status) {
        checks.append(Check(id: "ck-\(checks.count + 1)", kind: kind, purpose: purpose, prompt: prompt, response: response, status: status, at: Date()))
    }
    func count(_ kind: Check.Kind) -> Int { checks.filter { $0.kind == kind }.count }
    var baseline: MovementObservation? { movementObservations.first { $0.phase == .baseline } }
    var repeatCheck: MovementObservation? { movementObservations.last { $0.phase == .repeatCheck } }
}

/// A plausible pattern that may be contributing. Not a diagnosis, not a root cause.
struct ContributingPattern: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case possible, supported, weakened }
    var id: String
    var label: String                 // e.g. "Tightness building after a demanding activity"
    var status: Status
    var supporting: [String] = []     // evidence ids or short reasons
    var weakening: [String] = []
}

/// Something that matters and isn't known yet.
struct Uncertainty: Codable, Equatable, Identifiable {
    enum Importance: String, Codable { case high, medium, low }
    var id: String
    var topic: String                 // "Which part of the shoulder"
    var importance: Importance
    var field: String? = nil          // the assessment field it would fill, if any
}

/// One piece of evidence. The user is a sensor: their answers are observations too.
struct Evidence: Codable, Equatable, Identifiable {
    enum Source: String, Codable { case userReport, userObservation, movementCheck, location, careIntelligence, simulatedDevice }
    var id: String
    var source: Source
    var summary: String
    var field: String? = nil
    var value: String? = nil
    var supports: [String] = []       // pattern ids
    var weakens: [String] = []
    var at: Date
}

/// One investigation step that was carried out.
struct Check: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case question, location, movement, observation }
    enum Status: String, Codable { case answered, skipped, uncertain, inconclusive }
    var id: String
    var kind: Kind
    var purpose: String               // why it was worth doing
    var prompt: String                // what was asked or shown
    var response: String?             // what the user reported
    var status: Status
    var at: Date
}

/// How a movement felt, in the investigation's structured terms.
struct MovementObservation: Codable, Equatable {
    enum Phase: String, Codable { case baseline, repeatCheck }
    enum Outcome: String, Codable { case comfortable, mildDiscomfort, significantDiscomfort, unableToPerformComfortably }
    enum Change: String, Codable { case better, same, worse }
    var movementId: String
    var name: String
    var phase: Phase
    var outcome: Outcome
    var whereInMovement: String? = nil   // "about halfway"
    var location: String? = nil          // "outside"
    var quality: String? = nil           // "pulling"
    var userDescription: String? = nil   // their own words, if typed or said
    var changeVsBaseline: Change? = nil
    var at = Date()

    static func outcome(_ feel: MovementResult.Feel) -> Outcome {
        [.fine: .comfortable, .little: .mildDiscomfort, .quite: .significantDiscomfort, .cannot: .unableToPerformComfortably][feel]!
    }
    /// Uncomfortable enough that Lofer won't ask for it again.
    var isUncomfortable: Bool { outcome == .significantDiscomfort || outcome == .unableToPerformComfortably }
}

/// "Do we have enough information to take the next conservative action?"
/// Deliberately not a diagnostic confidence.
struct Readiness: Codable, Equatable {
    enum Sufficiency: String, Codable { case insufficient, partial, sufficient }
    var informationSufficiency: Sufficiency
    var reason: String
}

/// A choice offered as a tap.
struct ActionOption: Codable, Equatable { var label: String; var value: String }

/// What Lofer should do next. Care Intelligence may PROPOSE one; the deterministic
/// InvestigationEngine (and SafetyValidator) decide whether it happens.
enum InvestigationAction: Codable, Equatable {
    struct AskQuestion: Codable, Equatable {
        var field: String                 // the uncertainty / assessment field it fills
        var question: String
        var purpose: String
        var options: [ActionOption]? = nil
        var multiSelect: Bool? = nil
    }
    struct LocationRefinement: Codable, Equatable {
        enum Requested: String, Codable { case region, side, surface, precise }
        var broadRegion: String           // e.g. "shoulder"
        var currentSelection: String? = nil
        var requestedRefinement: Requested
        var prompt: String
        var purpose: String
    }
    struct MovementCheckRequest: Codable, Equatable {
        var movementId: String            // MovementTest id ("arm_raise")
        var phase: MovementObservation.Phase
        var purpose: String
        var targetObservation: String     // what to notice
    }
    struct ObservationRequest: Codable, Equatable {
        var observationId: String         // e.g. "eases_when_stopped"
        var prompt: String
        var purpose: String
        var options: [ActionOption]
    }
    struct Reason: Codable, Equatable { var reason: String }
    struct Conclusion: Codable, Equatable { var reason: String; var message: String }
    struct SafetyStop: Codable, Equatable { var reason: String; var urgent: Bool }

    case askQuestion(AskQuestion)
    case refineBodyLocation(LocationRefinement)
    case movementCheck(MovementCheckRequest)
    case requestUserObservation(ObservationRequest)
    case proceedToCare(Reason)
    case insufficientInformation(Conclusion)
    case recommendProfessionalAssessment(Conclusion)
    case safetyStop(SafetyStop)

    var type: String {
        switch self {
        case .askQuestion: "askQuestion"
        case .refineBodyLocation: "refineBodyLocation"
        case .movementCheck: "movementCheck"
        case .requestUserObservation: "requestUserObservation"
        case .proceedToCare: "proceedToCare"
        case .insufficientInformation: "insufficientInformation"
        case .recommendProfessionalAssessment: "recommendProfessionalAssessment"
        case .safetyStop: "safetyStop"
        }
    }
    /// Ends the investigation without care.
    var endsWithoutCare: Bool {
        switch self { case .insufficientInformation, .recommendProfessionalAssessment, .safetyStop: true; default: false }
    }

    // JSON: a flat object with a "type" field plus that action's fields,
    // e.g. {"type":"movementCheck","movementId":"arm_raise",...}. Same shape as the backend.
    private enum K: String, CodingKey { case type }
    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: K.self).decode(String.self, forKey: .type)
        switch type {
        case "askQuestion": self = .askQuestion(try AskQuestion(from: decoder))
        case "refineBodyLocation": self = .refineBodyLocation(try LocationRefinement(from: decoder))
        case "movementCheck": self = .movementCheck(try MovementCheckRequest(from: decoder))
        case "requestUserObservation": self = .requestUserObservation(try ObservationRequest(from: decoder))
        case "proceedToCare": self = .proceedToCare(try Reason(from: decoder))
        case "insufficientInformation": self = .insufficientInformation(try Conclusion(from: decoder))
        case "recommendProfessionalAssessment": self = .recommendProfessionalAssessment(try Conclusion(from: decoder))
        case "safetyStop": self = .safetyStop(try SafetyStop(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: try decoder.container(keyedBy: K.self), debugDescription: "Unknown action \(type)")
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(type, forKey: .type)
        switch self {
        case .askQuestion(let p): try p.encode(to: encoder)
        case .refineBodyLocation(let p): try p.encode(to: encoder)
        case .movementCheck(let p): try p.encode(to: encoder)
        case .requestUserObservation(let p): try p.encode(to: encoder)
        case .proceedToCare(let p): try p.encode(to: encoder)
        case .insufficientInformation(let p), .recommendProfessionalAssessment(let p): try p.encode(to: encoder)
        case .safetyStop(let p): try p.encode(to: encoder)
        }
    }
}
