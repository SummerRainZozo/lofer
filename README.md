# Lofer

Lofer is the iOS app for an AI-powered physical-care wearable. You tell Lofer how your body feels (by voice or typing), show it where on a 3D body, and it suggests a gentle session, runs it on the wearable, checks how you feel afterwards, and remembers what helped.

> **Tell Lofer how you feel → it understands → asks only what it still needs → confirms → checks a movement → suggests care → treats → checks again → learns.**

The hardware, the voice provider and the AI are not connected yet. Each one is **simulated** behind a clearly named interface, so it can be swapped for the real thing later without rewriting the app.

---

## 1. Open and run the app

**You need:** a Mac with **Xcode 26** (or newer). The app targets **iOS 17+** and is tested on the **iPhone 17** Simulator.

1. Open **`Lofer.xcodeproj`** (double-click it, or in Terminal: `open Lofer.xcodeproj`).
2. At the top of Xcode, pick the **Lofer** scheme and an iPhone Simulator (for example *iPhone 17*).
3. Press **▶ Run** (⌘R). The Simulator opens and Lofer starts with its logo animation.
4. To run the tests, press **⌘U**.

**Try a hands-free demo:** in Xcode choose *Product › Scheme › Edit Scheme… › Run › Arguments* and add `-LoferDemoFull`. Lofer will play a whole sample conversation by itself (`-LoferDemo` plays just the opening story).

**Where the app starts:** [`Lofer/App/LoferApp.swift`](Lofer/App/LoferApp.swift).

> Running on a real iPhone needs your Apple ID set as the signing team: select the **Lofer** target › *Signing & Capabilities* › *Team*.

## 2. Open the same project in VS Code

Open the **whole `Lofer` folder** in VS Code (*File › Open Folder…* and choose `~/Projects/Lofer`). Xcode and VS Code use the **same files**, so there is only ever one copy. Edit in VS Code, then run in Xcode.

VS Code will suggest the *Swift* extension (from `.vscode/extensions.json`). Install it for code colouring and jump-to-definition.

New files you create inside `Lofer/` are picked up by Xcode automatically. You don't need to "add them to the project".

## 3. Where things live

```
Lofer/
├── Lofer.xcodeproj            ← open this in Xcode
├── Lofer/                     ← the app's source code
│   ├── App/                   ← entry point, navigation, wiring of services (AppModel)
│   ├── Features/              ← one folder per part of the journey (UI + its flow)
│   │   ├── Splash/            ← logo animation
│   │   ├── Home/              ← "How is your body feeling today?"
│   │   ├── Care/              ← CareFlowModel (the care state machine) + the care screen and its sheets
│   │   ├── MovementCheck/     ← illustrated movement demonstrations
│   │   ├── Treatment/         ← suggested care, customise, active session
│   │   ├── Results/           ← "How does that feel now?", outcome, safety stop
│   │   ├── History/           ← Body history, episode detail, physiotherapist summary
│   │   ├── Profile/           ← profile questions, safety check, saved routines
│   │   └── TypographyLab/     ← temporary font comparison screen
│   ├── Components/            ← reusable UI: VoiceOrb, PebbleLogo, LoferButton, BottomSheet…
│   ├── Models/                ← plain data: AssessmentState, BodyRegion, TreatmentPlan, Episode…
│   ├── Services/              ← logic with no UI
│   │   ├── Intelligence/      ← SymptomParser, AssessmentService, SafetyValidator, TreatmentEngine, CareIntelligenceService
│   │   ├── Device/            ← DeviceInterface + MockLoferDevice (simulated wearable)
│   │   ├── Voice/             ← VoiceAgent + MockVoiceAgent (+ ElevenLabs placeholder)
│   │   └── Memory/            ← BodyMemoryStore (episodes, routines, profile, physio summary)
│   ├── BodyModel/             ← the 3D body: shape maths, mesh loading, SceneKit view
│   ├── DesignSystem/          ← Colors, Typography, Spacing
│   ├── Resources/             ← fonts and the pre-generated body mesh
│   └── Assets.xcassets        ← app icon and accent colour
├── LoferTests/                ← automated tests (⌘U)
├── docs/
│   ├── MIGRATION.md           ← what moved from the web prototype, and how
│   └── artifact-reference/    ← the original web prototype, kept for reference
└── tools/                     ← helper scripts (e.g. regenerate the body mesh)
```

### Quick finder

| I want to change… | Look in |
|---|---|
| A screen's layout or wording | `Lofer/Features/<Feature>/…View.swift` or `…Sheet.swift` |
| What Lofer asks next, or how it acknowledges | `Services/Intelligence/AssessmentService.swift` |
| How sentences are understood ("tight after tennis") | `Services/Intelligence/SymptomParser.swift` |
| The order of the care journey | `Features/Care/CareFlowModel.swift` |
| Safety rules (when not to treat, intensity limits) | `Services/Intelligence/SafetyValidator.swift` |
| Suggested programmes, "why it might feel this way" | `Services/Intelligence/TreatmentEngine.swift` |
| The 3D body (look, camera, taps) | `BodyModel/BodySceneController.swift` |
| Body areas and their names | `Models/BodyRegion.swift` |
| Movement checks | `Models/MovementTest.swift`, `Features/MovementCheck/` |
| Voice | `Services/Voice/VoiceAgent.swift` |
| Simulated hardware | `Services/Device/MockLoferDevice.swift` |
| Saved history / physio summary | `Services/Memory/BodyMemoryStore.swift` |
| Colours, fonts, spacing | `DesignSystem/` |

### How the layers fit together

```
SwiftUI views (Features/…)            what you see
      ↓ call actions / read state
CareFlowModel                         the care journey (state machine)
      ↓ asks
AssessmentService · TreatmentEngine   understanding + suggestions (no UI)
      ↓ every plan goes through
SafetyValidator                       deterministic rules → "sealed" commands
      ↓ only sealed commands reach
DeviceInterface → MockLoferDevice     (later: PhysicalLoferDevice over Bluetooth)
```

Voice never controls the hardware. What you say becomes text, the text becomes a structured intent, and only the safety layer can create a command the device accepts. The compiler enforces this: `SealedCommand` can only be created inside `SafetyValidator.swift`.

### Swapping in real services later

| Interface | Now | Later |
|---|---|---|
| `CareIntelligenceService` | `MockCareIntelligenceService` (keyword parser) | `APICareIntelligenceService` (an LLM behind Lofer's backend) |
| `VoiceAgent` | `MockVoiceAgent` (typed text stands in for speech) | `ElevenLabsVoiceAgent` or another provider |
| `DeviceInterface` | `MockLoferDevice` | `PhysicalLoferDevice` (Bluetooth) |

All of them are created in one place: [`Lofer/App/AppModel.swift`](Lofer/App/AppModel.swift).

**Never put API keys in the app or in Git.** Real providers should get short-lived tokens from Lofer's own backend. `.gitignore` already excludes `.env` and `Secrets.*` files.

---

## 4. Development Workflow (Git + GitHub)

**GitHub is the shared source of truth.** Each person works on their own *branch*, then asks to merge it into `main` with a *pull request*. Nobody pushes straight to `main`, so you never overwrite each other's work.

```
main  ───●────────●──────────●───      (always working, shared)
          \      /  \        /
           feature/body-map   feature/voice-agent
```

### How to get the latest code
```bash
git checkout main
git pull origin main
```

### How to start new work
```bash
git checkout -b feature/name-of-feature
```
Name it after what you're doing, for example `feature/body-map`, `feature/voice-agent`, `feature/assessment`, `feature/treatment`.

### How to save work (a "commit" is a saved checkpoint)
```bash
git add .
git commit -m "Describe what changed"
```

### How to share work
```bash
git push -u origin feature/name-of-feature
```
Then open the repository on github.com. GitHub shows a **Compare & pull request** button. Create the pull request, ask your friend to look at it, and press **Merge** when you're both happy.

### How to get your friend's changes
After their pull request is merged:
```bash
git checkout main
git pull origin main
```
If you're in the middle of your own branch and want their changes too:
```bash
git checkout feature/your-branch
git merge main
```

### Good habits
- Pull `main` before starting anything new.
- Keep branches small and short-lived. One feature per branch.
- Run the app (⌘R) and the tests (⌘U) before opening a pull request.
- If Git says there's a **conflict**, both of you changed the same lines. Open the file, keep the right version, then `git add` and `git commit`.

---

## 5. Working with Claude on this project

This local repository is the real Lofer codebase. The hosted web prototype is a reference only (see `docs/artifact-reference/`). Changes are made here, built in Xcode, committed, and shared through GitHub. See `CLAUDE.md`.
