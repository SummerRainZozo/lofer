import XCTest
@testable import Lofer

/// Phase 2–3: the iterative investigation. Driven through the real CareFlowModel with the
/// on-device Care Intelligence (offline, deterministic) or a stub provider, a simulated
/// device and a fresh Body Memory. The backend's mock provider is covered by
/// EndToEndBackendTests and backend/tests.
@MainActor
final class InvestigationTests: XCTestCase {
    static let tennis = "I played tennis for two hours yesterday. The back of my right shoulder started feeling tight afterwards. It's mostly okay normally but hurts a little when I lift my arm above my head."

    private func makeModel(intelligence: CareIntelligenceService = LocalCareIntelligenceService(), profile: ((inout UserProfile) -> Void)? = nil)
        -> (model: CareFlowModel, memory: BodyMemoryStore, device: MockLoferDevice) {
        let memory = BodyMemoryStore(defaults: UserDefaults(suiteName: "lofer.tests.\(UUID().uuidString)")!)
        memory.clear()
        if let profile { memory.updateProfile(profile) }
        let device = MockLoferDevice()
        let model = CareFlowModel(memory: memory, intelligence: intelligence, device: device, voice: MockVoiceAgent(), body: BodySceneController())
        model.reset()
        return (model, memory, device)
    }
    /// What Lofer is asking about right now ("side", "region", a question field…), if anything.
    private func asking(_ m: CareFlowModel) -> String? {
        if m.pendingSide != nil { return "side" }
        if m.step == .clarify { return m.question?.field }
        if m.step == .locate { return m.A.bodyRegion == nil ? "region" : "spot" }
        return nil
    }

    // MARK: 1. Information extraction / preservation

    func testShortStoryIsUnderstoodAndNotReasked() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory("My right shoulder became tight after tennis yesterday.")
        XCTAssertEqual(m.A.laterality, "right")
        XCTAssertEqual(m.A.activityContext, "tennis")
        XCTAssertEqual(m.A.onset, "yesterday")
        XCTAssertEqual(m.A.sensation, "tightness")
        XCTAssertNotNil(m.A.bodyRegion)
        XCTAssertFalse(["side", "region", "onset", "sensation"].contains(asking(m) ?? ""), "Asked about \(asking(m) ?? "")")
    }

    // MARK: 2. Detailed input

    func testDetailedStoryIsPreserved() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory(Self.tennis)
        XCTAssertEqual(m.A.bodyRegion, "r_sh_back")
        XCTAssertEqual(m.A.laterality, "right")
        XCTAssertEqual(m.A.specificArea, "back")
        XCTAssertEqual(m.A.activityContext, "tennis")
        XCTAssertEqual(m.A.activityDuration, "two hours")
        XCTAssertEqual(m.A.onset, "yesterday")
        XCTAssertEqual(m.A.sensation, "tightness")
        XCTAssertEqual(m.A.symptomsAtRest, "minimal")
        XCTAssertEqual(m.A.movementTriggers, ["Raising the arm overhead"])
        XCTAssertLessThanOrEqual(m.A.severity ?? 10, 3)
        XCTAssertEqual(m.step, .locate, "The one useful next step: show where it's most noticeable")
    }

    // MARK: 3. Context preservation

    func testSecondInputUpdatesTheSameState() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory("My right knee hurts.")
        let evidenceBefore = m.investigation.evidence.count
        let checksBefore = m.investigation.checks.count
        m.confirmArea(m.A.bodyRegion!)
        await m.settle()
        await m.hear("It's more of a dull ache.")
        XCTAssertEqual(m.A.bodyRegion, "r_knee", "Earlier facts kept")
        XCTAssertEqual(m.A.laterality, "right")
        XCTAssertEqual(m.A.sensation, "ache", "New fact added")
        XCTAssertGreaterThan(m.investigation.evidence.count, evidenceBefore, "Same investigation, more evidence")
        XCTAssertGreaterThan(m.investigation.checks.count, checksBefore)
        XCTAssertGreaterThanOrEqual(m.investigation.cycles, 3)
    }

    // MARK: 4. Iterative investigation

    func testLocationThenQuestionThenMovementThenProceed() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory("My right knee hurts.")
        XCTAssertEqual(asking(m), "spot", "1: where exactly")
        m.confirmArea(m.A.bodyRegion!)
        await m.settle()
        XCTAssertEqual(asking(m), "sensation", "2: what it feels like")
        m.answerChip("sensation", "ache")
        await m.settle()
        XCTAssertEqual(m.step, .movement, "3: a movement check")
        XCTAssertEqual(m.movementTest?.id, "mini_squat")
        m.movementAnswer(.init(feel: .little, whereInMovement: "about halfway"))
        await m.settle()
        XCTAssertEqual(m.step, .confirm, "4: enough information")
        XCTAssertEqual(m.investigation.readiness.informationSufficiency, .sufficient)
        XCTAssertEqual(m.investigation.checks.map(\.kind), [.location, .question, .movement])
    }

    func testObservationRoundTripsThroughTheLoop() async {
        let observation = InvestigationAction.requestUserObservation(.init(observationId: "eases_when_stopped", prompt: "Did it ease when you stopped?",
                                                                           purpose: "Whether it settles", options: [.init(label: "Yes, it eased", value: "eased"), .init(label: "It lingered", value: "lingered")]))
        let stub = StubIntelligence(script: [nil, nil, observation])   // after the movement, ask for an observation
        let (m, _, _) = makeModel(intelligence: stub)
        await m.beginWithStory("My right knee aches.")
        m.confirmArea(m.A.bodyRegion!); await m.settle()
        XCTAssertEqual(m.step, .movement)
        m.movementAnswer(.init(feel: .little)); await m.settle()
        XCTAssertEqual(m.question?.field, "observation:eases_when_stopped")
        await m.hear("Yes, it eased.")
        await m.settle()
        XCTAssertEqual(m.investigation.checks.last { $0.kind == .observation }?.response, "Yes, it eased")
        XCTAssertTrue(m.investigation.evidence.contains { $0.source == .userObservation && $0.value == "eased" })
        XCTAssertEqual(m.step, .confirm)
    }

    // MARK: 5. Location refinement

    func testLocationRefinementIsStructuredEvidence() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory(Self.tennis)
        m.confirmArea("r_sh_back")
        XCTAssertTrue(m.A.regionConfirmed)
        XCTAssertEqual(m.investigation.checks.last?.kind, .location)
        XCTAssertEqual(m.investigation.checks.last?.response, BodyAtlas.shared["r_sh_back"].label)
        XCTAssertTrue(m.investigation.evidence.contains { $0.source == .location && $0.value == "r_sh_back" })
    }

    // MARK: 6. Movement observation

    func testMovementResultBecomesEvidence() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory(Self.tennis)
        m.confirmArea("r_sh_back"); await m.settle()
        XCTAssertEqual(m.step, .movement)
        XCTAssertEqual(m.movementTest?.id, "arm_raise")
        m.movementAnswer(.init(feel: .little, whereInMovement: "about halfway", quality: "pulling"))
        let baseline = m.investigation.baseline
        XCTAssertEqual(baseline?.outcome, .mildDiscomfort)
        XCTAssertEqual(baseline?.whereInMovement, "about halfway")
        XCTAssertTrue(m.investigation.evidence.contains { $0.source == .movementCheck && $0.value == "mildDiscomfort" })
    }

    func testAnUncomfortableMovementIsNotRepeated() async {
        let (m, _, _) = makeModel()
        await m.beginWithStory(Self.tennis)
        m.confirmArea("r_sh_back"); await m.settle()
        m.movementAnswer(.init(feel: .quite)); await m.settle()
        let ctx = InvestigationEngine.Context(A: m.A, investigation: m.investigation, movement: m.movementTest)
        let again = InvestigationAction.movementCheck(.init(movementId: "arm_raise", phase: .baseline, purpose: "again", targetObservation: ""))
        XCTAssertFalse(InvestigationEngine.isValid(again, ctx))
    }

    // MARK: 7. Safety overrides Care Intelligence

    func testProceedToCareIsBlockedBySafety() async {
        // A provider that always says "proceed", for someone with a clotting condition and calf pain.
        let stub = StubIntelligence(always: .proceedToCare(.init(reason: "Looks fine")))
        let (m, _, device) = makeModel(intelligence: stub) { $0.clotting = true }
        await m.beginWithStory("My left calf is tight.")
        m.confirmArea("l_calf")
        await m.settle()
        XCTAssertEqual(m.step, .stop)
        XCTAssertTrue(m.tri?.reasons.contains { $0.contains("clotting") } ?? false)
        m.startTreatment()
        XCTAssertFalse(device.isRunning, "Treatment must not start")
    }

    func testEngineSafetyOutranksProposal() {
        var A = AssessmentState(); AssessmentService.setRegion(&A, "r_knee", confirmed: true); A.sensation = "ache"
        A.safetyFlags = [.init(level: .stop, label: "Swelling, bruising or deformity")]
        let triage = SafetyValidator.triage(AssessmentService.symptom(A), profile: UserProfile())
        let (action, overridden) = InvestigationEngine.decide(proposal: .proceedToCare(.init(reason: "x")),
                                                              .init(A: A, investigation: InvestigationState(), triage: triage))
        XCTAssertEqual(action.type, "safetyStop")
        XCTAssertNotNil(overridden)
    }

    func testEngineNeverReasksSomethingKnown() {
        var A = AssessmentState(); AssessmentService.setRegion(&A, "r_sh_back", confirmed: true)
        A.onset = "yesterday"; A.sensation = "tightness"
        let ask = InvestigationAction.askQuestion(.init(field: "onset", question: "When did it start?", purpose: "x"))
        let (action, _) = InvestigationEngine.decide(proposal: ask, .init(A: A, investigation: InvestigationState(), movement: MovementTest.forArea("r_sh_back")))
        XCTAssertNotEqual(action, ask)
        XCTAssertEqual(action.type, "movementCheck")
    }

    // MARK: 8. Insufficient information

    func testCanConcludeThereIsNotEnoughInformation() async {
        let (m, memory, device) = makeModel(intelligence: StubIntelligence(always: InvestigationEngine.insufficient("Too vague")))
        await m.beginWithStory("I just feel a bit off.")
        XCTAssertEqual(m.step, .stop)
        XCTAssertEqual(m.conclusion?.type, "insufficientInformation")
        XCTAssertFalse(device.isRunning)
        XCTAssertEqual(memory.all.first?.investigation?.conclusion, "Too vague")
    }

    func testBudgetEndsInDeferralNotClearance() {
        var inv = InvestigationState(); inv.cycles = InvestigationEngine.Limits.cycles
        var A = AssessmentState(); AssessmentService.setRegion(&A, "r_knee")
        let (action, _) = InvestigationEngine.decide(proposal: .proceedToCare(.init(reason: "x")), .init(A: A, investigation: inv))
        XCTAssertEqual(action.type, "insufficientInformation")
    }

    // MARK: 9. Do not treat

    func testCanRecommendAProfessionalInsteadOfTreating() async {
        let message = "This has been there a while. It's worth having it looked at."
        let stub = StubIntelligence(always: .recommendProfessionalAssessment(.init(reason: "Persistent, at rest", message: message)))
        let (m, _, device) = makeModel(intelligence: stub)
        await m.beginWithStory("My lower back has hurt all the time for months.")
        XCTAssertEqual(m.step, .stop)
        XCTAssertEqual(m.conclusion?.type, "recommendProfessionalAssessment")
        XCTAssertEqual(m.agentLine, message)
        m.startTreatment()
        XCTAssertFalse(device.isRunning)
    }

    // MARK: 10–11. Reassessment and Body Memory: one session, state → investigation → observation → intervention → outcome

    func testFullSessionIsRecordedAsOneEpisode() async throws {
        let (m, memory, device) = makeModel()
        await m.beginWithStory(Self.tennis)
        m.confirmArea("r_sh_back"); await m.settle()
        m.movementAnswer(.init(feel: .little, whereInMovement: "about halfway")); await m.settle()
        XCTAssertEqual(m.step, .confirm)
        m.confirmYes()
        XCTAssertEqual(m.step, .suggest)
        XCTAssertTrue(m.plan?.reason?.contains("arm raise") ?? false, "The plan says how it'll be compared afterwards")
        m.startTreatment()
        XCTAssertTrue(device.isRunning)
        m.reading = device.tick(seconds: 60)
        m.endRun()
        XCTAssertEqual(m.step, .movement, "The same movement, after care")
        m.movementAnswer(.init(feel: .fine))
        m.reassess("little")

        let e = try XCTUnwrap(memory.all.first)
        XCTAssertEqual(memory.all.count, 1)
        XCTAssertEqual(e.symptom.areaId, "r_sh_back")                                     // state
        XCTAssertEqual(e.investigation?.checks.map(\.kind), [.location, .movement, .movement])   // investigation
        XCTAssertEqual(e.investigation?.baseline?.outcome, .mildDiscomfort)                // observation (before)
        XCTAssertEqual(e.investigation?.repeatCheck?.changeVsBaseline, .better)            // observation (after)
        XCTAssertNotNil(e.intervention)                                                    // intervention
        XCTAssertEqual(e.outcome.response, "little")                                       // outcome
        XCTAssertEqual(e.movement?.before?.feel, .little); XCTAssertEqual(e.movement?.after?.feel, .fine)

        // Next time, this session counts as relevant history for the same shoulder.
        XCTAssertEqual(memory.relevantMemory(for: "r_sh_front", activity: "tennis").count, 1)
        XCTAssertTrue(memory.relevantMemory(for: "l_ankle", activity: "running").isEmpty)
    }

    // MARK: 12. Backend failure

    func testUnreachableBackendFallsBackGracefully() async {
        let offline = APICareIntelligenceService(baseURL: URL(string: "http://127.0.0.1:9")!, timeout: 2)
        let (m, _, _) = makeModel(intelligence: offline)
        await m.beginWithStory(Self.tennis)
        XCTAssertEqual(m.A.bodyRegion, "r_sh_back", "Understood on-device")
        XCTAssertEqual(m.step, .locate)
        XCTAssertEqual(m.investigation.intelligenceSources.last, "local (fallback)")
        XCTAssertNotNil(m.intelligenceNote)
    }

    // MARK: 13. Provider swappability (+ the language guard)

    func testAnyProviderWorksAndCannotDiagnose() async {
        var stub = StubIntelligence(always: nil)
        stub.acknowledgement = "You have a rotator cuff tear."      // a provider overstepping
        let (m, _, _) = makeModel(intelligence: stub)
        await m.beginWithStory(Self.tennis)
        XCTAssertFalse(m.agentLine.contains("tear"), "Diagnostic wording is replaced with Lofer's own")
        XCTAssertEqual(m.investigation.intelligenceSources.last, "stub")
    }
}

/// A stand-in provider: understands like the on-device service, but proposes scripted actions.
struct StubIntelligence: CareIntelligenceService {
    var always: InvestigationAction?
    var script: [InvestigationAction?] = []
    var acknowledgement: String?
    private let counter = Counter()
    init(always: InvestigationAction?) { self.always = always }
    init(script: [InvestigationAction?]) { self.script = script }

    func respond(to request: CareRequest) async throws -> CareIntelligenceResponse {
        var r = LocalCareIntelligenceService.response(to: request)
        r.provider = "stub"
        let i = counter.next()
        if let a = always ?? (i < script.count ? script[i] : nil) { r.recommendedNextAction = a }
        if let ack = acknowledgement { r.userFacingResponse.acknowledgement = ack }
        return r
    }
    final class Counter: @unchecked Sendable { private var n = -1; func next() -> Int { n += 1; return n } }
}
