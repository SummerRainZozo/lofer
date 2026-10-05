# Care flow: decisions and open policy questions

An engineering record for the investigation-led care roadmap (Passes 1–5). It lists how the
prototype currently applies policy, and the questions that need a clinical or product decision.
Nothing here is clinically validated. The prototype runs against a simulated device.

## Pass 1 (done): make the current flow consistent

| Item | What the code does now | Where |
|---|---|---|
| Warning signs first | From the movement check onwards, every utterance is checked for warning signs before any other intent. Serious signs stop a running session first, then show the stop screen. | `CareFlowModel.handleWarningSigns`, `safetyStop` |
| Urgency and evidence kept | Signs keep their original level and label; the user's words are appended to the record. A sign during the movement check is no longer turned into "couldn't do the movement". | same |
| Answer status | Questions record `affirmative`, `negative`, `uncertain` or `skipped`; no entry = unanswered. Showing a question, or learning an unrelated field, doesn't answer it. | `AnswerStatus`, `AssessmentService.update` |
| Negation | "no numbness" → ruled out; "not sure if it is numb" → uncertain; "new numbness" → reported. Only the few words before a sign can negate it. | `SymptomParser.mention` |
| Field completeness | `confidence` renamed `fieldCompleteness`: how many core fields are filled, not confidence in any decision. | `AssessmentState` |
| Movement deterioration | A worse after-session movement check overrides "feels better": `review` pathway, no routine offer, no reassuring explanation. | `TreatmentEngine.reassess` |
| No normalising | Removed "often settles within a day", "that's normal after one session", "another session often helps", and similar. | `TreatmentEngine.explain`, `reassess` |
| Too strong vs worse | "Too strong" lowers intensity (pauses at the gentlest level). "Worse" pauses, and the session resumes only after "Has it settled?" → yes. "Still worse" ends the session as `worse`. | `CareFlowModel.feedback`, `settled`, `stillWorse` |
| Stated restrictions enforced | Outcomes that say "I'll pause automatic sessions" save `pausesAutomaticCare`; the safety gate then stops care for that joint/segment. | `Episode.Outcome`, `BodyMemoryStore.automaticCarePause`, `SafetyValidator.triage` |
| Stale work cancelled | Every input and reset bumps a generation counter; interpretation that finishes late is dropped. The delayed movement → suggestion hand-off was removed. App-level transcript tasks are cancelled on new input or exit. | `CareFlowModel.generation`, `AppModel.transcriptTask` |
| Idempotent saving | One id per episode; saving again updates the record. Reassessment can't run twice. | `BodyMemoryStore.add`, `CareFlowModel.saveEpisode` |
| Sample isolation | Sample episodes don't inform suggestions, check-ins, recurrence or paused care, except in `-LoferDemo` / `-LoferDemoFull`. | `BodyMemoryStore.samplesInformDecisions` |

Tests: `LoferTests/CareFlowSafetyTests.swift`.

## Open policy questions (need a decision before any clinical use)

1. **Unsure or skipped warning-sign answer.** The prototype *defers* care ("I don't have enough information to recommend a session here") and offers to answer the check again. Is deferral right, and what should the user be advised to do?
2. **Partial negation.** "No numbness" in reply to "any numbness, tingling, swelling or weakness?" is currently read as "no" to the whole question. Should each sign be confirmed separately?
3. **Caution-level signs during a session** ("sharp", "getting worse") pause the session and ask "has it settled?". Is that the right response, or should they end the session?
4. **Pause on automatic care.** There is no expiry and no way to lift it except clearing Body Memory. Who or what lifts it (time, a professional review, a new episode type)?
5. **Movement deterioration threshold.** Any one-step worsening on the four-point scale (fine / a little / quite / can't) triggers review. Is one step the right threshold?
6. **Which outcomes pause automatic care.** Currently: "worse", a worse movement check, a new warning sign since the session started, and two "no change" sessions in a row. Confirm this list.
7. **"Too strong" at the gentlest level** pauses the session. Should it end it instead?
8. **Keyword parsing** is a heuristic stand-in. Negation and uncertainty detection must be validated (or replaced) before relying on them.

## Known gaps left for later passes

- `SafetyValidator.validate` still inserts a gentle vibration step when all modalities are removed (Pass 4: return a no-session decision instead).
- Typed commands, customisation, saved routines and repeat sessions share triage but aren't yet tied to an evidence revision or protocol version (Pass 4).
- No evidence model, investigation service or protocol versioning yet (Passes 2–3).
- Episode records don't yet store answer statuses, uncertain signs or protocol metadata (Pass 5).
