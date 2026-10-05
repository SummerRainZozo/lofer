// The mock provider behaves like the future LLM: structured, context-aware, never repetitive.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MockCareIntelligenceProvider } from '../src/providers/mock/MockCareIntelligenceProvider.ts';
import { CareIntelligenceResponse } from '../src/schemas/care.ts';
import { request, assessment, investigation, TENNIS, tennisConfirmed, baselineMild } from './helpers.ts';

const mock = new MockCareIntelligenceProvider();
const ask = async (r: Parameters<typeof mock.respond>[0]) => {
  const out = await mock.respond(r);
  assert.ok(CareIntelligenceResponse.safeParse(out).success, 'every response matches the schema');
  return out;
};
const asksAbout = (a: { type: string; field?: string; requestedRefinement?: string }) =>
  a.type === 'askQuestion' ? a.field : a.type === 'refineBodyLocation' ? a.requestedRefinement : null;

test('detailed story: everything said is extracted', async () => {
  const r = await ask(request({ text: TENNIS, expectedField: 'story' }));
  assert.equal(r.extractedInformation.bodyMention?.template, '{s}_sh_back');
  assert.equal(r.extractedInformation.side, 'right');
  assert.deepEqual(
    { s: r.assessmentUpdates.sensation, o: r.assessmentUpdates.onset, a: r.assessmentUpdates.activityContext, d: r.assessmentUpdates.activityDuration,
      rest: r.assessmentUpdates.symptomsAtRest, area: r.assessmentUpdates.specificArea },
    { s: 'tightness', o: 'yesterday', a: 'tennis', d: 'two hours', rest: 'minimal', area: 'back' });
  assert.deepEqual(r.assessmentUpdates.movementTriggers, ['Raising the arm overhead']);
  assert.ok((r.assessmentUpdates.severity ?? 10) <= 3, 'mild, from "a little"');
});

test('detailed story: no question about what was already said', async () => {
  const r = await ask(request({ text: TENNIS, expectedField: 'story' }));
  assert.ok(!['side', 'region', 'onset', 'triggers', 'sensation'].includes(asksAbout(r.recommendedNextAction) ?? ''));
  assert.equal(r.recommendedNextAction.type, 'refineBodyLocation');
  assert.match(r.userFacingResponse.acknowledgement, /tennis/);
});

test('short story: never asks side, region, activity or onset', async () => {
  const r = await ask(request({ text: 'My right shoulder became tight after tennis yesterday.', expectedField: 'story' }));
  assert.ok(!['side', 'region', 'onset', 'activityContext'].includes(asksAbout(r.recommendedNextAction) ?? ''));
  assert.equal(r.recommendedNextAction.type, 'refineBodyLocation');
  if (r.recommendedNextAction.type === 'refineBodyLocation') assert.equal(r.recommendedNextAction.requestedRefinement, 'surface');
});

test('iterative: location → movement check → observation → proceed, on the same investigation', async () => {
  const afterSpot = await ask(request({ latestUserInput: { kind: 'location', text: 'Back of right shoulder', field: 'region', value: 'r_sh_back' },
                                        currentAssessmentState: tennisConfirmed(), currentCareFlowState: 'locate', investigation: investigation({ cycles: 1 }) }));
  assert.equal(afterSpot.recommendedNextAction.type, 'movementCheck');

  const afterMovement = await ask(request({ latestUserInput: { kind: 'movementResult', text: 'a little uncomfortable', field: 'arm_raise', value: 'mildDiscomfort' },
                                            currentAssessmentState: tennisConfirmed(), completedMovementChecks: [baselineMild], currentCareFlowState: 'movement',
                                            investigation: investigation({ cycles: 2 }) }));
  assert.equal(afterMovement.recommendedNextAction.type, 'requestUserObservation');
  if (afterMovement.recommendedNextAction.type === 'requestUserObservation') assert.match(afterMovement.recommendedNextAction.prompt, /halfway/);

  const afterObservation = await ask(request({ latestUserInput: { kind: 'observation', text: 'Yes, it eased', field: 'eases_when_stopped', value: 'eased' },
                                               currentAssessmentState: tennisConfirmed(), completedMovementChecks: [baselineMild], currentCareFlowState: 'clarify',
                                               investigation: investigation({ cycles: 3 }) }));
  assert.equal(afterObservation.recommendedNextAction.type, 'proceedToCare');
  assert.equal(afterObservation.readiness.informationSufficiency, 'sufficient');
  assert.ok(afterObservation.possibleContributingPatterns.some((p) => p.id === 'movement-provoked' && p.status === 'supported'));
});

test('a movement described in words counts as the baseline straight away', async () => {
  const r = await ask(request({ text: 'It starts pulling about halfway.', currentCareFlowState: 'movement',
                                currentAssessmentState: tennisConfirmed(), investigation: investigation({ cycles: 2 }) }));
  assert.equal(r.extractedInformation.movementResult?.feel, 'little');
  assert.equal(r.recommendedNextAction.type, 'requestUserObservation', 'not the same movement again');
});

test('an observation answered in words is understood (no repeat question)', async () => {
  const r = await ask(request({ text: 'Yes, it eased straight away.', expectedField: 'observation:eases_when_stopped', currentCareFlowState: 'clarify',
                                currentAssessmentState: tennisConfirmed(), completedMovementChecks: [baselineMild], investigation: investigation({ cycles: 3 }) }));
  assert.deepEqual(r.extractedInformation.observation, { label: 'Yes, it eased', value: 'eased' });
  assert.equal(r.recommendedNextAction.type, 'proceedToCare');
});

test('iterative: a vaguer start asks about the feeling first, then moves on', async () => {
  const first = await ask(request({ text: 'My right knee hurts.' }));
  assert.equal(asksAbout(first.recommendedNextAction), 'sensation');
  const second = await ask(request({ text: 'Kind of achy.', expectedField: 'sensation', currentCareFlowState: 'clarify',
                                     currentAssessmentState: assessment({ bodyRegion: 'r_knee', laterality: 'right', sensation: 'pain' }) }));
  assert.equal(second.recommendedNextAction.type, 'refineBodyLocation', 'feeling known now: pin down the spot next');
});

test('location: an unsided area asks which side; no area asks where', async () => {
  const unsided = await ask(request({ text: 'My shoulder hurts.' }));
  assert.equal(asksAbout(unsided.recommendedNextAction), 'side');
  const nowhere = await ask(request({ text: 'I just feel a bit off today.' }));
  assert.equal(asksAbout(nowhere.recommendedNextAction), 'region');
});

test('insufficient information: still vague after a couple of rounds', async () => {
  const r = await ask(request({ text: "I don't know, just off.", investigation: investigation({ cycles: 2 }) }));
  assert.equal(r.recommendedNextAction.type, 'insufficientInformation');
});

test('do not treat: warning signs stop; persistent pain at rest goes to a professional', async () => {
  const swollen = await ask(request({ text: 'My left calf is hot and swollen.' }));
  assert.equal(swollen.recommendedNextAction.type, 'safetyStop');
  const urgent = await ask(request({ text: 'I have chest pain and feel short of breath.' }));
  assert.equal(urgent.recommendedNextAction.type, 'safetyStop');
  if (urgent.recommendedNextAction.type === 'safetyStop') assert.equal(urgent.recommendedNextAction.urgent, true);
  const persistent = await ask(request({ text: "My lower back has hurt all the time for months and it's getting worse." }));
  assert.equal(persistent.recommendedNextAction.type, 'recommendProfessionalAssessment');
});

test('negation and uncertainty in warning signs', async () => {
  const no = await ask(request({ text: 'No numbness, it just feels tight in my right shoulder.' }));
  assert.deepEqual(no.extractedInformation.warningSigns.map((w) => w.status), ['negated']);
  assert.notEqual(no.recommendedNextAction.type, 'safetyStop');
  const unsure = await ask(request({ text: "My right shoulder is tight, I'm not sure if it's numb." }));
  assert.equal(unsure.extractedInformation.warningSigns[0]?.status, 'uncertain');
  assert.equal(asksAbout(unsure.recommendedNextAction), 'safety', 'unsure → ask the safety check');
});

test('never diagnoses', async () => {
  for (const text of [TENNIS, 'My shoulder hurts.', 'My lower back is stiff from sitting all day.']) {
    const r = await ask(request({ text }));
    const words = JSON.stringify(r.userFacingResponse) + r.possibleContributingPatterns.map((p) => p.label).join(' ');
    assert.doesNotMatch(words, /diagnos|tear|tendin|bursitis|impingement|root cause|definitely/i);
  }
});
