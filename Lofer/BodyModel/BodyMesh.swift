import Foundation
import simd

/// The pre-generated body mesh (Resources/Body/BodyMesh.bin) plus per-area statistics
/// used to frame the camera ("where is the right shoulder, how big, which way does it face").
/// Regenerate with: node tools/generate-body-mesh.js
final class BodyMesh {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let regions: [UInt16]          // per vertex: index into BodyAtlas.shared.leaves
    let indices: [UInt32]

    struct AreaStats { var center: SIMD3<Float>; var radius: Float; var normal: SIMD3<Float> }
    private(set) var stats: [String: AreaStats] = [:]
    private let atlas = BodyAtlas.shared

    static func loadFromBundle() -> BodyMesh? {
        guard let url = Bundle.main.url(forResource: "BodyMesh", withExtension: "bin"),
              let data = try? Data(contentsOf: url),
              let regionsURL = Bundle.main.url(forResource: "BodyMeshRegions", withExtension: "json"),
              let names = try? JSONDecoder().decode([String].self, from: Data(contentsOf: regionsURL)) else { return nil }
        return BodyMesh(data: data, regionNames: names)
    }

    init?(data: Data, regionNames: [String]) {
        func u32(_ o: Int) -> UInt32 { data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: o, as: UInt32.self) } }
        let v = Int(u32(0)), ic = Int(u32(4))
        guard data.count >= 8 + v * 26 + ic * 4 else { return nil }
        var pos = [SIMD3<Float>](), nor = [SIMD3<Float>](), reg = [UInt16](), idx = [UInt32]()
        pos.reserveCapacity(v); nor.reserveCapacity(v); reg.reserveCapacity(v); idx.reserveCapacity(ic)
        data.withUnsafeBytes { raw in
            var o = 8
            for _ in 0..<v { pos.append(SIMD3(raw.loadUnaligned(fromByteOffset: o, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 4, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 8, as: Float.self))); o += 12 }
            for _ in 0..<v { nor.append(SIMD3(raw.loadUnaligned(fromByteOffset: o, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 4, as: Float.self), raw.loadUnaligned(fromByteOffset: o + 8, as: Float.self))); o += 12 }
            // Map the file's region order onto the app's atlas order by name (safe if they ever differ).
            let remap = regionNames.map { UInt16(BodyAtlas.shared.leafIndex[$0] ?? 0) }
            for _ in 0..<v { let r = Int(raw.loadUnaligned(fromByteOffset: o, as: UInt16.self)); reg.append(remap[min(r, remap.count - 1)]); o += 2 }
            for _ in 0..<ic { idx.append(raw.loadUnaligned(fromByteOffset: o, as: UInt32.self)); o += 4 }
        }
        positions = pos; normals = nor; regions = reg; indices = idx
        computeStats()
    }

    private func computeStats() {
        let L = atlas.leaves.count
        var n = [Int](repeating: 0, count: L), sum = [SIMD3<Float>](repeating: .zero, count: L), nsum = sum
        var mn = [SIMD3<Float>](repeating: SIMD3(repeating: 9), count: L), mx = [SIMD3<Float>](repeating: SIMD3(repeating: -9), count: L)
        for i in positions.indices {
            let r = Int(regions[i]); n[r] += 1; sum[r] += positions[i]; nsum[r] += normals[i]
            mn[r] = simd_min(mn[r], positions[i]); mx[r] = simd_max(mx[r], positions[i])
        }
        for id in atlas.nodes.keys {
            let ls = atlas.leaves(of: id).compactMap { atlas.leafIndex[$0] }.filter { n[$0] > 0 }
            guard !ls.isEmpty else { continue }
            var lo = SIMD3<Float>(repeating: 9), hi = SIMD3<Float>(repeating: -9), ns = SIMD3<Float>.zero, cnt = 0
            for i in ls { lo = simd_min(lo, mn[i]); hi = simd_max(hi, mx[i]); ns += nsum[i]; cnt += n[i] }
            stats[id] = AreaStats(center: (lo + hi) / 2, radius: simd_length(hi - lo) / 2, normal: ns / Float(cnt))
        }
    }

    func hasArea(_ id: String) -> Bool { stats[id] != nil }

    /// A real surface point inside an area (closest vertex to the area's centre, preferring
    /// ones that face `toward`), for placing the spot when the user names an area by voice.
    func representativePoint(of id: String, toward: SIMD3<Float>? = nil) -> (point: SIMD3<Float>, normal: SIMD3<Float>)? {
        guard let st = stats[id] else { return nil }
        let set = Set(atlas.leaves(of: id).compactMap { atlas.leafIndex[$0] }.map { UInt16($0) })
        var best = -1, bs = Float.greatestFiniteMagnitude
        for i in positions.indices where set.contains(regions[i]) {
            var sc = simd_distance(positions[i], st.center)
            if let d = toward { sc -= simd_dot(normals[i], d) * st.radius * 0.5 }
            if sc < bs { bs = sc; best = i }
        }
        return best < 0 ? nil : (positions[best], normals[best])
    }
}
