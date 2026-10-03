/* MOVEMENT CHECKS — simple wellness checks before and after a session.
   Not diagnostic: the user says how the movement feels, so before/after can be
   compared. CLARITY > MINIMALISM: each check is an illustrated, looping
   demonstration (START → MOVE → RETURN → PAUSE) with ghosted start/end poses,
   a direction arrow, a motion trail and the area to notice softly lit. */
(function (root) {
  const STOP = 'Move only as far as feels comfortable. Stop if it gets sharp or starts to hurt more.';
  const TESTS = [
    { id: 'arm_raise', name: 'Arm raise', match: /_sh_|shoulder|_ua_|uarm|_trap|_scap|chest|_lat/,
      intro: 'Before we start, let’s see how your shoulder feels with a simple movement.',
      start: 'Stand tall, arms relaxed by your sides.', move: 'Slowly raise your {side} arm forwards and up.', back: 'Lower it slowly back down.',
      notice: 'Where it starts to feel tight, and how high your arm goes.' },
    { id: 'head_turn', name: 'Head turn', match: /neck|backhead|headneck/,
      intro: 'Before we start, let’s see how your neck feels when you turn.',
      start: 'Sit or stand tall, looking straight ahead.', move: 'Slowly turn your head to look over one shoulder.', back: 'Come back to the middle, then try the other side.',
      notice: 'Which side feels tighter, and how far you can turn.' },
    { id: 'forward_reach', name: 'Forward reach', match: /lowerback|lowback|_glute|_hip|hips|mid_back|upperback/,
      intro: 'Before we start, let’s see how your back feels with a gentle reach.',
      start: 'Stand with feet hip-width apart, knees soft, hands on your thighs.', move: 'Slide your hands slowly down towards your knees.', back: 'Roll back up slowly.',
      notice: 'How far you can reach and where you feel it.' },
    { id: 'heel_raise', name: 'Heel raise', match: /calf|achilles|ankle|heel|sole|foot|lleg|shin|lc_/,
      intro: 'Before we start, let’s see how your calf feels with a simple movement.',
      start: 'Stand facing a wall with a hand on it for balance.', move: 'Rise slowly onto your toes.', back: 'Lower your heels slowly back down.',
      notice: 'Tightness in the calf or heel as you rise.' },
    { id: 'mini_squat', name: 'Mini squat', match: /knee|_kn_|thigh|_th_/,
      intro: 'Before we start, let’s see how your knee feels with a small bend.',
      start: 'Stand behind a chair, holding its back.', move: 'Bend your knees a little, as if starting to sit.', back: 'Stand back up. Keep it shallow.',
      notice: 'Where you feel it in the knee or thigh.' },
    { id: 'wrist_lift', name: 'Wrist lift', match: /elbow|_el_|farm|_fa_|wrist|_wr_|hand|palm|thumb|fingers/,
      intro: 'Before we start, let’s see how your wrist feels with a simple movement.',
      start: 'Rest your forearm on a table, palm facing down, hand just over the edge.', move: 'Slowly lift the back of your hand up.', back: 'Lower it slowly back to level.',
      notice: 'Any pulling along the forearm or around the wrist.' }
  ];
  const testFor = areaId => TESTS.find(t => t.match.test(areaId)) || null;
  // Answer buttons after the demonstration → a 0–10 score for before/after comparison.
  const RESPONSES = [['fine', 'Feels fine', 1], ['little', 'A little uncomfortable', 3], ['quite', 'Quite uncomfortable', 6], ['cannot', 'I can’t do this comfortably', 9]];
  const scoreOf = feel => (RESPONSES.find(r => r[0] === feel) || [, , null])[2];

  // ---------- geometry helpers ----------
  const R = d => d * Math.PI / 180;
  const at = (p, len, deg) => [p[0] + Math.sin(R(deg)) * len, p[1] + Math.cos(R(deg)) * len]; // 0° = straight down, 90° = forward (right), 180° = up
  const seg = (a, b, ra, rb, k = 'body') => ({ t: 'seg', a, b, ra, rb, k });
  const lerp = (a, b, k) => a + (b - a) * k;
  function segPath(a, b, ra, rb) {
    const ang = Math.atan2(b[1] - a[1], b[0] - a[0]), n = ang + Math.PI / 2, c = Math.cos(n), s = Math.sin(n);
    const P = (p, r, d) => `${(p[0] + c * r * d).toFixed(1)},${(p[1] + s * r * d).toFixed(1)}`;
    return `M${P(a, ra, 1)}L${P(b, rb, 1)}A${rb},${rb} 0 0,0 ${P(b, rb, -1)}L${P(a, ra, -1)}A${ra},${ra} 0 0,0 ${P(a, ra, 1)}Z`;
  }

  // Side-view standing figure facing right. Angles in degrees; px units in a 240×220 box.
  function standing({ arm = 0, trunk = 0, knee = 0, heel = 0, handOn = null, far = null }) {
    const ground = 204, toe = [128, ground], ankle = [114, ground - 6 - heel];
    const kneeP = at(ankle, 48, 180 - knee * .45), hip = at(kneeP, 50, 180 + knee * .55);
    const shoulder = at(hip, 56, 180 - trunk), neck = at(shoulder, 10, 180 - trunk * .9), head = at(neck, 15, 180 - trunk * .8);
    const elbow = handOn ? handOn[0] : at(shoulder, 30, arm + trunk * .15), hand = handOn ? handOn[1] : at(elbow, 28, arm + trunk * .15);
    const parts = [];
    if (far) parts.push(...far({ shoulder, hip }));
    parts.push(seg([ankle[0] - 8, ankle[1] + 2], [toe[0] + (heel ? 0 : 0), ground - 2], 5, 4, 'body'));       // foot
    parts.push(seg(ankle, kneeP, 6, 8), seg(kneeP, hip, 8, 12));                                            // leg
    parts.push(seg(hip, shoulder, 15, 17));                                                                  // torso
    parts.push(seg(shoulder, neck, 6, 6));
    parts.push({ t: 'head', c: head, r: 13, face: 1 });
    parts.push(seg(shoulder, elbow, 6.5, 5.5), seg(elbow, hand, 5.5, 4.5), { t: 'circle', c: hand, r: 5.5, k: 'body' });
    return { parts, j: { ankle, kneeP, hip, shoulder, elbow, hand, head } };
  }

  const FIG = {
    arm_raise: k => { const f = standing({ arm: lerp(4, 165, k) }); return { ...f, eff: f.j.hand, glow: [f.j.shoulder, 15] }; },
    forward_reach: k => {
      const trunk = lerp(0, 52, k), base = standing({ trunk });
      const thighTop = base.j.hip, kneeP = base.j.kneeP, tgt = [lerp(thighTop[0] + 10, kneeP[0] + 8, k), lerp(thighTop[1] + 8, kneeP[1] - 4, k)];
      const elbow = [(base.j.shoulder[0] + tgt[0]) / 2 + 6, (base.j.shoulder[1] + tgt[1]) / 2];
      const f = standing({ trunk, handOn: [elbow, tgt] });
      return { ...f, eff: tgt, glow: [[f.j.hip[0] - 6, f.j.hip[1] - 22], 16] };
    },
    heel_raise: k => {
      const heel = lerp(0, 13, k), f0 = standing({ heel });
      const handOn = [[f0.j.shoulder[0] + 22, f0.j.shoulder[1] + 14], [196, f0.j.shoulder[1] + 2]];
      const f = standing({ heel, handOn });
      f.parts.unshift({ t: 'rect', x: 200, y: 20, w: 10, h: 186, rx: 3, k: 'prop' });            // wall
      return { ...f, eff: [f.j.ankle[0] - 8, f.j.ankle[1] + 2], glow: [[f.j.ankle[0] - 2, f.j.ankle[1] - 22], 13] };
    },
    mini_squat: k => {
      const knee = lerp(0, 62, k), f0 = standing({ knee, trunk: lerp(0, 18, k) });
      const grip = [f0.j.shoulder[0] + 46, 104 + k * 2];
      const f = standing({ knee, trunk: lerp(0, 18, k), handOn: [[(f0.j.shoulder[0] + grip[0]) / 2, f0.j.shoulder[1] + 16], grip] });
      f.parts.unshift({ t: 'path', d: 'M172,98 L178,98 L182,204 L176,204 Z M172,98 h40 M206,98 L210,204 M178,150 h32', k: 'prop' });   // chair back
      return { ...f, eff: f.j.hip, glow: [f.j.kneeP, 13] };
    },
    head_turn: k => {
      // front view; turn left then right inside one "move" so both sides are shown
      const turn = Math.sin(k * Math.PI) * (k < .5 ? 1 : 1);
      const parts = [
        seg([120, 214], [120, 136], 34, 30), seg([86, 128], [154, 128], 11, 11),   // torso and shoulders
        seg([120, 126], [120, 98], 9, 9), { t: 'face', c: [120, 74], r: 22, turn: turn * .9 }];
      return { parts, j: {}, eff: [120 + turn * 22, 50], glow: [[120, 100], 14], arrowCustom: 'turn' };
    },
    wrist_lift: k => {
      // A person seated at a table, forearm resting on it, palm down, hand just past the edge.
      const tableY = 140, edge = 168, shoulder = [44, 78], elbow = [74, tableY - 8], wrist = [edge - 2, tableY - 8];
      const ang = lerp(18, -40, k);                                             // degrees from horizontal; + = drooping down
      const dir = [Math.cos(R(ang)), Math.sin(R(ang))], perp = [-dir[1], dir[0]];
      const P = (u, v) => [wrist[0] + dir[0] * u + perp[0] * v, wrist[1] + dir[1] * u + perp[1] * v];
      const hand = `M${P(0, -8)}L${P(30, -10)}Q${P(52, -10)} ${P(56, -3)}Q${P(57, 6)} ${P(48, 8)}L${P(8, 9)}Z`;   // back of hand up, fingers together
      const parts = [
        { t: 'rect', x: 60, y: tableY, w: edge - 60, h: 10, rx: 3, k: 'prop' }, { t: 'rect', x: 74, y: tableY + 10, w: 7, h: 56, rx: 2, k: 'prop' },
        { t: 'rect', x: 10, y: 150, w: 44, h: 8, rx: 3, k: 'prop' },               // seat
        seg([36, 150], shoulder, 16, 18), { t: 'head', c: [48, 50], r: 14 },       // seated torso and head
        seg(shoulder, elbow, 8, 7), seg(elbow, wrist, 8, 6.5),                     // arm resting on the table
        { t: 'path', d: hand, k: 'body' },
        { t: 'path', d: `M${P(10, 9)}Q${P(22, 15)} ${P(30, 11)}`, k: 'line' }];   // thumb tucked underneath
      return { parts, j: { wrist }, eff: P(54, 0), glow: [wrist, 12], labels: k < .05 ? [['palm faces down', [P(26, 26)[0], P(26, 26)[1]]]] : [] };
    }
  };

  // ---------- renderer ----------
  const DEFS = `<defs>
    <linearGradient id="mvSkin" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F1D6C3"/><stop offset="1" stop-color="#C79A80"/></linearGradient>
    <radialGradient id="mvGlow"><stop offset="0" stop-color="#FFE9D8" stop-opacity=".95"/><stop offset=".45" stop-color="#E4B598" stop-opacity=".45"/><stop offset="1" stop-color="#E4B598" stop-opacity="0"/></radialGradient>
    <marker id="mvArrow" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#E4B598"/></marker></defs>`;
  function shape(p, style) {
    const ghost = style === 'ghost';
    const fill = ghost ? 'none' : p.k === 'prop' ? 'rgba(243,235,226,.10)' : p.k === 'line' ? 'none' : 'url(#mvSkin)';
    const stroke = ghost ? 'rgba(243,235,226,.28)' : p.k === 'prop' ? 'rgba(243,235,226,.22)' : p.k === 'line' ? 'rgba(120,80,64,.6)' : 'rgba(255,240,230,.35)';
    const sw = ghost ? 1.2 : 1, dash = ghost ? ' stroke-dasharray="3 3"' : '';
    if (ghost && p.k === 'prop') return '';
    const st = `fill="${fill}" stroke="${stroke}" stroke-width="${sw}"${dash} stroke-linejoin="round"`;
    if (p.t === 'seg') return `<path d="${segPath(p.a, p.b, p.ra, p.rb)}" ${st}/>`;
    if (p.t === 'circle') return `<circle cx="${p.c[0].toFixed(1)}" cy="${p.c[1].toFixed(1)}" r="${p.r}" ${st}/>`;
    if (p.t === 'rect') return `<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" rx="${p.rx || 0}" ${st}/>`;
    if (p.t === 'poly') return `<polygon points="${p.pts.map(q => q.map(v => v.toFixed(1)).join(',')).join(' ')}" ${st}/>`;
    if (p.t === 'path') return `<path d="${p.d}" ${st}${p.k === 'prop' ? ' stroke-width="1.5"' : ''}/>`;
    if (p.t === 'head') return `<circle cx="${p.c[0].toFixed(1)}" cy="${p.c[1].toFixed(1)}" r="${p.r}" ${st}/>` + (ghost ? '' : `<circle cx="${(p.c[0] + 8).toFixed(1)}" cy="${(p.c[1] - 3).toFixed(1)}" r="1.6" fill="#5a3f33"/>`);
    if (p.t === 'face') {
      const x = p.c[0], y = p.c[1], tr = p.turn, rx = p.r * (1 - Math.abs(tr) * .12);
      const eyes = ghost ? '' : [-1, 1].map(s => `<ellipse cx="${(x + tr * p.r * .55 + s * 7 * (1 - Math.abs(tr) * .5)).toFixed(1)}" cy="${y - 3}" rx="${(2 * (1 - Math.abs(tr) * .3)).toFixed(1)}" ry="2" fill="#5a3f33"/>`).join('') +
        `<path d="M${(x + tr * p.r * .7).toFixed(1)},${y + 1} l${(tr * 4).toFixed(1)},6 l${(-tr * 3 - 1).toFixed(1)},1" fill="none" stroke="#8a6352" stroke-width="1.6" stroke-linecap="round"/>`;
      const ears = ghost ? '' : [-1, 1].map(s => { const vis = 1 - Math.max(0, s * tr); return `<ellipse cx="${(x + s * rx - tr * 3).toFixed(1)}" cy="${y + 1}" rx="${(3.5 * vis).toFixed(1)}" ry="6" fill="url(#mvSkin)"/>`; }).join('');
      return ears + `<ellipse cx="${x}" cy="${y}" rx="${rx.toFixed(1)}" ry="${p.r + 3}" ${st}/>` + eyes;
    }
    return '';
  }
  function arrowPath(fig, forward) {
    const pts = []; for (let i = 0; i <= 14; i++) pts.push(fig(i / 14).eff);
    const d = 'M' + pts.map(p => p.map(v => v.toFixed(1)).join(',')).join(' L');
    return `<path d="${d}" fill="none" stroke="#E4B598" stroke-opacity=".75" stroke-width="1.6" stroke-dasharray="4 4" ${forward ? 'marker-end' : 'marker-start'}="url(#mvArrow)"/>`;
  }
  // Mounts a looping demo; returns controls { pause(), play(), replay(), paused, stop() }.
  function animate(container, test, { onPhase } = {}) {
    const fig = FIG[test.id] || FIG.arm_raise;
    const box = document.createElement('div'); box.className = 'mv';
    box.innerHTML = `<svg viewBox="0 0 240 220" role="img" aria-label="${test.name} demonstration"></svg>`;
    container.appendChild(box);
    const svg = box.querySelector('svg');
    const ghosts = `<g opacity=".9">${fig(0).parts.map(p => shape(p, 'ghost')).join('')}${fig(1).parts.map(p => shape(p, 'ghost')).join('')}</g>`;
    const props = fig(0).parts.filter(p => p.k === 'prop').map(p => shape(p, 'solid')).join('');
    const arrows = [arrowPath(fig, true), arrowPath(fig, false)];
    const CYCLE = 7600, PH = [['start', 1200], ['move', 2400], ['hold', 800], ['return', 2400], ['pause', 800]];
    let t0 = performance.now(), pausedAt = null, raf = 0, lastPhase = null;
    function frameAt(now) {
      let c = ((now - t0) % CYCLE + CYCLE) % CYCLE, k = 0, phase = 'start';
      for (const [name, dur] of PH) { if (c < dur) { phase = name; const u = c / dur, e = u < .5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2;
        k = name === 'move' ? e : name === 'hold' ? 1 : name === 'return' ? 1 - e : 0; break; } c -= dur; }
      const f = fig(k);
      const trail = [1, 2, 3].map(i => { const kk = phase === 'move' ? Math.max(0, k - i * .07) : phase === 'return' ? Math.min(1, k + i * .07) : k; const p = fig(kk).eff;
        return phase === 'move' || phase === 'return' ? `<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="${3.5 - i * .7}" fill="#E4B598" opacity="${.45 - i * .12}"/>` : ''; }).join('');
      const glow = `<circle cx="${f.glow[0][0].toFixed(1)}" cy="${f.glow[0][1].toFixed(1)}" r="${(f.glow[1] * (1 + .12 * Math.sin(now / 300))).toFixed(1)}" fill="url(#mvGlow)"/>`;
      const labels = (f.labels || []).map(([s, p]) => `<text x="${p[0].toFixed(0)}" y="${p[1].toFixed(0)}" font-size="9" fill="#CFC3BA" text-anchor="middle">${s}</text>`).join('');
      svg.innerHTML = DEFS + `<line x1="10" y1="206" x2="230" y2="206" stroke="rgba(243,235,226,.12)" stroke-width="2"/>` + props + ghosts +
        (phase === 'return' ? arrows[1] : arrows[0]) + f.parts.filter(p => p.k !== 'prop').map(p => shape(p, 'solid')).join('') + glow + trail + labels;
      if (phase !== lastPhase) { lastPhase = phase; onPhase && onPhase(phase); }
    }
    const loop = now => { if (!box.isConnected) return; if (pausedAt == null) frameAt(now); raf = requestAnimationFrame(loop); };
    frameAt(performance.now()); raf = requestAnimationFrame(loop);
    // Keep going even where animation frames are throttled (e.g. some previews).
    const iv = setInterval(() => { if (!box.isConnected) return clearInterval(iv); if (pausedAt == null) frameAt(performance.now()); }, 120);
    return {
      get paused() { return pausedAt != null; },
      pause() { if (pausedAt == null) pausedAt = performance.now(); },
      play() { if (pausedAt != null) { t0 += performance.now() - pausedAt; pausedAt = null; } },
      replay() { t0 = performance.now(); pausedAt = null; frameAt(t0); },
      stop() { cancelAnimationFrame(raf); clearInterval(iv); }
    };
  }

  root.Lofer = root.Lofer || {};
  root.Lofer.Movement = { TESTS, testFor, animate, STOP, RESPONSES, scoreOf };
})(typeof window !== 'undefined' ? window : globalThis);
