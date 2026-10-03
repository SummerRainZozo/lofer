/* BODY MEMORY + OUTCOME MODEL — every episode, stored on this device.
   Episode = SYMPTOM (what the user said, structured) + STATE (sensors, movement
   check) + INTERVENTION (what ran) + FEEDBACK (during treatment) + OUTCOME.
   The user's own words are always kept next to the structured summary. */
(function (root) {
  const { N, groupOf, sideOf } = root.Lofer.Anatomy;
  const { TYPE_LABEL } = root.Lofer.Symptom;
  const { MOD } = root.Lofer.Engine;
  const K = 'lofer.memory.v1', KR = 'lofer.routines.v1';
  const get = (k, d) => { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (_) { return d; } };
  const put = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} };
  const day = 864e5;

  let episodes = get(K, null);
  let routines = get(KR, {});
  if (!Array.isArray(episodes)) { episodes = seed(); put(K, episodes); }

  function seed() {
    let s = 11; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
    const log = (steps) => { const out = []; let t = 0, skin = 32.4;
      for (const st of steps) for (let k = 0; k < st.minutes * 6; k++, t += 10) {
        skin += ((st.modality === 'heat' ? 34 + st.intensity * 1.2 : 32.6) - skin) * .16;
        const p = st.modality === 'heat' ? 4 + st.intensity : st.modality === 'ems' ? 6 : (8 + st.intensity * 8) * (1 + .2 * Math.sin(t / 2)) + (rnd() - .5) * 2;
        out.push({ t, modality: st.modality, level: st.intensity, pressure: +p.toFixed(1), skinTemp: +skin.toFixed(1) }); }
      return out; };
    const mk = (daysAgo, hour, o) => {
      const d = new Date(Date.now() - daysAgo * day); d.setHours(hour, 12, 0, 0);
      const steps = o.steps, lg = log(steps);
      return { id: 'sample-' + daysAgo, sample: true, createdAt: d.toISOString(), said: o.said, point: null, normal: null,
        symptom: { areaId: o.area, pairId: null, side: sideOf(o.area), type: o.type, severity: o.sev, onset: o.onset, activity: o.act, triggers: o.trig || [], previous: daysAgo < 15, flags: [] },
        triage: { level: 'ok', reasons: [] },
        intervention: { planName: o.plan, kind: o.kind, steps, minutesPlanned: steps.reduce((a, x) => a + x.minutes, 0), durationSec: steps.reduce((a, x) => a + x.minutes * 60, 0), patches: ['P1', 'P2', 'P3'], adjustments: o.adj || [], log: lg },
        feedback: o.fb || [{ t: 240, value: 'good', via: 'tap' }],
        test: o.test || null,
        outcome: { response: o.resp, severityAfter: o.after, pathway: o.resp === 'much' ? 'positive' : o.resp === 'same' ? 'partial' : 'partial', sensors: summarise(lg) } };
    };
    const shoulder = [{ modality: 'vibration', intensity: 3, minutes: 3 }, { modality: 'compression', intensity: 3, minutes: 4 }, { modality: 'heat', intensity: 2, minutes: 3 }];
    const back = [{ modality: 'vibration', intensity: 2, minutes: 4 }, { modality: 'compression', intensity: 2, minutes: 4 }, { modality: 'heat', intensity: 2, minutes: 2 }];
    return [
      mk(19, 20, { area: 'r_sh_front', type: 'tightness', sev: 7, after: 3, onset: 'yesterday', act: 'tennis', trig: ['Arm elevation'], kind: 'gentle', plan: 'Gentle recovery', steps: shoulder, resp: 'much',
        said: ['My right shoulder is really tight after tennis yesterday, it hurts when I lift my arm.'], test: { id: 'arm_raise', name: 'Arm raise', before: 6, after: 3 } }),
      mk(15, 8, { area: 'r_lowback', type: 'tightness', sev: 5, after: 2, onset: 'today', act: 'sitting', kind: 'gentle', plan: 'Gentle recovery', steps: back, resp: 'much',
        said: ['Lower back is stiff from sitting all day.'] }),
      mk(12, 21, { area: 'r_sh_front', type: 'tightness', sev: 6, after: 4, onset: 'yesterday', act: 'tennis', trig: ['Arm elevation'], kind: 'targeted', plan: 'Targeted relief', steps: shoulder, resp: 'little',
        said: ['Same shoulder again after tennis. Tight when I serve.'], test: { id: 'arm_raise', name: 'Arm raise', before: 5, after: 3 },
        fb: [{ t: 180, value: 'too strong', via: 'voice' }, { t: 420, value: 'good', via: 'tap' }], adj: [{ t: 180, what: 'Intensity 3 → 2 (too strong)' }] }),
      mk(9, 19, { area: 'l_calf', type: 'soreness', sev: 5, after: 3, onset: 'today', act: 'running', kind: 'targeted', plan: 'Targeted relief', steps: back, resp: 'little',
        said: ['My left calf is destroyed after my long run.'] }),
      mk(6, 18, { area: 'r_lowback', type: 'tightness', sev: 4, after: 1, onset: 'today', act: 'sitting', kind: 'gentle', plan: 'Gentle recovery', steps: back, resp: 'much',
        said: ['Back is stiff again, long day at the desk.'] }),
      mk(3, 20, { area: 'r_sh_front', type: 'tightness', sev: 6, after: 6, onset: 'yesterday', act: 'tennis', trig: ['Arm elevation'], kind: 'targeted', plan: 'Targeted relief', steps: shoulder, resp: 'same',
        said: ['Right shoulder tight again since tennis, sore when I raise my arm.'], test: { id: 'arm_raise', name: 'Arm raise', before: 6, after: 6 } })
    ].reverse();
  }

  function summarise(log) {
    const p = log.filter(x => x.modality !== 'heat').map(x => x.pressure);
    const sk = log.map(x => x.skinTemp);
    const avg = p.length ? p.reduce((a, b) => a + b, 0) / p.length : 0;
    return { avgPressure: Math.round(avg), peakPressure: Math.round(Math.max(0, ...p)), skinStart: sk[0] ?? null, skinPeak: sk.length ? Math.max(...sk) : null };
  }

  const M = {
    all: () => [...episodes].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)),
    get: id => episodes.find(e => e.id === id),
    add(ep) { episodes.push(ep); put(K, episodes); return ep; },
    update(ep) { const i = episodes.findIndex(e => e.id === ep.id); if (i >= 0) episodes[i] = ep; else episodes.push(ep); put(K, episodes); },
    remove(id) { episodes = episodes.filter(e => e.id !== id); put(K, episodes); },
    clear() { episodes = []; put(K, episodes); },
    restoreSamples() { episodes = [...episodes.filter(e => !e.sample), ...seed()]; put(K, episodes); },
    summarise,
    // Earlier episodes for the same joint/segment, newest first.
    history(areaId, excludeId) { const g = groupOf(areaId); return M.all().filter(e => e.id !== excludeId && e.outcome && groupOf(e.symptom.areaId) === g); },
    routineFor(areaId, activity) { const g = groupOf(areaId); return routines[g + '|' + (activity || '')] || routines[g + '|'] || null; },
    saveRoutine(areaId, activity, name, plan) {
      const g = groupOf(areaId); routines[g + '|' + (activity || '')] = { name, plan: { steps: plan.steps, minutes: plan.minutes }, savedAt: new Date().toISOString() }; put(KR, routines);
    },
    routinesList: () => Object.entries(routines).map(([k, v]) => ({ key: k, group: k.split('|')[0], activity: k.split('|')[1], ...v })),
    removeRoutine(key) { delete routines[key]; put(KR, routines); },

    // "What tends to bother this user, when, and what helps?"
    insights(now = Date.now()) {
      const by = {};
      for (const e of M.all()) { const g = groupOf(e.symptom.areaId); (by[g] ||= []).push(e); }
      return Object.entries(by).map(([g, list]) => {
        const ctx = {}; list.forEach(e => e.symptom.activity && (ctx[e.symptom.activity] = (ctx[e.symptom.activity] || 0) + 1));
        const top = Object.keys(ctx).sort((a, b) => ctx[b] - ctx[a])[0] || null;
        const helped = list.filter(e => ['much', 'little'].includes(e.outcome?.response));
        const seq = {}; helped.forEach(e => { const k = e.intervention ? e.intervention.steps.map(s => MOD[s.modality].label.toLowerCase()).join(' then ') : ''; if (k) seq[k] = (seq[k] || 0) + 1; });
        const last30 = list.filter(e => now - new Date(e.createdAt) < 30 * day).length;
        const prev30 = list.filter(e => { const a = now - new Date(e.createdAt); return a >= 30 * day && a < 60 * day; }).length;
        const lastTwo = list.slice(0, 2).map(e => e.outcome?.response);
        return { group: g, label: N[g].label, count: list.length, last: list[0].createdAt, topContext: top, topContextCount: top ? ctx[top] : 0,
          helpedCount: helped.length, best: Object.keys(seq).sort((a, b) => seq[b] - seq[a])[0] || null,
          trend: last30 > prev30 && prev30 > 0 ? 'more often' : null,
          selfCareFailing: lastTwo.length === 2 && lastTwo.every(r => r === 'same' || r === 'worse') || lastTwo[0] === 'worse' };
      }).sort((a, b) => b.count - a.count);
    },

    // Physiotherapist summary. Keeps sources apart and makes no diagnosis.
    report({ days = 90, group = null, now = Date.now() } = {}) {
      const list = M.all().filter(e => now - new Date(e.createdAt) < days * day && (!group || groupOf(e.symptom.areaId) === group));
      if (!list.length) return null;
      const counts = {}; list.forEach(e => { const g = groupOf(e.symptom.areaId); counts[g] = (counts[g] || 0) + 1; });
      const primary = group || Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0];
      const eps = list.filter(e => groupOf(e.symptom.areaId) === primary).reverse(); // oldest first
      const fmt = d => new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
      const ctx = {}; eps.forEach(e => e.symptom.activity && (ctx[e.symptom.activity] = (ctx[e.symptom.activity] || 0) + 1));
      const topCtx = Object.keys(ctx).sort((a, b) => ctx[b] - ctx[a])[0];
      const types = [...new Set(eps.map(e => (TYPE_LABEL[e.symptom.type] || 'Discomfort').toLowerCase()))];
      const trig = [...new Set(eps.flatMap(e => e.symptom.triggers || []))];
      const resp = { much: 'clear improvement', little: 'some improvement', same: 'no change', worse: 'worse' };
      const tests = eps.filter(e => e.test && e.test.before != null);
      const sens = eps.filter(e => e.outcome?.sensors);
      const avgP = sens.length ? Math.round(sens.reduce((a, e) => a + (e.outcome.sensors.avgPressure || 0), 0) / sens.length) : null;
      const kinds = {}; eps.forEach(e => e.intervention && (kinds[e.intervention.planName] = (kinds[e.intervention.planName] || 0) + 1));
      const mins = Math.round(eps.reduce((a, e) => a + (e.intervention?.durationSec || 0), 0) / 60);
      const mods = [...new Set(eps.flatMap(e => (e.intervention?.steps || []).map(s => MOD[s.modality].label.toLowerCase())))];
      const lastTwo = eps.slice(-2).map(e => e.outcome?.response);
      const obs = [];
      if (eps.length >= 2) obs.push(`${eps.length} episodes for this area between ${fmt(eps[0].createdAt)} and ${fmt(eps[eps.length - 1].createdAt)}.`);
      if (topCtx && ctx[topCtx] >= 2) obs.push(`${ctx[topCtx]} of ${eps.length} episodes were reported after ${topCtx}.`);
      if (lastTwo.length === 2 && lastTwo[1] === 'same' && lastTwo[0] !== 'same') obs.push('Reported response to self-care has decreased in the most recent session.');
      if (eps.some(e => e.triage?.level === 'stop')) obs.push('Lofer declined to treat at least one episode because of reported warning signs.');
      return {
        title: 'Lofer care summary',
        period: `${fmt(eps[0].createdAt)} – ${fmt(eps[eps.length - 1].createdAt)}`,
        region: N[primary].label,
        episodes: `${eps.length} reported episode${eps.length > 1 ? 's' : ''}`,
        userReported: [
          ['Symptoms', `Recurring ${types.join(', ')}`],
          trig.length ? ['Movement associated with discomfort', trig.join(', ')] : null,
          topCtx ? ['Common context', `${ctx[topCtx]}/${eps.length} after ${topCtx}`] : null,
          ['Self-reported severity (before → after)', eps.map(e => `${fmt(e.createdAt)}: ${e.symptom.severity ?? '–'} → ${e.outcome?.severityAfter ?? '–'}`).join('; ')],
          ['Reported response', eps.map(e => `${fmt(e.createdAt)} ${resp[e.outcome?.response] || 'not recorded'}`).join('; ')],
          tests.length ? ['Movement check (discomfort 0–10, before → after)', tests.map(e => `${e.test.name} ${e.test.before} → ${e.test.after ?? '–'}`).join('; ')] : null
        ].filter(Boolean),
        quotes: eps.flatMap(e => e.said || []).slice(-3),
        treatment: [
          ['Sessions', `${eps.filter(e => e.intervention).length} recovery sessions, ${mins} minutes in total`],
          ['Programmes', Object.entries(kinds).map(([k, v]) => `${k} ×${v}`).join(', ')],
          ['Modalities', mods.join(', ')]
        ],
        measured: [
          avgP != null ? ['Average applied pressure', `${avgP} kPa (simulated device)`] : null,
          sens.some(e => e.outcome.sensors.skinPeak) ? ['Peak skin temperature during heat', `${Math.max(...sens.map(e => e.outcome.sensors.skinPeak || 0)).toFixed(1)} °C (simulated device)`] : null
        ].filter(Boolean),
        observations: obs,
        note: 'Generated by Lofer from the user’s own reports and device logs. It is not a diagnosis.'
      };
    },
    reportText(r) {
      const L = [r.title.toUpperCase(), '', `Period: ${r.period}`, `Primary region: ${r.region}`, `Episodes: ${r.episodes}`, '', 'USER-REPORTED'];
      r.userReported.forEach(([k, v]) => L.push(`- ${k}: ${v}`));
      if (r.quotes.length) { L.push('- In their words:'); r.quotes.forEach(q => L.push(`  "${q}"`)); }
      L.push('', 'TREATMENT PERFORMED'); r.treatment.forEach(([k, v]) => L.push(`- ${k}: ${v}`));
      if (r.measured.length) { L.push('', 'DEVICE-MEASURED'); r.measured.forEach(([k, v]) => L.push(`- ${k}: ${v}`)); }
      if (r.observations.length) { L.push('', 'SYSTEM-GENERATED OBSERVATIONS'); r.observations.forEach(o => L.push(`- ${o}`)); }
      L.push('', r.note);
      return L.join('\n');
    }
  };

  root.Lofer = root.Lofer || {};
  root.Lofer.Memory = M;
})(typeof window !== 'undefined' ? window : globalThis);
