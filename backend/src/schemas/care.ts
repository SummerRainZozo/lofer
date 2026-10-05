// THE CARE INTELLIGENCE CONTRACT — validated on the way in AND on the way out.
// Mirrors Lofer/Services/Intelligence/CareSchema.swift and Lofer/Models/Investigation.swift
// field for field (camelCase JSON, ISO-8601 dates). Bump SCHEMA_VERSION on both sides together.
//
// The response schema is STRICT: it has no place for device commands, intensities, durations
// or diagnoses, and unknown fields are rejected. A provider (mock now, an LLM later) can only
// return structured understanding and a PROPOSED next step.
import { z } from 'zod';

export const SCHEMA_VERSION = 1;

// ── Shared building blocks ──────────────────────────────────────────────────
export const FlagLevel = z.enum(['caution', 'stop', 'urgent']);
export const SafetyFlag = z.object({ level: FlagLevel, label: z.string() });
export const MovementFeel = z.enum(['fine', 'little', 'quite', 'cannot']);
export const MovementResult = z.object({
  feel: MovementFeel,
  whereInMovement: z.string().nullish(),
  quality: z.string().nullish(),
  sideOfIt: z.string().nullish(),
});
export const AnswerStatus = z.enum(['affirmative', 'negative', 'uncertain', 'skipped']);
export const ActionOption = z.object({ label: z.string().min(1), value: z.string().min(1) });

/** The app's AssessmentState. Loose: the app owns this model and may add fields. */
export const AssessmentState = z.looseObject({
  bodyRegion: z.string().nullish(),
  regionConfirmed: z.boolean(),
  pair: z.string().nullish(),
  laterality: z.string().nullish(),
  specificArea: z.string().nullish(),
  userDescription: z.array(z.string()),
  onset: z.string().nullish(),
  onsetType: z.string().nullish(),
  activityContext: z.string().nullish(),
  activityDuration: z.string().nullish(),
  sensation: z.string().nullish(),
  sensationWords: z.string().nullish(),
  severity: z.number().int().min(0).max(10).nullish(),
  movementTriggers: z.array(z.string()),
  relievingFactors: z.array(z.string()),
  symptomsAtRest: z.string().nullish(),
  previousEpisodes: z.boolean().nullish(),
  progression: z.string().nullish(),
  safetyFlags: z.array(SafetyFlag),
  uncertainSigns: z.array(SafetyFlag),
  movementBefore: MovementResult.nullish(),
  movementAfter: MovementResult.nullish(),
  answers: z.record(z.string(), AnswerStatus),
  questionsAsked: z.number().int(),
});

// ── Investigation ───────────────────────────────────────────────────────────
export const ContributingPattern = z.object({
  id: z.string(),
  label: z.string(),                       // never a diagnosis
  status: z.enum(['possible', 'supported', 'weakened']),
  supporting: z.array(z.string()),
  weakening: z.array(z.string()),
});
export const Uncertainty = z.object({
  id: z.string(),
  topic: z.string(),
  importance: z.enum(['high', 'medium', 'low']),
  field: z.string().nullish(),
});
export const Evidence = z.object({
  id: z.string(),
  source: z.enum(['userReport', 'userObservation', 'movementCheck', 'location', 'careIntelligence', 'simulatedDevice']),
  summary: z.string(),
  field: z.string().nullish(),
  value: z.string().nullish(),
  supports: z.array(z.string()),
  weakens: z.array(z.string()),
  at: z.string(),
});
export const Check = z.object({
  id: z.string(),
  kind: z.enum(['question', 'location', 'movement', 'observation']),
  purpose: z.string(),
  prompt: z.string(),
  response: z.string().nullish(),
  status: z.enum(['answered', 'skipped', 'uncertain', 'inconclusive']),
  at: z.string(),
});
export const MovementObservation = z.object({
  movementId: z.string(),
  name: z.string(),
  phase: z.enum(['baseline', 'repeatCheck']),
  outcome: z.enum(['comfortable', 'mildDiscomfort', 'significantDiscomfort', 'unableToPerformComfortably']),
  whereInMovement: z.string().nullish(),
  location: z.string().nullish(),
  quality: z.string().nullish(),
  userDescription: z.string().nullish(),
  changeVsBaseline: z.enum(['better', 'same', 'worse']).nullish(),
  at: z.string(),
});
export const Readiness = z.object({
  informationSufficiency: z.enum(['insufficient', 'partial', 'sufficient']), // not a diagnostic confidence
  reason: z.string(),
});

/** What Lofer should do next. A provider only PROPOSES; the app's deterministic engine decides. */
export const InvestigationAction = z.discriminatedUnion('type', [
  z.object({ type: z.literal('askQuestion'), field: z.string(), question: z.string(), purpose: z.string(),
             options: z.array(ActionOption).nullish(), multiSelect: z.boolean().nullish() }).strict(),
  z.object({ type: z.literal('refineBodyLocation'), broadRegion: z.string(), currentSelection: z.string().nullish(),
             requestedRefinement: z.enum(['region', 'side', 'surface', 'precise']), prompt: z.string(), purpose: z.string() }).strict(),
  z.object({ type: z.literal('movementCheck'), movementId: z.string(), phase: z.enum(['baseline', 'repeatCheck']),
             purpose: z.string(), targetObservation: z.string() }).strict(),
  z.object({ type: z.literal('requestUserObservation'), observationId: z.string(), prompt: z.string(), purpose: z.string(),
             options: z.array(ActionOption).min(2) }).strict(),
  z.object({ type: z.literal('proceedToCare'), reason: z.string() }).strict(),
  z.object({ type: z.literal('insufficientInformation'), reason: z.string(), message: z.string() }).strict(),
  z.object({ type: z.literal('recommendProfessionalAssessment'), reason: z.string(), message: z.string() }).strict(),
  z.object({ type: z.literal('safetyStop'), reason: z.string(), urgent: z.boolean() }).strict(),
]);

export const InvestigationState = z.looseObject({
  patterns: z.array(ContributingPattern),
  uncertainties: z.array(Uncertainty),
  evidence: z.array(Evidence),
  checks: z.array(Check),
  movementObservations: z.array(MovementObservation),
  nextAction: InvestigationAction.nullish(),
  readiness: Readiness,
  cycles: z.number().int().min(0),
  intelligenceSources: z.array(z.string()),
  conclusion: z.string().nullish(),
});

// ── Request ─────────────────────────────────────────────────────────────────
export const CareInput = z.object({
  kind: z.enum(['utterance', 'answer', 'location', 'movementResult', 'observation']),
  text: z.string().max(2000).nullish(),
  field: z.string().nullish(),
  value: z.string().nullish(),
});
export const ConversationTurn = z.object({ role: z.enum(['user', 'lofer']), text: z.string().max(2000) });
export const SelectedRegion = z.object({
  id: z.string(), label: z.string(), group: z.string(), laterality: z.string().nullish(), confirmed: z.boolean(), isLeaf: z.boolean(),
});
export const MemorySummary = z.object({
  date: z.string(), area: z.string(), activity: z.string().nullish(), sensation: z.string().nullish(),
  movement: z.string().nullish(), intervention: z.string().nullish(), response: z.string().nullish(), pausedAutomaticCare: z.boolean(),
});

export const CareRequest = z.object({
  schemaVersion: z.literal(SCHEMA_VERSION),
  requestId: z.string().min(1),
  sessionId: z.string().min(1),
  turn: z.number().int().min(0),
  latestUserInput: CareInput,
  expectedField: z.string().nullish(),
  conversationHistory: z.array(ConversationTurn).max(20),
  currentAssessmentState: AssessmentState,
  selectedBodyRegion: SelectedRegion.nullish(),
  investigation: InvestigationState,
  completedMovementChecks: z.array(MovementObservation),
  relevantBodyMemory: z.array(MemorySummary).max(5),
  currentCareFlowState: z.string(),
});

// ── Response ────────────────────────────────────────────────────────────────
export const WarningSign = z.object({ level: FlagLevel, label: z.string(), status: z.enum(['reported', 'negated', 'uncertain']) });
export const ExtractedInformation = z.object({
  bodyMention: z.object({ regionId: z.string().nullish(), template: z.string().nullish(), noun: z.string().nullish() }).strict().nullish(),
  side: z.enum(['left', 'right']).nullish(),
  bilateral: z.boolean().nullish(),
  warningSigns: z.array(WarningSign),
  confirm: z.boolean().nullish(),
  deny: z.boolean().nullish(),
  unsure: z.boolean().nullish(),
  skip: z.boolean().nullish(),
  direction: z.enum(['up', 'down', 'front', 'back', 'out', 'in', 'L', 'R']).nullish(),
  slight: z.boolean().nullish(),
  movementResult: MovementResult.nullish(),
  observation: ActionOption.nullish(),
}).strict();
export const AssessmentPatch = z.object({
  sensation: z.enum(['tightness', 'soreness', 'ache', 'sharp', 'burning', 'cramp', 'unclear', 'pain']).nullish(),
  severity: z.number().int().min(0).max(10).nullish(),
  onset: z.enum(['today', 'last night', 'yesterday', 'a few days ago', 'weeks ago', 'months ago']).nullish(),
  onsetType: z.enum(['sudden', 'gradual']).nullish(),
  activityContext: z.string().nullish(),
  activityDuration: z.string().nullish(),
  symptomsAtRest: z.enum(['minimal', 'present']).nullish(),
  progression: z.enum(['improving', 'stable', 'worsening']).nullish(),
  previousEpisodes: z.boolean().nullish(),
  movementTriggers: z.array(z.string()).nullish(),
  relievingFactors: z.array(z.string()).nullish(),
  specificArea: z.enum(['front', 'back', 'outer', 'inner', 'top']).nullish(),
}).strict();
export const UserFacingResponse = z.object({ acknowledgement: z.string().max(280), prompt: z.string().max(280) }).strict();

export const CareIntelligenceResponse = z.object({
  schemaVersion: z.literal(SCHEMA_VERSION),
  requestId: z.string(),
  provider: z.string(),
  extractedInformation: ExtractedInformation,
  assessmentUpdates: AssessmentPatch,
  possibleContributingPatterns: z.array(ContributingPattern),
  uncertainties: z.array(Uncertainty),
  evidenceUpdates: z.array(Evidence),
  recommendedNextAction: InvestigationAction,
  readiness: Readiness,
  userFacingResponse: UserFacingResponse,
}).strict();

export type CareRequest = z.infer<typeof CareRequest>;
export type CareIntelligenceResponse = z.infer<typeof CareIntelligenceResponse>;
export type InvestigationAction = z.infer<typeof InvestigationAction>;
export type ExtractedInformation = z.infer<typeof ExtractedInformation>;
export type AssessmentPatch = z.infer<typeof AssessmentPatch>;
export type ContributingPattern = z.infer<typeof ContributingPattern>;
export type Uncertainty = z.infer<typeof Uncertainty>;
export type Evidence = z.infer<typeof Evidence>;
export type MovementObservation = z.infer<typeof MovementObservation>;
export type WarningSign = z.infer<typeof WarningSign>;
export type MovementResult = z.infer<typeof MovementResult>;
