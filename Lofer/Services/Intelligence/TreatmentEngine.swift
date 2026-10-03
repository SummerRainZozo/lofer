import Foundation

/// CARE / TREATMENT ENGINE — proposes the candidate next action. It never talks to the
/// device: everything it proposes goes through SafetyValidator first.
enum TreatmentEngine {
    static let levels = ["", "Very gentle", "Gentle", "Moderate", "Firm", "Deep"]
    private static let atlas = BodyAtlas.shared
    private static func clampI(_ v: Int) -> Int { max(1, min(5, v)) }

    /// "shoulder", "lower back"… for sentences.
    static func regionNoun(_ id: String?) -> String {
        guard let id else { return "recovery" }
        let g = atlas[atlas.group(of: id)]
        return g.shortName.replacingOccurrences(of: "Right ", with: "").replacingOccurrences(of: "Left ", with: "").lowercased()
    }

    private static func build(_ kind: TreatmentPlan.Kind, _ name: String, _ rows: [(Modality, Int, Double)?], total: Int, s: SymptomSnapshot) -> TreatmentPlan {
        let steps = rows.compactMap { $0 }.map { TreatmentStep(modality: $0.0, intensity: clampI($0.1), minutes: max(1, Int((Double(total) * $0.2).rounded()))) }
        return TreatmentPlan(kind: kind, name: name, region: s.areaId ?? "body", pair: s.pairId, steps: steps)
    }

    struct Suggestion { var options: [TreatmentPlan]; var pick: TreatmentPlan; var headline: String }

    /// SUGGEST: a small set of options plus the one Lofer recommends.
    static func suggest(_ s: SymptomSnapshot, _ tri: TriageResult, profile: UserProfile, history: [Episode], routine: SavedRoutine?) -> Suggestion {
        let base = profile.baseIntensity, len = profile.lengthMinutes, heat = profile.heat
        let stimOk = ["tightness", "soreness", "cramp"].contains(s.type ?? "")
        let noun = regionNoun(s.areaId)
        var gentle = build(.gentle, "Gentle \(noun) recovery", [(.vibration, base - 1, 0.4), (.compression, base - 1, 0.4), heat ? (.heat, 2, 0.2) : nil], total: min(10, len), s: s)
        gentle.reason = tri.level == .caution ? "Kept gentle and short to be safe, based on what you've told me." : "A gentle starting point based on how your \(noun) is feeling today."
        var targeted = build(.targeted, "Targeted \(noun) relief", [(.vibration, base, 0.25), (.compression, base, 0.4), stimOk ? (.ems, base - 1, 0.15) : nil, heat ? (.heat, 2, 0.2) : nil], total: len, s: s)
        targeted.reason = s.activity.map { "A little more focused, for tightness that's built up after \($0)." } ?? "A little more focused, once you know how Lofer feels."
        var options: [TreatmentPlan] = []
        if let r = routine { options.append(TreatmentPlan(kind: .routine, name: r.name, region: s.areaId ?? "body", pair: s.pairId, steps: r.steps, reason: "What helped your \(noun) last time.")) }
        options += [gentle, targeted]
        var pick = options[0]
        if routine == nil { pick = (tri.level == .caution || history.isEmpty || ["sharp", "ache", "pain", "burning"].contains(s.type ?? "")) ? gentle : targeted }
        let headline = pick.kind == .routine ? "Last time your \(pick.name.lowercased()) helped. Shall we start with that?"
            : pick.kind == .gentle ? "I think we can start gently here." : "I think a slightly more focused session suits this."
        return Suggestion(options: options, pick: pick, headline: headline)
    }

    /// Natural-language changes ("more heat", "no electrical stimulation") → plan edits.
    static func apply(_ prefs: TreatmentPrefs, to plan: TreatmentPlan, profile: UserProfile) -> (TreatmentPlan, [String]) {
        var p = plan, said: [String] = []
        func idx(_ m: Modality) -> Int? { p.steps.firstIndex { $0.modality == m } }
        if prefs.heat == 1 { if let i = idx(.heat) { p.steps[i].minutes += 2; p.steps[i].intensity = clampI(p.steps[i].intensity + 1) } else { p.steps.append(.init(modality: .heat, intensity: 2, minutes: 3)) }; said.append("more heat") }
        if prefs.heat == -1 { p.steps.removeAll { $0.modality == .heat }; said.append("no heat") }
        if prefs.intensity == -1 { for i in p.steps.indices { p.steps[i].intensity = clampI(min(p.steps[i].intensity - 1, 2)) }; said.append("kept gentle") }
        if prefs.intensity == 1 { for i in p.steps.indices where p.steps[i].modality != .heat { p.steps[i].intensity = clampI(p.steps[i].intensity + 1) }; said.append("a bit firmer") }
        if prefs.ems == false, idx(.ems) != nil { p.steps.removeAll { $0.modality == .ems }; said.append("no muscle stimulation") }
        if prefs.ems == true, idx(.ems) == nil { p.steps.insert(.init(modality: .ems, intensity: clampI(profile.baseIntensity - 1), minutes: 3), at: max(0, p.steps.count - 1)); said.append("muscle stimulation added") }
        if prefs.vibration == false { p.steps.removeAll { $0.modality == .vibration }; said.append("no vibration") }
        if let f = prefs.focus { p.focus = f; said.append(["up": "focus higher", "down": "focus lower", "out": "focus further out", "in": "focus further in", "front": "focus toward the front", "back": "focus toward the back"][f] ?? "focus moved") }
        let cur = max(1, p.minutes)
        let target: Int? = prefs.minutes ?? (prefs.shorter ? Int(Double(cur) * 0.7) : prefs.longer ? Int(Double(cur) * 1.3) : nil)
        if let target { for i in p.steps.indices { p.steps[i].minutes = max(1, Int((Double(p.steps[i].minutes) * Double(target) / Double(cur)).rounded())) }; said.append("\(p.minutes) minutes") }
        if !said.isEmpty { if p.kind != .routine { p.kind = .custom }; p.adjusted = true }
        return (p, said)
    }

    /// TREAT: what to do with feedback during a session.
    enum FeedbackAction { case level(Int, String), keepGoing(String), pause(String) }
    static func feedbackAction(_ fb: String) -> FeedbackAction? {
        switch fb {
        case "too strong": return .level(-1, "Easing off a little.")
        case "too weak": return .level(1, "A little firmer.")
        case "good": return .keepGoing("Good. I'll carry on.")
        case "worse": return .pause("Let's pause. Is it okay to carry on more gently, or would you rather stop here?")
        default: return nil
        }
    }
    /// When to ask "How does this feel?". Fewer check-ins for people who usually say "good".
    static func checkIns(_ history: [Episode]) -> [Double] {
        let fbs = history.flatMap { $0.feedback.map(\.value) }
        if fbs.filter({ $0 == "too strong" }).count >= 2 { return [0.15, 0.45, 0.75] }
        if fbs.count >= 4 && fbs.allSatisfy({ $0 == "good" }) { return [0.5] }
        return [0.3, 0.7]
    }

    struct Reassessment { var pathway: String; var escalate: Bool; var headline: String; var body: String; var offerRoutine = false; var routineName = ""; var observations: [String] = [] }
    private static func ord(_ n: Int) -> String { let s = (n % 100 > 10 && n % 100 < 14) ? "th" : ["th", "st", "nd", "rd"][safe: n % 10] ?? "th"; return "\(n)\(s)" }

    /// REASSESS: pick the pathway after a session.
    static func reassess(response: String, _ s: SymptomSnapshot, history: [Episode], now: Date = Date()) -> Reassessment {
        let areaId = s.areaId ?? "body", group = atlas.group(of: areaId), gLabel = atlas[group].label.lowercased(), noun = regionNoun(areaId)
        let day = 86400.0
        let prior = history.filter { $0.intervention != nil && now.timeIntervalSince($0.createdAt) < 90 * day }
        let recent = prior.filter { now.timeIntervalSince($0.createdAt) < 60 * day }
        let occurrences = recent.count + 1
        let ctx = s.activity
        let ctxCount = recent.filter { $0.symptom.activity == ctx && ctx != nil }.count + (ctx != nil ? 1 : 0)
        let notHelping = prior.prefix(2).filter { ["same", "worse"].contains($0.outcome.response ?? "") }.count
        var seq: [String: Int] = [:]
        for e in prior where ["much", "little"].contains(e.outcome.response ?? "") {
            seq[(e.intervention?.steps ?? []).map { $0.modality.label.lowercased() }.joined(separator: " then "), default: 0] += 1
        }
        let best = seq.max { $0.value < $1.value }?.key
        let routineName = ctx.map { "Post-\($0) \(noun) routine" } ?? "\(noun.prefix(1).uppercased() + noun.dropFirst()) routine"
        let recurring = occurrences >= 3 || ctxCount >= 2
        let typeWord = ["tightness": "tight", "soreness": "sore", "ache": "achy", "sharp": "painful", "cramp": "crampy"][s.type ?? ""] ?? "uncomfortable"
        let recurText = recurring ? "This is the \(ord(occurrences)) time your \(gLabel) has become \(typeWord)\(ctx.map { " after \($0)" } ?? " recently").\(best.map { " Earlier sessions responded best to \($0)." } ?? "")" : ""
        switch response {
        case "worse":
            return Reassessment(pathway: "escalate", escalate: true, headline: "That's made it worse, so let's stop here.",
                                body: "I don't want to push this with something stronger. It's worth having it looked at by a physiotherapist, and I can put together a short summary for them.")
        case "same" where notHelping >= 1:
            return Reassessment(pathway: "escalate", escalate: true, headline: "It doesn't sound like this helped much. Let's not keep pushing it.",
                                body: "This is the \(notHelping + 1 == 2 ? "second" : ord(notHelping + 1)) session in a row that hasn't eased your \(gLabel), so I'll pause automatic care here. A physiotherapist can take a proper look, and I can prepare a summary for them.")
        case "much":
            return Reassessment(pathway: "positive", escalate: false, headline: "Lovely. Your \(noun) responded well today, and I've remembered what worked.",
                                body: recurring ? "\(recurText) Shall I save today's session as your \(routineName.lowercased())?" : "", offerRoutine: recurring, routineName: routineName)
        case "little":
            return Reassessment(pathway: recurring ? "recurring" : "partial", escalate: false, headline: "Good, it’s eased a little.",
                                body: recurring ? "\(recurText) Shall I save this as your \(routineName.lowercased()), so it's ready next time?" : "Another gentle session later today or tomorrow often helps. I'll keep an eye on how it goes.",
                                offerRoutine: recurring, routineName: routineName)
        default:
            return Reassessment(pathway: "partial", escalate: false, headline: "No real change yet.",
                                body: "That's normal after one session. Let's try a gentle one tomorrow. If it still feels the same after that, it's worth getting it checked.")
        }
    }

    /// WHY IT MIGHT FEEL THIS WAY — one or two plausible, hedged sentences. Never a diagnosis.
    static func explain(response: String, _ s: SymptomSnapshot, plan: TreatmentPlan?, before: MovementResult?, after: MovementResult?) -> String {
        let order: [MovementResult.Feel: Int] = [.fine: 0, .little: 1, .quite: 2, .cannot: 3]
        let mv: Int? = { guard let b = before, let a = after else { return nil }; return (order[b.feel]! - order[a.feel]!).signum() }()
        let mods = Set((plan?.steps ?? []).map(\.modality))
        let heat = mods.contains(.heat), press = mods.contains(.compression) || mods.contains(.vibration)
        let how = heat && press ? "Gentle pressure and warmth" : heat ? "Warmth" : press ? "Gentle pressure and vibration" : "The session"
        let act = s.activity, noun = regionNoun(s.areaId)
        let sore = s.type == "soreness" || (act ?? "").has("running|training|lifting|team sport|tennis|climbing")
        let desk = act == "sitting" || act == "work"
        var lines: [String] = []
        switch response {
        case "much", "little":
            lines.append("\(how) can help tight muscles relax and bring more blood flow to the area, which often makes things feel \(response == "much" ? "noticeably easier" : "a bit easier") for a while.")
            if mv == 1 { lines.append("That may be why the movement felt easier just now.") }
            else if mv == 0 { lines.append("The movement might take a little longer to catch up. That's quite common.") }
            else if mv == -1 { lines.append("If the movement felt a bit more noticeable, the area may simply be more aware after being worked on.") }
            if response == "little" { lines.append(sore ? "Soreness after \(act ?? "exercise") often eases over a day or two, so it may keep improving." : desk ? "Stiffness from sitting often eases further with regular movement through the day." : "It may keep easing with rest and gentle movement.") }
        case "same":
            lines.append(sore ? "Muscles worked hard during \(act ?? "exercise") can stay tight for a day or two, and one session doesn't always shift that."
                         : desk ? "Stiffness that builds up over long periods of sitting can take more than one session to ease."
                         : "Sometimes the tightness sits slightly away from where we worked, or your \(noun) needs a little more time.")
            if mv == 1 { lines.append("The movement did feel a little easier, which may be an early sign it’s settling.") }
        case "worse":
            lines.append("A treated area can feel tender for a while afterwards, a bit like after a massage, and that often settles within a day.")
            lines.append("But if it keeps getting worse, it may need a different approach, which is why I'd rather not push further today.")
        default: break
        }
        return lines.prefix(2).joined(separator: " ")
    }
}

extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }
