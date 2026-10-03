import Foundation

/// The "understanding" part of Lofer: turns what the user says into structured fields.
///
///   CareIntelligenceService
///   ├── MockCareIntelligenceService   ← now: on-device keyword parser (SymptomParser)
///   └── APICareIntelligenceService    ← later: an LLM behind Lofer's own backend
///
/// The rest of the app only sees `ParsedUtterance`, so swapping the implementation
/// changes nothing else. Never put API keys in the app: the API version should call
/// Lofer's backend, which holds the keys.
protocol CareIntelligenceService {
    func interpret(_ utterance: String) async -> ParsedUtterance
}

struct MockCareIntelligenceService: CareIntelligenceService {
    func interpret(_ utterance: String) async -> ParsedUtterance { SymptomParser.parse(utterance) }
}

/// Placeholder for the future LLM-backed version (not used yet).
struct APICareIntelligenceService: CareIntelligenceService {
    /// Lofer's own backend endpoint (which talks to the LLM). No keys live here.
    var endpoint: URL
    func interpret(_ utterance: String) async -> ParsedUtterance {
        // TODO: POST the utterance + current AssessmentState to `endpoint`, decode ParsedUtterance.
        // Falls back to the on-device parser until the backend exists.
        SymptomParser.parse(utterance)
    }
}
