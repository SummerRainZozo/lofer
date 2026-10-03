import SwiftUI
import simd

/// Front + back silhouettes with a glow wherever episodes happened (brighter = more often).
/// The silhouette is traced once from the same body shape (BodySDF), so it always matches the 3D body.
struct BodyMap2D: View {
    let episodes: [Episode]
    var mesh: BodyMesh? = nil                 // used to place glows for episodes saved without an exact spot
    var highlightGroup: String? = nil
    var onTapGroup: ((String) -> Void)? = nil
    @State private var silhouette: Silhouette? = Silhouette.cached

    var body: some View {
        GeometryReader { geo in
            let W = Double(geo.size.width), H = W / 2 * 1.55, sc = H * 0.92 / 1.83, top = H * 0.04, panels = [W * 0.25, W * 0.75]
            let dots = dotPositions(W: W, sc: sc, top: top, panels: panels)
            Canvas { ctx, _ in
                if let s = silhouette {
                    for (pi, cx) in panels.enumerated() {
                        var path = Path()
                        for j in 0..<s.ny { for i in 0..<s.nx where s.mask[i + s.nx * j] {
                            let x = Double(s.x0) + Double(i) * Double(s.h), y = Double(s.y0) + Double(j) * Double(s.h)
                            let px = cx + (pi == 1 ? -x : x) * sc, py = top + (1.8 - y) * sc, d = Double(s.h) * sc * 1.1
                            path.addRect(CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d))
                        } }
                        ctx.fill(path, with: .color(Color.loferPeach.opacity(0.13)))
                    }
                }
                for d in dots {
                    let on = highlightGroup == nil || highlightGroup == d.group, r = d.r * 2.4
                    ctx.fill(Path(ellipseIn: CGRect(x: d.p.x - r, y: d.p.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [Color(hex: 0xF6E2D2).opacity(on ? 0.95 : 0.25), Color.loferPeach.opacity(on ? 0.55 : 0.12), .clear]), center: d.p, startRadius: 0, endRadius: r))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { loc in
                if let hit = dots.min(by: { hypot($0.p.x - loc.x, $0.p.y - loc.y) < hypot($1.p.x - loc.x, $1.p.y - loc.y) }),
                   hypot(hit.p.x - loc.x, hit.p.y - loc.y) < hit.r * 2.4 + 8 { onTapGroup?(hit.group) }
            }
            HStack { Text("FRONT").frame(maxWidth: .infinity); Text("BACK").frame(maxWidth: .infinity) }
                .font(LoferFont.ui(10.5)).tracking(1.6).foregroundStyle(Color.loferFaint).offset(y: H + 4)
        }
        .aspectRatio(2 / 1.65, contentMode: .fit)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x1E1A19).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.loferLine))
        .task { if silhouette == nil { silhouette = await Task.detached { Silhouette.compute() }.value } }
    }

    private struct Dot { var p: CGPoint; var r: Double; var group: String }
    private func dotPositions(W: Double, sc: Double, top: Double, panels: [Double]) -> [Dot] {
        let atlas = BodyAtlas.shared
        let grouped = Dictionary(grouping: episodes) { atlas.group(of: $0.symptom.areaId) }
        return grouped.compactMap { g, list in
            guard let e = list.first else { return nil }
            let (p, n): (SIMD3<Float>, SIMD3<Float>)
            if let pt = e.point, let nn = e.normal { p = SIMD3(pt[0], pt[1], pt[2]); n = SIMD3(nn[0], nn[1], nn[2]) }
            else if let rp = mesh?.representativePoint(of: e.symptom.areaId) { (p, n) = rp } else { return nil }
            let back = n.z < -0.15, cx = panels[back ? 1 : 0]
            return Dot(p: CGPoint(x: cx + Double(back ? -p.x : p.x) * sc, y: top + (1.8 - Double(p.y)) * sc), r: 4 + 2.4 * sqrt(Double(list.count)), group: g)
        }
    }
}

/// A 2D occupancy grid of the body seen from the front (the back is its mirror image).
struct Silhouette: Sendable {
    let mask: [Bool]; let nx: Int; let ny: Int; let h: Float; let x0: Float; let y0: Float
    nonisolated(unsafe) static var cached: Silhouette?
    static func compute() -> Silhouette {
        let h: Float = 0.012, x0: Float = -0.4, y0: Float = -0.03, nx = Int(0.8 / h), ny = Int(1.83 / h)
        var m = [Bool](repeating: false, count: nx * ny)
        for j in 0..<ny { for i in 0..<nx {
            let x = x0 + Float(i) * h, y = y0 + Float(j) * h
            var z: Float = -0.2
            while z <= 0.2 { if BodySDF.sdf([x, y, z]) < 0 { m[i + nx * j] = true; break }; z += 0.018 }
        } }
        let s = Silhouette(mask: m, nx: nx, ny: ny, h: h, x0: x0, y0: y0); cached = s; return s
    }
}
