# Migration: web prototype → native iOS app

**Date:** 3 October 2026
**Source:** the hosted Lofer Artifact (version 7), a web page using HTML/CSS/JavaScript and three.js. Its full source is preserved unchanged in [`artifact-reference/`](artifact-reference/).
**Target:** this repository, a native SwiftUI app for iOS 17+, built with Xcode 26.

## Approach

- **Product logic was ported, not reinvented.** The JavaScript layers (symptom parser, assessment, safety, care engine, Body Memory, movement checks, voice) were translated to Swift one-to-one, keeping the same rules, thresholds and wording, and split into Models/Services with no UI code.
- **The UI was recreated in SwiftUI** following the same screens, flow, copy and dark visual system. Web layout tricks (CSS) were replaced by native layout.
- **The 3D body uses SceneKit** (Apple's 3D framework) instead of three.js. The body's shape is identical: the mesh is generated from the prototype's own `geo.js` by `tools/generate-body-mesh.js` and shipped as `Resources/Body/BodyMesh.bin`. The glass shader was rewritten for SceneKit (Metal).
- **Anything not real yet stays simulated** behind a Swift protocol (`VoiceAgent`, `DeviceInterface`, `CareIntelligenceService`).

## Feature by feature

| Artifact feature | iOS implementation | Status | Notes |
|---|---|---|---|
| Logo intro (appear, breathe, float away, particle trail, horizon) | `Features/Splash/SplashView.swift`, `Components/LoferMark.swift`, `App/RootView.swift` (`HorizonGlow`) | ✅ Recreated in SwiftUI | Tap to skip, as before |
| Dark Lofer palette | `DesignSystem/Colors.swift` | ✅ Migrated | Same hex values as the brand board |
| Typography (Figtree UI, Quicksand wordmark) | `DesignSystem/Typography.swift`, `Resources/Fonts/` | ✅ Migrated | Fonts bundled (SIL Open Font License) |
| Typography comparison screen | `Features/TypographyLab/TypographyLabView.swift` | ✅ Recreated | Avenir Next is built into iOS. Söhne and Circular are paid, so free stand-ins are shown (labelled). The final font is still undecided |
| Home: greeting, orb, "Or show me on your body" | `Features/Home/HomeView.swift`, `Components/VoiceOrb.swift` | ✅ Recreated | Orb drawn with SwiftUI Canvas |
| Body area tree (113 areas, incl. detailed wrist/hand) | `Models/BodyRegion.swift` | ✅ Ported 1:1 | Same ids as the prototype |
| Symptom parsing (keywords → structured fields) | `Services/Intelligence/SymptomParser.swift` | ✅ Ported 1:1 | Will be replaced by an LLM via `CareIntelligenceService` |
| AssessmentState + one-question-at-a-time logic | `Models/AssessmentState.swift`, `Services/Intelligence/AssessmentService.swift` | ✅ Ported 1:1 | Same question order, acknowledgements and summary |
| Care state machine (listening → … → outcome) | `Features/Care/CareFlowModel.swift` | ✅ Ported | No product logic inside views |
| Safety triage + sealed commands | `Services/Intelligence/SafetyValidator.swift` | ✅ Ported, **stronger** | In Swift, `SealedCommand` can only be created by the validator (compiler-enforced) |
| Care suggestions, prefs ("more heat"), feedback, reassessment | `Services/Intelligence/TreatmentEngine.swift` | ✅ Ported 1:1 | |
| "Why it might feel this way" (hedged explanation) | `TreatmentEngine.explain` | ✅ Ported 1:1 | Saved as "Lofer's note (not a diagnosis)" |
| 3D glass body, highlights, camera framing, layout zones | `BodyModel/BodySceneController.swift`, `Features/Care/CareView.swift` | ✅ Recreated in SceneKit | Text never sits over the body: the dock and sheet are measured and the camera frames into the space left |
| Tap to choose / move the spot, ↑↓←→ pad, voice directions | `CareFlowModel` (`moveSpot`, `nudge`, `refine`), `Features/Care/CareSheet.swift` | ✅ Ported | |
| Front / Back / Inner / Outer limb views, ↻ Reset view | `BodySceneController.setLimbView`, `CareView` | ✅ Ported | Inner view cuts away the torso with a clipping shader |
| Breadcrumb navigation + single ← back | `CareView.navBar`, `CareFlowModel.goBack` | ✅ Ported | |
| Movement checks (illustrated, looping, before/after) | `Models/MovementTest.swift`, `Features/MovementCheck/` | ✅ Recreated in SwiftUI Canvas | Same six checks and figures |
| Treatment simulation (timer, check-ins, patches, adjustments) | `Features/Treatment/`, `Services/Device/MockLoferDevice.swift` | 🟡 Simulated | Runs 20× faster than real time in this preview |
| Reassessment, outcome, routines, escalation | `Features/Results/ResultSheets.swift` | ✅ Recreated | |
| Body Memory (episodes, insights, sample history) | `Services/Memory/BodyMemoryStore.swift` | ✅ Ported | Stored as JSON in UserDefaults. SwiftData or a synced backend later |
| Body history, episode detail, pressure chart | `Features/History/` | ✅ Recreated | Chart uses Swift Charts |
| Physiotherapist care summary | `Features/History/CareSummaryView.swift` | ✅ Recreated, **improved** | Uses the native iOS share sheet |
| Profile + safety questions | `Features/Profile/ProfileView.swift` | ✅ Recreated | |
| Mock voice agent (states, transcript, speaking) | `Services/Voice/VoiceAgent.swift`, `Components/InputBar.swift` | 🟡 Mocked | Typing stands in for speech; there is no audio yet |
| ElevenLabs voice | `ElevenLabsVoiceAgent` | ⏳ Placeholder | Needs a backend that issues session tokens. No keys in the app |
| LLM understanding | `APICareIntelligenceService` | ⏳ Placeholder | Falls back to the keyword parser |
| Physical wearable | `DeviceInterface` (`PhysicalLoferDevice` to be written) | ⏳ Not started | Bluetooth driver goes behind the same protocol |
| Desktop side panel ("Try saying") | Replaced by launch arguments `-LoferDemo` / `-LoferDemoFull` | 🔁 Replaced | A side panel doesn't exist on a phone |
| Simulated-mic sample phrases | "Try: …" suggestion in `InputBar` | ✅ Kept | |

## Known differences and follow-ups

- **SceneKit** is Apple's established 3D framework and works well here, but Apple is steering new work towards RealityKit. Moving the body to RealityKit later only touches `BodyModel/`.
- **Body Memory is stored per device** in UserDefaults for now. Plan: SwiftData, then optional sync through Lofer's backend.
- **Language understanding is still keyword-based.** Phrasings outside the patterns fall through to a polite "I didn't quite catch that".
- **The glass shading** was tuned by eye against the prototype. It may need small adjustments on real devices.
