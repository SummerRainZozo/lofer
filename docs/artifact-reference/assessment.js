/* ASSESSMENT — what Lofer understands about this episode, and what it still needs.
   The conversation never walks a fixed questionnaire. Each turn:
     user speaks → fields extracted (symptom.js) → AssessmentState updated →
     what's known? → what important thing is missing? → ONE question (or confirm).
   Copy here is user-facing: warm, short, feeling-first, no clinical words. */
(function (root) {
  const { N, groupOf } = root.Lofer.Anatomy;

  function create() {
    return {
      bodyRegion: null, regionConfirmed: false, pair: null, laterality: null,
      userDescription: [],                 // the user's own words, always kept
      onset: null, onsetType: null, activityContext: null, activityDuration: null,
      sensation: null, sensationWords: null, severity: null,
      movementTriggers: [], relievingFactors: [], symptomsAtRest: null,
      previousEpisodes: null, progression: null, safetyFlags: [],
      movement: { before: null, after: null },
      asked: {}, questionsAsked: 0, confidence: 0, missingFields: []
    };
  }

  // ---------- language helpers ----------
  const FEEL = { tightness: 'tight', soreness: 'sore', ache: 'achy', sharp: 'sharp', burning: 'like it’s burning', cramp: 'crampy', unclear: 'a bit off', pain: 'uncomfortable' };
  const FEEL_NOUN = { tightness: 'tightness', soreness: 'soreness', ache: 'a dull ache', sharp: 'a sharper pain', burning: 'a burning feeling', cramp: 'cramping', unclear: 'something that feels off', pain: 'discomfort' };
  const ONSET = { today: 'today', 'last night': 'last night', yesterday: 'yesterday', 'a few days ago': 'a few days ago', 'weeks ago': 'a few weeks ago', 'months ago': 'some months ago' };
  const TRIG = { 'Raising the arm overhead': 'lifting your arm overhead', 'Lifting the arm': 'lifting your arm', 'Reaching backwards': 'reaching backwards',
    Rotating: 'rotating it', 'Lifting the hand': 'lifting your hand', Gripping: 'gripping', 'Turning the head': 'turning your head', 'Bending forward': 'bending forward',
    'Prolonged sitting': 'sitting for a while', 'Standing up': 'standing up', 'Squatting or kneeling': 'squatting or kneeling', Typing: 'typing', 'Overhead throwing or serving': 'serving or throwing',
    'Pushing or leaning on it': 'leaning on it', 'Looking down': 'looking down', 'Carrying things': 'carrying things', 'Going up on my toes': 'going up on your toes', 'First steps in the morning': 'the first steps in the morning' };
  const trig = t => TRIG[t] || t.toLowerCase();
  const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
  const around = id => { if (!id) return 'there'; const s = N[id].say || N[id].label.toLowerCase(); return s.startsWith('the ') ? s : `around ${s}`; };
  const startedPhrase = A => {
    const when = ONSET[A.onset] || null, act = A.activityContext;
    if (act && when) return `after ${act} ${when}`;
    if (act) return `after ${act}`;
    if (when) return when;
    return null;
  };
  const joinAnd = parts => parts.length < 2 ? parts.join('') : parts.slice(0, -1).join(', ') + ' and ' + parts[parts.length - 1];

  // Region-specific examples so the follow-up feels like it understood where you are.
  const BRINGS_ON = [
    [/shoulder|uarm|trap|scap|lat|chest/, 'lifting or rotating your arm', ['Lifting it overhead', 'Reaching behind me', 'Rotating it', 'Carrying things']],
    [/elbow|farm|wrist|hand/, 'gripping, rotating your wrist, or lifting your hand', ['Gripping', 'Rotating my wrist', 'Lifting my hand', 'Typing']],
    [/neck|headneck|face|backhead/, 'turning your head or looking down', ['Turning my head', 'Looking down', 'Sitting at a screen']],
    [/lowerback|lowback|hips|hip|glute|upperback|mid_back/, 'bending, sitting or standing up', ['Bending forward', 'Sitting for a while', 'Standing up', 'Lifting things']],
    [/knee|thigh/, 'stairs, squatting or walking', ['Stairs', 'Squatting', 'Walking', 'Running']],
    [/lleg|calf|achilles|footg|ankle|heel|sole|leg/, 'walking, running or going up on your toes', ['Walking', 'Running', 'Going up on my toes', 'First steps in the morning']]];
  const OPTION_TRIGGER = { 'Lifting it overhead': 'Raising the arm overhead', 'Reaching behind me': 'Reaching backwards', 'Rotating it': 'Rotating', 'Rotating my wrist': 'Rotating',
    'Lifting my hand': 'Lifting the hand', 'Turning my head': 'Turning the head', 'Sitting at a screen': 'Prolonged sitting', 'Sitting for a while': 'Prolonged sitting', 'Squatting': 'Squatting or kneeling', 'Lifting things': 'Carrying things' };
  const bringsOnFor = id => (id && BRINGS_ON.find(([re]) => re.test(groupOf(id) + ' ' + id))) || [null, 'particular movements or positions', ['Certain movements', 'Sitting still', 'Exercise']];

  // ---------- update from one utterance ----------
  // expect = the field Lofer just asked about (answers are read in that light).
  function update(A, r, { expect = null } = {}) {
    const learned = [];
    const set = (k, v) => { if (v != null && A[k] !== v && v !== '') { A[k] = v; learned.push(k); } };
    const t = (r.raw || '').toLowerCase();
    const descriptive = !!(r.entry || r.type || r.activity || r.triggers.length || r.onset || Object.keys(r.story || {}).length);
    if (descriptive || expect === 'story' || expect === 'sensation') A.userDescription.push(r.raw.trim());
    if (r.type && r.type !== 'pain') { if (!A.sensation || ['pain', 'unclear'].includes(A.sensation) || expect === 'sensation') set('sensation', r.type); }
    else if (r.type === 'pain' && !A.sensation) set('sensation', 'pain');
    if (expect === 'sensation' && !r.type && t.trim().length > 2) { A.sensation = 'other'; A.sensationWords = r.raw.trim(); learned.push('sensation'); }
    if (r.severity != null && (expect === 'severity' || descriptive)) set('severity', r.severity);
    set('onset', r.onset); set('activityContext', r.activity);
    const s = r.story || {};
    set('activityDuration', s.activityDuration); set('symptomsAtRest', s.atRest); set('progression', s.progression); set('onsetType', s.onsetType);
    if (s.relieving && !A.relievingFactors.includes(s.relieving)) { A.relievingFactors.push(s.relieving); learned.push('relievingFactors'); }
    for (const x of r.triggers) if (!A.movementTriggers.includes(x)) { A.movementTriggers.push(x); learned.push('movementTriggers'); }
    if (r.previous) set('previousEpisodes', true);
    for (const f of r.flags) if (!A.safetyFlags.some(x => x.label === f.label)) { A.safetyFlags.push(f); learned.push('safetyFlags'); }
    // Answers that only make sense against the question asked
    if (expect === 'triggers' && !r.triggers.length) {
      if (/all the time|most of the time|constant|always there/.test(t)) set('symptomsAtRest', 'present');
      else if (r.deny || /nothing|none|not really|not sure|no idea|don'?t know/.test(t)) { A.movementTriggers.push('Nothing in particular'); learned.push('movementTriggers'); }
    }
    if (expect === 'previous') { if (/\b(yes|yeah|before|again|usually|comes and goes)\b/.test(t)) set('previousEpisodes', true); else if (r.deny || /new|first time|never/.test(t)) set('previousEpisodes', false); }
    if (expect === 'safety' && (r.deny || /none|nothing|no$/.test(t.trim()))) learned.push('safetyChecked');
    if (r.bilateral) set('laterality', 'both');
    refreshMeta(A);
    return learned;
  }
  function setRegion(A, id, { pair = null, confirmed = false } = {}) {
    const changed = A.bodyRegion !== id;
    A.bodyRegion = id; A.pair = pair; A.regionConfirmed = confirmed;
    A.laterality = pair ? 'both' : N[id].side === 'l' ? 'left' : N[id].side === 'r' ? 'right' : 'centre';
    refreshMeta(A);
    return changed;
  }
  // Apply a tapped answer chip.
  function answer(A, field, value) {
    if (field === 'sensation') { A.sensation = value; }
    if (field === 'severity') A.severity = value;
    if (field === 'onset') A.onset = value;
    if (field === 'triggers') {
      if (value === '__rest') A.symptomsAtRest = 'present';
      else if (value === '__none') A.movementTriggers.push('Nothing in particular');
      else A.movementTriggers.push(OPTION_TRIGGER[value] || value);
    }
    if (field === 'previous') A.previousEpisodes = value;
    if (field === 'safety') value.forEach(f => A.safetyFlags.push(f));
    A.asked[field] = true;
    refreshMeta(A);
  }

  // ---------- what's missing, and the one question worth asking ----------
  // A "caution" word like "sharp" is a reason TO ask; only a serious sign already heard makes the question unnecessary.
  const needsSafety = A => !A.asked.safety && !A.safetyFlags.some(f => f.level !== 'caution') &&
    (['sharp', 'burning'].includes(A.sensation) || (A.severity ?? 0) >= 7 || (A.onsetType === 'sudden' && !A.activityContext) ||
     A.progression === 'worsening' || A.onset === 'months ago' || A.symptomsAtRest === 'present');
  function missing(A, { historyCount = 0 } = {}) {
    const m = [];
    if (!A.userDescription.length && !A.sensation) m.push('story');
    if (!A.bodyRegion) m.push('region');
    if (!A.sensation || ['pain', 'unclear'].includes(A.sensation)) m.push('sensation');
    if (needsSafety(A)) m.push('safety');
    if (!A.movementTriggers.length && !A.symptomsAtRest) m.push('triggers');
    if (!A.onset && !A.activityContext) m.push('onset');
    if (A.severity == null) m.push('severity');
    if (A.previousEpisodes == null && !historyCount) m.push('previous');
    return m;
  }
  function refreshMeta(A) {
    const m = missing(A);
    A.missingFields = m;
    const core = ['region', 'sensation', 'triggers', 'onset', 'severity'];
    A.confidence = +(1 - core.filter(f => m.includes(f)).length / core.length).toFixed(2);
  }
  const MAX_FOLLOW_UPS = 4;

  function nextQuestion(A, { historyCount = 0 } = {}) {
    const m = missing(A, { historyCount }).filter(f => !A.asked[f] || f === 'region');
    if (m.includes('story')) return { field: 'story', text: "Tell me what's been going on and how it feels.", hint: 'Say it however feels natural. What you were doing, where it is, how it feels.' };
    if (m.includes('region')) return { field: 'region', text: 'Where are you feeling it? Tell me, or show me on your body.' };
    const capped = A.questionsAsked >= MAX_FOLLOW_UPS;
    const order = ['sensation', 'safety', 'triggers', 'onset', 'severity', 'previous'];
    for (const f of order) {
      if (!m.includes(f)) continue;
      if (capped && !['sensation', 'safety'].includes(f)) continue;
      if (f === 'previous' && A.questionsAsked >= 3) continue;
      return Q[f](A);
    }
    return null;   // enough to confirm
  }
  const Q = {
    sensation: A => ({ field: 'sensation', text: A.sensation === 'unclear' ? 'Let’s put a word to it. Does it feel more tight, sore, achy, or sharp?' : 'How does it feel? More tight, sore, achy, or sharp?',
      options: [['Tight', 'tightness'], ['Sore', 'soreness'], ['Achy', 'ache'], ['Sharp', 'sharp'], ['Something else', '__other']] }),
    safety: () => ({ field: 'safety', text: 'One quick check. Is there any numbness, tingling, swelling or weakness with it?', multi: true,
      options: [['Numbness or tingling', 'Numbness or tingling'], ['Swelling', 'Swelling, bruising or deformity'], ['Weakness', 'Weakness or loss of movement'], ['After a fall or knock', 'Recent fall, knock or injury']] }),
    triggers: A => { const [, ex, opts] = bringsOnFor(A.bodyRegion);
      return { field: 'triggers', text: `Does anything bring it on? For example ${ex}.`, options: [...opts.slice(0, 3).map(o => [o, o]), ['It’s there all the time', '__rest'], ['Nothing really', '__none']] }; },
    onset: () => ({ field: 'onset', text: 'When did you first notice it?', options: [['Today', 'today'], ['Yesterday', 'yesterday'], ['A few days ago', 'a few days ago'], ['A week or two', 'weeks ago'], ['Longer than that', 'months ago']] }),
    severity: () => ({ field: 'severity', text: 'How much is it bothering you right now?', options: [['A little', 2], ['Moderately', 4], ['Quite a lot', 6], ['A lot', 8]] }),
    previous: () => ({ field: 'previous', text: 'Has this happened before, or is it new?', options: [['It’s happened before', true], ['This is new', false]] })
  };

  // ---------- what Lofer says back ----------
  // Short acknowledgement of what was understood this turn (no filler).
  function ack(A, learned) {
    const bits = [];
    const sp = startedPhrase(A);
    if ((learned.includes('activityContext') || learned.includes('onset')) && sp) bits.push(`it started ${sp}`);
    if (learned.includes('region') && A.bodyRegion) bits.push(`it's mainly ${around(A.bodyRegion)}`);
    if (learned.includes('sensation') && A.sensation && A.sensation !== 'pain') bits.push(A.sensation === 'other' ? `it feels ${A.sensationWords.toLowerCase().replace(/[.!]$/, '')}` : `it feels ${FEEL[A.sensation]}`);
    if (learned.includes('movementTriggers')) { const tr = A.movementTriggers.filter(x => x !== 'Nothing in particular'); if (tr.length) bits.push(`${trig(tr[tr.length - 1])} brings it on`); }
    if (learned.includes('symptomsAtRest')) bits.push(A.symptomsAtRest === 'minimal' ? "it's mostly fine at rest" : "it's there most of the time");
    if (!bits.length) return '';
    return `Got it, ${bits[0].replace(/^it started /, '').replace(/^it's mainly (around )?/, '')}.`;   // one short clause, never a recap
  }
  // The short "here's what I understood" line, shown before anything is suggested.
  // Two plain sentences: what and where, then when and what makes it worse.
  function summary(A) {
    const feel = A.sensation === 'other' ? `“${A.sensationWords}”` : FEEL_NOUN[A.sensation] || 'Some discomfort';
    const say = A.pair ? `both ${(N[A.bodyRegion].crumb || N[A.bodyRegion].label).replace(/^(Right|Left) /, '').toLowerCase()}s` : (N[A.bodyRegion]?.say || 'that area');
    const where = say.startsWith('the ') ? `at ${say}` : `in ${say}`;
    let s = `${cap(feel.replace(/^a /, 'A '))} ${where}.`;
    const second = [];
    const sp = startedPhrase(A);
    if (sp) second.push(`it started ${sp}`);
    const tr = A.movementTriggers.filter(x => x !== 'Nothing in particular');
    if (tr.length) second.push(`${trig(tr[0])} makes it worse`);
    else if (A.symptomsAtRest === 'present') second.push("it's there most of the time");
    if (second.length) s += ` ${cap(second.join(', and '))}.`;
    return s;
  }

  // Hand-off to the safety layer / engine / Body Memory.
  function toSym(A) {
    const type = A.sensation === 'other' || A.sensation === 'unclear' ? 'pain' : A.sensation;
    return { areaId: A.bodyRegion, pairId: A.pair, side: A.laterality, type, severity: A.severity, onset: A.onset, onsetType: A.onsetType,
      activity: A.activityContext, activityDuration: A.activityDuration, triggers: [...A.movementTriggers], atRest: A.symptomsAtRest,
      relieving: [...A.relievingFactors], progression: A.progression, previous: A.previousEpisodes, flags: [...A.safetyFlags],
      sensationWords: A.sensationWords, movement: A.movement };
  }

  root.Lofer = root.Lofer || {};
  root.Lofer.Assessment = { create, update, setRegion, answer, missing, nextQuestion, ack, summary, toSym, FEEL_NOUN, MAX_FOLLOW_UPS };
})(typeof window !== 'undefined' ? window : globalThis);
