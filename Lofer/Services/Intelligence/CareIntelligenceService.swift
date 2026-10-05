import Foundation

/// CARE INTELLIGENCE — understands what the user said in the context of the whole
/// session, and PROPOSES what to do next. It never decides alone: the InvestigationEngine
/// validates the proposal and SafetyValidator decides what care is allowed.
///
///   CareIntelligenceService
///   ├── LocalCareIntelligenceService   ← on-device: keyword parser + deterministic engine (offline fallback)
///   └── APICareIntelligenceService     ← Lofer's backend (POST /api/care). Today the backend runs
///                                         MockCareIntelligenceProvider; later a real LLM provider,
///                                         with no change here.
///
/// Both return the same structured `CareIntelligenceResponse`. Never put API keys in the
/// app: the backend holds them.
protocol CareIntelligenceService {
    func respond(to request: CareRequest) async throws -> CareIntelligenceResponse
}

/// On-device Care Intelligence: the existing SymptomParser and AssessmentService, plus the
/// deterministic InvestigationEngine to propose a next step. Works offline, never throws
/// for a well-formed request. It doesn't generate contributing patterns: that's a job for
/// the backend provider, and Lofer works without them.
struct LocalCareIntelligenceService: CareIntelligenceService {
    func respond(to request: CareRequest) async throws -> CareIntelligenceResponse { Self.response(to: request) }

    static func response(to request: CareRequest) -> CareIntelligenceResponse {
        let input = request.latestUserInput
        let parsed = input.kind == .utterance ? SymptomParser.parse(input.text ?? "") : ParsedUtterance(raw: input.text ?? "")
        // Project the assessment forward with this input (a copy: the app does the real merge).
        var A = request.currentAssessmentState
        var learned = AssessmentService.update(&A, with: parsed, expect: request.expectedField)
        // The area, as the app would resolve it (an atlas id, or a side template plus a known side).
        if let e = parsed.entry {
            let side = parsed.side?.rawValue ?? (["left", "right"].contains(A.laterality ?? "") ? String(A.laterality!.prefix(1)) : nil)
            if let id = e.template.flatMap({ t in side.map { t.replacingOccurrences(of: "{s}", with: $0) } }) ?? e.id,
               BodyAtlas.shared.node(id) != nil, id != A.bodyRegion {
                AssessmentService.setRegion(&A, id); learned.append("region")
            }
        }
        let context = InvestigationEngine.Context(A: A, investigation: request.investigation,
                                                  movement: A.bodyRegion.flatMap { MovementTest.forArea($0) },
                                                  historyCount: request.relevantBodyMemory.count)
        return CareIntelligenceResponse(
            schemaVersion: CareSchema.version, requestId: request.requestId, provider: "local",
            extractedInformation: ExtractedInformation(parsed), assessmentUpdates: AssessmentPatch(parsed),
            possibleContributingPatterns: [], uncertainties: InvestigationEngine.uncertainties(context), evidenceUpdates: [],
            recommendedNextAction: InvestigationEngine.deterministicNext(context),
            readiness: InvestigationEngine.readiness(context),
            userFacingResponse: .init(acknowledgement: AssessmentService.ack(A, learned: learned), prompt: ""))
    }
}

/// Guards what Care Intelligence may SAY to the user. A provider (especially a future LLM)
/// must not diagnose or claim a root cause; anything that does is replaced with Lofer's own
/// deterministic wording.
enum CareLanguage {
    private static let forbidden = "diagnos|you have (a|an) |\\btear\\b|tendin|bursitis|impingement|sprain|strain\\b|arthritis|root cause|definitely|this is caused by|it'?s caused by|pathology"
    static func isAcceptable(_ text: String) -> Bool { !text.isEmpty && text.count <= 280 && !text.has(forbidden) }
}
