import SceneKit
import UIKit
import simd

/// How dominant the body is on the current step (bigger factor = body further away / smaller).
enum BodyRole: Double {
    case select = 1, treat = 1.001, clarify = 1.35, confirm = 1.25, movement = 1.6, suggest = 1.7, result = 1.3
    var zoomsClose: Bool { self == .select }
}

/// Owns the 3D body: SceneKit scene, glass shader, camera, taps, highlights, spot marker,
/// treatment patches. The care flow tells it WHAT to show; it decides HOW to draw it.
/// (SceneKit is Apple's built-in 3D framework; a later version could move to RealityKit.)
final class BodySceneController: NSObject {
    let scnView = SCNView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private var skinNode: SCNNode?
    private var depthNode: SCNNode?
    private var skinMaterial = SCNMaterial()
    private var depthMaterial = SCNMaterial()
    private let boneNode = SCNNode()
    private let marker = SCNNode()
    private var patchNodes: [SCNNode] = []
    private(set) var mesh: BodyMesh?
    private var displayLink: CADisplayLink?
    private let atlas = BodyAtlas.shared
    private let depthCategory = 1 << 3

    // Callbacks to the care flow
    var onTap: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
    var onReady: (() -> Void)?
    var onViewChanged: ((Bool) -> Void)?   // true when the user has turned/zoomed away from the home view

    // Layout: the free band between the information zone (top) and the sheet (bottom), in points.
    private var insetTop: CGFloat = 120, insetBottom: CGFloat = 260
    // Camera state (current and target), orbit around `target`
    private var th: Float = 0.9, ph: Float = 0.15, dist: Float = 5.4, target = SIMD3<Float>(0, 0.9, 0)
    private var thT: Float = 0.38, phT: Float = 0.06, distT: Float = 3.4, targetT = SIMD3<Float>(0, 0.9, 0)
    private var home = (th: Float(0.38), ph: Float(0.06), d: Float(3.4))
    private var dragging = false
    private var lastOff = false
    // Shading state
    private var stateTarget: [Float] = [], stateShown: [Float] = []
    private var colorsDirty = false
    private var spot: (p: SIMD3<Float>, n: SIMD3<Float>)?
    private var pointGlow: Float = 0, pointShown = SIMD3<Float>(0, -9, 0)
    private var patchModality: Modality?, patchesPaused = false
    private var clip: (n: SIMD3<Float>, d: Float)?
    private var startTime = CACurrentMediaTime()
    private let fovDeg: Float = 26

    override init() {
        super.init()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        let cam = SCNCamera(); cam.fieldOfView = CGFloat(fovDeg); cam.zNear = 0.02; cam.zFar = 30
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        setupGestures()
        // Build the body off the main thread (the mesh file is ~2 MB).
        DispatchQueue.global(qos: .userInitiated).async {
            let mesh = BodyMesh.loadFromBundle()
            DispatchQueue.main.async { [weak self] in self?.install(mesh) }
        }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common); displayLink = link
    }
    deinit { displayLink?.invalidate() }

    var isReady: Bool { mesh != nil }

    // MARK: - Scene construction
    private func install(_ mesh: BodyMesh?) {
        guard let mesh else { return }
        self.mesh = mesh
        let verts = mesh.positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let norms = mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let vSrc = SCNGeometrySource(vertices: verts), nSrc = SCNGeometrySource(normals: norms)
        stateTarget = [Float](repeating: 1, count: atlas.leaves.count); stateShown = stateTarget

        // Pass 1: invisible, writes depth only, so the glass shows one clean layer.
        let depthGeo = SCNGeometry(sources: [vSrc, nSrc], elements: [element])
        depthMaterial.colorBufferWriteMask = []
        depthMaterial.writesToDepthBuffer = true
        depthMaterial.lightingModel = .constant
        depthMaterial.shaderModifiers = [.fragment: Self.clipModifier]
        depthGeo.materials = [depthMaterial]
        let dn = SCNNode(geometry: depthGeo); dn.renderingOrder = 1; dn.categoryBitMask = depthCategory
        scene.rootNode.addChildNode(dn); depthNode = dn

        // Pass 2: the glass skin.
        skinMaterial.lightingModel = .constant
        skinMaterial.diffuse.contents = UIColor.white
        skinMaterial.blendMode = .alpha
        skinMaterial.writesToDepthBuffer = false
        skinMaterial.readsFromDepthBuffer = true
        skinMaterial.isDoubleSided = false
        skinMaterial.shaderModifiers = [.fragment: Self.glassModifier]
        let sn = SCNNode(); sn.renderingOrder = 2
        scene.rootNode.addChildNode(sn); skinNode = sn
        rebuildSkinGeometry()

        buildBones()
        buildFloor()
        buildMarker()
        frame("body", role: .select, turn: true)
        onReady?()
    }

    /// Per-vertex colour carries the highlight state: r = brightness/2, g = "selected" glow, b = pulse.
    /// (Alpha must stay 1: SceneKit treats vertex alpha as transparency.)
    private func rebuildSkinGeometry() {
        guard let mesh, let skinNode else { return }
        var colors = [SIMD4<Float>](repeating: .zero, count: mesh.positions.count)
        for i in colors.indices {
            let s = stateShown[Int(mesh.regions[i])]
            let dim: Float = 1 - smooth(0.3, 0.8, s)
            let alt = smooth(1.1, 1.2, s) * (1 - smooth(1.4, 1.5, s))
            let hov = smooth(1.45, 1.65, s) * (1 - smooth(1.8, 1.95, s))
            let lit = smooth(1.8, 2.1, s) * (1 - smooth(2.6, 2.9, s))
            let sel = smooth(2.6, 2.95, s)
            let bright = 1 - dim * 0.55 + alt * 0.07 + hov * 0.25
            colors[i] = SIMD4(bright / 2, sel, lit, 1)
        }
        let data = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let cSrc = SCNGeometrySource(data: data, semantic: .color, vectorCount: colors.count, usesFloatComponents: true, componentsPerVector: 4,
                                     bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        let vSrc = SCNGeometrySource(vertices: mesh.positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let nSrc = SCNGeometrySource(normals: mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let geo = SCNGeometry(sources: [vSrc, nSrc, cSrc], elements: [SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)])
        geo.materials = [skinMaterial]
        skinNode.geometry = geo
    }
    private func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float { let t = max(0, min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t) }

    private func buildBones() {
        let mat = SCNMaterial(); mat.lightingModel = .constant; mat.diffuse.contents = UIColor(red: 0.243, green: 0.188, blue: 0.161, alpha: 1)
        mat.shaderModifiers = [.fragment: Self.clipModifier]
        func bone(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r: CGFloat) {
            let d = b - a, len = simd_length(d)
            let n = SCNNode(geometry: SCNCylinder(radius: r, height: CGFloat(len)))
            n.geometry?.materials = [mat]
            n.simdPosition = (a + b) / 2
            n.simdOrientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(d))
            boneNode.addChildNode(n)
        }
        func ball(_ c: SIMD3<Float>, _ r: CGFloat) { let n = SCNNode(geometry: SCNSphere(radius: r)); n.geometry?.materials = [mat]; n.simdPosition = c; boneNode.addChildNode(n) }
        for x: Float in [1, -1] {
            bone([x * 0.19, 1.345, 0], [x * 0.262, 1.085, -0.005], 0.011)
            bone([x * 0.262, 1.08, -0.005], [x * 0.3, 0.86, 0.02], 0.008); bone([x * 0.272, 1.075, -0.01], [x * 0.315, 0.862, 0.012], 0.007)
            bone([x * 0.09, 0.93, 0], [x * 0.1, 0.535, 0.005], 0.014)
            bone([x * 0.1, 0.47, 0.005], [x * 0.104, 0.09, -0.01], 0.011); bone([x * 0.118, 0.46, -0.012], [x * 0.122, 0.1, -0.02], 0.006)
            bone([x * 0.02, 1.415, 0.045], [x * 0.17, 1.405, 0.005], 0.006)
            ball([x * 0.09, 0.935, 0], 0.02); ball([x * 0.1, 0.5, 0.01], 0.018); ball([x * 0.19, 1.36, 0], 0.022)
        }
        var y: Float = 0.98
        while y < 1.58 { ball([0, y, -0.045 + max(0, y - 1.35) * 0.1], 0.009); y += 0.028 }
        for i in 0..<6 {
            let t = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(0.105 - abs(Float(i) - 2) * 0.006), pipeRadius: 0.0035)); t.geometry?.materials = [mat]
            t.simdPosition = [0, 1.34 - Float(i) * 0.035, -0.01]; t.simdScale = [1.05, 1, 0.78]; t.eulerAngles.x = 0.25
            boneNode.addChildNode(t)
        }
        let pel = SCNNode(geometry: SCNTorus(ringRadius: 0.11, pipeRadius: 0.008)); pel.geometry?.materials = [mat]
        pel.simdPosition = [0, 0.98, 0]; pel.simdScale = [1.1, 1, 0.7]; pel.eulerAngles.x = -0.2; boneNode.addChildNode(pel)
        let skull = SCNNode(geometry: SCNSphere(radius: 0.066)); skull.geometry?.materials = [mat]; skull.simdPosition = [0, 1.655, 0]; skull.simdScale = [1, 1.15, 1.1]; boneNode.addChildNode(skull)
        boneNode.renderingOrder = 0
        scene.rootNode.addChildNode(boneNode)
    }
    private func buildFloor() {
        let size = CGSize(width: 128, height: 128)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 0.894, green: 0.71, blue: 0.596, alpha: 0.32).cgColor, UIColor(red: 0.894, green: 0.71, blue: 0.596, alpha: 0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 64, y: 64), startRadius: 0, endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
        let plane = SCNPlane(width: 1.3, height: 1.3)
        let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = img; m.writesToDepthBuffer = false; m.blendMode = .alpha
        plane.materials = [m]
        let n = SCNNode(geometry: plane); n.eulerAngles.x = -.pi / 2; n.position.y = -0.004; n.renderingOrder = 3
        scene.rootNode.addChildNode(n)
    }
    private func buildMarker() {
        let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor(red: 1, green: 0.965, blue: 0.93, alpha: 1); m.readsFromDepthBuffer = false
        let dot = SCNNode(geometry: SCNSphere(radius: 0.0055)); dot.geometry?.materials = [m]
        let ringM = SCNMaterial(); ringM.lightingModel = .constant; ringM.diffuse.contents = UIColor(red: 1, green: 0.945, blue: 0.894, alpha: 0.9); ringM.readsFromDepthBuffer = false
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.012, pipeRadius: 0.0011)); ring.geometry?.materials = [ringM]; ring.eulerAngles.x = .pi / 2
        let pulse = SCNAction.repeatForever(.sequence([.group([.scale(to: 2.2, duration: 2.2), .fadeOut(duration: 2.2)]), .group([.scale(to: 1, duration: 0), .fadeIn(duration: 0)])]))
        ring.runAction(pulse)
        marker.addChildNode(dot); marker.addChildNode(ring)
        marker.renderingOrder = 5; marker.isHidden = true
        scene.rootNode.addChildNode(marker)
    }

    // MARK: - Shaders (SceneKit "shader modifiers", Metal)
    /// Shared clipping used by the "Inner" limb view (cuts away the torso and other limb).
    static let clipModifier = """
    #pragma arguments
    float uClipOn;
    float3 uClipN;
    float uClipD;
    #pragma body
    if (uClipOn > 0.5) {
        float3 wp = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        if (dot(wp, uClipN) + uClipD < 0.0) { discard_fragment(); }
    }
    """
    /// Glass skin: soft rim glow, glossy highlight, warm sheen; highlight state from vertex colour.
    static let glassModifier = """
    #pragma arguments
    float uTime;
    float3 uPoint;
    float uPointOn;
    float uClipOn;
    float3 uClipN;
    float uClipD;
    #pragma body
    if (uClipOn > 0.5) {
        float3 wp = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        if (dot(wp, uClipN) + uClipD < 0.0) { discard_fragment(); }
    }
    float3 N = normalize(_surface.normal);
    float3 V = normalize(_surface.view);
    float ndv = clamp(dot(N, V), 0.0, 1.0);
    float fres = pow(1.0 - ndv, 3.0);
    float3 L = normalize(float3(-0.45, 0.75, 0.6));
    float dif = clamp(dot(N, L), 0.0, 1.0) * 0.5 + 0.5;
    float3 Hh = normalize(L + V);
    float spec = pow(clamp(dot(N, Hh), 0.0, 1.0), 48.0);
    float3 warm = float3(0.894, 0.710, 0.596);
    float3 cream = float3(0.965, 0.925, 0.886);
    float3 deep = float3(0.165, 0.118, 0.098);
    float4 vc = _surface.diffuse;
    float bright = vc.r * 2.0;
    float sel = vc.g;
    float lit = vc.b;
    float3 col = mix(deep, warm, 0.12 + 0.3 * dif);
    col += warm * fres * 0.85 + cream * spec * 0.35;
    col *= bright;
    float pulse = 0.82 + 0.18 * sin(uTime * 2.0);
    col += mix(warm, cream, 0.35) * lit * 0.4 * pulse;
    col += mix(warm, cream, 0.6) * sel * 0.38;
    float3 pV = (scn_frame.viewTransform * float4(uPoint, 1.0)).xyz;
    float d = distance(_surface.position, pV);
    col += cream * uPointOn * (exp(-d * d / (2.0 * 0.016 * 0.016)) * 0.8 + exp(-d * d / (2.0 * 0.05 * 0.05)) * 0.25);
    float a = clamp(0.34 + fres * 0.5 + spec * 0.2 + (lit + sel) * 0.2 - (1.0 - min(bright, 1.0)) * 0.3, 0.0, 0.95);
    _output.color = float4(col * a, a);
    """

    // MARK: - API used by the care flow
    func setInsets(top: CGFloat, bottom: CGFloat) {
        guard abs(top - insetTop) > 4 || abs(bottom - insetBottom) > 4 else { return }
        insetTop = top; insetBottom = bottom
        if let f = lastFrame { frame(f.id, role: f.role, turn: false) }
    }
    private var lastFrame: (id: String, role: BodyRole)?

    /// Point the camera at an area, sized to fit the free band, at the step's body role.
    func frame(_ id: String, role: BodyRole, turn: Bool) {
        guard let st = mesh?.stats[id] else { return }
        lastFrame = (id, role)
        let H = Float(max(scnView.bounds.height, 1)), W = Float(max(scnView.bounds.width, 1))
        let Hv = max(140, H - Float(insetTop + insetBottom))
        let tv = tan(fovDeg * .pi / 360)
        let r = max(st.radius, role.zoomsClose ? 0.07 : 0.26)
        let dv = r * 1.12 / (tv * Hv / H), dh = r * 1.12 / (tv * W / H)
        targetT = st.center; distT = max(dv, dh, 0.3) * Float(role.rawValue)
        if turn, let t = id == "body" ? 0.38 : theta(for: id) { thT = nearest(th, t) }
        phT = st.normal.y > 0.45 ? 0.5 : id.has("footg|_heel|_sole|_foottop") ? 0.32 : 0.07
        home = (thT, phT, distT)      // "Reset view" returns here; only the user's own drags/pinches count as "moved"
    }
    func resetView() { setLimbView(nil, limb: nil); thT = nearest(th, home.th); phT = home.ph; distT = home.d }

    /// Turn so a point faces the camera if it's on the far side.
    func face(normal n: SIMD3<Float>, at p: SIMD3<Float>) {
        let camDir = simd_normalize(cameraNode.simdWorldPosition - p)
        guard simd_dot(n, camDir) < 0.35, let t = theta(forNormal: n, at: p) else { return }
        thT = nearest(th, t); home.th = thT
    }
    func turn(to where_: String) {
        let t: Float = ["front": 0, "back": .pi, "side": .pi / 2][where_] ?? th + .pi
        thT = nearest(th, t); home.th = thT
    }
    /// Front / Back / Inner / Outer around a limb. "inner" cuts away the torso and the other limb.
    func setLimbView(_ v: String?, limb: String?) {
        clip = nil
        if let limb, v == "inner" {
            let sx: Float = limb.hasPrefix("l") ? 1 : -1, keep: Float = limb.contains("arm") ? 0.14 : 0.02
            clip = ([sx, 0, 0], -keep)
        }
        for m in [skinMaterial, depthMaterial] + boneMaterials() {
            m.setValue(NSNumber(value: clip == nil ? 0 : 1), forKey: "uClipOn")
            if let c = clip { m.setValue(NSValue(scnVector3: SCNVector3(c.n.x, c.n.y, c.n.z)), forKey: "uClipN"); m.setValue(NSNumber(value: c.d), forKey: "uClipD") }
        }
        if let limb, let v {
            let sx: Float = limb.hasPrefix("l") ? 1 : -1
            thT = nearest(th, ["front": 0, "back": .pi, "outer": sx * .pi / 2, "inner": -sx * .pi / 2][v] ?? 0); phT = 0.06
        }
    }
    private func boneMaterials() -> [SCNMaterial] { boneNode.childNodes.compactMap { $0.geometry?.firstMaterial } }

    /// Highlight state per leaf (same encoding as the prototype: 0 dim, 1 in focus, 1.28 alternate,
    /// 1.62 hover, 2.2 lit/pulsing, 3 selected).
    func setHighlights(_ states: [Float]) { stateTarget = states; colorsDirty = true }

    func setSpot(_ p: SIMD3<Float>?, normal n: SIMD3<Float>?) {
        if let p, let n { spot = (p, n) } else { spot = nil }
    }

    /// Place treatment patches around the treated spot (and the other side, if both).
    func setPatches(around points: [(SIMD3<Float>, SIMD3<Float>)]) {
        patchNodes.forEach { $0.removeFromParentNode() }; patchNodes = []
        for (p, n0) in points {
            let n = simd_normalize(n0), up: SIMD3<Float> = abs(n.y) > 0.9 ? [1, 0, 0] : [0, 1, 0]
            let t1 = simd_normalize(simd_cross(n, up)), t2 = simd_normalize(simd_cross(n, t1))
            for o in [t2 * 0.038, t2 * -0.038, t1 * 0.034] {
                let s = BodySDF.snap(p + o)
                let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor(red: 0.965, green: 0.886, blue: 0.824, alpha: 0.85); m.readsFromDepthBuffer = false
                let node = SCNNode(geometry: SCNCylinder(radius: 0.013, height: 0.0008)); node.geometry?.materials = [m]
                node.simdPosition = s.point + s.normal * 0.003
                node.simdOrientation = simd_quatf(from: [0, 1, 0], to: s.normal)
                node.renderingOrder = 4
                scene.rootNode.addChildNode(node); patchNodes.append(node)
            }
        }
    }
    func setPatchActivity(_ m: Modality?, paused: Bool) { patchModality = m; patchesPaused = paused }

    /// Camera right/up in world space (for ↑↓←→ nudges that follow the screen).
    func screenAxes() -> (right: SIMD3<Float>, up: SIMD3<Float>) { (cameraNode.simdWorldRight, cameraNode.simdWorldUp) }

    // MARK: - Camera maths
    private func nearest(_ from: Float, _ to: Float) -> Float { var t = to; while t - from > .pi { t -= 2 * .pi }; while t - from < -.pi { t += 2 * .pi }; return t }
    private func theta(for id: String) -> Float? {
        guard let st = mesh?.stats[id] else { return nil }
        let n = st.normal, len = sqrt(n.x * n.x + n.z * n.z)
        guard len >= 0.28 else { return nil }
        let nx = n.x / len, nz = n.z / len
        var a = atan2(nx, nz)
        if nz < -0.45 { var d = a - .pi; while d < -.pi { d += 2 * .pi }; while d > .pi { d -= 2 * .pi }; a = .pi + max(-0.6, min(0.6, d)) }
        else if nx * (st.center.x >= 0 ? 1 : -1) > 0 { a = max(-1.25, min(1.25, a)) }
        else { a = max(-0.45, min(0.45, a)) }
        return a
    }
    private func theta(forNormal n: SIMD3<Float>, at p: SIMD3<Float>) -> Float? {
        let len = sqrt(n.x * n.x + n.z * n.z); guard len >= 0.2 else { return nil }
        let nx = n.x / len, nz = n.z / len, a = atan2(nx, nz)
        if nz < -0.45 { return a }
        if nx * (p.x >= 0 ? 1 : -1) > 0 { return max(-1.3, min(1.3, a)) }
        return max(-0.5, min(0.5, a))
    }

    // MARK: - Frame loop
    @objc private func tick(_ link: CADisplayLink) {
        guard mesh != nil else { return }
        let dt = Float(min(0.05, link.targetTimestamp - link.timestamp + 0.0001))
        let k = 1 - exp(-dt * 3.2 * 1.0)
        if !dragging { th += (thT - th) * k }
        ph += (phT - ph) * k; dist += (distT - dist) * k; target += (targetT - target) * k
        // Shift the look-at point so the target sits in the middle of the free band.
        let H = Float(max(scnView.bounds.height, 1))
        let bandCenter = Float(insetTop) + (H - Float(insetTop + insetBottom)) / 2
        let shift = (bandCenter - H / 2) / H * 2 * dist * tan(fovDeg * .pi / 360)
        let pos = target + SIMD3(dist * sin(th) * cos(ph), dist * sin(ph), dist * cos(th) * cos(ph))
        cameraNode.simdPosition = pos
        cameraNode.simdLook(at: target, up: [0, 1, 0], localFront: [0, 0, -1])
        cameraNode.simdPosition += cameraNode.simdWorldUp * shift
        // Highlight transitions (rebuild the colour buffer only while something is changing)
        if colorsDirty {
            var changed = false
            for i in stateShown.indices where i < stateTarget.count {
                let d = stateTarget[i] - stateShown[i]
                if abs(d) > 0.01 { stateShown[i] += d * 0.35; changed = true } else { stateShown[i] = stateTarget[i] }
            }
            rebuildSkinGeometry()
            if !changed { colorsDirty = false }
        }
        // Shader uniforms
        let time = Float(CACurrentMediaTime() - startTime)
        skinMaterial.setValue(NSNumber(value: time), forKey: "uTime")
        pointGlow += ((spot == nil ? 0 : 1) - pointGlow) * 0.15
        if let s = spot { pointShown = pointGlow < 0.05 ? s.p : pointShown + (s.p - pointShown) * 0.25 }
        skinMaterial.setValue(NSValue(scnVector3: SCNVector3(pointShown.x, pointShown.y, pointShown.z)), forKey: "uPoint")
        skinMaterial.setValue(NSNumber(value: pointGlow), forKey: "uPointOn")
        marker.isHidden = spot == nil
        if let s = spot { marker.simdPosition = pointShown + s.n * 0.004; marker.simdOrientation = simd_quatf(from: [0, 1, 0], to: s.n) }
        // Patches pulse with the active modality
        let f: Float = ["vibration": 9, "compression": 1.4, "heat": 0.6, "ems": 3][patchModality?.rawValue ?? ""] ?? 1
        for (i, n) in patchNodes.enumerated() { n.opacity = patchesPaused ? 0.35 : CGFloat(0.55 + 0.35 * sin(time * f * .pi + Float(i))) }
        // Tell the UI whether "Reset view" is worth showing
        let off = abs(nearest(home.th, th) - home.th) > 0.3 || abs(distT / home.d - 1) > 0.15 || clip != nil
        if off != lastOff { lastOff = off; onViewChanged?(off) }
    }

    // MARK: - Gestures: drag to turn, pinch to zoom, tap to choose
    private func setupGestures() {
        scnView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan)))
        scnView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch)))
        scnView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
    }
    private var panStart = (th: Float(0), ph: Float(0))
    @objc private func pan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: scnView)
        switch g.state {
        case .began: dragging = true; panStart = (thT, phT)
        case .changed:
            thT = panStart.th - Float(t.x) * 0.009; th += (thT - th) * 0.5
            phT = max(-0.35, min(0.75, panStart.ph + Float(t.y) * 0.004))
        default: dragging = false
        }
    }
    private var pinchStart: Float = 1
    @objc private func pinch(_ g: UIPinchGestureRecognizer) {
        if g.state == .began { pinchStart = distT }
        distT = max(0.25, min(6, pinchStart / Float(g.scale)))
    }
    @objc private func tap(_ g: UITapGestureRecognizer) {
        let loc = g.location(in: scnView)
        let hits = scnView.hitTest(loc, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .categoryBitMask: depthCategory, .ignoreHiddenNodes: false])
        let hit = hits.first { h in
            guard let c = clip else { return true }
            let p = h.simdWorldCoordinates
            return simd_dot(p, c.n) + c.d >= 0
        }
        guard let h = hit else { return }
        let p = h.simdWorldCoordinates
        onTap?(p, BodySDF.normal(p))
    }
}
