import Foundation
import Observation

/// Voice states shared by every provider.
enum VoiceState: String { case idle = "IDLE", listening = "LISTENING", thinking = "THINKING", speaking = "SPEAKING", interrupted = "INTERRUPTED", error = "ERROR" }

/// VOICE — provider-independent. Voice is an input method for the whole app
/// (body selection, assessment, movement check, treatment, reassessment), not a chat screen.
/// It never controls hardware: transcripts go to the care flow, which turns them into
/// structured intents for the engine and safety layer.
///
///   VoiceAgent
///   ├── MockVoiceAgent          ← now: typed / sample text stands in for speech
///   └── ElevenLabsVoiceAgent    ← later: streaming speech via Lofer's backend (no keys in the app)
protocol VoiceAgent: AnyObject {
    var state: VoiceState { get }
    var onTranscript: ((String, Bool) -> Void)? { get set }   // (text, isFinal)
    func startListening()
    func stopListening()
    func transcribe(_ input: String)          // audio → text; in the mock, input is already text
    func speak(_ text: String)
    func interrupt()
}

/// Prototype provider: no microphone, no audio. While LISTENING the UI shows a text
/// field; whatever is submitted becomes the transcript. speak() holds the SPEAKING
/// state for about as long as the line would take to say.
@Observable
final class MockVoiceAgent: VoiceAgent {
    private(set) var state: VoiceState = .idle
    @ObservationIgnored var onTranscript: ((String, Bool) -> Void)?
    @ObservationIgnored private var speakTask: Task<Void, Never>?
    @ObservationIgnored private var simTask: Task<Void, Never>?

    func startListening() { if state == .speaking { interrupt() }; state = .listening }
    func stopListening() { if state == .listening { state = .idle } }
    func transcribe(_ input: String) {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { state = .idle; return }
        state = .thinking
        onTranscript?(t, true)
    }
    /// Simulate speech arriving word by word (used by sample phrases).
    func simulate(_ text: String) {
        startListening()
        simTask?.cancel()
        simTask = Task { @MainActor in
            var acc = ""
            for (i, w) in text.split(separator: " ").enumerated() {
                try? await Task.sleep(for: .milliseconds(140))
                if Task.isCancelled || state != .listening { return }
                acc += (i == 0 ? "" : " ") + w
                onTranscript?(acc, false)
            }
            try? await Task.sleep(for: .milliseconds(350))
            transcribe(text)
        }
    }
    func speak(_ text: String) {
        speakTask?.cancel()
        state = .speaking
        let ms = min(2600, 500 + text.count * 30)
        speakTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(ms))
            if !Task.isCancelled, state == .speaking { state = .idle }
        }
    }
    func interrupt() { speakTask?.cancel(); state = .interrupted; Task { @MainActor in try? await Task.sleep(for: .milliseconds(300)); if state == .interrupted { state = .idle } } }
    func finishThinkingIfSilent() { if state == .thinking { state = .idle } }
}

/// Placeholder. A real provider must get a short-lived session token from Lofer's
/// backend. API keys never ship in the app or the repository.
final class ElevenLabsVoiceAgent: VoiceAgent {
    private(set) var state: VoiceState = .idle
    var onTranscript: ((String, Bool) -> Void)?
    let tokenEndpoint: URL
    init(tokenEndpoint: URL) { self.tokenEndpoint = tokenEndpoint }
    func startListening() { state = .error }   // not configured yet
    func stopListening() { state = .idle }
    func transcribe(_ input: String) {}
    func speak(_ text: String) {}
    func interrupt() { state = .idle }
}
