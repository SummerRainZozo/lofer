import SwiftUI
import SceneKit

/// SwiftUI wrapper around the SceneKit body. All behaviour lives in BodySceneController.
struct BodySceneView: UIViewRepresentable {
    let controller: BodySceneController
    func makeUIView(context: Context) -> SCNView { controller.scnView }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
