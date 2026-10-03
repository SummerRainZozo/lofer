import Foundation

/// Which side of the body. Raw values match the area ids ("r_sh_front").
enum BodySide: String, Codable {
    case left = "l", right = "r"
    var word: String { self == .left ? "left" : "right" }
    var title: String { self == .left ? "Left" : "Right" }
}

/// One named area of the body (a node in the tree). Leaves are the smallest selectable areas.
struct BodyRegion: Identifiable, Hashable {
    let id: String
    let parent: String?
    var children: [String] = []
    var side: BodySide?
    let label: String          // "Front of shoulder"
    var crumb: String?         // short breadcrumb name ("Shoulder")
    var term: String?          // anatomical term, shown small (never required from the user)
    var say: String?           // how Lofer says it ("the front of your right shoulder")

    var shortName: String { crumb ?? label }
    var spoken: String { say ?? "your \(label.lowercased())" }
}

/// BODY MODEL: the tree Body › Right arm › Shoulder › Front of shoulder.
/// Every layer refers to areas by id. The order of leaves matters: it must match
/// Resources/Body/BodyMeshRegions.json (checked at load time).
final class BodyAtlas {
    static let shared = BodyAtlas()
    private(set) var nodes: [String: BodyRegion] = [:]
    private(set) var leaves: [String] = []
    private(set) var leafIndex: [String: Int] = [:]

    subscript(id: String) -> BodyRegion { nodes[id]! }
    func node(_ id: String?) -> BodyRegion? { id.flatMap { nodes[$0] } }

    func isLeaf(_ id: String) -> Bool { nodes[id]?.children.isEmpty ?? true }
    func leaves(of id: String) -> [String] { isLeaf(id) ? [id] : nodes[id]!.children.flatMap { leaves(of: $0) } }
    func path(to id: String) -> [String] {
        var p: [String] = []; var cur: String? = id
        while let c = cur { p.insert(c, at: 0); cur = nodes[c]?.parent }
        return p
    }
    func lca(_ a: String, _ b: String) -> String {
        let pa = path(to: a), pb = path(to: b); var r = "body"
        for i in 0..<min(pa.count, pb.count) where pa[i] == pb[i] { r = pa[i] }
        return r
    }
    /// Body Memory groups episodes at "joint / segment" level: r_sh_front → r_shoulder.
    func group(of id: String) -> String { let p = path(to: id); return p.count > 2 ? p[2] : p.last! }
    func laterality(of id: String) -> String { nodes[id]?.side?.word ?? "centre" }

    // MARK: - Building the tree (mirrors the prototype's anatomy.js exactly)
    private func add(_ id: String, _ parent: String?, _ label: String, side: BodySide? = nil, crumb: String? = nil, term: String? = nil, say: String? = nil) {
        var n = BodyRegion(id: id, parent: parent, side: side ?? parent.flatMap { nodes[$0]?.side }, label: label, crumb: crumb, term: term, say: say)
        n.children = []
        nodes[id] = n
        if let p = parent { nodes[p]?.children.append(id) }
    }
    private func leafSet(_ parent: String, _ s: BodySide, _ rows: [(String, String, String, String)]) {
        for (suf, label, term, say) in rows { add("\(s.rawValue)_\(suf)", parent, label, term: term, say: say) }
    }

    private init() {
        add("body", nil, "Full body", crumb: "Body")
        add("headneck", "body", "Head & neck", say: "your head and neck")
        add("face", "headneck", "Face & jaw", term: "masseter · temporalis", say: "your face and jaw")
        add("backhead", "headneck", "Back of head", term: "suboccipitals", say: "the back of your head")
        add("neck_f", "headneck", "Front of neck", term: "sternocleidomastoid", say: "the front of your neck")
        add("neck_b", "headneck", "Back of neck", term: "upper trapezius · levator scapulae", say: "the back of your neck")
        add("torso", "body", "Torso", say: "your torso")
        add("chest", "torso", "Chest", say: "your chest")
        add("abdomen", "torso", "Abdomen & sides", crumb: "Abdomen", say: "your abdomen")
        add("upper_abs", "abdomen", "Upper abdomen", term: "rectus abdominis", say: "your upper abdomen")
        add("lower_abs", "abdomen", "Lower abdomen", term: "rectus abdominis · lower", say: "your lower abdomen")
        add("upperback", "torso", "Upper back", say: "your upper back")
        add("mid_back", "upperback", "Between shoulder blades", term: "rhomboids · mid trapezius", say: "the area between your shoulder blades")
        add("lowerback", "torso", "Lower back", say: "your lower back")
        for s in [BodySide.right, .left] {
            let S = s.title, lo = s.word, r = s.rawValue
            add("\(r)_neckside", "headneck", "\(S) side of neck", side: s, term: "scalenes", say: "the \(lo) side of your neck")
            add("\(r)_chest", "chest", "\(S) chest", side: s, term: "pectoralis major", say: "the \(lo) side of your chest")
            add("\(r)_oblique", "abdomen", "\(S) side", side: s, term: "obliques", say: "your \(lo) side")
            add("\(r)_trap", "upperback", "\(S) upper trap", side: s, term: "upper trapezius", say: "your \(lo) upper trap")
            add("\(r)_scap", "upperback", "\(S) shoulder blade", side: s, term: "infraspinatus · teres", say: "your \(lo) shoulder blade")
            add("\(r)_lat", "upperback", "\(S) lat", side: s, term: "latissimus dorsi", say: "your \(lo) lat")
            add("\(r)_lowback", "lowerback", "\(S) lower back", side: s, term: "erector spinae · QL", say: "the \(lo) side of your lower back")
        }
        for s in [BodySide.right, .left] {
            let S = s.title, lo = s.word, r = s.rawValue, A = "\(r)_arm"
            add(A, "body", "\(S) arm", side: s, say: "your \(lo) arm")
            add("\(r)_shoulder", A, "\(S) shoulder", crumb: "Shoulder", say: "your \(lo) shoulder")
            leafSet("\(r)_shoulder", s, [
                ("sh_front", "Front of shoulder", "anterior deltoid", "the front of your \(lo) shoulder"),
                ("sh_outer", "Outer shoulder", "lateral deltoid", "the outside of your \(lo) shoulder"),
                ("sh_back", "Back of shoulder", "posterior deltoid · rotator cuff", "the back of your \(lo) shoulder"),
                ("sh_top", "Top of shoulder", "AC joint · supraspinatus", "the top of your \(lo) shoulder")])
            add("\(r)_uarm", A, "\(S) upper arm", crumb: "Upper arm", say: "your \(lo) upper arm")
            leafSet("\(r)_uarm", s, [
                ("ua_front", "Front of upper arm", "biceps", "the front of your \(lo) upper arm"),
                ("ua_outer", "Outer upper arm", "brachialis · deltoid insertion", "the outside of your \(lo) upper arm"),
                ("ua_back", "Back of upper arm", "triceps", "the back of your \(lo) upper arm"),
                ("ua_inner", "Inner upper arm", "coracobrachialis", "the inside of your \(lo) upper arm")])
            add("\(r)_elbow", A, "\(S) elbow", crumb: "Elbow", say: "your \(lo) elbow")
            leafSet("\(r)_elbow", s, [
                ("el_front", "Elbow crease", "biceps tendon", "the crease of your \(lo) elbow"),
                ("el_outer", "Outer elbow", "lateral epicondyle · tennis elbow", "the outside of your \(lo) elbow"),
                ("el_back", "Back of elbow", "olecranon · triceps tendon", "the back of your \(lo) elbow"),
                ("el_inner", "Inner elbow", "medial epicondyle · golfer's elbow", "the inside of your \(lo) elbow")])
            add("\(r)_farm", A, "\(S) forearm", crumb: "Forearm", say: "your \(lo) forearm")
            leafSet("\(r)_farm", s, [
                ("fa_outer", "Back of forearm", "wrist extensors", "the back of your \(lo) forearm"),
                ("fa_inner", "Palm side of forearm", "wrist flexors", "the palm side of your \(lo) forearm"),
                ("fa_front", "Thumb side of forearm", "brachioradialis", "the thumb side of your \(lo) forearm"),
                ("fa_back", "Little-finger side of forearm", "flexor carpi ulnaris", "the little-finger side of your \(lo) forearm")])
            add("\(r)_wrist", A, "\(S) wrist", crumb: "Wrist", say: "your \(lo) wrist")
            leafSet("\(r)_wrist", s, [
                ("wr_dorsal", "Back of wrist", "dorsal wrist · extensor tendons", "the back of your \(lo) wrist"),
                ("wr_palm", "Palm side of wrist", "carpal tunnel · flexor tendons", "the palm side of your \(lo) wrist"),
                ("wr_radial", "Thumb side of wrist", "radial wrist", "the thumb side of your \(lo) wrist"),
                ("wr_ulnar", "Little-finger side of wrist", "ulnar wrist", "the little-finger side of your \(lo) wrist"),
                ("wr_distal", "Lower forearm", "distal forearm", "just above your \(lo) wrist")])
            add("\(r)_hand", A, "\(S) hand", crumb: "Hand", say: "your \(lo) hand")
            leafSet("\(r)_hand", s, [
                ("palm", "Palm", "palm · thenar muscles", "your \(lo) palm"),
                ("backhand", "Back of hand", "extensor tendons", "the back of your \(lo) hand"),
                ("thumb", "Thumb", "thumb and its base", "your \(lo) thumb"),
                ("fingers", "Fingers", "finger flexors · extensors", "the fingers of your \(lo) hand"),
                ("hand_edge", "Little-finger edge", "hypothenar", "the little-finger edge of your \(lo) hand")])
        }
        add("hips", "body", "Hips & glutes", crumb: "Hips", say: "your hips")
        for s in [BodySide.right, .left] {
            let S = s.title, lo = s.word, r = s.rawValue
            add("\(r)_hip", "hips", "\(S) hip", side: s, say: "your \(lo) hip")
            leafSet("\(r)_hip", s, [
                ("hipflex", "Hip flexor", "iliopsoas", "your \(lo) hip flexor"),
                ("hipout", "Outer hip", "glute medius · TFL", "the outside of your \(lo) hip"),
                ("glute", "Glute", "gluteus maximus", "your \(lo) glute")])
        }
        for s in [BodySide.right, .left] {
            let S = s.title, lo = s.word, r = s.rawValue, L = "\(r)_leg"
            add(L, "body", "\(S) leg", side: s, say: "your \(lo) leg")
            add("\(r)_thigh", L, "\(S) thigh", crumb: "Thigh", say: "your \(lo) thigh")
            leafSet("\(r)_thigh", s, [
                ("th_front", "Front of thigh", "quadriceps", "the front of your \(lo) thigh"),
                ("th_outer", "Outer thigh", "IT band", "the outside of your \(lo) thigh"),
                ("th_back", "Back of thigh", "hamstrings", "the back of your \(lo) thigh"),
                ("th_inner", "Inner thigh", "adductors", "the inside of your \(lo) thigh")])
            add("\(r)_knee", L, "\(S) knee", crumb: "Knee", say: "your \(lo) knee")
            leafSet("\(r)_knee", s, [
                ("kn_front", "Kneecap", "patellar tendon", "your \(lo) kneecap"),
                ("kn_outer", "Outer knee", "LCL · IT band", "the outside of your \(lo) knee"),
                ("kn_back", "Back of knee", "popliteus", "the back of your \(lo) knee"),
                ("kn_inner", "Inner knee", "MCL", "the inside of your \(lo) knee")])
            add("\(r)_lleg", L, "\(S) lower leg", crumb: "Lower leg", say: "your \(lo) lower leg")
            leafSet("\(r)_lleg", s, [
                ("shin", "Shin", "tibialis anterior", "your \(lo) shin"),
                ("lc_outer", "Outer calf", "peroneals", "the outside of your \(lo) calf"),
                ("calf", "Calf", "gastrocnemius · soleus", "your \(lo) calf"),
                ("lc_inner", "Inner calf", "medial gastrocnemius", "the inside of your \(lo) calf"),
                ("achilles", "Achilles", "achilles tendon", "your \(lo) achilles")])
            add("\(r)_footg", L, "\(S) ankle & foot", crumb: "Ankle & foot", say: "your \(lo) ankle and foot")
            leafSet("\(r)_footg", s, [
                ("ankle", "Ankle", "talocrural joint", "your \(lo) ankle"),
                ("foottop", "Top of foot", "extensor tendons", "the top of your \(lo) foot"),
                ("heel", "Heel", "calcaneus", "your \(lo) heel"),
                ("sole", "Sole", "plantar fascia", "the sole of your \(lo) foot")])
        }
        nodes["body"]?.children = ["headneck", "torso", "r_arm", "l_arm", "hips", "r_leg", "l_leg"]
        leaves = leaves(of: "body")
        for (i, l) in leaves.enumerated() { leafIndex[l] = i }
    }
}
