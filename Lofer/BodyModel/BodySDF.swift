import simd

/// The body's shape as a "signed distance field": a function that says how far any point is
/// from the skin (negative = inside). Ported from the prototype's geo.js.
/// - The visible mesh is pre-generated from this (tools/generate-body-mesh.js → BodyMesh.bin).
/// - At runtime it's used to snap points onto the skin and to name the area under a point.
/// Units are metres, y up, +z faces the viewer, +x is the figure's LEFT side.
enum BodySDF {
    struct Prim {
        enum Shape { case cone(a: SIMD3<Float>, b: SIMD3<Float>, r1: Float, r2: Float), ellipsoid(c: SIMD3<Float>, r: SIMD3<Float>) }
        var shape: Shape
        var part: String
        var k: Float           // how softly it blends into its neighbours
        var side: BodySide?
    }

    static let prims: [Prim] = {
        var P: [Prim] = []
        func E(_ c: SIMD3<Float>, _ r: SIMD3<Float>, _ part: String, _ k: Float, _ s: BodySide? = nil) { P.append(Prim(shape: .ellipsoid(c: c, r: r), part: part, k: k, side: s)) }
        func C(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r1: Float, _ r2: Float, _ part: String, _ k: Float, _ s: BodySide? = nil) { P.append(Prim(shape: .cone(a: a, b: b, r1: r1, r2: r2), part: part, k: k, side: s)) }
        E([0, 0.965, -0.005], [0.15, 0.105, 0.098], "hips", 0.05)
        E([0, 1.10, 0], [0.125, 0.13, 0.085], "torso", 0.07)
        E([0, 1.27, -0.008], [0.15, 0.13, 0.097], "torso", 0.07)
        E([0, 1.375, -0.012], [0.16, 0.055, 0.078], "torso", 0.05)
        C([0, 1.41, -0.012], [0, 1.55, 0], 0.056, 0.048, "neck", 0.045)
        E([0, 1.645, 0.005], [0.077, 0.103, 0.09], "head", 0.035)
        E([0, 1.588, 0.028], [0.058, 0.048, 0.058], "head", 0.03)
        for s in [BodySide.left, .right] {
            let x: Float = s == .left ? 1 : -1
            E([x * 0.072, 1.29, 0.05], [0.074, 0.056, 0.045], "torso", 0.04)
            C([x * 0.035, 1.46, -0.02], [x * 0.15, 1.405, -0.02], 0.042, 0.036, "torso", 0.05)
            E([x * 0.08, 0.93, -0.05], [0.09, 0.095, 0.075], "hips", 0.045, s)
            E([x * 0.185, 1.37, 0], [0.056, 0.062, 0.058], "shoulder", 0.04, s)
            C([x * 0.195, 1.335, 0], [x * 0.265, 1.08, -0.005], 0.047, 0.036, "uarm", 0.03, s)
            E([x * 0.222, 1.22, 0.022], [0.033, 0.07, 0.03], "uarm", 0.03, s)
            E([x * 0.228, 1.23, -0.024], [0.034, 0.08, 0.03], "uarm", 0.03, s)
            C([x * 0.265, 1.08, -0.005], [x * 0.31, 0.85, 0.02], 0.037, 0.025, "farm", 0.025, s)
            E([x * 0.262, 1.005, 0], [0.034, 0.07, 0.035], "farm", 0.03, s)
            E([x * 0.266, 1.078, -0.034], [0.017, 0.02, 0.014], "elbow", 0.015, s)
            E([x * 0.32, 0.785, 0.027], [0.019, 0.047, 0.04], "palm", 0.026, s)
            E([x * 0.317, 0.716, 0.031], [0.015, 0.045, 0.033], "fingers", 0.012, s)
            C([x * 0.311, 0.808, 0.06], [x * 0.306, 0.752, 0.082], 0.012, 0.0095, "thumb", 0.012, s)
            C([x * 0.088, 0.93, 0], [x * 0.1, 0.53, 0.005], 0.087, 0.052, "thigh", 0.05, s)
            E([x * 0.1, 0.5, 0.012], [0.05, 0.056, 0.052], "knee", 0.03, s)
            C([x * 0.1, 0.49, 0], [x * 0.105, 0.085, -0.018], 0.05, 0.032, "lleg", 0.03, s)
            E([x * 0.103, 0.355, -0.03], [0.047, 0.1, 0.05], "lleg", 0.035, s)
            E([x * 0.108, 0.035, 0.045], [0.042, 0.035, 0.115], "foot", 0.025, s)
        }
        return P
    }()

    private static func roundCone(_ p: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r1: Float, _ r2: Float) -> Float {
        let ba = b - a, l2 = simd_dot(ba, ba), rr = r1 - r2, a2 = l2 - rr * rr, il2 = 1 / l2
        let pa = p - a, y = simd_dot(pa, ba), z = y - l2
        let q = pa * l2 - ba * y
        let x2 = simd_dot(q, q), y2 = y * y * l2, z2 = z * z * l2
        let k = (rr > 0 ? 1 : rr < 0 ? -1 : 0) * rr * rr * x2
        if (z > 0 ? 1 : z < 0 ? -1 : 0) * a2 * z2 > k { return sqrt(x2 + z2) * il2 - r2 }
        if (y > 0 ? 1 : y < 0 ? -1 : 0) * a2 * y2 < k { return sqrt(x2 + y2) * il2 - r1 }
        return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1
    }
    private static func ellipsoid(_ p: SIMD3<Float>, _ c: SIMD3<Float>, _ r: SIMD3<Float>) -> Float {
        let d = p - c, k0 = simd_length(d / r), k1 = simd_length(d / (r * r))
        return k1 < 1e-9 ? -min(r.x, r.y, r.z) : k0 * (k0 - 1) / k1
    }
    static func distance(_ prim: Prim, _ p: SIMD3<Float>) -> Float {
        switch prim.shape {
        case let .cone(a, b, r1, r2): return roundCone(p, a, b, r1, r2)
        case let .ellipsoid(c, r): return ellipsoid(p, c, r)
        }
    }
    /// Distance from p to the skin (smoothly blended union of all parts).
    static func sdf(_ p: SIMD3<Float>) -> Float {
        var d = distance(prims[0], p)
        for prim in prims.dropFirst() {
            let di = distance(prim, p), h = max(prim.k - abs(d - di), 0) / prim.k
            d = min(d, di) - h * h * prim.k * 0.25
        }
        return d
    }
    static func normal(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let e: Float = 0.002
        let g = SIMD3<Float>(sdf(p + [e, 0, 0]) - sdf(p - [e, 0, 0]), sdf(p + [0, e, 0]) - sdf(p - [0, e, 0]), sdf(p + [0, 0, e]) - sdf(p - [0, 0, e]))
        return simd_normalize(g)
    }
    /// Pull a point onto the skin.
    static func snap(_ p: SIMD3<Float>) -> (point: SIMD3<Float>, normal: SIMD3<Float>) {
        var q = p
        for _ in 0..<10 { let d = sdf(q); if abs(d) < 1e-4 { break }; q -= normal(q) * d }
        return (q, normal(q))
    }

    /// Which named area does a surface point (with normal) belong to?
    static func classify(_ p: SIMD3<Float>, _ n: SIMD3<Float>) -> String {
        var best = 0, bd = Float.greatestFiniteMagnitude
        for (i, prim) in prims.enumerated() { let d = distance(prim, p); if d < bd { bd = d; best = i } }
        let prim = prims[best]
        let s = prim.side?.rawValue ?? (p.x >= 0 ? "l" : "r")
        let out = n.x * (s == "l" ? 1 : -1)
        let facet = abs(n.z) >= abs(out) ? (n.z > 0 ? "front" : "back") : (out > 0 ? "outer" : "inner")
        var t: Float = 0.5
        if case let .cone(a, b, _, _) = prim.shape { let ba = b - a; t = max(0, min(1, simd_dot(p - a, ba) / simd_dot(ba, ba))) }
        let wrist = ["outer": "_wr_dorsal", "inner": "_wr_palm", "front": "_wr_radial", "back": "_wr_ulnar"]
        let (x, y, z) = (p.x, p.y, p.z)
        switch prim.part {
        case "head": return n.z > 0.05 ? "face" : "backhead"
        case "neck": return n.z > 0.45 ? "neck_f" : n.z < -0.3 ? "neck_b" : s + "_neckside"
        case "torso":
            if y > 1.37 && (n.y > 0.45 || n.z < -0.1) { return s + "_trap" }
            if n.z > 0.3 { return y > 1.19 ? s + "_chest" : y > 1.07 ? "upper_abs" : "lower_abs" }
            if n.z < -0.3 { return y > 1.17 ? (abs(x) < 0.035 ? "mid_back" : s + "_scap") : s + "_lowback" }
            return y > 1.18 ? s + "_lat" : s + "_oblique"
        case "hips":
            if n.z > 0.3 { return s + "_hipflex" }
            if n.z < -0.2 { return s + "_glute" }
            return abs(x) > 0.1 ? s + "_hipout" : (n.z > 0 ? s + "_hipflex" : s + "_glute")
        case "shoulder":
            if n.y > 0.6 { return s + "_sh_top" }
            return s + "_sh_" + (facet == "inner" ? (n.z >= 0 ? "front" : "back") : facet)
        case "uarm": return t > 0.86 ? s + "_el_" + facet : s + "_ua_" + facet
        case "elbow": return s + "_el_back"
        case "farm":
            if t < 0.1 { return s + "_el_" + facet }
            if t > 0.86 { return s + wrist[facet]! }
            if t > 0.72 { return s + "_wr_distal" }
            return s + "_fa_" + facet
        case "palm":
            if y > 0.82 { return s + wrist[facet]! }
            return s + ["inner": "_palm", "outer": "_backhand", "front": "_thumb", "back": "_hand_edge"][facet]!
        case "fingers": return s + "_fingers"
        case "thumb": return s + "_thumb"
        case "thigh": return t > 0.9 ? s + "_kn_" + facet : s + "_th_" + facet
        case "knee": return s + "_kn_" + facet
        case "lleg":
            if y > 0.46 { return s + "_kn_" + facet }
            if y < 0.1 { return s + "_ankle" }
            if facet == "back" && y < 0.2 { return s + "_achilles" }
            return s + ["front": "_shin", "back": "_calf", "outer": "_lc_outer", "inner": "_lc_inner"][facet]!
        case "foot":
            if z < -0.02 { return s + "_heel" }
            if n.y < -0.4 { return s + "_sole" }
            if y > 0.065 && z < 0.03 { return s + "_ankle" }
            return s + "_foottop"
        default: return "face"
        }
    }
}
