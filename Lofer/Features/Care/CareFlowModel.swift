import SwiftUI
import Observation
import simd

/// THE CARE FLOW (state machine). One episode, from "how are you feeling?" to Body Memory:
///
///   listening → clarify (one question at a time) → locate (choose the spot on the body) →
///   confirm understanding [→ correct] → movement check → suggest [→ customise] →
///   treat ⇄ paused → movement check again → reassess → outcome → Body Memory
///   "stop" (safety) can happen from any step. Steps are skipped when not needed.
///
/// This model only orchestrates. Understanding = AssessmentService, safety = SafetyValidator,
/// plans = TreatmentEngine, hardware = DeviceInterface, memory = BodyMemoryStore.
/// Views read its state and call its actions; they never contain product logic.
@Observable @MainActor
final class CareFlowModel {
    enum Step: String { case listening, clarify, locate, confirm, correct, movement, suggest, custom, treat, paused, reassess, outcome, stop }
    struct Spot { var id: String; var p: SIMD3<Float>; var n: SIMD3<Float> }
    struct Care { var id: String; var point: Bool; var pair: String? = nil }
    struct PendingSide { var template: String; var noun: String; var both: Bool }

    // Dependencies (swappable: mock now, real later)
    @ObservationIgnored let memory: BodyMemoryStore
    @ObservationIgnored let intelligence: CareIntelligenceService
    @ObservationIgnored let device: DeviceInterface
    @ObservationIgnored let voice: MockVoiceAgent
    @ObservationIgnored let body: BodySceneController
    @ObservationIgnored private let atlas = BodyAtlas.shared
    @ObservationIgnored var onExit: (() -> Void)?                 // back to home
    @ObservationIgnored var onOpenReport: ((String?) -> Void)?    // physio summary for an area group

    // What the user sees
    var agentLine = "Show me where it's bothering you."
    var heard = ""
    var step: Step = .locate
    var bodyReady = false
    var viewOffHome = false
    var limbView: String?

    // Body selection
    var focus = "body"
    var cand: String?
    var sel: Spot?
    var lit: [String] = []
    var pendingSide: PendingSide?
    var care: Care?

    // Understanding
    var A = AssessmentState()
    var question: AssessmentQuestion?
    @ObservationIgnored private var expect: String?
    @ObservationIgnored private var trail: [Step] = []
    @ObservationIgnored private var startedAt = Date()

    // Suggestion + safety
    var tri: TriageResult?
    var sym: SymptomSnapshot?
    var options: [TreatmentPlan] = []
    var plan: TreatmentPlan?
    var validated: SafetyValidator.Validation?
    @ObservationIgnored private var history: [Episode] = []

    // Movement check
    var movementTest: MovementTest?
    var movementPhase = "before"
    @ObservationIgnored private var skipMovement = false

    // Treatment
    static let previewSpeed = 20.0      // the preview runs sessions 20× faster than real time
    var reading: DeviceReading?
    var totalSeconds: Double = 1
    var checkIn = false
    var pausedForWorse = false
    @ObservationIgnored private var checkAt: [Double] = []
    @ObservationIgnored private var nextCheck = 0
    @ObservationIgnored private var checkStarted = Date()
    @ObservationIgnored private var feedbackLog: [Episode.Feedback] = []
    @ObservationIgnored private var adjustments: [String] = []
    @ObservationIgnored private var runResult: (elapsed: Int, log: [Episode.LogEntry])?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    // Result
    var result: TreatmentEngine.Reassessment?
    var why = ""
    var routineSaved = false

    init(memory: BodyMemoryStore, intelligence: CareIntelligenceService, device: DeviceInterface, voice: MockVoiceAgent, body: BodySceneController) {
        self.memory = memory; self.intelligence = intelligence; self.device = device; self.voice = voice; self.body = body
        body.onReady = { [weak self] in Task { @MainActor in self?.bodyReady = true; self?.refresh() } }
        body.onTap = { [weak self] p, n in Task { @MainActor in self?.tapped(p, n) } }
        body.onViewChanged = { [weak self] off in Task { @MainActor in self?.viewOffHome = off } }
        bodyReady = body.isReady
    }

    // MARK: - Starting an episode
    func reset() {
        stopTicker(); _ = device.stop(); body.setPatches(around: []); body.setSpot(nil, normal: nil); body.setLimbView(nil, limb: nil)
        focus = "body"; cand = nil; sel = nil; lit = []; pendingSide = nil; care = nil
        A = AssessmentState(); question = nil; expect = nil; trail = []; startedAt = Date()
        tri = nil; sym = nil; options = []; plan = nil; validated = nil; history = []
        movementTest = nil; movementPhase = "before"; skipMovement = false
        reading = nil; checkIn = false; pausedForWorse = false; feedbackLog = []; adjustments = []; runResult = nil
        result = nil; why = ""; routineSaved = false; limbView = nil; heard = ""
    }
    /// Touch route: the body comes first, the story after.
    func beginWithBody() { reset(); step = .locate; say("Show me where it's bothering you."); body.frame("body", role: .select, turn: true); refresh() }
    /// Voice/text route: the story was told on the home screen.
    func beginWithStory(_ text: String) async {
        reset()
        heard = "“\(text)”"
        let r = await intelligence.interpret(text)
        var learned = AssessmentService.update(&A, with: r, expect: "story")
        let res = r.entry.flatMap { resolve(r, $0) }
        if case .id(let id)? = res { AssessmentService.setRegion(&A, id); learned.append("region") }
        step = .listening
        body.frame("body", role: .select, turn: true)
        if A.safetyFlags.contains(where: { $0.level == .urgent }) { return runTriage() }
        if let res { await applyTarget(res, advanceAfter: false) }
        advance(learned)
    }

    // MARK: - Hearing the user (voice or typed) — read against the current step
    func hear(_ text: String) async {
        heard = "“\(text)”"
        let r = await intelligence.interpret(text)
        let t = text.lowercased()
        switch step {
        case .clarify, .listening, .correct: return await understand(r)
        case .confirm:
            if r.isDescriptive { return await understand(r) }
            if r.deny { return correction() }
            if r.confirm { return confirmYes() }
            return say("Is that right? You can say yes, or tell me what to change.")
        case .movement:
            if t.has("skip") { return skipMovementCheck() }
            if let m = r.movement ?? (r.flags.isEmpty ? nil : MovementResult(feel: .cannot)) { return movementAnswer(m) }
            return say("How did that feel? Fine, a little uncomfortable, quite uncomfortable, or not comfortable at all?")
        case .suggest, .custom:
            if let p = r.prefs { return applyPrefs(p) }
            if r.start || r.confirm { return startTreatment() }
            if let d = r.direction, sel != nil { var p = TreatmentPrefs(); p.focus = d; return applyPrefs(p) }
            return say("You can say things like “more heat”, “keep it gentle” or “no electrical stimulation”. Say “start” when you're ready.")
        case .treat, .paused:
            if t.has("\\b(stop|end|finish)\\b") { return endRun() }
            if t.has("pause|hold on|wait"), step == .treat { device.pause(); step = .paused; return say("Paused.") }
            if t.has("resume|continue|carry on|go on"), step == .paused { return resumeRun(gentler: pausedForWorse) }
            if let f = r.prefs?.focus ?? (t.has("focus|move") ? r.direction : nil) { return moveFocus(f) }
            if let fb = r.feedback { return feedback(fb, via: "voice") }
            if let i = r.prefs?.intensity { return feedback(i < 0 ? "too strong" : "too weak", via: "voice") }
            return say("You can say “too strong”, “that feels good”, “move the focus lower”, or “stop”.")
        case .reassess:
            if let resp = r.response { return reassess(resp) }
            return say("Is it much better, a little better, about the same, or worse?")
        case .outcome, .stop:
            return say("Tap Done when you're finished.")
        case .locate:
            if r.isDescriptive && r.entry == nil {
                let learned = AssessmentService.update(&A, with: r, expect: nil)
                if r.flags.contains(where: { $0.level != .caution }) { return advance(learned) }
            }
            if r.zoom, let c = cand, !atlas.isLeaf(c) { return zoomIn(c) }
            if let e = r.entry, let res = resolve(r, e) { return await applyTarget(res) }
            if let ps = pendingSide, let s = r.side { return await applyTarget(.id(ps.template.replacingOccurrences(of: "{s}", with: s.rawValue))) }
            if let ps = pendingSide, r.bilateral || t.has("\\bboth\\b") { return confirmBoth(ps.template) }
            if r.confirm, sel != nil { return confirmSpot() }
            if r.confirm, cand != nil { return say("Should I zoom in, or take the whole area?") }
            if let w = r.turn { body.turn(to: w); return say("Turning you around.") }
            if let d = r.direction, sel != nil || cand != nil || !lit.isEmpty { return refine(d, slight: r.slight) }
            if r.direction != nil { return say("Tap roughly where it is first, then I can move it.") }
            if A.userDescription.isEmpty && (r.type != nil || r.activity != nil || r.onset != nil) { return await understand(r) }
            return say("You can tap the body, or say something like “slightly lower” or “my left calf”.")
        }
    }

    /// Everything said while Lofer is getting to know the problem.
    private func understand(_ r: ParsedUtterance) async {
        let t = r.raw.lowercased()
        // While answering a question, a body word only moves the area if it sounds like a correction.
        let relocate = r.entry != nil && (A.bodyRegion == nil || expect == nil || expect == "story" || t.has("actually|it'?s (my|in|on|more)|not (my|the)|rather|instead"))
        var learned = AssessmentService.update(&A, with: r, expect: expect)
        if let e = expect, !learned.isEmpty { A.asked.insert(e); A.questionsAsked += 1 }
        if relocate, let e = r.entry, let res = resolve(r, e) {
            if case .id(let id) = res, id != A.bodyRegion { learned.append("region") }
            await applyTarget(res, advanceAfter: false)
        } else if learned.isEmpty, let d = r.direction, sel != nil || !lit.isEmpty {
            refine(d, slight: r.slight, keepFlow: true); care = nil; A.regionConfirmed = false
            return say("Got it, \(sel.map { atlas[$0.id].spoken } ?? "there"). \(question?.text ?? "")")
        }
        if learned.isEmpty && step == .clarify { return say("Sorry, I didn't quite catch that. \(question?.text ?? "")") }
        advance(learned)
    }

    /// Decide the next step from what's known and what's missing. One question at a time.
    func advance(_ learned: [String] = [], skipAck: Bool = false) {
        if A.safetyFlags.contains(where: { $0.level != .caution }) { return runTriage() }
        let ack = skipAck ? "" : AssessmentService.ack(A, learned: learned)
        if let ps = pendingSide { go(.locate); expect = nil; return say(ack, ps.both ? "Is it both \(ps.noun)s, or one more than the other?" : "Which \(ps.noun) is it, left or right?") }
        let hc = A.bodyRegion.map { memory.history(for: $0).count } ?? 0
        let q = AssessmentService.nextQuestion(A, historyCount: hc)
        if q?.field == "region" { go(.locate); expect = nil; return say(ack, q!.text) }
        if let q { question = q; expect = q.field; go(.clarify); return say(ack, q.text) }
        if !A.regionConfirmed { go(.locate); expect = nil; return say(ack, locatePrompt) }
        go(.confirm); expect = nil
        say(confirmLine)
    }
    var confirmLine: String { "\(AssessmentService.summary(A)) Is that right?" }
    private var locatePrompt: String {
        if sel != nil { return "Here? Tap “That’s the spot”, or tell me which way to move it." }
        if !lit.isEmpty { return "Show me exactly where. Tap it, or say something like ‘more towards the back’." }
        return "Show me where it's bothering you."
    }
    private func go(_ s: Step) { if step != s { trail.append(step); step = s }; refresh() }

    // MARK: - Answers from chips
    func answerChip(_ field: String, _ value: String) {
        if field == "sensation" && value == "__other" { expect = "sensation"; return say("Tell me in your own words. Whatever comes to mind.") }
        AssessmentService.answer(&A, field: field, value: value); A.questionsAsked += 1
        let learned = ["sensation": ["sensation"], "triggers": value == "__rest" ? ["symptomsAtRest"] : value == "__none" ? [] : ["movementTriggers"], "onset": ["onset"]][field] ?? []
        advance(learned)
    }
    func answerSafety(_ labels: [String]) { AssessmentService.addSafetyAnswers(&A, labels); A.questionsAsked += 1; advance() }
    func confirmYes() { runTriage() }
    func correction() { go(.correct); say("No problem. What should I change? Tap one, or just tell me.") }
    func correct(_ what: String) {
        switch what {
        case "place": A.regionConfirmed = false; care = nil; go(.locate); return say(locatePrompt)
        case "feel": A.sensation = nil; A.sensationWords = nil; A.asked.remove("sensation")
        case "when": A.onset = nil; A.activityContext = nil; A.asked.remove("onset")
        default: A.movementTriggers = []; A.symptomsAtRest = nil; A.asked.remove("triggers")
        }
        A.questionsAsked = min(A.questionsAsked, AssessmentService.maxFollowUps - 1)
        advance(skipAck: true)
    }
    func backToSummary() { go(.confirm); say(confirmLine) }

    // MARK: - Safety gate
    private func runTriage() {
        let s = AssessmentService.symptom(A); sym = s
        let t = SafetyValidator.triage(s, profile: memory.profile); tri = t
        if t.level == .stop {
            go(.stop); saveEpisode(treated: false)
            return say(t.urgent ? "This needs medical attention rather than Lofer." : "I don't think Lofer should treat this one. Let me explain why.")
        }
        if A.movementBefore == nil && !skipMovement { return movementStep("before") }
        suggestStep()
    }

    // MARK: - Movement check (before and after)
    func movementStep(_ phase: String) {
        if movementTest == nil, let r = A.bodyRegion { movementTest = MovementTest.forArea(r) }
        guard let test = movementTest else { skipMovement = true; return phase == "before" ? suggestStep() : reassessStep() }
        movementPhase = phase; go(.movement)
        say(phase == "before" ? test.intro : "Let's try that movement again and see how it feels now?")
    }
    func movementAnswer(_ m: MovementResult) {
        if movementPhase == "after" { A.movementAfter = m; return reassessStep() }
        A.movementBefore = m
        // The safety layer decides what a difficult movement means (gentler care, or stop).
        sym = AssessmentService.symptom(A); tri = SafetyValidator.triage(sym!, profile: memory.profile)
        if tri?.level == .stop { go(.stop); saveEpisode(treated: false); return say("Thanks for trying. I don't think Lofer should treat this today.") }
        let detail = [m.whereInMovement, m.quality.map { "a \($0) feeling" }, m.sideOfIt.map { "on the \($0)" }].compactMap { $0 }.joined(separator: ", ")
        say([.fine: "Good, that helps.", .little: "Thanks. I've noted that\(detail.isEmpty ? "" : " (\(detail))").", .quite: "Thanks. I'll keep things gentle.", .cannot: "That's fine, no need to push it. I'll keep things gentle."][m.feel]!)
        Task { try? await Task.sleep(for: .milliseconds(900)); suggestStep() }
    }
    func skipMovementCheck() { skipMovement = true; movementPhase == "after" ? reassessStep() : suggestStep() }

    // MARK: - Suggest
    private func suggestStep() {
        guard let s = sym ?? Optional(AssessmentService.symptom(A)), let t = tri, let region = A.bodyRegion else { return }
        history = memory.history(for: region)
        let sug = TreatmentEngine.suggest(s, t, profile: memory.profile, history: history, routine: memory.routine(for: region, activity: s.activity))
        options = sug.options
        pick(sug.pick)
        go(.suggest)
        say("\(sug.headline) Would you like to try this, or is there something you'd change?")
    }
    func pick(_ p: TreatmentPlan) { plan = p; if let t = tri { validated = SafetyValidator.validate(p, t) }; refresh() }
    func applyPrefs(_ prefs: TreatmentPrefs) {
        guard let p = plan else { return }
        let (np, said) = TreatmentEngine.apply(prefs, to: p, profile: memory.profile)
        if let f = prefs.focus, sel != nil { refine(f, slight: true, keepFlow: true) }
        pick(np)
        let notes = validated?.notes.isEmpty == false ? " " + validated!.notes.joined(separator: " ") : ""
        say(said.isEmpty ? "Okay.\(notes)" : "Done: \(said.joined(separator: ", ")).\(notes)")
    }
    func openCustomise() { go(.custom); say("Change anything you like. I’ll keep it within safe limits.") }
    func closeCustomise() { go(.suggest) }
    func toggle(_ m: Modality) {
        guard var p = plan else { return }
        if p.steps.contains(where: { $0.modality == m }) { p.steps.removeAll { $0.modality == m } }
        else { let heatIdx = p.steps.firstIndex { $0.modality == .heat } ?? p.steps.endIndex; p.steps.insert(.init(modality: m, intensity: 2, minutes: 3), at: m == .heat ? p.steps.endIndex : heatIdx) }
        p.adjusted = true; if p.kind != .routine { p.kind = .custom }; pick(p)
    }
    func adjust(_ m: Modality, minutes: Int? = nil, intensity: Int? = nil) {
        guard var p = plan, let i = p.steps.firstIndex(where: { $0.modality == m }) else { return }
        if let v = minutes { p.steps[i].minutes = max(1, min(10, v)) }
        if let v = intensity { p.steps[i].intensity = max(1, min(5, v)) }
        p.adjusted = true; if p.kind != .routine { p.kind = .custom }; pick(p)
    }

    // MARK: - Treat
    func startTreatment() {
        guard let p = plan, let t = tri else { return }
        let v = SafetyValidator.validate(p, t); validated = v
        guard v.ok, let cmd = v.command else { go(.stop); return }
        device.start(cmd)                         // the only way anything reaches the device
        totalSeconds = Double(v.plan.minutes * 60)
        checkAt = TreatmentEngine.checkIns(history); nextCheck = 0; checkIn = false
        go(.treat)
        placePatches()
        say("Starting gently. Just tell me any time if it's too much.")
        startTicker()
    }
    /// The session runs on its own clock (not tied to drawing), so it keeps going if the screen redraws slowly.
    private func startTicker() {
        stopTicker()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tickSession(0.25)
            }
        }
    }
    private func stopTicker() { ticker?.cancel(); ticker = nil }
    private func tickSession(_ dt: Double) {
        guard step == .treat || step == .paused, let rd = device.tick(seconds: dt * Self.previewSpeed) else { return }
        reading = rd
        body.setPatchActivity(rd.modality, paused: rd.paused)
        let frac = rd.t / max(1, totalSeconds)
        if step == .treat && !checkIn && nextCheck < checkAt.count && frac >= checkAt[nextCheck] {
            checkIn = true; checkStarted = Date(); nextCheck += 1; say("How does this feel?")
        }
        if checkIn && Date().timeIntervalSince(checkStarted) > 14 { checkIn = false }      // no answer → carry on quietly
        if rd.done { endRun() }
    }
    func feedback(_ value: String, via: String = "tap") {
        guard let rd = reading, let t = tri else { return }
        feedbackLog.append(.init(t: Int(rd.t), value: value, via: via)); checkIn = false
        switch TreatmentEngine.feedbackAction(value) {
        case .level(let delta, let line)?:
            let change = SafetyValidator.validateLevel(rd.level + delta, modality: rd.modality, t)
            device.setIntensity(change)
            adjustments.append("Intensity \(rd.level) → \(change.intensity) (\(value))")
            say(change.capped && delta > 0 ? "That's as firm as I can safely go here." : line)
        case .pause(let line)?:
            device.pause(); step = .paused; pausedForWorse = true; say(line)
        case .keepGoing(let line)?: say(line)
        case nil: break
        }
    }
    func pauseOrResume() { if step == .paused { resumeRun(gentler: false) } else { device.pause(); step = .paused; refresh() } }
    func resumeRun(gentler: Bool) {
        if gentler, let rd = reading, let t = tri {
            let change = SafetyValidator.validateLevel(rd.level - 1, modality: rd.modality, t); device.setIntensity(change)
            adjustments.append("Paused after discomfort increased, resumed at level \(change.intensity)")
        }
        pausedForWorse = false; device.resume(); step = .treat; refresh()
        say(gentler ? "Carrying on more gently. Tell me straight away if it gets worse." : "Resuming.")
    }
    private func moveFocus(_ dir: String) {
        guard let s = sel, care?.point == true, let t = tri else { return say("This session covers the whole area, so there is nothing to move.") }
        refine(dir, slight: true, keepFlow: true)
        guard let new = sel, let change = SafetyValidator.validateRetarget(from: s.id, to: new.id, t) else { return say("I can only move the focus within the same area during a session.") }
        device.retarget(change); care?.id = new.id; placePatches()
        adjustments.append("Focus moved to \(atlas[new.id].label.lowercased())")
        say("Moved the focus \(["up": "higher", "down": "lower", "out": "further out", "in": "further in", "front": "toward the front", "back": "toward the back"][dir] ?? "").")
    }
    func endRun() {
        stopTicker()
        runResult = device.stop(); body.setPatches(around: []); checkIn = false
        if A.movementBefore != nil && !skipMovement { return movementStep("after") }
        reassessStep()
    }
    private func placePatches() {
        guard let c = care, let mesh = body.mesh else { return }
        var pts: [(SIMD3<Float>, SIMD3<Float>)] = []
        if c.point, let s = sel { pts.append((s.p, s.n)) } else if let r = mesh.representativePoint(of: c.id) { pts.append(r) }
        if let pr = c.pair, let r = mesh.representativePoint(of: pr) { pts.append(r) }
        body.setPatches(around: pts)
    }

    // MARK: - Reassess → learn / escalate
    private func reassessStep() { go(.reassess); say("All done. How does that feel now?") }
    func reassess(_ response: String) {
        let s = sym ?? AssessmentService.symptom(A)
        let r = TreatmentEngine.reassess(response: response, s, history: history); result = r
        // A plausible, hedged "why it might feel this way" (shown, and spoken by the voice agent).
        why = TreatmentEngine.explain(response: response, s, plan: validated?.plan, before: A.movementBefore, after: A.movementAfter)
        saveEpisode(treated: true, response: response)
        go(.outcome)
        say(r.headline, speak: "\(r.headline) \(why)")
    }
    func saveRoutine() {
        guard let r = result, let region = A.bodyRegion, let p = validated?.plan else { return }
        memory.saveRoutine(areaId: region, activity: A.activityContext, name: r.routineName, steps: p.steps); routineSaved = true
        say("Saved as your \(r.routineName.lowercased()). I'll suggest it next time.")
    }
    private func saveEpisode(treated: Bool, response: String? = nil) {
        let s = sym ?? AssessmentService.symptom(A)
        let spot = care?.point == true ? sel : nil
        let run = treated ? runResult : nil
        var e = Episode(id: "e\(Int(Date().timeIntervalSince1970))", createdAt: startedAt, said: A.userDescription,
                        point: spot.map { [$0.p.x, $0.p.y, $0.p.z] }, normal: spot.map { [$0.n.x, $0.n.y, $0.n.z] },
                        symptom: .init(areaId: s.areaId ?? "body", pairId: s.pairId, side: s.side, type: s.type, severity: s.severity, onset: s.onset,
                                       activity: s.activity, triggers: s.triggers, atRest: s.atRest, previous: s.previous, flags: s.flags.map(\.label)),
                        triage: .init(level: tri?.level.rawValue ?? "ok", reasons: tri?.reasons ?? []),
                        outcome: .init(response: response, pathway: treated ? (result?.pathway ?? "") : "not treated"))
        if let run, let v = validated {
            e.intervention = .init(planName: v.plan.name, kind: v.plan.kind, steps: v.plan.steps, minutesPlanned: v.plan.minutes, durationSec: run.elapsed,
                                   patches: device.activePatches, adjustments: adjustments, safetyNotes: v.notes, log: run.log)
            e.outcome.sensors = BodyMemoryStore.summarise(run.log)
            e.outcome.lofersNote = why.isEmpty ? nil : why
        }
        e.feedback = feedbackLog
        if let t = movementTest, A.movementBefore != nil { e.movement = .init(name: t.name, before: A.movementBefore, after: A.movementAfter) }
        memory.add(e)
    }

    // MARK: - Body selection (touch + voice share these)
    enum Target { case id(String), ask(PendingSide) }
    private func resolve(_ r: ParsedUtterance, _ e: ParsedUtterance.PartEntry) -> Target? {
        let side = r.side ?? (step == .listening ? nil : currentSide)
        if let tmpl = e.template, let side { return .id(tmpl.replacingOccurrences(of: "{s}", with: side.rawValue)) }
        if let tmpl = e.template, r.bilateral || A.laterality == "both" { return .ask(PendingSide(template: tmpl, noun: e.noun ?? "side", both: true)) }
        if let id = e.id { return .id(id) }
        if let tmpl = e.template { return .ask(PendingSide(template: tmpl, noun: e.noun ?? "side", both: false)) }
        return nil
    }
    private var currentSide: BodySide? { [sel?.id, cand, lit.first, focus].compactMap { $0 }.compactMap { atlas.node($0)?.side }.first }

    /// Show a place the user mentioned on the body; the conversation decides what Lofer says next.
    func applyTarget(_ target: Target, advanceAfter: Bool = true) async {
        switch target {
        case .ask(let ps):
            let a = ps.template.replacingOccurrences(of: "{s}", with: "r"), b = ps.template.replacingOccurrences(of: "{s}", with: "l")
            focus = atlas.lca(a, b); cand = nil; sel = nil; lit = [a, b]; pendingSide = ps; care = nil
            body.frame(focus, role: .select, turn: true); refresh()
            if advanceAfter { advance() }
        case .id(let id):
            pendingSide = nil
            if atlas.isLeaf(id), let rp = body.mesh?.representativePoint(of: id) {
                body.frame(atlas[id].parent!, role: role, turn: false)
                select(id, rp.point, rp.normal, keepCare: true)
            } else { focus = id; cand = nil; sel = nil; lit = [id]; care = nil; body.frame(id, role: .select, turn: true) }
            let changed = AssessmentService.setRegion(&A, id)
            refresh()
            if advanceAfter { advance(changed ? ["region"] : []) }
        }
    }
    func chooseSide(_ s: BodySide) { if let ps = pendingSide { Task { await applyTarget(.id(ps.template.replacingOccurrences(of: "{s}", with: s.rawValue))) } } }

    func goFocus(_ id: String) {
        focus = id; cand = nil; sel = nil; lit = []; pendingSide = nil; care = nil
        body.frame(id, role: .select, turn: true); refresh()
        say(id == "body" ? "Show me where it's bothering you." : "\(atlas[id].label). Where exactly?")
    }
    func preview(_ id: String) {
        cand = id; sel = nil; lit = []; pendingSide = nil; refresh()
        say(atlas.isLeaf(id) ? "\(AssessmentService.cap(atlas[id].spoken))?" : "\(atlas[id].label). Zoom in, or choose the whole area.")
    }
    func zoomIn(_ id: String) { goFocus(id) }
    func pickChild(_ id: String) {
        if atlas.isLeaf(id), let rp = body.mesh?.representativePoint(of: id) { select(id, rp.point, rp.normal); say("Here? \(AssessmentService.cap(atlas[id].spoken)).") }
        else { preview(id) }
    }
    private func select(_ id: String, _ p: SIMD3<Float>, _ n: SIMD3<Float>, keepCare: Bool = false) {
        let parent = atlas[id].parent ?? "body"
        let changed = parent != focus
        sel = Spot(id: id, p: p, n: n); cand = nil; lit = []; pendingSide = nil; focus = parent
        if !keepCare { care = nil }
        if changed { body.frame(parent, role: role, turn: false) }
        body.face(normal: n, at: p)
        refresh()
    }
    /// A tap on the body. Once a spot exists (or the place is being checked), the tap moves the spot there.
    private func tapped(_ p: SIMD3<Float>, _ n: SIMD3<Float>) {
        guard [.locate, .listening, .clarify, .confirm, .correct].contains(step) else { return }
        if sel != nil || care != nil || [.clarify, .confirm, .correct].contains(step) { return moveSpot(to: p, n) }
        let L = BodySDF.classify(p, n), path = atlas.path(to: L)
        let base = path.contains(focus) ? focus : atlas.lca(focus, L)
        if base != focus { focus = base; body.frame(base, role: .select, turn: true) }
        guard let i = path.firstIndex(of: base), i + 1 < path.count else { return }
        let next = path[i + 1]
        if next == L { select(L, p, n); return say("Here? \(AssessmentService.cap(atlas[L].spoken)).") }
        if cand == next { return zoomIn(next) }
        preview(next)
    }
    private func moveSpot(to p: SIMD3<Float>, _ n: SIMD3<Float>) {
        let L = BodySDF.classify(p, n), wasConfirmed = care != nil
        select(L, p, n, keepCare: true)
        if wasConfirmed { care = Care(id: L, point: true) }
        AssessmentService.setRegion(&A, L, confirmed: wasConfirmed)
        if step == .confirm { refresh(); return say(confirmLine) }
        if [.locate, .listening].contains(step) { say("Here? \(AssessmentService.cap(atlas[L].spoken)).") }
    }
    /// ↑ ↓ ← → pad: nudges the spot in SCREEN directions, so it moves the way the user sees it.
    func nudge(dx: Float, dy: Float) {
        guard let s = sel else { return }
        let ax = body.screenAxes()
        let q = BodySDF.snap(s.p + ax.right * dx * 0.022 + ax.up * dy * 0.022)
        moveSpot(to: q.point, q.normal)
    }
    /// Voice directions ("a bit lower", "more towards the back").
    func refine(_ dir: String, slight: Bool, keepFlow: Bool = false) {
        guard let mesh = body.mesh else { return }
        if sel == nil {
            // Only a whole area is lit → pick the part of it that lies that way.
            let area = cand ?? lit.first ?? focus
            let sx: Float = (mesh.stats[area]?.center.x ?? 1) >= 0 ? 1 : -1
            let score: (BodyMesh.AreaStats) -> Float = ["up": { $0.center.y }, "down": { -$0.center.y }, "front": { $0.normal.z }, "back": { -$0.normal.z },
                                                        "out": { $0.normal.x * sx }, "in": { -$0.normal.x * sx }, "L": { $0.center.x }, "R": { -$0.center.x }][dir] ?? { $0.center.y }
            guard let pick = atlas.leaves(of: area).filter({ mesh.stats[$0] != nil }).max(by: { score(mesh.stats[$0]!) < score(mesh.stats[$1]!) }),
                  let rp = mesh.representativePoint(of: pick) else { return }
            select(pick, rp.point, rp.normal, keepCare: keepFlow)
            if !keepFlow { say("Here? \(AssessmentService.cap(atlas[pick].spoken)).") }
            return
        }
        let s = sel!, sx: Float = s.p.x >= 0 ? 1 : -1
        let v: SIMD3<Float> = ["up": [0, 1, 0], "down": [0, -1, 0], "out": [sx, 0, 0], "in": [-sx, 0, 0], "front": [0, 0, 1], "back": [0, 0, -1], "L": [1, 0, 0], "R": [-1, 0, 0]][dir] ?? .zero
        let step: Float = dir == "front" || dir == "back" ? (slight ? 0.05 : 0.08) : (slight ? 0.026 : 0.045)
        let q = BodySDF.snap(s.p + v * step)
        let L = BodySDF.classify(q.point, q.normal)
        select(L, q.point, q.normal, keepCare: keepFlow)
        if !keepFlow { say(L == s.id ? "A little \(["down": "lower", "up": "higher", "out": "further out", "in": "further in", "front": "toward the front", "back": "toward the back"][dir] ?? "over"). Here?" : "Here? \(AssessmentService.cap(atlas[L].spoken)).") }
    }
    func confirmSpot() { guard let s = sel else { return }; care = Care(id: s.id, point: true); regionConfirmed(s.id) }
    func confirmArea(_ id: String) { care = Care(id: id, point: false); cand = nil; sel = nil; lit = []; pendingSide = nil; if !atlas.isLeaf(id) { body.frame(id, role: role, turn: true) }; regionConfirmed(id) }
    func confirmBoth(_ tmpl: String) {
        let a = tmpl.replacingOccurrences(of: "{s}", with: "r"), b = tmpl.replacingOccurrences(of: "{s}", with: "l")
        care = Care(id: a, point: false, pair: b); cand = nil; sel = nil; lit = [a, b]; pendingSide = nil
        regionConfirmed(a, pair: b)
    }
    private func regionConfirmed(_ id: String, pair: String? = nil) {
        let changed = AssessmentService.setRegion(&A, id, pair: pair, confirmed: true)
        advance(changed ? ["region"] : [])
    }

    /// ← always means "back one step".
    func goBack() {
        switch step {
        case .treat, .paused: return endRun()
        case .outcome, .stop: return onExit?() ?? ()
        case .reassess: return
        case .movement where movementPhase == "after": return
        case .locate, .listening:
            if care != nil { care = nil; refresh(); return say("Okay. Adjust it, or tap somewhere else.") }
            if cand != nil || sel != nil || !lit.isEmpty || pendingSide != nil { cand = nil; sel = nil; lit = []; pendingSide = nil; refresh(); return say("Okay. Tap where it bothers you.") }
            if focus == "body" { return onExit?() ?? () }
            return goFocus(atlas[focus].parent ?? "body")
        default:
            let prev = trail.popLast() ?? .locate
            step = prev
            if prev == .locate || prev == .listening { care = nil; A.regionConfirmed = false }
            refresh()
            say(prev == .clarify ? (question?.text ?? "") : prev == .confirm ? confirmLine : prev == .movement ? (movementTest?.intro ?? "") : prev == .suggest ? "Here’s what I’d suggest." : locatePrompt)
        }
    }

    // MARK: - Body view tools
    var limb: String? { atlas.path(to: focus).first { $0.has("^[rl]_(arm|leg)$") } }
    func setLimbView(_ v: String?) { limbView = limbView == v ? nil : v; body.setLimbView(limbView, limb: limb) }
    func resetView() { limbView = nil; body.resetView() }

    // MARK: - Keeping the body in sync with the conversation
    var role: BodyRole {
        switch step {
        case .locate, .listening: return .select
        case .treat, .paused: return .treat
        case .clarify: return .clarify
        case .confirm, .correct: return .confirm
        case .movement: return .movement
        case .suggest, .custom, .stop: return .suggest
        case .reassess, .outcome: return .result
        }
    }
    func refresh() {
        guard bodyReady, let mesh = body.mesh else { return }
        var states = [Float](repeating: 0, count: atlas.leaves.count)
        for (i, c) in atlas[focus].children.filter({ mesh.hasArea($0) }).enumerated() {
            for l in atlas.leaves(of: c) { if let k = atlas.leafIndex[l] { states[k] = i % 2 == 1 ? 1.28 : 1 } }
        }
        func setAll(_ id: String, _ v: Float) { for l in atlas.leaves(of: id) { if let k = atlas.leafIndex[l] { states[k] = v } } }
        lit.forEach { setAll($0, 2.2) }
        if let c = cand { setAll(c, 2.2) }
        if let c = care, !c.point { setAll(c.id, 2.2); if let p = c.pair { setAll(p, 2.2) } }
        if let s = sel, let k = atlas.leafIndex[s.id] { states[k] = 3 }
        if let c = care, step == .treat || step == .paused { setAll(c.id, 2.3); if let p = c.pair { setAll(p, 2.3) } }
        body.setHighlights(states)
        body.setSpot(sel.map { $0.p }, normal: sel.map { $0.n })
        body.frame(focus, role: role, turn: false)
    }

    // MARK: - Speaking
    /// Everything Lofer says appears in the information zone and goes through the voice agent.
    func say(_ parts: String..., speak: String? = nil) {
        let text = parts.filter { !$0.isEmpty }.joined(separator: " ")
        guard !text.isEmpty else { return }
        heard = ""                        // one message at a time
        withAnimation(.easeOut(duration: 0.25)) { agentLine = text }
        voice.speak(speak ?? text)
    }
}
