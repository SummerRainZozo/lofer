// Builders for test requests, shaped exactly like what the iOS app sends.
import type { CareRequest } from '../src/schemas/care.ts';

type A = CareRequest['currentAssessmentState'];
type Inv = CareRequest['investigation'];

export function assessment(over: Partial<A> = {}): A {
  return { regionConfirmed: false, userDescription: [], movementTriggers: [], relievingFactors: [], safetyFlags: [], uncertainSigns: [],
           answers: {}, questionsAsked: 0, ...over } as A;
}
export function investigation(over: Partial<Inv> = {}): Inv {
  return { patterns: [], uncertainties: [], evidence: [], checks: [], movementObservations: [],
           readiness: { informationSufficiency: 'insufficient', reason: '' }, cycles: 0, intelligenceSources: [], ...over } as Inv;
}
let n = 0;
export function request(over: Partial<CareRequest> & { text?: string } = {}): CareRequest {
  const { text, ...rest } = over;
  return {
    schemaVersion: 1, requestId: `req-${++n}`, sessionId: 'session-1', turn: 1,
    latestUserInput: { kind: 'utterance', text: text ?? '' }, expectedField: null, conversationHistory: [],
    currentAssessmentState: assessment(), selectedBodyRegion: null, investigation: investigation(), completedMovementChecks: [],
    relevantBodyMemory: [], currentCareFlowState: 'listening', ...rest,
  };
}
export const TENNIS = "I played tennis for two hours yesterday. The back of my right shoulder started feeling tight afterwards. It's mostly okay normally but hurts a little when I lift my arm above my head.";

/** The assessment after the tennis story was told and the spot confirmed on the body. */
export const tennisConfirmed = () => assessment({
  bodyRegion: 'r_sh_back', regionConfirmed: true, laterality: 'right', specificArea: 'back', sensation: 'tightness', severity: 2,
  onset: 'yesterday', activityContext: 'tennis', activityDuration: 'two hours', symptomsAtRest: 'minimal',
  movementTriggers: ['Raising the arm overhead'], userDescription: [TENNIS],
});
export const baselineMild = { movementId: 'arm_raise', name: 'Arm raise', phase: 'baseline' as const, outcome: 'mildDiscomfort' as const,
                              whereInMovement: 'about halfway', quality: 'pulling', at: new Date().toISOString() };
