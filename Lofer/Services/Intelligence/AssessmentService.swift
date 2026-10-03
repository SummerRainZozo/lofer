import Foundation

/// One follow-up question Lofer may ask. `options` are tap-to-answer chips (label, value).
struct AssessmentQuestion: Equatable {
    var field: String
    var text: String
    var hint: String? = nil
    var options: [(String, String)] = []
    var multi = false
    static func == (a: Self, b: Self) -> Bool { a.field == b.field && a.text == b.text }
}

/// ASSESSMENT — what Lofer understands, what's still missing, and the ONE next question.
/// The conversation never walks a fixed questionnaire:
///   user speaks → fields extracted → state updated → what's missing? → one question (or confirm).
/// Copy here is user-facing: warm, short, feeling-first, never clinical.
enum AssessmentService {
    static let maxFollowUps = 4
    private static let atlas = BodyAtlas.shared

    // MARK: language helpers
    static let feel = ["tightness": "tight", "soreness": "sore", "ache": "achy", "sharp": "sharp", "burning": "like it’s burning", "cramp": "crampy", "unclear": "a bit off", "pain": "uncomfortable"]
    static let feelNoun = ["tightness": "tightness", "soreness": "soreness", "ache": "a dull ache", "sharp": "a sharper pain", "burning": "a burning feeling", "cramp": "cramping", "unclear": "something that feels off", "pain": "discomfort"]
    static let onsetWords = ["today": "today", "last night": "last night", "yesterday": "yesterday", "a few days ago": "a few days ago", "weeks ago": "a few weeks ago", "months ago": "some months ago"]
    static let triggerWords = ["Raising the arm overhead": "lifting your arm overhead", "Lifting the arm": "lifting your arm", "Reaching backwards": "reaching backwards",
        "Rotating": "rotating it", "Lifting the hand": "lifting your hand", "Gripping": "gripping", "Turning the head": "turning your head", "Bending forward": "bending forward",
        "Prolonged sitting": "sitting for a while", "Standing up": "standing up", "Squatting or kneeling": "squatting or kneeling", "Typing": "typing", "Overhead throwing or serving": "serving or throwing",
        "Pushing or leaning on it": "leaning on it", "Looking down": "looking down", "Carrying things": "carrying things", "Going up on my toes": "going up on your toes", "First steps in the morning": "the first steps in the morning"]
    static func triggerPhrase(_ t: String) -> String { triggerWords[t] ?? t.lowercased() }
    static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    static func startedPhrase(_ A: AssessmentState) -> String? {
        let when = A.onset.flatMap { onsetWords[$0] }
        switch (A.activityContext, when) {
        case let (act?, w?): return "after \(act) \(w)"
        case let (act?, nil): return "after \(act)"
        case let (nil, w?): return w
        default: return nil
        }
    }
    /// Region-specific examples, so the follow-up sounds like it understood where you are.
    static let bringsOn: [(String, String, [String])] = [
        ("shoulder|uarm|trap|scap|lat|chest", "lifting or rotating your arm", ["Lifting it overhead", "Reaching behind me", "Rotating it"]),
        ("elbow|farm|wrist|hand", "gripping, rotating your wrist, or lifting your hand", ["Gripping", "Rotating my wrist", "Lifting my hand"]),
        ("neck|headneck|face|backhead", "turning your head or looking down", ["Turning my head", "Looking down", "Sitting at a screen"]),
        ("lowerback|lowback|hips|hip|glute|upperback|mid_back", "bending, sitting or standing up", ["Bending forward", "Sitting for a while", "Standing up"]),
        ("knee|thigh", "stairs, squatting or walking", ["Stairs", "Squatting", "Walking"]),
        ("lleg|calf|achilles|footg|ankle|heel|sole|leg", "walking, running or going up on your toes", ["Walking", "Running", "Going up on my toes"]),
    ]
    static let optionTrigger = ["Lifting it overhead": "Raising the arm overhead", "Reaching behind me": "Reaching backwards", "Rotating it": "Rotating", "Rotating my wrist": "Rotating",
        "Lifting my hand": "Lifting the hand", "Turning my head": "Turning the head", "Sitting at a screen": "Prolonged sitting", "Sitting for a while": "Prolonged sitting", "Squatting": "Squatting or kneeling", "Lifting things": "Carrying things"]

    // MARK: update from one utterance
    /// `expect` = the field Lofer just asked about. Returns the names of fields learned this turn.
    static func update(_ A: inout AssessmentState, with r: ParsedUtterance, expect: String?) -> [String] {
        var learned: [String] = []
        let t = r.raw.lowercased()
        func set<T: Equatable>(_ kp: WritableKeyPath<AssessmentState, T?>, _ v: T?, _ name: String) {
            if let v, A[keyPath: kp] != v { A[keyPath: kp] = v; learned.append(name) }
        }
        if r.isDescriptive || expect == "story" || expect == "sensation" { A.userDescription.append(r.raw.trimmingCharacters(in: .whitespaces)) }
        if let ty = r.type, ty != "pain" {
            if A.sensation == nil || ["pain", "unclear"].contains(A.sensation!) || expect == "sensation" { set(\.sensation, ty, "sensation") }
        } else if r.type == "pain" && A.sensation == nil { set(\.sensation, "pain", "sensation") }
        if expect == "sensation" && r.type == nil && t.trimmingCharacters(in: .whitespaces).count > 2 {
            A.sensation = "other"; A.sensationWords = r.raw.trimmingCharacters(in: .whitespaces); learned.append("sensation")
        }
        if let s = r.severity, expect == "severity" || r.isDescriptive { set(\.severity, s, "severity") }
        set(\.onset, r.onset, "onset"); set(\.activityContext, r.activity, "activityContext")
        set(\.activityDuration, r.story.activityDuration, "activityDuration"); set(\.symptomsAtRest, r.story.atRest, "symptomsAtRest")
        set(\.progression, r.story.progression, "progression"); set(\.onsetType, r.story.onsetType, "onsetType")
        if let rel = r.story.relieving, !A.relievingFactors.contains(rel) { A.relievingFactors.append(rel); learned.append("relievingFactors") }
        for x in r.triggers where !A.movementTriggers.contains(x) { A.movementTriggers.append(x); learned.append("movementTriggers") }
        if r.previous { set(\.previousEpisodes, true, "previousEpisodes") }
        for f in r.flags where !A.safetyFlags.contains(where: { $0.label == f.label }) { A.safetyFlags.append(f); learned.append("safetyFlags") }
        if expect == "triggers" && r.triggers.isEmpty {
            if t.has("all the time|most of the time|constant|always there") { set(\.symptomsAtRest, "present", "symptomsAtRest") }
            else if r.deny || t.has("nothing|none|not really|not sure|no idea|don'?t know") { A.movementTriggers.append("Nothing in particular"); learned.append("movementTriggers") }
        }
        if expect == "previous" {
            if t.has("\\b(yes|yeah|before|again|usually|comes and goes)\\b") { set(\.previousEpisodes, true, "previousEpisodes") }
            else if r.deny || t.has("new|first time|never") { set(\.previousEpisodes, false, "previousEpisodes") }
        }
        if expect == "safety" && (r.deny || t.has("none|nothing|^\\s*no\\s*$")) { learned.append("safetyChecked") }
        if r.bilateral { set(\.laterality, "both", "laterality") }
        refreshMeta(&A)
        return learned
    }

    @discardableResult
    static func setRegion(_ A: inout AssessmentState, _ id: String, pair: String? = nil, confirmed: Bool = false) -> Bool {
        let changed = A.bodyRegion != id
        A.bodyRegion = id; A.pair = pair; A.regionConfirmed = confirmed
        A.laterality = pair != nil ? "both" : atlas.laterality(of: id)
        refreshMeta(&A)
        return changed
    }

    /// Apply a tapped answer chip.
    static func answer(_ A: inout AssessmentState, field: String, value: String) {
        switch field {
        case "sensation": A.sensation = value
        case "severity": A.severity = Int(value)
        case "onset": A.onset = value
        case "triggers":
            if value == "__rest" { A.symptomsAtRest = "present" }
            else if value == "__none" { A.movementTriggers.append("Nothing in particular") }
            else { A.movementTriggers.append(optionTrigger[value] ?? value) }
        case "previous": A.previousEpisodes = value == "true"
        default: break
        }
        A.asked.insert(field)
        refreshMeta(&A)
    }
    static func addSafetyAnswers(_ A: inout AssessmentState, _ labels: [String]) {
        for l in labels { A.safetyFlags.append(SafetyFlag(level: .stop, label: l)) }
        A.asked.insert("safety"); refreshMeta(&A)
    }

    // MARK: what's missing → the one question worth asking
    /// A "caution" word like "sharp" is a reason TO ask; only a serious sign already heard makes it unnecessary.
    static func needsSafety(_ A: AssessmentState) -> Bool {
        guard !A.asked.contains("safety"), !A.safetyFlags.contains(where: { $0.level != .caution }) else { return false }
        return ["sharp", "burning"].contains(A.sensation ?? "") || (A.severity ?? 0) >= 7 || (A.onsetType == "sudden" && A.activityContext == nil)
            || A.progression == "worsening" || A.onset == "months ago" || A.symptomsAtRest == "present"
    }
    static func missing(_ A: AssessmentState, historyCount: Int = 0) -> [String] {
        var m: [String] = []
        if A.userDescription.isEmpty && A.sensation == nil { m.append("story") }
        if A.bodyRegion == nil { m.append("region") }
        if A.sensation == nil || ["pain", "unclear"].contains(A.sensation!) { m.append("sensation") }
        if needsSafety(A) { m.append("safety") }
        if A.movementTriggers.isEmpty && A.symptomsAtRest == nil { m.append("triggers") }
        if A.onset == nil && A.activityContext == nil { m.append("onset") }
        if A.severity == nil { m.append("severity") }
        if A.previousEpisodes == nil && historyCount == 0 { m.append("previous") }
        return m
    }
    static func refreshMeta(_ A: inout AssessmentState) {
        let m = missing(A); A.missingFields = m
        let core = ["region", "sensation", "triggers", "onset", "severity"]
        A.confidence = 1 - Double(core.filter { m.contains($0) }.count) / Double(core.count)
    }

    static func nextQuestion(_ A: AssessmentState, historyCount: Int) -> AssessmentQuestion? {
        let m = missing(A, historyCount: historyCount).filter { !A.asked.contains($0) || $0 == "region" }
        if m.contains("story") { return AssessmentQuestion(field: "story", text: "Tell me what's been going on and how it feels.", hint: "Talk or type, however feels natural.") }
        if m.contains("region") { return AssessmentQuestion(field: "region", text: "Where are you feeling it? Tell me, or show me on your body.") }
        let capped = A.questionsAsked >= maxFollowUps
        for f in ["sensation", "safety", "triggers", "onset", "severity", "previous"] where m.contains(f) {
            if capped && !["sensation", "safety"].contains(f) { continue }
            if f == "previous" && A.questionsAsked >= 3 { continue }
            return question(f, A)
        }
        return nil   // enough to confirm
    }
    static func question(_ f: String, _ A: AssessmentState) -> AssessmentQuestion {
        switch f {
        case "sensation":
            return AssessmentQuestion(field: f, text: A.sensation == "unclear" ? "Let’s put a word to it. Does it feel more tight, sore, achy, or sharp?" : "How does it feel? More tight, sore, achy, or sharp?",
                                      options: [("Tight", "tightness"), ("Sore", "soreness"), ("Achy", "ache"), ("Sharp", "sharp"), ("Something else", "__other")])
        case "safety":
            return AssessmentQuestion(field: f, text: "One quick check. Is there any numbness, tingling, swelling or weakness with it?",
                                      options: [("Numbness or tingling", "Numbness or tingling"), ("Swelling", "Swelling, bruising or deformity"), ("Weakness", "Weakness or loss of movement"), ("After a fall or knock", "Recent fall, knock or injury")], multi: true)
        case "triggers":
            let key = A.bodyRegion.map { atlas.group(of: $0) + " " + $0 } ?? ""
            let (_, ex, opts) = bringsOn.first { key.has($0.0) } ?? ("", "particular movements or positions", ["Certain movements", "Sitting still", "Exercise"])
            return AssessmentQuestion(field: f, text: "Does anything bring it on? For example \(ex).",
                                      options: opts.map { ($0, $0) } + [("It’s there all the time", "__rest"), ("Nothing really", "__none")])
        case "onset":
            return AssessmentQuestion(field: f, text: "When did you first notice it?",
                                      options: [("Today", "today"), ("Yesterday", "yesterday"), ("A few days ago", "a few days ago"), ("A week or two", "weeks ago"), ("Longer than that", "months ago")])
        case "severity":
            return AssessmentQuestion(field: f, text: "How much is it bothering you right now?", options: [("A little", "2"), ("Moderately", "4"), ("Quite a lot", "6"), ("A lot", "8")])
        default:
            return AssessmentQuestion(field: "previous", text: "Has this happened before, or is it new?", options: [("It’s happened before", "true"), ("This is new", "false")])
        }
    }

    // MARK: what Lofer says back
    /// One short acknowledgement clause, never a recap ("Got it, lifting your arm overhead brings it on.").
    static func ack(_ A: AssessmentState, learned: [String]) -> String {
        var bits: [String] = []
        if learned.contains("activityContext") || learned.contains("onset"), let sp = startedPhrase(A) { bits.append(sp) }
        if learned.contains("region"), let r = A.bodyRegion { bits.append(atlas[r].spoken) }
        if learned.contains("sensation"), let s = A.sensation, s != "pain" {
            bits.append(s == "other" ? "it feels \(A.sensationWords?.lowercased() ?? "")" : "it feels \(feel[s] ?? s)")
        }
        if learned.contains("movementTriggers"), let tr = A.movementTriggers.last(where: { $0 != "Nothing in particular" }) { bits.append("\(triggerPhrase(tr)) brings it on") }
        if learned.contains("symptomsAtRest") { bits.append(A.symptomsAtRest == "minimal" ? "it's mostly fine at rest" : "it's there most of the time") }
        guard let first = bits.first else { return "" }
        return "Got it, \(first)."
    }
    /// The short "here's what I understood" line shown before anything is suggested.
    static func summary(_ A: AssessmentState) -> String {
        let feelN = A.sensation == "other" ? "“\(A.sensationWords ?? "")”" : (feelNoun[A.sensation ?? ""] ?? "some discomfort")
        let say: String = {
            guard let r = A.bodyRegion else { return "that area" }
            if A.pair != nil { return "both \(atlas[r].shortName.replacingOccurrences(of: "Right ", with: "").replacingOccurrences(of: "Left ", with: "").lowercased())s" }
            return atlas[r].spoken
        }()
        let whereText = say.hasPrefix("the ") ? "at \(say)" : "in \(say)"
        var s = "\(cap(feelN)) \(whereText)."
        var second: [String] = []
        if let sp = startedPhrase(A) { second.append("it started \(sp)") }
        if let tr = A.movementTriggers.first(where: { $0 != "Nothing in particular" }) { second.append("\(triggerPhrase(tr)) makes it worse") }
        else if A.symptomsAtRest == "present" { second.append("it's there most of the time") }
        if !second.isEmpty { s += " " + cap(second.joined(separator: ", and ")) + "." }
        return s
    }

    /// Hand-off to the safety layer / engine / Body Memory.
    static func symptom(_ A: AssessmentState) -> SymptomSnapshot {
        SymptomSnapshot(areaId: A.bodyRegion, pairId: A.pair, side: A.laterality,
                        type: ["other", "unclear"].contains(A.sensation ?? "") ? "pain" : A.sensation,
                        severity: A.severity, onset: A.onset, onsetType: A.onsetType, activity: A.activityContext,
                        triggers: A.movementTriggers, atRest: A.symptomsAtRest, progression: A.progression,
                        previous: A.previousEpisodes, flags: A.safetyFlags, movementBefore: A.movementBefore)
    }
}

/// The structured symptom passed between layers (assessment → safety → engine → memory).
struct SymptomSnapshot {
    var areaId: String? = nil
    var pairId: String? = nil
    var side: String? = nil
    var type: String? = nil
    var severity: Int? = nil
    var onset: String? = nil
    var onsetType: String? = nil
    var activity: String? = nil
    var triggers: [String] = []
    var atRest: String? = nil
    var progression: String? = nil
    var previous: Bool? = nil
    var flags: [SafetyFlag] = []
    var movementBefore: MovementResult? = nil
}
