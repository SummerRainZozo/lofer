import XCTest
@testable import Lofer

/// Pass 1: the care flow handles warning signs, answers and outcomes consistently.
/// These drive the real CareFlowModel step by step (not just helper functions), with a
/// simulated device and a fresh, empty Body Memory for each test.
@MainActor
final class CareFlowSafetyTests: XCTestCase {

    // MARK: - Helpers

    /// A fresh model. `samples: false` empties Body Memory (it seeds sample episodes by default).
    private func makeModel(samples: Bool = false, intelligence: CareIntelligenceService = LocalCareIntelligenceService())
        -> (model: CareFlowModel, memory: BodyMemoryStore, device: MockLoferDevice) {
        let memory = BodyMemoryStore(defaults: UserDefaults(suiteName: "lofer.tests.\(UUID().uuidString)")!)
        if !samples { memory.clear() }
        let device = MockLoferDevice()
        let model = CareFlowModel(memory: memory, intelligence: intelligence, device: device, voice: MockVoiceAgent(), body: BodySceneController())
        model.reset()
        return (model, memory, device)
    }

    /// A described, confirmed right-shoulder tightness, ready for the safety gate.
    private func describeShoulder(_ model: CareFlowModel) {
        AssessmentService.setRegion(&model.A, "r_sh_front", confirmed: true)
        model.A.userDescription = ["My right shoulder is tight after tennis."]
        model.A.sensation = "tightness"; model.A.severity = 3; model.A.onset = "yesterday"; model.A.activityContext = "tennis"
        model.A.movementTriggers = ["Raising the arm overhead"]; model.A.previousEpisodes = false
    }
    /// Summary confirmed → movement check (before).
    private func toMovement(_ model: CareFlowModel) {
        describeShoulder(model); model.confirmYes()
        XCTAssertEqual(model.step, .movement)
    }
    /// … → movement answered → (investigation decides it's enough) → summary confirmed → suggestion.
    private func toSuggestion(_ model: CareFlowModel) async {
        toMovement(model); model.movementAnswer(.init(feel: .little))
        await model.settle()
        XCTAssertEqual(model.step, .confirm, "Enough information: Lofer summarises what it checked")
        model.confirmYes()
        XCTAssertEqual(model.step, .suggest)
    }
    /// … → session running, with a first reading.
    private func toTreatment(_ model: CareFlowModel, _ device: MockLoferDevice) async {
        await toSuggestion(model); model.startTreatment()
        XCTAssertEqual(model.step, .treat); XCTAssertTrue(device.isRunning)
        model.reading = device.tick(seconds: 30)
    }

    // MARK: - 4. Negation and ambiguity

    func testNegatedUncertainAndReportedNumbness() {
        let no = SymptomParser.parse("No numbness.")
        XCTAssertTrue(no.flags.isEmpty, "“no numbness” must not report numbness")
        XCTAssertEqual(no.negatedFlags.map(\.label), ["Numbness or tingling"])

        let unsure = SymptomParser.parse("I'm not sure if it is numb.")
        XCTAssertTrue(unsure.flags.isEmpty)
        XCTAssertEqual(unsure.uncertainFlags.map(\.label), ["Numbness or tingling"])

        let new = SymptomParser.parse("There's some new numbness in my hand.")
        XCTAssertEqual(new.flags.map(\.level), [.stop])
    }
    func testNegationOnlyCountsNearTheSign() {
        XCTAssertFalse(SymptomParser.parse("Not long after tennis my arm went numb.").flags.isEmpty, "A distant “not” must not cancel a warning sign")
        let mixed = SymptomParser.parse("No swelling, but it is numb.")
        XCTAssertEqual(mixed.flags.map(\.label), ["Numbness or tingling"])
        XCTAssertEqual(mixed.negatedFlags.map(\.label), ["Swelling, bruising or deformity"])
    }
    func testNotWorseIsNotWorse() {
        XCTAssertNotEqual(SymptomParser.parse("It's not worse, just the same.").feedback, "worse")
        XCTAssertNotEqual(SymptomParser.parse("No worse than before.").response, "worse")
        XCTAssertEqual(SymptomParser.parse("It's getting worse.").feedback, "worse")
    }

    // MARK: - 3. Answer statuses

    func testSafetyAnswerStatuses() {
        func status(_ text: String) -> AnswerStatus? {
            var A = AssessmentState()
            _ = AssessmentService.update(&A, with: SymptomParser.parse(text), expect: "safety")
            return A.answers["safety"]
        }
        XCTAssertEqual(status("No, none of those."), .negative)
        XCTAssertEqual(status("No numbness."), .negative)
        XCTAssertEqual(status("Not sure."), .uncertain)
        XCTAssertEqual(status("Not sure if it is numb."), .uncertain)
        XCTAssertEqual(status("Yes, my fingers are tingling."), .affirmative)
        XCTAssertEqual(status("Skip."), .skipped)
        XCTAssertNil(status("It started yesterday."), "An unrelated reply leaves the question unanswered")
    }
    func testUnrelatedReplyDoesNotAnswerTheQuestionAndUnsureDefers() async {
        let (model, _, device) = makeModel()
        await model.beginWithStory("My right shoulder has a sharp pain.")
        XCTAssertEqual(model.question?.field, "safety")

        await model.hear("It started yesterday.")
        XCTAssertEqual(model.step, .clarify)
        XCTAssertEqual(model.question?.field, "safety", "Still waiting for the safety answer")
        XCTAssertNil(model.A.answers["safety"])

        await model.hear("I'm not sure.")
        XCTAssertEqual(model.step, .stop)
        XCTAssertEqual(model.tri?.deferred, true, "“Not sure” defers care; it never clears it")
        XCTAssertFalse(device.isRunning)
    }
    func testSkippedSafetyCheckDefersAndCanBeRevisited() async {
        let (model, _, _) = makeModel()
        describeShoulder(model); model.A.sensation = "sharp"
        model.skipSafety()
        XCTAssertEqual(model.step, .stop)
        XCTAssertEqual(model.tri?.deferred, true)
        model.revisitSafety()
        await model.settle()
        XCTAssertEqual(model.question?.field, "safety")
        model.answerSafety([])                     // "None of these"
        await model.settle()
        XCTAssertEqual(model.A.answers["safety"], .negative)
        XCTAssertNotEqual(model.step, .stop)
    }

    // MARK: - 1 & 2. Warning signs first, at every active stage

    func testWarningSignDuringMovementKeepsTheSign() async {
        let (model, _, _) = makeModel()
        toMovement(model)
        await model.hear("I tried, but now my arm feels numb.")
        XCTAssertEqual(model.step, .stop)
        XCTAssertNil(model.A.movementBefore, "A warning sign is not turned into “couldn’t do the movement”")
        XCTAssertTrue(model.tri?.reasons.contains("Numbness or tingling") ?? false)
    }
    func testUrgentSignDuringSuggestionStaysUrgent() async {
        let (model, _, device) = makeModel()
        await toSuggestion(model)
        await model.hear("Actually I have chest pain and I'm short of breath.")
        XCTAssertEqual(model.step, .stop)
        XCTAssertEqual(model.tri?.urgent, true)
        XCTAssertFalse(device.isRunning)
    }
    func testCautionSignDuringSuggestionTightensThePlan() async {
        let (model, _, _) = makeModel()
        await toSuggestion(model)
        await model.hear("It's quite sharp actually.")
        XCTAssertEqual(model.step, .suggest)
        XCTAssertEqual(model.tri?.level, .caution)
        XCTAssertLessThanOrEqual(model.validated?.plan.steps.map(\.intensity).max() ?? 0, model.tri?.maxIntensity ?? 0)
    }
    func testWarningSignDuringTreatmentStopsTheDeviceFirst() async {
        let (model, memory, device) = makeModel()
        await toTreatment(model, device)
        await model.hear("My fingers have gone numb.")
        XCTAssertFalse(device.isRunning, "The session stops before anything else")
        XCTAssertEqual(model.step, .stop)
        let saved = memory.all.first
        XCTAssertNotNil(saved?.intervention, "What actually ran is still recorded")
        XCTAssertEqual(saved?.outcome.pathway, "stopped")
        XCTAssertNotNil(saved?.outcome.stopReason)
    }
    func testWarningSignWhilePausedStops() async {
        let (model, _, device) = makeModel()
        await toTreatment(model, device)
        model.pauseOrResume()
        XCTAssertEqual(model.step, .paused)
        await model.hear("My knee is swollen now.")
        XCTAssertEqual(model.step, .stop)
        XCTAssertFalse(device.isRunning)
    }
    func testWarningSignAfterTheOutcomeUpdatesTheSameEpisode() async {
        let (model, memory, device) = makeModel()
        await toTreatment(model, device)
        model.endRun()
        model.movementAnswer(.init(feel: .fine))     // movement check after
        model.reassess("little")
        XCTAssertEqual(model.step, .outcome)
        await model.hear("Now my hand is tingling.")
        XCTAssertEqual(model.step, .stop)
        XCTAssertEqual(memory.all.count, 1, "Same episode, updated, not a second one")
        XCTAssertTrue(memory.all[0].symptom.flags.contains("Numbness or tingling"))
    }

    // MARK: - 8. "Too strong" is not worsening; worsening needs a check before resuming

    func testTooStrongLowersIntensityAndKeepsGoing() async {
        let (model, _, device) = makeModel()
        await toTreatment(model, device)
        let before = model.reading!.level
        model.feedback("too strong")
        XCTAssertEqual(model.step, .treat)
        XCTAssertFalse(model.pausedForWorse)
        XCTAssertLessThan(device.tick(seconds: 1)!.level, before)
    }
    func testWorseCannotBeResumedWithoutTheSettleCheck() async {
        let (model, _, device) = makeModel()
        await toTreatment(model, device)
        model.feedback("worse")
        XCTAssertEqual(model.step, .paused); XCTAssertTrue(model.pausedForWorse)

        model.pauseOrResume()                        // the Resume button
        XCTAssertEqual(model.step, .paused, "No way round the check")
        await model.hear("Carry on.")
        XCTAssertEqual(model.step, .paused, "“Carry on” alone doesn't answer “has it settled?”")

        model.stillWorse()
        XCTAssertFalse(device.isRunning)
        XCTAssertEqual(model.step, .outcome)
        XCTAssertEqual(model.result?.pathway, "escalate")
        XCTAssertEqual(model.result?.pausesAutomaticCare, true)
    }
    func testSettledResumesMoreGently() async {
        let (model, _, device) = makeModel()
        await toTreatment(model, device)
        model.feedback("worse")
        model.settled()
        XCTAssertEqual(model.step, .treat)
        XCTAssertFalse(model.pausedForWorse)
    }

    // MARK: - 6 & 7. Reassessment uses all the evidence, and doesn't explain worsening away

    func testMovementGettingWorseOverridesFeelingBetter() {
        let s = SymptomSnapshot(areaId: "r_sh_front", type: "tightness", activity: "tennis")
        let r = TreatmentEngine.reassess(response: "much", s, history: [],
                                         movement: .init(name: "Arm raise", before: .init(feel: .little), after: .init(feel: .quite)))
        XCTAssertEqual(r.pathway, "review")
        XCTAssertTrue(r.escalate)
        XCTAssertFalse(r.offerRoutine)
        XCTAssertTrue(r.pausesAutomaticCare)
        XCTAssertTrue(r.headline.contains("movement felt worse"))
    }
    func testMovementWorseInTheFlowSkipsTheExplanation() async {
        let (model, _, device) = makeModel()
        await toTreatment(model, device)
        model.endRun()
        model.movementAnswer(.init(feel: .cannot))   // worse than “a little” before
        model.reassess("much")
        XCTAssertEqual(model.result?.pathway, "review")
        XCTAssertTrue(model.why.isEmpty, "No reassuring “why” when the evidence conflicts")
    }
    func testNoNormalisingWorseningOrPromisingAnotherSession() {
        let s = SymptomSnapshot(areaId: "r_sh_front", type: "tightness", activity: "tennis")
        XCTAssertTrue(TreatmentEngine.explain(response: "worse", s, plan: nil, before: nil, after: nil).isEmpty)
        for resp in ["much", "little", "same"] {
            let text = TreatmentEngine.reassess(response: resp, s, history: []).body + " "
                + TreatmentEngine.explain(response: resp, s, plan: nil, before: .init(feel: .little), after: .init(feel: .quite))
            XCTAssertFalse(text.has("often helps|will help|keep improving|that'?s normal|quite common|settles within"), "\(resp): \(text)")
        }
    }

    // MARK: - 9. A stated pause on automatic care is enforced

    func testPausedAutomaticCareIsEnforced() {
        let (model, memory, device) = makeModel()
        memory.add(Episode(id: "earlier", createdAt: Date().addingTimeInterval(-86400), said: ["It got worse."],
                           symptom: .init(areaId: "r_sh_back"), triage: .init(level: "ok", reasons: []),
                           outcome: .init(response: "worse", pathway: "escalate", pausesAutomaticCare: true)))
        describeShoulder(model); model.confirmYes()
        XCTAssertEqual(model.step, .stop)
        XCTAssertTrue(model.tri?.reasons.contains { $0.contains("paused") } ?? false)
        model.startTreatment()
        XCTAssertFalse(device.isRunning)
    }

    // MARK: - 10. Stale work is dropped

    func testInterpretationFinishingAfterAResetIsIgnored() async {
        let (model, _, _) = makeModel(intelligence: SlowIntelligence())
        model.beginWithBody()
        let pending = Task { await model.hear("My right knee is swollen.") }
        try? await Task.sleep(for: .milliseconds(50))
        model.reset()                                // the user leaves before it finishes
        await pending.value
        XCTAssertTrue(model.A.safetyFlags.isEmpty)
        XCTAssertNil(model.tri)
    }
    func testNewerInputSupersedesOlderInput() async {
        let (model, _, _) = makeModel(intelligence: SlowIntelligence())
        model.beginWithBody()
        let first = Task { await model.hear("My right knee is swollen.") }
        try? await Task.sleep(for: .milliseconds(50))
        await model.hear("Sorry, it's my left calf.")
        await first.value
        XCTAssertTrue(model.A.safetyFlags.isEmpty, "The older, superseded input must not apply")
    }

    // MARK: - 11. Saving is idempotent

    func testReassessingTwiceSavesOnce() async {
        let (model, memory, device) = makeModel()
        await toTreatment(model, device)
        model.endRun()
        model.movementAnswer(.init(feel: .fine))
        model.reassess("little"); model.reassess("little")
        XCTAssertEqual(memory.all.count, 1)
    }

    // MARK: - 12. Sample history doesn't inform real decisions

    func testSamplesAreExcludedFromDecisionsOutsideDemoMode() {
        let (_, memory, _) = makeModel(samples: true)
        XCTAssertFalse(memory.all.isEmpty, "Samples are still there for History")
        XCTAssertTrue(memory.history(for: "r_sh_front").isEmpty)
        memory.samplesInformDecisions = true          // explicit demo mode
        XCTAssertFalse(memory.history(for: "r_sh_front").isEmpty)
    }

    // MARK: - Compatibility

    func testOlderSavedEpisodesStillLoad() throws {
        let e = Episode(id: "old", createdAt: Date(), said: [], symptom: .init(areaId: "r_sh_front"), triage: .init(level: "ok", reasons: []),
                        outcome: .init(response: "much", pathway: "positive", stopReason: "x", pausesAutomaticCare: true))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(e)) as! [String: Any]
        var outcome = json["outcome"] as! [String: Any]
        outcome.removeValue(forKey: "stopReason"); outcome.removeValue(forKey: "pausesAutomaticCare")
        json["outcome"] = outcome
        let decoded = try JSONDecoder().decode(Episode.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.outcome.pausesAutomaticCare)
        XCTAssertEqual(decoded.outcome.response, "much")
    }
}

/// Interprets like the real parser, but slowly, so tests can interrupt it.
private struct SlowIntelligence: CareIntelligenceService {
    func respond(to request: CareRequest) async throws -> CareIntelligenceResponse {
        try? await Task.sleep(for: .milliseconds(300))
        return LocalCareIntelligenceService.response(to: request)
    }
}
