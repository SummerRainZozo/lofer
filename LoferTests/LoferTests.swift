import XCTest
@testable import Lofer

/// Checks for the product logic (no UI). Run with ⌘U in Xcode.
final class LoferTests: XCTestCase {

    // MARK: understanding what the user says
    func testStoryIsUnderstood() {
        let r = SymptomParser.parse("I played tennis for about two hours yesterday. My right shoulder started feeling quite tight. It's mostly okay normally but hurts when I lift my arm above my head.")
        XCTAssertEqual(r.entry?.template, "{s}_shoulder")
        XCTAssertEqual(r.side, .right)
        XCTAssertEqual(r.type, "tightness")
        XCTAssertEqual(r.activity, "tennis")
        XCTAssertEqual(r.onset, "yesterday")
        XCTAssertEqual(r.story.activityDuration, "about two hours")
        XCTAssertEqual(r.story.atRest, "minimal")
        XCTAssertTrue(r.triggers.contains("Raising the arm overhead"))
    }
    func testAboveMyHeadIsNotTheHead() {
        XCTAssertNil(SymptomParser.parse("Mostly when I lift it above my head.").entry)
    }
    func testBothSides() {
        let r = SymptomParser.parse("My calves are destroyed after running.")
        XCTAssertTrue(r.bilateral)
        XCTAssertEqual(r.activity, "running")
    }
    func testPreferencesAndFeedback() {
        let p = SymptomParser.parse("More heat, and no electrical stimulation please.").prefs
        XCTAssertEqual(p?.heat, 1)
        XCTAssertEqual(p?.ems, false)
        XCTAssertEqual(SymptomParser.parse("That's slightly too strong.").feedback, "too strong")
        XCTAssertEqual(SymptomParser.parse("It definitely feels looser now.").response, "little")
    }

    // MARK: one question at a time, never re-asking
    func testDoesNotReaskWhatWasSaid() {
        var A = AssessmentState()
        AssessmentService.setRegion(&A, "r_shoulder")
        _ = AssessmentService.update(&A, with: SymptomParser.parse("I played tennis yesterday and my right shoulder has felt tight since."), expect: "story")
        let q = AssessmentService.nextQuestion(A, historyCount: 1)
        XCTAssertEqual(q?.field, "triggers", "Should ask what brings it on — not when it started or how it feels")
    }
    func testSharpFeelingTriggersSafetyQuestion() {
        var A = AssessmentState()
        AssessmentService.setRegion(&A, "r_shoulder")
        _ = AssessmentService.update(&A, with: SymptomParser.parse("It's a sharp pain."), expect: "story")
        XCTAssertEqual(AssessmentService.nextQuestion(A, historyCount: 1)?.field, "safety")
    }

    // MARK: safety
    func testWarningSignsStopTreatment() {
        var A = AssessmentState()
        AssessmentService.setRegion(&A, "r_knee")
        _ = AssessmentService.update(&A, with: SymptomParser.parse("I fell yesterday and my knee is swollen"), expect: "story")
        let tri = SafetyValidator.triage(AssessmentService.symptom(A), profile: UserProfile())
        XCTAssertEqual(tri.level, .stop)
    }
    func testChestPainIsUrgent() {
        let r = SymptomParser.parse("chest pain and short of breath")
        let tri = SafetyValidator.triage(SymptomSnapshot(flags: r.flags), profile: UserProfile())
        XCTAssertTrue(tri.urgent)
    }
    func testValidatorCapsAndRemovesStimulationWithImplant() {
        var profile = UserProfile(); profile.implant = true
        let tri = SafetyValidator.triage(SymptomSnapshot(areaId: "r_sh_front", type: "tightness"), profile: profile)
        let plan = TreatmentPlan(kind: .targeted, name: "Test", region: "r_sh_front", steps: [.init(modality: .ems, intensity: 4, minutes: 3), .init(modality: .compression, intensity: 5, minutes: 30)])
        let v = SafetyValidator.validate(plan, tri)
        XCTAssertFalse(v.plan.steps.contains { $0.modality == .ems })
        XCTAssertLessThanOrEqual(v.plan.steps.map(\.intensity).max() ?? 0, tri.maxIntensity)
        XCTAssertLessThanOrEqual(v.plan.minutes, tri.maxMinutes)
        XCTAssertNotNil(v.command, "Only the validator can produce a command the device accepts")
    }

    // MARK: hedged explanations
    func testExplanationIsHedged() {
        let s = SymptomSnapshot(areaId: "r_sh_back", type: "tightness", activity: "tennis")
        let plan = TreatmentPlan(kind: .gentle, name: "Gentle", region: "r_sh_back", steps: [.init(modality: .compression, intensity: 2, minutes: 5), .init(modality: .heat, intensity: 2, minutes: 2)])
        for resp in ["much", "little", "same", "worse"] {
            let text = TreatmentEngine.explain(response: resp, s, plan: plan, before: .init(feel: .little), after: .init(feel: .fine))
            XCTAssertFalse(text.isEmpty)
            XCTAssertTrue(text.has("may|often|can|might"), "Explanation should be hedged: \(text)")
        }
    }

    // MARK: body model
    func testClassifierMatchesAtlas() {
        let atlas = BodyAtlas.shared
        XCTAssertEqual(atlas.leaves.count, 113)
        let s = BodySDF.snap([-0.2, 1.37, -0.2])     // behind the right shoulder
        XCTAssertNotNil(atlas.node(BodySDF.classify(s.point, s.normal)))
    }
}
