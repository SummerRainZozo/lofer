# Working on Lofer (notes for Claude)

- **This repository is the canonical Lofer codebase.** The hosted web Artifact is a historical reference only (`docs/artifact-reference/`). Do not build features there.
- Workflow for any change: inspect the existing code → edit the relevant files → build (`xcodebuild … build`) and test (`xcodebuild … test`) → list exactly which files changed → commit on a feature branch when asked → push / open a PR only when asked.
- The owner is learning software engineering: keep names obvious, add short comments where a design choice isn't self-evident, prefer small focused edits, and explain changes file by file.
- Keep the layers separate: Views → `CareFlowModel` → Services (`AssessmentService`, `TreatmentEngine`, `SafetyValidator`) → `DeviceInterface`. Voice never controls hardware; only `SafetyValidator` can create `SealedCommand`s.
- Never commit secrets or API keys. Real providers get tokens from a backend.
- Build: `xcodebuild -project Lofer.xcodeproj -scheme Lofer -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Test: same command with `test`.
- Demo for screenshots: launch with `-LoferDemoFull`.
- The body mesh is generated from `docs/artifact-reference/geo.js`: `node tools/generate-body-mesh.js`.
