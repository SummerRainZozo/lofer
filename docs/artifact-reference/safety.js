/* SAFETY LAYER — deterministic rules, no AI.
   1. triage(): decides whether Lofer may treat at all (ok / caution / stop).
   2. validate(): checks a proposed plan and returns a sealed command, adjusted
      to fit the limits. The device only accepts sealed commands, so neither
      the voice agent nor the care engine can reach the hardware directly. */
(function (root) {
  const { N, pathTo } = root.Lofer.Anatomy;
  const SEALED = new WeakSet();
  const LIMITS = { maxIntensity: 5, maxMinutes: 20, maxHeat: 3 };

  const GUIDANCE = {
    urgent: 'Please get urgent medical help now. If symptoms are severe or getting worse quickly, call your local emergency number.',
    stop: 'Please have it looked at by a GP or physiotherapist before using Lofer on this area.',
    caution: "I'll keep things gentle and short, and check in more often."
  };

  // Areas where electrical muscle stimulation is never used.
  const NO_EMS_AREA = /neck_f|face|_neckside|chest|upper_abs|lower_abs|abdomen|headneck|backhead/;
  // Joints and thin-tissue areas: intensity stays low.
  const SENSITIVE = /_kn_|_el_|_wrist|_ankle|_achilles|neck|face|backhead|_palm|_backhand|_heel|_sole|_foottop/;

  function triage(sym, profile = {}) {
    const reasons = []; let level = 'ok', urgent = false;
    const area = sym.areaId ? pathTo(sym.areaId).join(' ') : '';
    const bump = (lv, why) => { reasons.push(why); if (lv === 'stop' || (lv === 'caution' && level === 'ok')) level = lv; };
    for (const f of sym.flags || []) {
      if (f.level === 'urgent') { urgent = true; bump('stop', f.label); }
      else bump(f.level, f.label);
    }
    if (sym.severity != null && sym.severity >= 9) bump('stop', `Very severe pain (${sym.severity}/10)`);
    else if (sym.severity != null && sym.severity >= 7) bump('caution', `Strong pain (${sym.severity}/10)`);
    if (sym.type === 'sharp') bump('caution', 'Described as sharp');
    if (sym.type === 'burning') bump('caution', 'Described as burning');
    if (sym.onset === 'months ago') bump('caution', 'Has lasted for months');
    if (sym.atRest === 'present') bump('caution', 'There most of the time, even at rest');
    if (sym.progression === 'worsening') bump('caution', 'Getting worse');
    const mv = sym.movement?.before;
    if (mv && mv.feel === 'cannot') {
      if (sym.type === 'sharp' || (sym.severity ?? 0) >= 7) bump('stop', 'Couldn’t do a simple movement comfortably, with strong or sharp pain');
      else bump('caution', 'Couldn’t do the movement check comfortably');
    } else if (mv && mv.feel === 'quite') bump('caution', 'Movement check was quite uncomfortable');
    if (profile.clot && /_lleg|_calf|_thigh|_leg/.test(area)) bump('stop', 'Leg discomfort with a blood clotting condition');
    if (profile.recent) bump('caution', 'Injury or surgery in the last 6 weeks (from your profile)');
    if (profile.pregnant) bump('caution', 'Pregnancy (from your profile)');
    if (profile.implant) bump('caution', 'Implanted device (from your profile)');
    if (sym.areaId && /neck_f|face/.test(sym.areaId)) bump('caution', 'Sensitive area');
    const constraints = {
      maxIntensity: level === 'caution' ? 2 : (sym.areaId && SENSITIVE.test(sym.areaId) ? 3 : LIMITS.maxIntensity),
      maxMinutes: level === 'caution' ? 10 : LIMITS.maxMinutes,
      noEMS: !!(profile.implant || profile.pregnant || (sym.areaId && NO_EMS_AREA.test(area + ' ' + sym.areaId)) || level === 'caution'),
      noHeat: (sym.flags || []).some(f => /Swelling|injury/.test(f.label)) || (profile.pregnant && /abdomen|lowerback|_lowback/.test(area))
    };
    return { level, urgent, reasons, guidance: urgent ? GUIDANCE.urgent : GUIDANCE[level] || '', constraints };
  }

  // Check a plan against the limits. Returns { ok, plan, notes, command }.
  function validate(plan, tri) {
    if (!tri || tri.level === 'stop') return { ok: false, plan, notes: ['Treatment is not available for this situation.'], command: null };
    const c = tri.constraints, notes = [];
    let steps = plan.steps.map(s => ({ ...s }));
    if (c.noEMS && steps.some(s => s.modality === 'ems')) {
      steps = steps.filter(s => s.modality !== 'ems');
      notes.push('Muscle stimulation left out for safety.');
    }
    if (c.noHeat && steps.some(s => s.modality === 'heat')) {
      steps = steps.filter(s => s.modality !== 'heat');
      notes.push('Heat left out: not advised with swelling or a recent knock.');
    }
    let capped = false;
    for (const s of steps) {
      const max = s.modality === 'heat' ? Math.min(c.maxIntensity, LIMITS.maxHeat) : c.maxIntensity;
      if (s.intensity > max) { s.intensity = max; capped = true; }
      if (s.intensity < 1) s.intensity = 1;
      s.minutes = Math.max(1, Math.round(s.minutes));
    }
    if (capped) notes.push(`Intensity capped at level ${c.maxIntensity}.`);
    let total = steps.reduce((a, s) => a + s.minutes, 0);
    if (total > c.maxMinutes) {
      const k = c.maxMinutes / total;
      steps.forEach(s => s.minutes = Math.max(1, Math.round(s.minutes * k)));
      total = steps.reduce((a, s) => a + s.minutes, 0);
      notes.push(`Shortened to ${total} minutes.`);
    }
    if (!steps.length) { steps = [{ modality: 'vibration', intensity: 1, minutes: 5 }]; notes.push('Using a gentle vibration only.'); }
    const out = { ...plan, steps, minutes: steps.reduce((a, s) => a + s.minutes, 0) };
    const command = Object.freeze({ region: plan.region, pair: plan.pair || null, focus: plan.focus || null, steps: Object.freeze(steps.map(s => Object.freeze({ ...s }))) });
    SEALED.add(command);
    return { ok: true, plan: out, notes, command };
  }

  // A change during treatment (e.g. "too strong") is checked the same way.
  function validateLevel(level, modality, tri) {
    const max = modality === 'heat' ? Math.min(tri.constraints.maxIntensity, LIMITS.maxHeat) : tri.constraints.maxIntensity;
    const v = Math.max(1, Math.min(max, level));
    const cmd = Object.freeze({ setIntensity: v, capped: v !== level }); SEALED.add(cmd); return cmd;
  }
  function validateRetarget(fromId, toId, tri) {
    // Moving the focus is allowed only within the same joint/segment (e.g. around the right shoulder).
    const g = id => pathTo(id)[2] || id;
    if (!tri || tri.level === 'stop' || g(fromId) !== g(toId)) return null;
    const cmd = Object.freeze({ retarget: toId }); SEALED.add(cmd); return cmd;
  }
  const isSealed = cmd => !!cmd && SEALED.has(cmd);

  root.Lofer = root.Lofer || {};
  root.Lofer.Safety = { triage, validate, validateLevel, validateRetarget, isSealed, LIMITS, GUIDANCE };
})(typeof window !== 'undefined' ? window : globalThis);
