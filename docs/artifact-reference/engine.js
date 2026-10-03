/* CARE / TREATMENT ENGINE — decides the candidate next action.
   A plan = BODY REGION + steps of { MODALITY, INTENSITY (1–5), DURATION }
   in SEQUENCE. The engine only proposes; the Safety layer validates. */
(function (root) {
  const { N, groupOf } = root.Lofer.Anatomy;
  const { TYPE_LABEL } = root.Lofer.Symptom;

  const MOD = {
    vibration: { label: 'Vibration', short: 'Vibration' },
    compression: { label: 'Compression', short: 'Compression' },
    heat: { label: 'Heat', short: 'Heat' },
    ems: { label: 'Muscle stimulation', short: 'Stimulation' }
  };
  const LEVELS = ['', 'Very gentle', 'Gentle', 'Moderate', 'Firm', 'Deep'];
  const clampI = v => Math.max(1, Math.min(5, v));

  function build(kind, name, rows, total, sym) {
    rows = rows.filter(Boolean);
    const steps = rows.map(([modality, intensity, share]) => ({ modality, intensity: clampI(intensity), minutes: Math.max(1, Math.round(total * share)) }));
    return { id: kind + '-' + Date.now().toString(36), kind, name, region: sym.areaId, pair: sym.pairId || null, focus: null, steps, minutes: steps.reduce((a, s) => a + s.minutes, 0) };
  }
  const describe = plan => plan.steps.map(s => `${MOD[s.modality].short} ${s.minutes} min`).join(' → ');
  const levelText = plan => { const m = Math.max(...plan.steps.filter(s => s.modality !== 'heat').map(s => s.intensity), 1); return LEVELS[m]; };
  const regionNoun = id => { if (!id) return 'recovery'; const g = N[groupOf(id)]; return (g.crumb || g.label).replace(/^(Right|Left) /, '').toLowerCase(); };

  // SUGGEST: a small set of options plus the one Lofer recommends.
  function suggest({ sym, tri, profile = {}, history = [], routine = null }) {
    const base = { Gentle: 2, Moderate: 3, Firm: 4 }[profile.pressure] || 3;
    const len = parseInt(profile.length, 10) || 15;
    const heat = profile.heat !== false;
    const stimOk = ['tightness', 'soreness', 'cramp'].includes(sym.type);
    const noun = regionNoun(sym.areaId);
    const gentle = build('gentle', `Gentle ${noun} recovery`, [['vibration', base - 1, .4], ['compression', base - 1, .4], heat && ['heat', 2, .2]], Math.min(10, len), sym);
    gentle.reason = tri.level === 'caution' ? `Kept gentle and short to be safe, based on what you've told me.` : `A gentle starting point based on how your ${noun} is feeling today.`;
    const targeted = build('targeted', `Targeted ${noun} relief`, [['vibration', base, .25], ['compression', base, .4], stimOk && ['ems', base - 1, .15], heat && ['heat', 2, .2]], len, sym);
    targeted.reason = sym.activity ? `A little more focused, for tightness that's built up after ${sym.activity}.` : 'A little more focused, once you know how Lofer feels.';
    const options = [];
    if (routine) options.push({ ...routine.plan, id: 'routine-' + Date.now().toString(36), kind: 'routine', name: routine.name, region: sym.areaId, pair: sym.pairId || null, reason: `What helped your ${noun} last time.` });
    options.push(gentle, targeted);
    let pick = options[0];
    if (!routine) pick = (tri.level === 'caution' || !history.length || ['sharp', 'ache', 'pain', 'burning'].includes(sym.type)) ? gentle : targeted;
    const headline = pick.kind === 'routine' ? `Last time your ${pick.name.toLowerCase()} helped. Shall we start with that?`
      : pick.kind === 'gentle' ? 'I think we can start gently here.' : 'I think a slightly more focused session suits this.';
    return { options, pick, headline };
  }

  // Natural-language changes ("more heat", "no electrical stimulation") → plan edits.
  function applyPrefs(plan, prefs, profile = {}) {
    const p = { ...plan, steps: plan.steps.map(s => ({ ...s })) }, said = [];
    const base = { Gentle: 2, Moderate: 3, Firm: 4 }[profile.pressure] || 3;
    const find = m => p.steps.find(s => s.modality === m);
    if (prefs.heat === 1) { const h = find('heat'); if (h) { h.minutes += 2; h.intensity = clampI(h.intensity + 1); } else p.steps.push({ modality: 'heat', intensity: 2, minutes: 3 }); said.push('more heat'); }
    if (prefs.heat === -1) { p.steps = p.steps.filter(s => s.modality !== 'heat'); said.push('no heat'); }
    if (prefs.intensity === -1) { p.steps.forEach(s => s.intensity = clampI(Math.min(s.intensity - 1, 2))); said.push('kept gentle'); }
    if (prefs.intensity === 1) { p.steps.forEach(s => { if (s.modality !== 'heat') s.intensity = clampI(s.intensity + 1); }); said.push('a bit firmer'); }
    if (prefs.ems === false && find('ems')) { p.steps = p.steps.filter(s => s.modality !== 'ems'); said.push('no muscle stimulation'); }
    if (prefs.ems === true && !find('ems')) { p.steps.splice(Math.max(0, p.steps.length - 1), 0, { modality: 'ems', intensity: clampI(base - 1), minutes: 3 }); said.push('muscle stimulation added'); }
    if (prefs.vibration === false) { p.steps = p.steps.filter(s => s.modality !== 'vibration'); said.push('no vibration'); }
    if (prefs.vibration === true && !find('vibration')) { p.steps.unshift({ modality: 'vibration', intensity: clampI(base), minutes: 3 }); said.push('vibration added'); }
    if (prefs.focus) { p.focus = prefs.focus; said.push({ up: 'focus higher', down: 'focus lower', out: 'focus further out', in: 'focus further in', front: 'focus toward the front', back: 'focus toward the back' }[prefs.focus]); }
    if (prefs.minutes) {
      const cur = p.steps.reduce((a, s) => a + s.minutes, 0) || 1;
      const target = prefs.minutes === 'shorter' ? Math.round(cur * .7) : prefs.minutes === 'longer' ? Math.round(cur * 1.3) : prefs.minutes;
      p.steps.forEach(s => s.minutes = Math.max(1, Math.round(s.minutes * target / cur)));
      said.push(`${p.steps.reduce((a, s) => a + s.minutes, 0)} minutes`);
    }
    p.minutes = p.steps.reduce((a, s) => a + s.minutes, 0);
    if (said.length) { p.kind = p.kind === 'routine' ? 'routine' : 'custom'; p.adjusted = true; }
    return { plan: p, said };
  }

  // TREAT: what to do with feedback during a session.
  function feedbackAction(fb) {
    return {
      'too strong': { type: 'level', delta: -1, say: 'Easing off a little.' },
      'too weak': { type: 'level', delta: 1, say: 'A little firmer.' },
      good: { type: 'continue', say: "Good. I'll carry on." },
      worse: { type: 'pause', say: "Let's pause. Is it okay to carry on more gently, or would you rather stop here?" }
    }[fb] || null;
  }
  // When to ask "How does this feel?". Fewer check-ins for people who usually say "good".
  function checkIns(history) {
    const fbs = history.flatMap(e => (e.feedback || []).map(f => f.value));
    if (fbs.filter(v => v === 'too strong').length >= 2) return [.15, .45, .75];
    if (fbs.length >= 4 && fbs.every(v => v === 'good')) return [.5];
    return [.3, .7];
  }

  const ADVICE = [
    [/shoulder|trap|scap|uarm/, 'A few slow arm circles and a gradual warm-up before playing can help the shoulder settle into exercise.'],
    [/lowerback|lowback|hips|glute/, 'Short walking breaks every 30 to 45 minutes of sitting tend to keep the lower back from stiffening.'],
    [/neck|headneck/, 'Bring your screen up to eye level and take a moment every hour to roll your shoulders back.'],
    [/lleg|calf|achilles|footg/, 'An easy walk and staying hydrated after long runs helps calves recover between sessions.'],
    [/knee|thigh/, 'Keep moving gently. Short walks are usually better than complete rest for tired legs.'],
    [/elbow|farm|handg|wrist/, 'Take regular breaks from gripping and typing, and loosen your grip where you can.']];
  const ord = n => n + (['th', 'st', 'nd', 'rd'][(n % 100 > 10 && n % 100 < 14) ? 0 : n % 10] || 'th');

  // REASSESS: pick the pathway after a session.
  function reassess({ response, sym, plan, history = [], now = Date.now() }) {
    const group = groupOf(sym.areaId), gLabel = N[group].label.toLowerCase(), noun = regionNoun(sym.areaId);
    const day = 864e5;
    const prior = history.filter(e => e.outcome && now - new Date(e.createdAt) < 90 * day);
    const recent = prior.filter(e => now - new Date(e.createdAt) < 60 * day);
    const occurrences = recent.length + 1;
    const ctx = sym.activity;
    const ctxCount = recent.filter(e => e.symptom.activity === ctx).length + (ctx ? 1 : 0);
    const notHelping = prior.slice(0, 2).filter(e => ['same', 'worse'].includes(e.outcome.response)).length;
    const good = prior.filter(e => ['much', 'little'].includes(e.outcome.response));
    const seqCount = {}; good.forEach(e => { const k = (e.intervention.steps || []).map(s => MOD[s.modality].label.toLowerCase()).join(' then '); seqCount[k] = (seqCount[k] || 0) + 1; });
    const best = Object.keys(seqCount).sort((a, b) => seqCount[b] - seqCount[a])[0] || null;
    const last30 = recent.filter(e => now - new Date(e.createdAt) < 30 * day).length + 1;
    const prev30 = prior.filter(e => { const a = now - new Date(e.createdAt); return a >= 30 * day && a < 60 * day; }).length;
    const observations = [];
    if (occurrences >= 2) observations.push(`${ord(occurrences)} episode for the ${gLabel} in 60 days.`);
    if (ctx && ctxCount >= 2) observations.push(`${ctxCount} of ${occurrences} followed ${ctx}.`);
    if (last30 > prev30 && prev30 > 0) observations.push('Happening more often than the month before.');
    const advice = (ADVICE.find(([re]) => re.test(group)) || [, 'Gentle movement through the day usually helps more than complete rest.'])[1];
    const routineName = ctx ? `Post-${ctx} ${noun} routine` : `${cap(noun)} routine`;
    const recurring = occurrences >= 3 || ctxCount >= 2;
    const typeWord = (TYPE_LABEL[sym.type] || 'uncomfortable').toLowerCase().replace('tightness', 'tight').replace('soreness', 'sore').replace('dull ache', 'achy').replace('sharp pain', 'painful').replace('discomfort', 'uncomfortable').replace('cramping', 'crampy');
    const recurText = recurring ? `This is the ${ord(occurrences)} time your ${gLabel} has become ${typeWord}${ctx ? ` after ${ctx}` : ' recently'}.${best ? ` Earlier sessions responded best to ${best}.` : ''}` : '';

    if (response === 'worse') return { pathway: 'escalate', escalate: true, observations, advice: null,
      headline: "That's made it worse, so let's stop here.",
      body: "I don't want to push this with something stronger. It's worth having it looked at by a physiotherapist, and I can put together a short summary for them." };
    if (response === 'same' && notHelping >= 1) return { pathway: 'escalate', escalate: true, observations, advice: null,
      headline: "It doesn't sound like this helped much. Let's not keep pushing it.",
      body: `This is the ${notHelping + 1 === 2 ? 'second' : ord(notHelping + 1)} session in a row that hasn't eased your ${gLabel}, so I'll pause automatic care here. A physiotherapist can take a proper look, and I can prepare a summary for them.` };
    if (response === 'much') return { pathway: 'positive', escalate: false, observations, advice: recurring ? advice : null,
      headline: `Lovely. Your ${noun} responded well today, and I've remembered what worked.`,
      body: recurring ? `${recurText} Shall I save today's session as your ${routineName.toLowerCase()}?` : '',
      offerRoutine: recurring, routineName };
    if (response === 'little') return { pathway: recurring ? 'recurring' : 'partial', escalate: false, observations, advice,
      headline: 'Good, it’s eased a little.',
      body: recurring ? `${recurText} Shall I save this as your ${routineName.toLowerCase()}, so it's ready next time?`
        : "Another gentle session later today or tomorrow often helps. I'll keep an eye on how it goes.",
      offerRoutine: recurring, routineName };
    return { pathway: 'partial', escalate: false, observations, advice,
      headline: 'No real change yet.',
      body: "That's normal after one session. Let's try a gentle one tomorrow. If it still feels the same after that, it's worth getting it checked." };
  }
  const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

  // WHY IT MIGHT FEEL THIS WAY — one or two plausible, hedged sentences after a session.
  // Uses the answer, how the movement check changed, what the user felt and why, and what ran.
  // Never a diagnosis: always "may", "often", "can".
  function explain({ response, sym = {}, plan = null, before = null, after = null }) {
    const S = { fine: 0, little: 1, quite: 2, cannot: 3 };
    const mv = before && after ? Math.sign(S[before.feel] - S[after.feel]) : null;   // 1 easier, 0 same, -1 harder
    const mods = (plan?.steps || []).map(s => s.modality);
    const heat = mods.includes('heat'), press = mods.includes('compression') || mods.includes('vibration');
    const how = heat && press ? 'Gentle pressure and warmth' : heat ? 'Warmth' : press ? 'Gentle pressure and vibration' : 'The session';
    const act = sym.activity, noun = regionNoun(sym.areaId);
    const sore = sym.type === 'soreness' || /running|training|lifting|team sport|tennis|climbing/.test(act || '');
    const desk = act === 'sitting' || act === 'work';
    const lines = [];
    if (response === 'much' || response === 'little') {
      lines.push(`${how} can help tight muscles relax and bring more blood flow to the area, which often makes things feel ${response === 'much' ? 'noticeably easier' : 'a bit easier'} for a while.`);
      if (mv === 1) lines.push('That may be why the movement felt easier just now.');
      else if (mv === 0) lines.push("The movement might take a little longer to catch up. That's quite common.");
      else if (mv === -1) lines.push('If the movement felt a bit more noticeable, the area may simply be more aware after being worked on.');
      if (response === 'little') lines.push(sore ? `Soreness after ${act || 'exercise'} often eases over a day or two, so it may keep improving.` : desk ? 'Stiffness from sitting often eases further with regular movement through the day.' : 'It may keep easing with rest and gentle movement.');
    } else if (response === 'same') {
      lines.push(sore ? `Muscles worked hard during ${act || 'exercise'} can stay tight for a day or two, and one session doesn't always shift that.`
        : desk ? 'Stiffness that builds up over long periods of sitting can take more than one session to ease.'
        : `Sometimes the tightness sits slightly away from where we worked, or your ${noun} needs a little more time.`);
      if (mv === 1) lines.push('The movement did feel a little easier, which may be an early sign it’s settling.');
    } else if (response === 'worse') {
      lines.push('A treated area can feel tender for a while afterwards, a bit like after a massage, and that often settles within a day.');
      lines.push("But if it keeps getting worse, it may need a different approach, which is why I'd rather not push further today.");
    }
    return lines.slice(0, 2).join(' ');
  }

  root.Lofer = root.Lofer || {};
  root.Lofer.Engine = { MOD, LEVELS, suggest, applyPrefs, describe, levelText, feedbackAction, checkIns, reassess, explain, regionNoun };
})(typeof window !== 'undefined' ? window : globalThis);
