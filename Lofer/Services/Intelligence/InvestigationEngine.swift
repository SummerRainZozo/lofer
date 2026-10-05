import Foundation

/// INVESTIGATION ENGINE — deterministic, no AI. It has the final say on what happens next.
///
///   Care Intelligence PROPOSES an action ──▶ InvestigationEngine.decide ──▶ the action Lofer takes
///
/// Order of authority:
///   1. Safety: if the safety gate (SafetyValidator.triage) says stop, investigation stops.
///   2. Conservative endings ("not enough information", "see a professional") are always accepted.
///   3. A budget keeps Lofer concise: a few questions, location refinements, one baseline
///      movement and one observation. When it runs out, Lofer defers rather than guesses.
///   4. A proposal is only accepted if it's valid now: never re-ask something known, never
///      repeat an uncomfortable movement, only "proceed to care" when there's enough information.
///   5. Otherwise the engine picks the next step itself, from the existing AssessmentService logic.
enum InvestigationEngine {
    /// Upper limits per session, so Lofer stays concise (not interrogative).
    enum Limits {
        static let cycles = 7
        static let questions = 3        // the safety question doesn't count against this
        static let locationRefinements = 2
        static let movementChecks = 1   // one baseline; the same movement is repeated after care
        static let observations = 1
    }

    /// Everything the engine looks at. No network, no UI.
    struct Context {
        var A: AssessmentState
        var investigation: InvestigationState
        var triage: TriageResult? = nil          // current safety-gate result, when available
        var movement: MovementTest? = nil        // the movement check available for this area
        var historyCount = 0                     // earlier relevant sessions
        var movementSkipped: Bool { investigation.checks.contains { $0.kind == .movement && $0.status == .skipped } }
    }

    // MARK: - What is known, uncertain, and is it enough?

    /// Whether an assessment field already has an answer (so it must not be asked again).
    static func isKnown(_ field: String, _ A: AssessmentState) -> Bool {
        if A.isAnswered(field) { return true }
        switch field {
        case "region": return A.bodyRegion != nil
        case "sensation": return A.sensation.map { !["pain", "unclear"].contains($0) } ?? false
        case "triggers": return !A.movementTriggers.isEmpty || A.symptomsAtRest != nil
        case "onset": return A.onset != nil || A.activityContext != nil
        case "severity": return A.severity != nil
        case "previous": return A.previousEpisodes != nil
        case "safety": return !AssessmentService.needsSafety(A)
        default: return false
        }
    }

    /// What matters that isn't known yet, most important first.
    static func uncertainties(_ c: Context) -> [Uncertainty] {
        let A = c.A
        var u: [Uncertainty] = []
        if A.bodyRegion == nil { u.append(.init(id: "where", topic: "Where it's felt", importance: .high, field: "region")) }
        else if !A.regionConfirmed { u.append(.init(id: "precise-area", topic: "The exact area", importance: .medium, field: nil)) }
        if !isKnown("sensation", A) && !A.isAnswered("sensation") { u.append(.init(id: "feeling", topic: "What it feels like", importance: .high, field: "sensation")) }
        if AssessmentService.needsSafety(A) { u.append(.init(id: "warning-signs", topic: "Numbness, tingling, swelling or weakness", importance: .high, field: "safety")) }
        if c.movement != nil && c.investigation.baseline == nil && !c.movementSkipped {
            u.append(.init(id: "movement-response", topic: "How a simple movement feels", importance: .high, field: nil))
        }
        if !isKnown("triggers", A) { u.append(.init(id: "triggers", topic: "What brings it on", importance: .medium, field: "triggers")) }
        if !isKnown("onset", A) { u.append(.init(id: "onset", topic: "When it started", importance: .low, field: "onset")) }
        if !isKnown("severity", A) { u.append(.init(id: "severity", topic: "How much it's bothering you", importance: .low, field: "severity")) }
        return u
    }

    /// Enough information to consider conservative care? (Safety is checked separately, after.)
    static func isReadyForCare(_ c: Context) -> Bool {
        let A = c.A
        guard A.bodyRegion != nil, A.regionConfirmed else { return false }
        guard isKnown("sensation", A) || A.isAnswered("sensation") else { return false }
        guard !AssessmentService.needsSafety(A), !A.safetyUnresolved else { return false }
        if c.movement != nil && c.investigation.baseline == nil && !c.movementSkipped { return false }
        return true
    }

    static func readiness(_ c: Context) -> Readiness {
        if isReadyForCare(c) { return .init(informationSufficiency: .sufficient, reason: "Area confirmed, feeling known, warning signs ruled out, and the movement response observed.") }
        if c.A.bodyRegion != nil && (isKnown("sensation", c.A) || c.A.isAnswered("sensation")) {
            let open = uncertainties(c).filter { $0.importance != .low }.map { $0.topic.lowercased() }
            return .init(informationSufficiency: .partial, reason: "Still open: \(open.joined(separator: ", ")).")
        }
        return .init(informationSufficiency: .insufficient, reason: "The area or the feeling is still unclear.")
    }

    // MARK: - Deciding the next action

    /// The action Lofer will actually take, and (when the proposal was overridden) why.
    static func decide(proposal: InvestigationAction?, _ c: Context) -> (action: InvestigationAction, overridden: String?) {
        // 1. Safety first: the deterministic gate overrides anything proposed.
        if let t = c.triage, t.level == .stop {
            return (.safetyStop(.init(reason: t.reasons.joined(separator: "; "), urgent: t.urgent)),
                    proposal.map { $0.type == "safetyStop" ? nil : "Safety gate stopped care (\($0.type) not taken)" } ?? nil)
        }
        // 2. Conservative endings are always allowed.
        if let p = proposal, p.endsWithoutCare { return (p, nil) }
        // 3. Budget: don't keep investigating forever.
        if c.investigation.cycles >= Limits.cycles && !isReadyForCare(c) {
            return (insufficient("Investigation budget reached without enough information"), "Budget reached")
        }
        // 4. Accept the proposal if it's valid right now.
        if let p = proposal, isValid(p, c) { return (p, nil) }
        // 5. Otherwise choose the next step deterministically.
        return (deterministicNext(c), proposal.map { "Proposal \($0.type) not valid now; used the deterministic next step" })
    }

    static func isValid(_ action: InvestigationAction, _ c: Context) -> Bool {
        let A = c.A, inv = c.investigation
        switch action {
        case .askQuestion(let q):
            guard q.field != "region", !isKnown(q.field, A), !A.isAnswered(q.field) else { return false }
            return q.field == "safety" || inv.count(.question) < Limits.questions
        case .refineBodyLocation(let l):
            guard inv.count(.location) < Limits.locationRefinements else { return false }
            switch l.requestedRefinement {
            case .region: return A.bodyRegion == nil
            case .side: return A.laterality == nil
            case .surface, .precise: return A.bodyRegion != nil && !A.regionConfirmed
            }
        case .movementCheck(let m):
            // Only the movement check that exists for this area (the app owns the content).
            guard c.movement?.id == m.movementId else { return false }
            // Never repeat a baseline, and never ask again for one that was uncomfortable.
            return m.phase == .baseline && inv.baseline == nil && !c.movementSkipped && inv.count(.movement) < Limits.movementChecks
        case .requestUserObservation(let o):
            return inv.count(.observation) < Limits.observations && !inv.checks.contains { $0.kind == .observation && $0.purpose == o.observationId }
        case .proceedToCare:
            return isReadyForCare(c)
        case .insufficientInformation, .recommendProfessionalAssessment, .safetyStop:
            return true
        }
    }

    /// The deterministic next step: what's most worth finding out, in a fixed order of
    /// importance. Used when there's no valid proposal, and by the on-device fallback.
    static func deterministicNext(_ c: Context) -> InvestigationAction {
        let A = c.A, inv = c.investigation
        let noun = A.bodyRegion.map { TreatmentEngine.regionNoun($0) } ?? "body"
        if A.bodyRegion == nil {
            if inv.count(.location) < Limits.locationRefinements {
                return .refineBodyLocation(.init(broadRegion: "body", requestedRefinement: .region,
                                                 prompt: "Where are you feeling it? Tap the body, or tell me.", purpose: "Find the area"))
            }
            return insufficient("The area couldn't be established")
        }
        if AssessmentService.needsSafety(A) { return ask(AssessmentService.question("safety", A), purpose: "Rule out warning signs") }
        if !A.regionConfirmed && inv.count(.location) < Limits.locationRefinements {
            return .refineBodyLocation(.init(broadRegion: noun, currentSelection: A.bodyRegion, requestedRefinement: .precise,
                                             prompt: "Show me where it's most noticeable.", purpose: "Pin down the exact area"))
        }
        if !isKnown("sensation", A) && !A.isAnswered("sensation") && inv.count(.question) < Limits.questions {
            return ask(AssessmentService.question("sensation", A), purpose: "Understand what it feels like")
        }
        if let t = c.movement, inv.baseline == nil, !c.movementSkipped, inv.count(.movement) < Limits.movementChecks {
            return .movementCheck(.init(movementId: t.id, phase: .baseline, purpose: "See how the area responds to movement", targetObservation: t.notice))
        }
        if isReadyForCare(c) { return .proceedToCare(.init(reason: readiness(c).reason)) }
        if inv.count(.question) < Limits.questions, let q = AssessmentService.nextQuestion(A, historyCount: c.historyCount), q.field != "region" {
            return ask(q, purpose: "Fill an important gap")
        }
        return insufficient(readiness(c).reason)
    }

    private static func ask(_ q: AssessmentQuestion, purpose: String) -> InvestigationAction {
        .askQuestion(.init(field: q.field, question: q.text, purpose: purpose,
                           options: q.options.isEmpty ? nil : q.options.map { ActionOption(label: $0.0, value: $0.1) },
                           multiSelect: q.multi ? true : nil))
    }
    static func insufficient(_ reason: String) -> InvestigationAction {
        .insufficientInformation(.init(reason: reason, message: "I don't have enough information to recommend a session here."))
    }
}
