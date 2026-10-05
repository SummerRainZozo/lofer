import Foundation

/// SYMPTOM / CONTEXT MODEL — turns what the user says into structured fields.
/// This is the keyword stand-in from the prototype. In production an LLM fills the
/// same `ParsedUtterance` (see CareIntelligenceService), so nothing downstream changes.
struct ParsedUtterance {
    struct PartEntry { var id: String? = nil; var template: String? = nil; var noun: String? = nil }
    var raw: String
    var entry: PartEntry? = nil
    var side: BodySide? = nil
    var bilateral = false
    var type: String? = nil
    var severity: Int? = nil
    var onset: String? = nil
    var activity: String? = nil
    var triggers: [String] = []
    var previous = false
    var flags: [SafetyFlag] = []           // warning signs the user reported ("my hand is numb")
    var negatedFlags: [SafetyFlag] = []    // warning signs the user ruled out ("no numbness")
    var uncertainFlags: [SafetyFlag] = []  // warning signs the user wasn't sure about ("not sure if it's numb")
    var unsure = false                     // "not sure", "don't know"
    var skip = false                       // "skip", "rather not say"
    var prefs: TreatmentPrefs? = nil
    var feedback: String? = nil            // too strong / too weak / good / worse
    var response: String? = nil            // much / little / same / worse
    var direction: String? = nil           // up / down / front / back / out / in / L / R
    var slight = false
    var confirm = false
    var deny = false
    var turn: String? = nil
    var zoom = false
    var start = false
    var story = StoryDetails()
    var movement: MovementResult? = nil

    var isDescriptive: Bool {
        entry != nil || type != nil || activity != nil || !triggers.isEmpty || onset != nil || !story.isEmpty || !flags.isEmpty || !uncertainFlags.isEmpty
    }
}

struct StoryDetails {
    var activityDuration: String? = nil
    var atRest: String? = nil
    var relieving: String? = nil
    var progression: String? = nil
    var onsetType: String? = nil
    var isEmpty: Bool { activityDuration == nil && atRest == nil && relieving == nil && progression == nil && onsetType == nil }
}

/// Changes the user asks for when Lofer suggests a session ("more heat", "keep it gentle").
struct TreatmentPrefs {
    var heat: Int? = nil
    var intensity: Int? = nil
    var ems: Bool? = nil
    var vibration: Bool? = nil
    var focus: String? = nil
    var minutes: Int? = nil
    var shorter = false
    var longer = false
}

// Small regex helpers so patterns read like the prototype's JavaScript.
extension String {
    func has(_ pattern: String) -> Bool { range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
    /// Capture groups of the first match ([0] = whole match). Empty groups are "".
    func groups(_ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i); return r.location == NSNotFound ? "" : (self as NSString).substring(with: r)
        }
    }
}

enum SymptomParser {
    private static let O = "(?:my |the |your )?(?:left |right )?"
    typealias E = ParsedUtterance.PartEntry
    /// Body-area phrases → area ids. "{s}" becomes the side (r/l). First match wins.
    static let parts: [(String, E)] = [
        ("front of \(O)neck|throat", E(id: "neck_f")),
        ("side of \(O)neck", E(template: "{s}_neckside", noun: "neck")),
        ("back of \(O)neck|\\bneck\\b", E(id: "neck_b")),
        ("rotator cuff", E(template: "{s}_sh_back", noun: "shoulder")),
        ("between (my |the )?shoulder ?blades|rhomboid|mid(dle)? back", E(id: "mid_back")),
        ("shoulder ?blade|scapula", E(template: "{s}_scap", noun: "shoulder blade")),
        ("\\btraps?\\b|trapezius", E(id: "upperback", template: "{s}_trap")),
        ("upper back|thoracic", E(id: "upperback")),
        ("lower back|lumbar|\\bql\\b|\\bmy back\\b|\\bback pain|\\bback (is|feels|has|hurts)", E(id: "lowerback", template: "{s}_lowback")),
        ("\\blats?\\b|latissimus", E(template: "{s}_lat", noun: "lat")),
        ("back of (my |the )?head|headache", E(id: "backhead")),
        ("\\bjaw\\b|\\bface\\b|temple", E(id: "face")),
        ("(?<!(above|over|behind) (my |your |the )?)\\bhead\\b", E(id: "headneck")),
        ("front of \(O)shoulder|front delt", E(template: "{s}_sh_front", noun: "shoulder")),
        ("back of \(O)shoulder|rear delt", E(template: "{s}_sh_back", noun: "shoulder")),
        ("top of \(O)shoulder", E(template: "{s}_sh_top", noun: "shoulder")),
        ("outside of \(O)shoulder|outer shoulder|side delt", E(template: "{s}_sh_outer", noun: "shoulder")),
        ("shoulder|\\bdelts?\\b|deltoid", E(template: "{s}_shoulder", noun: "shoulder")),
        ("bicep", E(template: "{s}_ua_front", noun: "arm")),
        ("tricep", E(template: "{s}_ua_back", noun: "arm")),
        ("upper arm", E(template: "{s}_uarm", noun: "upper arm")),
        ("tennis elbow|outer elbow|outside of (my )?(left |right )?elbow", E(template: "{s}_el_outer", noun: "elbow")),
        ("golfer'?s elbow|inner elbow|inside of (my )?(left |right )?elbow", E(template: "{s}_el_inner", noun: "elbow")),
        ("elbow", E(template: "{s}_elbow", noun: "elbow")),
        ("forearm", E(template: "{s}_farm", noun: "forearm")),
        ("back of \(O)wrist|top of \(O)wrist", E(template: "{s}_wr_dorsal", noun: "wrist")),
        ("thumb side of \(O)wrist|base of \(O)thumb", E(template: "{s}_wr_radial", noun: "wrist")),
        ("(little|pinky|small) finger side|outside of \(O)wrist", E(template: "{s}_wr_ulnar", noun: "wrist")),
        ("inside of \(O)wrist|inner wrist|palm side of \(O)wrist|underside of \(O)wrist", E(template: "{s}_wr_palm", noun: "wrist")),
        ("wrist|carpal", E(template: "{s}_wrist", noun: "wrist")),
        ("\\bthumb", E(template: "{s}_thumb", noun: "thumb")),
        ("\\bfingers?\\b|knuckle", E(template: "{s}_fingers", noun: "hand")),
        ("\\bpalm", E(template: "{s}_palm", noun: "hand")),
        ("back of \(O)hand", E(template: "{s}_backhand", noun: "hand")),
        ("\\bhands?\\b", E(template: "{s}_hand", noun: "hand")),
        ("\\barms?\\b", E(template: "{s}_arm", noun: "arm")),
        ("chest|\\bpecs?\\b", E(id: "chest", template: "{s}_chest")),
        ("oblique|love handle", E(id: "abdomen", template: "{s}_oblique")),
        ("\\babs\\b|stomach|abdom|\\bcore\\b|belly", E(id: "abdomen")),
        ("hip flexor|psoas", E(template: "{s}_hipflex", noun: "hip")),
        ("glute|\\bbum\\b|\\bbutt|buttock|piriformis", E(id: "hips", template: "{s}_glute")),
        ("outer hip|side of (my )?hip", E(template: "{s}_hipout", noun: "hip")),
        ("\\bhips?\\b", E(id: "hips", template: "{s}_hip")),
        ("groin|inner thigh|adductor", E(template: "{s}_th_inner", noun: "thigh")),
        ("\\bit ?band|outer thigh", E(template: "{s}_th_outer", noun: "thigh")),
        ("hamstring|\\bhammy|back of (my )?(left |right )?thigh", E(template: "{s}_th_back", noun: "hamstring")),
        ("\\bquads?\\b|quadricep", E(template: "{s}_th_front", noun: "quad")),
        ("thigh", E(template: "{s}_thigh", noun: "thigh")),
        ("kneecap|patella", E(template: "{s}_kn_front", noun: "knee")),
        ("back of \(O)knee|behind \(O)knee", E(template: "{s}_kn_back", noun: "knee")),
        ("inside of \(O)knee|inner knee", E(template: "{s}_kn_inner", noun: "knee")),
        ("outside of \(O)knee|outer knee", E(template: "{s}_kn_outer", noun: "knee")),
        ("\\bknees?\\b", E(template: "{s}_knee", noun: "knee")),
        ("\\bshins?\\b", E(template: "{s}_shin", noun: "shin")),
        ("\\bcalf\\b|calves", E(template: "{s}_calf", noun: "calf")),
        ("achilles", E(template: "{s}_achilles", noun: "achilles")),
        ("ankle", E(template: "{s}_ankle", noun: "ankle")),
        ("heel", E(template: "{s}_heel", noun: "heel")),
        ("plantar|\\bsole\\b|\\barch\\b", E(template: "{s}_sole", noun: "foot")),
        ("\\bfoot\\b|\\bfeet\\b|\\btoes?\\b", E(template: "{s}_footg", noun: "foot")),
        ("\\blower legs?\\b", E(template: "{s}_lleg", noun: "lower leg")),
        ("\\blegs?\\b", E(template: "{s}_leg", noun: "leg")),
    ]
    static let plural = "\\b(both|calves|shoulders|knees|hamstrings|quads|thighs|legs|arms|hips|elbows|wrists|ankles|feet|shins)\\b"

    /// Symptom types, in neutral wording for the Care Record.
    static let types: [(id: String, label: String, pattern: String)] = [
        ("tightness", "Tightness", "tight|stiff|tense|tension|knot"),
        ("cramp", "Cramping", "cramp|spasm"),
        ("sharp", "Sharp pain", "sharp|stabbing|shooting|pinch"),
        ("soreness", "Soreness", "\\bsore|destroyed|wrecked|\\bdead\\b|doms|battered"),
        ("ache", "Dull ache", "\\bach(e|es|y|ing)\\b|dull|nagging|throb"),
        ("burning", "Burning", "burn"),
        ("unclear", "Feels off", "weird|funny|strange|\\boff\\b|not right|odd"),
        ("pain", "Discomfort", "pain|hurt|uncomfortable"),
    ]
    static func typeLabel(_ id: String?) -> String? { types.first { $0.id == id }?.label }

    static let activities: [(String, String)] = [
        ("tennis|padel|squash|badminton", "tennis"), ("\\brun\\b|running|\\bran\\b|\\bjog", "running"),
        ("lifting|deadlift|squat|bench|weights", "lifting"), ("\\bgym\\b|workout|training|crossfit", "training"),
        ("sitting|desk|laptop|computer", "sitting"), ("working|at work|work all day|long day", "work"),
        ("slept|sleeping|\\bsleep\\b", "sleeping"), ("cycling|\\bbike\\b|\\bride\\b", "cycling"), ("golf", "golf"),
        ("yoga|pilates", "yoga"), ("football|soccer|basketball|rugby", "team sport"), ("climb", "climbing"),
        ("\\bhik", "hiking"), ("swim", "swimming"), ("flight|plane|driving|long drive", "travelling"),
        ("garden|lifting boxes|moving house", "lifting at home"),
    ]
    static let triggerPatterns: [(String, String)] = [
        ("(above|over) my head|overhead|reach(ing)? up", "Raising the arm overhead"),
        ("(lift|raise|raising|lifting) (my |the )?arm(?! (above|over))", "Lifting the arm"),
        ("reach(ing)? (back|behind|backwards)|behind my back", "Reaching backwards"),
        ("rotat(e|ing)|twist(ing)?", "Rotating"),
        ("(lift|lifting|raise|raising) (my |the )?hand|bend(ing)? (my )?wrist (back|up)", "Lifting the hand"),
        ("push(ing)? up|press(ing)? (on|down)|weight through", "Pushing or leaning on it"),
        ("turn(ing)? my head|look(ing)? over my shoulder", "Turning the head"),
        ("bend(ing)? (over|down|forward)|bending", "Bending forward"),
        ("when i sit|sitting for|after sitting", "Prolonged sitting"), ("walking|when i walk", "Walking"), ("stairs", "Stairs"),
        ("grip|gripping|holding|opening jars", "Gripping"), ("squat|kneel", "Squatting or kneeling"),
        ("stand(ing)? up|getting up", "Standing up"), ("typing|mouse", "Typing"), ("when i run|running uphill", "Running"),
        ("serv(e|ing)|throw", "Overhead throwing or serving"),
    ]
    /// Warning signs. urgent = urgent help now; stop = see a professional first; caution = be conservative.
    static let flagPatterns: [(FlagLevel, String, String)] = [
        (.urgent, "chest pain|pain in (my )?chest|chest (feels )?(tight|heavy|crushing)|short(ness)? of breath|can'?t breathe|struggling to breathe|fainted|passed out|slurred|face (is )?drooping", "Chest symptoms or breathing difficulty"),
        (.urgent, "worst headache|sudden severe headache|thunderclap", "Sudden severe headache"),
        (.urgent, "(lost|losing|loss of) (control of )?(my )?(bladder|bowel)|numb (between|in) (my )?(legs|groin|saddle)", "Bladder, bowel or saddle numbness"),
        (.stop, "numb|tingl|pins and needles|electric shock", "Numbness or tingling"),
        (.stop, "\\bweak(ness)?\\b|gives way|giving way|can'?t (move|lift|bear weight|walk|straighten|bend|grip)", "Weakness or loss of movement"),
        (.stop, "swollen|swelling|bruis|deform|out of place|dislocat", "Swelling, bruising or deformity"),
        (.stop, "popped|\\bsnap|heard a (pop|crack|click)|\\bfell\\b|\\bfall\\b|crash|accident|got hit|was hit|knock(ed)?|twisted", "Recent fall, knock or injury"),
        (.stop, "fever|night sweats|unexplained weight|wakes me (up )?at night|night pain|constant pain at night", "Fever, night pain or unexplained weight loss"),
        (.stop, "(calf|leg) (is |feels )?(hot|red|swollen|warm)|hot and swollen|red and hot", "Hot, red or swollen calf"),
        (.caution, "sharp|shooting|stabbing", "Sharp pain"),
        (.caution, "getting worse|worse (every|each) day|keeps getting worse", "Getting worse over time"),
    ]

    // MARK: negation and uncertainty
    /// Words that, earlier in the same clause, rule a sign out ("no numbness", "it isn't swollen").
    static let negators = "\\b(no|not|never|without|none|nor|neither|haven'?t|hasn'?t|hadn'?t|didn'?t|don'?t|doesn'?t|isn'?t|wasn'?t|aren'?t|weren'?t)\\b"
    /// Words that make a sign uncertain rather than reported ("not sure if it's numb", "maybe a bit swollen").
    static let uncertainty = "not (really |quite |totally |too )?sure|unsure|not certain|don'?t know|no idea|can'?t tell|\\bmaybe\\b|\\bmight\\b|possibly|perhaps|wonder"
    enum Mention { case reported, negated, uncertain }

    /// Splits what was said into clauses, so "no numbness but it's swollen" reads as two separate statements.
    static func clauses(_ raw: String) -> [String] {
        raw.lowercased().replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "[.,;:!?]+|\\b(but|and|although|though|however|except)\\b", with: "|", options: .regularExpression)
            .split(separator: "|").map { " " + normalise(String($0)) + " " }
    }
    static func normalise(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "[^a-z0-9/' ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    /// How `pattern` is meant across the whole utterance. Any clause that reports it wins
    /// (so "no swelling, but it is numb" still reports numbness); nil = not mentioned.
    /// Only the few words just before the sign count, so "not long after tennis my arm went numb"
    /// still reports numbness: missing a real warning sign is the worse mistake.
    static func mention(of pattern: String, in clauses: [String]) -> Mention? {
        var result: Mention?
        for c in clauses {
            guard let r = c.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            let words = c[..<r.lowerBound].split(separator: " ")
            let near = { (n: Int) in " " + words.suffix(n).joined(separator: " ") + " " }
            let m: Mention = near(6).has(uncertainty) ? .uncertain : near(4).has(negators) ? .negated : .reported
            if m == .reported { return .reported }
            if m == .uncertain || result == nil { result = m }
        }
        return result
    }

    static func severity(_ t: String) -> Int? {
        if let g = t.groups("\\b(10|[0-9])( ?/ ?10| out of (ten|10))\\b") ?? t.groups("\\b(?:about|around|maybe|like) (?:a )?(10|[0-9])\\b") ?? t.groups("^ ?(10|[0-9]) ?$") {
            return Int(g[1])
        }
        if t.has("unbearable|worst|excruciating|agony") { return 9 }
        if t.has("destroyed|killing|terrible|awful|really bad|very bad|wrecked|a lot\\b(?! better)") && !t.has("quite a lot") { return 7 }
        if t.has("quite a lot|really|very|quite bad|pretty bad") { return 6 }
        if t.has("moderate(ly)?|a fair bit|quite a bit|somewhat") { return 4 }
        if t.has("a (little|bit)|slight|mild|niggle|not (much|too bad)") { return t.has("not (much|too bad)|a little") ? 2 : 3 }
        return nil
    }
    static func onset(_ t: String) -> String? {
        if t.has("just now|this morning|today|an hour ago|earlier today") { return "today" }
        if t.has("last night") { return "last night" }
        if t.has("yesterday") { return "yesterday" }
        if t.has("few days|couple of days|since (monday|tuesday|wednesday|thursday|friday|saturday|sunday|the weekend)|this week") { return "a few days ago" }
        if t.has("(a|one|two|three|couple of|few) weeks?|last week|fortnight") { return "weeks ago" }
        if t.has("months?|years?|for ages|always|forever") { return "months ago" }
        return nil
    }
    static func prefs(_ t: String) -> TreatmentPrefs? {
        var p = TreatmentPrefs(); var any = false
        if t.has("more heat|warmer|hotter|add (some )?heat|with heat|extra heat|bit more heat") { p.heat = 1; any = true }
        if t.has("no heat|less heat|cooler|too (hot|warm)|without heat") { p.heat = -1; any = true }
        if t.has("gentle|gently|softer|lighter|keep it (easy|light|soft)|go easy") { p.intensity = -1; any = true }
        if t.has("stronger|firmer|deeper|harder|more pressure|more intense") { p.intensity = 1; any = true }
        if t.has("no (electrical|electric|ems|stim|tens|pulses|muscle stim)|without (ems|electric|stim)|not the electric") { p.ems = false; any = true }
        else if t.has("(add|with|use|include) (some )?(ems|electrical|electric|stim|tens|muscle stim)") { p.ems = true; any = true }
        if t.has("no vibration|without vibration") { p.vibration = false; any = true }
        if let g = t.groups("focus (higher|lower|further (?:out|in)|more (?:to the )?(?:front|back))|(higher|lower) (up|down)") {
            let s = g[0]
            p.focus = s.has("higher|up") ? "up" : s.has("lower|down") ? "down" : s.has("out") ? "out" : s.has("in\\b") ? "in" : s.has("front") ? "front" : "back"; any = true
        }
        if let g = t.groups("(\\d{1,2}) ?(min|minute)") { p.minutes = Int(g[1]); any = true }
        else if t.has("shorter|quick|quicker") { p.shorter = true; any = true }
        else if t.has("longer") { p.longer = true; any = true }
        return any ? p : nil
    }
    static let notWorse = "\\b(not|no|isn'?t|doesn'?t feel|never) (any )?worse"
    static func feedback(_ t: String) -> String? {
        if t.has("worse|more pain|more painful|hurts more|increas|getting sore|starting to hurt|really hurts") && !t.has(notWorse) { return "worse" }
        if t.has("too (strong|much|hard|intense)|slightly too|bit much|softer|ease off|ouch|gentler|turn it down") { return "too strong" }
        if t.has("too (weak|soft|light|gentle)|can'?t feel|barely|stronger|firmer|turn it up") { return "too weak" }
        if t.has("\\b(good|nice|fine|great|perfect|lovely|ok|okay|comfortable|just right)\\b") { return "good" }
        return nil
    }
    static func response(_ t: String) -> String? {
        if t.has("much better|way better|loads better|a lot better|great|amazing|fixed|gone") { return "much" }
        if t.has("worse") && !t.has(notWorse) { return "worse" }
        if t.has("same|no (different|change)|not really|didn'?t help|nothing changed") { return "same" }
        if t.has("better|easier|looser|eased") { return "little" }
        return nil
    }
    static func story(_ t: String) -> StoryDetails {
        var d = StoryDetails()
        if let g = t.groups("for (about |around |roughly |nearly |over )?(an? |one |two |three |four |five |half an |\\d+ )(hours?|hrs?|minutes?|mins?)") { d.activityDuration = String(g[0].dropFirst(4)) }
        if t.has("(mostly|generally|usually|otherwise) (okay|ok|fine|alright)|doesn'?t (really )?hurt (normally|at rest|when i'?m still)|fine (at rest|normally|when i'?m still)|only (hurts|bothers me) when|fine until") { d.atRest = "minimal" }
        if t.has("all the time|constant(ly)?|even (at rest|when i'?m still|lying down)|keeps me up|doesn'?t go away") { d.atRest = "present" }
        if let g = t.groups("(heat|warmth|stretching|rest|resting|moving|massage|a shower|ice) (helps|makes it better)") { d.relieving = g[1] }
        if t.has("getting better|improving|easing (off)?|better than (it was|yesterday)") { d.progression = "improving" }
        if t.has("getting worse|worse (each|every)|worsening|worse than (it was|yesterday)") { d.progression = "worsening" }
        if t.has("suddenly|all of a sudden|out of nowhere|felt a (pop|twinge|ping)") { d.onsetType = "sudden" }
        else if t.has("gradually|crept up|built up|over time|slowly got") { d.onsetType = "gradual" }
        return d
    }
    /// How a movement check felt, in the user's words ("starts pulling about halfway").
    static func movement(_ t: String) -> MovementResult? {
        var feel: MovementResult.Feel?
        if t.has("can'?t|couldn'?t|unable|too (painful|sore)|not comfortably") { feel = .cannot }
        else if t.has("quite (uncomfortable|sore|painful)|really (hurt|uncomfortable)|a lot") { feel = .quite }
        else if t.has("halfway|half way|middle|starts (hurting|pulling)|a (little|bit) uncomfortable|bit (sore|tight)|slightly|uncomfortable at the|until i get to") { feel = .little }
        else if t.has("\\b(fine|easy|easier|no problem|comfortable|felt okay|feels okay|nothing|looser|better)\\b") { feel = .fine }
        guard let f = feel else { return nil }
        var m = MovementResult(feel: f)
        if t.has("halfway|half way|middle") { m.whereInMovement = "about halfway" }
        else if t.has("(the )?top|the end|all the way|until i get to|at the end|furthest") { m.whereInMovement = "near the end of the movement" }
        else if t.has("straight away|as soon as|right at the start") { m.whereInMovement = "right from the start" }
        m.quality = t.has("pull") ? "pulling" : t.has("pinch") ? "pinching" : t.has("tight") ? "tightness" : t.has("sharp") ? "sharp" : nil
        m.sideOfIt = t.has("outside|outer") ? "outside" : t.has("inside|inner") ? "inside" : t.has("front") ? "front" : t.has("\\bback\\b") ? "back" : nil
        return m
    }

    static func parse(_ raw: String) -> ParsedUtterance {
        var r = ParsedUtterance(raw: raw)
        var t = " " + raw.lowercased()
            .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "[^a-z0-9/' ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) + " "
        t = t.replacingOccurrences(of: "  ", with: " ")
        var t2 = t.replacingOccurrences(of: "all right|right now|right away|right after|right before|right there|that's right|thats right", with: " ", options: .regularExpression)
        let lr = t2.groups("(?:to|towards?) the (left|right)|more (?:to the )?(left|right)|further (left|right)")
        if let lr { t2 = t2.replacingOccurrences(of: lr[0], with: " ") }
        if let g = t2.groups("\\b(right|left)\\b") { r.side = g[1] == "left" ? .left : .right }
        if r.side == nil && t.has(plural) { r.bilateral = true }
        let dirOnly = t.has("^( (actually|um|uh|no|yes|and|it's|its|it is|a|bit|little|slightly|more|mostly|further|toward|towards|to|the|of|it|on|at|that|one|side|part|area|spot|than|there|same|just|higher|lower|up|down|above|below|outside|outer|inside|inner|front|back|left|right|focus|move|can|you|please))+ $")
        if !dirOnly { r.entry = parts.first { t.has($0.0) }?.1 }
        if t.has("\\b(lower|down|below|beneath|underneath)\\b") { r.direction = "down" }
        else if t.has("\\b(higher|up|above)\\b") { r.direction = "up" }
        else if t.has("\\b(front of it|to the front|toward the front|towards the front|more front|at the front|on the front)\\b") { r.direction = "front" }
        else if t.has("\\b(back of it|further back|to the back|toward the back|towards the back|more back|at the back|on the back)\\b") { r.direction = "back" }
        else if t.has("\\b(outside|outer|outwards?)\\b") { r.direction = "out" }
        else if t.has("\\b(inside|inner|inwards?)\\b") { r.direction = "in" }
        else if let lr { r.direction = lr.dropFirst().contains("left") ? "L" : "R" }
        r.slight = t.has("slight|little|\\bbit\\b|\\btad\\b|touch")
        if let g = t.groups("\\b(turn|flip|rotate|spin)\\b|show (me )?(the )?(back|front|side)"), !t.has("turn(ing)? my head") {
            r.turn = g[0].has("back") ? "back" : g[0].has("front") ? "front" : g[0].has("side") ? "side" : "toggle"
        }
        r.zoom = t.has("zoom|closer|narrow")
        r.confirm = t.has("\\b(yes|yep|yeah|yup|correct|exactly|perfect)\\b|that'?s (it|the spot|right)|spot on|right there|looks (right|good)|sounds good")
        r.deny = t.has("\\b(no|nope|not quite|not really|wrong)\\b")
        r.start = t.has("\\b(start|begin|go ahead|let'?s go|let'?s do it|try (it|this)|ready)\\b")
        let cl = clauses(raw)
        // "Not sharp, more achy" → achy: a feeling that's ruled out isn't the feeling.
        r.type = types.first { mention(of: $0.pattern, in: cl) == .reported }?.id
        r.severity = severity(t)
        r.onset = onset(t)
        r.activity = activities.first { t.has($0.0) }?.1
        for (p, label) in triggerPatterns where t.has(p) && !r.triggers.contains(label) { r.triggers.append(label) }
        r.previous = t.has("again|keeps|always|every time|recurring|comes back|keeps coming back|usual|as usual|same as last")
        for (level, p, label) in flagPatterns {
            switch mention(of: p, in: cl) {
            case .reported?: r.flags.append(SafetyFlag(level: level, label: label))
            case .negated?: r.negatedFlags.append(SafetyFlag(level: level, label: label))
            case .uncertain?: r.uncertainFlags.append(SafetyFlag(level: level, label: label))
            case nil: break
            }
        }
        r.unsure = t.has(uncertainty)
        r.skip = t.has("\\bskip|rather not (say|answer)|next question")
        r.prefs = prefs(t)
        r.feedback = feedback(t)
        r.response = response(t)
        r.story = story(t)
        r.movement = movement(t)
        return r
    }
}
