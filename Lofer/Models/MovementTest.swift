import Foundation

/// A simple wellness movement check shown before and after a session. Not diagnostic:
/// the user just says how it feels, so before/after can be compared.
struct MovementTest: Identifiable {
    let id: String
    let name: String
    let matches: String        // area ids this check is used for (regex)
    let intro: String
    let start: String
    let move: String           // may contain {side}
    let back: String
    let notice: String

    static let stopLine = "Move only as far as feels comfortable. Stop if it gets sharp or starts to hurt more."

    static let all: [MovementTest] = [
        .init(id: "arm_raise", name: "Arm raise", matches: "_sh_|shoulder|_ua_|uarm|_trap|_scap|chest|_lat",
              intro: "Before we start, let’s see how your shoulder feels with a simple movement.",
              start: "Stand tall, arms relaxed by your sides.", move: "Slowly raise your {side} arm forwards and up.", back: "Lower it slowly back down.",
              notice: "Where it starts to feel tight, and how high your arm goes."),
        .init(id: "head_turn", name: "Head turn", matches: "neck|backhead|headneck",
              intro: "Before we start, let’s see how your neck feels when you turn.",
              start: "Sit or stand tall, looking straight ahead.", move: "Slowly turn your head to look over one shoulder.", back: "Come back to the middle, then try the other side.",
              notice: "Which side feels tighter, and how far you can turn."),
        .init(id: "forward_reach", name: "Forward reach", matches: "lowerback|lowback|_glute|_hip|hips|mid_back|upperback",
              intro: "Before we start, let’s see how your back feels with a gentle reach.",
              start: "Stand with feet hip-width apart, knees soft, hands on your thighs.", move: "Slide your hands slowly down towards your knees.", back: "Roll back up slowly.",
              notice: "How far you can reach and where you feel it."),
        .init(id: "heel_raise", name: "Heel raise", matches: "calf|achilles|ankle|heel|sole|foot|lleg|shin|lc_",
              intro: "Before we start, let’s see how your calf feels with a simple movement.",
              start: "Stand facing a wall with a hand on it for balance.", move: "Rise slowly onto your toes.", back: "Lower your heels slowly back down.",
              notice: "Tightness in the calf or heel as you rise."),
        .init(id: "mini_squat", name: "Mini squat", matches: "knee|_kn_|thigh|_th_",
              intro: "Before we start, let’s see how your knee feels with a small bend.",
              start: "Stand behind a chair, holding its back.", move: "Bend your knees a little, as if starting to sit.", back: "Stand back up. Keep it shallow.",
              notice: "Where you feel it in the knee or thigh."),
        .init(id: "wrist_lift", name: "Wrist lift", matches: "elbow|_el_|farm|_fa_|wrist|_wr_|hand|palm|thumb|fingers",
              intro: "Before we start, let’s see how your wrist feels with a simple movement.",
              start: "Rest your forearm on a table, palm facing down, hand just over the edge.", move: "Slowly lift the back of your hand up.", back: "Lower it slowly back to level.",
              notice: "Any pulling along the forearm or around the wrist."),
    ]
    static func forArea(_ id: String) -> MovementTest? { all.first { id.has($0.matches) } }
}
