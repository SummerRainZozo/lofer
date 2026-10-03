import SwiftUI
import Observation

/// App-wide state: which screen is showing, page navigation, and the shared services.
/// Mock services are created HERE — swapping in real ones later (LLM, ElevenLabs,
/// physical device) is a one-line change in this file.
@Observable @MainActor
final class AppModel {
    enum Screen { case splash, home, care }
    enum Page: Hashable { case history, episode(String), report(String?), profile, typography }

    var screen: Screen = .splash
    var path: [Page] = []

    // Shared services
    let memory = BodyMemoryStore()
    let voice = MockVoiceAgent()
    let device: DeviceInterface = MockLoferDevice()
    let intelligence: CareIntelligenceService = MockCareIntelligenceService()
    let body = BodySceneController()
    @ObservationIgnored private(set) lazy var care: CareFlowModel = {
        let c = CareFlowModel(memory: memory, intelligence: intelligence, device: device, voice: voice, body: body)
        c.onExit = { [weak self] in self?.goHome() }
        c.onOpenReport = { [weak self] g in self?.goHome(); self?.path = [.report(g)] }
        return c
    }()

    // Home screen state
    var homeLine = "How is your body feeling today?"
    var homeHeard = ""
    var homeContext = ""
    var input = InputState()

    struct InputState { var visible = false; var voiceMode = false; var suggestion: String? }

    static let greetings = ["How is your body feeling today?", "Tell me what’s been going on and how you’re feeling.", "Anything bothering you today?"]
    static let homeSamples = ["I played tennis yesterday and my right shoulder has felt tight since.", "The back of my left knee is sore after my run.",
                              "My lower back is stiff from sitting all day.", "My wrist feels weird after working all day."]
    @ObservationIgnored private var sampleIndex = 0

    init() {
        voice.onTranscript = { [weak self] text, final in
            Task { @MainActor in self?.transcript(text, final: final) }
        }
        _ = care
        // Demo modes for screenshots/testing (Xcode: Product › Scheme › Edit Scheme › Arguments):
        //   -LoferDemo      plays a sample story
        //   -LoferDemoFull  plays a whole conversation, through the movement check to treatment
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-LoferDemo") || args.contains("-LoferDemoFull") {
            let script: [(Double, String)] = args.contains("-LoferDemoFull")
                ? [(5, Self.homeSamples[0]), (7, "Mostly when I lift it above my head."), (6, "Quite a lot."), (6, "It's actually more towards the back."),
                   (6, "Yes, that's it."), (6, "Yes, that's right."), (7, "It starts pulling about halfway."), (7, "Okay, let's start.")]
                : [(5, Self.homeSamples[0])]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4)); self.screen = .home
                for (wait, line) in script { try? await Task.sleep(for: .seconds(wait)); self.voice.simulate(line) }
            }
        }
    }

    // MARK: navigation
    func finishSplash() { if screen == .splash { withAnimation(Motion.slow) { screen = .home } } }
    func goHome() { care.reset(); input.visible = false; homeHeard = ""; homeContext = ""; homeLine = Self.greetings[0]; withAnimation(Motion.slow) { screen = .home } }
    func openBody() { care.beginWithBody(); withAnimation(Motion.slow) { screen = .care } }
    func treatAgain(_ e: Episode) {
        path = []
        care.beginWithBody()
        withAnimation(Motion.slow) { screen = .care }
        Task { await care.applyTarget(.id(e.symptom.areaId)) }
    }

    // MARK: voice + typing (both end up as a transcript)
    /// Mic button: start listening (mock = a text field + suggestion), stop, or interrupt Lofer.
    func micTapped() {
        if voice.state == .listening { voice.stopListening(); input.visible = false; return }
        voice.startListening()
        input = InputState(visible: true, voiceMode: true, suggestion: suggestion())
    }
    func keyboardTapped() { input = InputState(visible: true, voiceMode: false, suggestion: nil) }
    func submitTyped(_ text: String) { input.visible = false; voice.transcribe(text) }
    func useSuggestion() { if let s = input.suggestion { input.visible = false; voice.simulate(s) } }
    func closeInput() { input.visible = false; voice.stopListening() }

    private func transcript(_ text: String, final: Bool) {
        if screen == .home { homeHeard = "“\(text)”" } else { care.heard = "“\(text)”" }
        guard final else { return }
        input.visible = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if screen == .home {
                // The story is told on the home screen; Lofer acknowledges, then the body takes over.
                let r = SymptomParser.parse(text)
                var probe = AssessmentState(); var learned = AssessmentService.update(&probe, with: r, expect: "story")
                if let e = r.entry, e.id != nil || r.side != nil { learned.append("region") }
                homeLine = AssessmentService.ack(probe, learned: learned).isEmpty ? "Thanks for telling me." : AssessmentService.ack(probe, learned: learned)
                homeContext = [SymptomParser.typeLabel(r.type).flatMap { r.type == "pain" ? nil : $0 }, r.activity.map { "after \($0)" }, r.onset].compactMap { $0 }.joined(separator: " · ")
                voice.speak(homeLine)
                try? await Task.sleep(for: .milliseconds(1400))
                withAnimation(Motion.slow) { screen = .care }
                await care.beginWithStory(text)
            } else {
                await care.hear(text)
            }
            voice.finishThinkingIfSilent()
        }
    }

    /// What the user would plausibly say next (offered as a one-tap suggestion while "listening").
    func suggestion() -> String {
        if screen == .home { defer { sampleIndex += 1 }; return Self.homeSamples[sampleIndex % Self.homeSamples.count] }
        let c = care
        if c.pendingSide != nil { return "The right one." }
        switch c.step {
        case .clarify:
            return ["story": "I played tennis yesterday and my shoulder has felt tight since.", "sensation": "It feels tight.", "triggers": "Mostly when I lift it above my head.",
                    "onset": "Since yesterday.", "severity": "Quite a lot.", "previous": "It’s happened before.", "safety": "No, none of those."][c.question?.field ?? ""] ?? "Okay."
        case .locate, .listening: return c.sel != nil ? "Yes, that’s it." : !c.lit.isEmpty ? "It’s actually more towards the back." : "My right shoulder."
        case .confirm: return "Yes, that’s right."
        case .correct: return "It’s more on the outside, actually."
        case .movement: return c.movementPhase == "after" ? "It feels easier now." : "It starts pulling about halfway."
        case .suggest: return "Keep it gentle, and a bit more heat."
        case .custom: return "Okay, let’s start."
        case .treat: return c.checkIn ? "That’s a little too strong." : "Can you focus slightly lower?"
        case .paused: return "Carry on."
        case .reassess: return "It definitely feels looser now."
        default: return "Thanks."
        }
    }
}
