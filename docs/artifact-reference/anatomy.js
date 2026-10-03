/* BODY MODEL — the named areas of the body and how they nest.
   Body › Right arm › Shoulder › Front of shoulder. Every other layer refers to
   areas by these ids (e.g. 'r_sh_front'), never by screen position. */
(function (root) {
  const N = {};
  function add(id, parent, o = {}) {
    const n = { id, parent, children: [], ...o };
    if (!n.side && parent && N[parent].side) n.side = N[parent].side;
    N[id] = n; if (parent) N[parent].children.push(id); return n;
  }
  const SIDES = { r: 'Right', l: 'Left' };
  add('body', null, { label: 'Full body', crumb: 'Body' });
  add('headneck', 'body', { label: 'Head & neck', say: 'your head and neck' });
  add('face', 'headneck', { label: 'Face & jaw', term: 'masseter · temporalis', say: 'your face and jaw' });
  add('backhead', 'headneck', { label: 'Back of head', term: 'suboccipitals', say: 'the back of your head' });
  add('neck_f', 'headneck', { label: 'Front of neck', term: 'sternocleidomastoid', say: 'the front of your neck' });
  add('neck_b', 'headneck', { label: 'Back of neck', term: 'upper trapezius · levator scapulae', say: 'the back of your neck' });
  add('torso', 'body', { label: 'Torso', say: 'your torso' });
  add('chest', 'torso', { label: 'Chest', say: 'your chest' });
  add('abdomen', 'torso', { label: 'Abdomen & sides', crumb: 'Abdomen', say: 'your abdomen' });
  add('upper_abs', 'abdomen', { label: 'Upper abdomen', term: 'rectus abdominis', say: 'your upper abdomen' });
  add('lower_abs', 'abdomen', { label: 'Lower abdomen', term: 'rectus abdominis · lower', say: 'your lower abdomen' });
  add('upperback', 'torso', { label: 'Upper back', say: 'your upper back' });
  add('mid_back', 'upperback', { label: 'Between shoulder blades', term: 'rhomboids · mid trapezius', say: 'the area between your shoulder blades' });
  add('lowerback', 'torso', { label: 'Lower back', say: 'your lower back' });
  for (const s of ['r', 'l']) {
    const Sd = SIDES[s], lo = Sd.toLowerCase();
    add(`${s}_neckside`, 'headneck', { side: s, label: `${Sd} side of neck`, term: 'scalenes', say: `the ${lo} side of your neck` });
    add(`${s}_chest`, 'chest', { side: s, label: `${Sd} chest`, term: 'pectoralis major', say: `the ${lo} side of your chest` });
    add(`${s}_oblique`, 'abdomen', { side: s, label: `${Sd} side`, term: 'obliques', say: `your ${lo} side` });
    add(`${s}_trap`, 'upperback', { side: s, label: `${Sd} upper trap`, term: 'upper trapezius', say: `your ${lo} upper trap` });
    add(`${s}_scap`, 'upperback', { side: s, label: `${Sd} shoulder blade`, term: 'infraspinatus · teres', say: `your ${lo} shoulder blade` });
    add(`${s}_lat`, 'upperback', { side: s, label: `${Sd} lat`, term: 'latissimus dorsi', say: `your ${lo} lat` });
    add(`${s}_lowback`, 'lowerback', { side: s, label: `${Sd} lower back`, term: 'erector spinae · QL', say: `the ${lo} side of your lower back` });
  }
  const leafSet = (parent, s, rows) => rows.forEach(([suf, label, term, say]) => add(`${s}_${suf}`, parent, { label, term, say }));
  for (const s of ['r', 'l']) {
    const Sd = SIDES[s], lo = Sd.toLowerCase(), A = `${s}_arm`;
    add(A, 'body', { side: s, label: `${Sd} arm`, say: `your ${lo} arm` });
    add(`${s}_shoulder`, A, { label: `${Sd} shoulder`, crumb: 'Shoulder', say: `your ${lo} shoulder` });
    leafSet(`${s}_shoulder`, s, [
      ['sh_front', 'Front of shoulder', 'anterior deltoid', `the front of your ${lo} shoulder`],
      ['sh_outer', 'Outer shoulder', 'lateral deltoid', `the outside of your ${lo} shoulder`],
      ['sh_back', 'Back of shoulder', 'posterior deltoid · rotator cuff', `the back of your ${lo} shoulder`],
      ['sh_top', 'Top of shoulder', 'AC joint · supraspinatus', `the top of your ${lo} shoulder`]]);
    add(`${s}_uarm`, A, { label: `${Sd} upper arm`, crumb: 'Upper arm', say: `your ${lo} upper arm` });
    leafSet(`${s}_uarm`, s, [
      ['ua_front', 'Front of upper arm', 'biceps', `the front of your ${lo} upper arm`],
      ['ua_outer', 'Outer upper arm', 'brachialis · deltoid insertion', `the outside of your ${lo} upper arm`],
      ['ua_back', 'Back of upper arm', 'triceps', `the back of your ${lo} upper arm`],
      ['ua_inner', 'Inner upper arm', 'coracobrachialis', `the inside of your ${lo} upper arm`]]);
    add(`${s}_elbow`, A, { label: `${Sd} elbow`, crumb: 'Elbow', say: `your ${lo} elbow` });
    leafSet(`${s}_elbow`, s, [
      ['el_front', 'Elbow crease', 'biceps tendon', `the crease of your ${lo} elbow`],
      ['el_outer', 'Outer elbow', 'lateral epicondyle · tennis elbow', `the outside of your ${lo} elbow`],
      ['el_back', 'Back of elbow', 'olecranon · triceps tendon', `the back of your ${lo} elbow`],
      ['el_inner', 'Inner elbow', "medial epicondyle · golfer's elbow", `the inside of your ${lo} elbow`]]);
    // Facets follow the resting pose (palms facing the thighs, thumbs forward).
    add(`${s}_farm`, A, { label: `${Sd} forearm`, crumb: 'Forearm', say: `your ${lo} forearm` });
    leafSet(`${s}_farm`, s, [
      ['fa_outer', 'Back of forearm', 'wrist extensors', `the back of your ${lo} forearm`],
      ['fa_inner', 'Palm side of forearm', 'wrist flexors', `the palm side of your ${lo} forearm`],
      ['fa_front', 'Thumb side of forearm', 'brachioradialis', `the thumb side of your ${lo} forearm`],
      ['fa_back', 'Little-finger side of forearm', 'flexor carpi ulnaris', `the little-finger side of your ${lo} forearm`]]);
    add(`${s}_wrist`, A, { label: `${Sd} wrist`, crumb: 'Wrist', say: `your ${lo} wrist` });
    leafSet(`${s}_wrist`, s, [
      ['wr_dorsal', 'Back of wrist', 'dorsal wrist · extensor tendons', `the back of your ${lo} wrist`],
      ['wr_palm', 'Palm side of wrist', 'carpal tunnel · flexor tendons', `the palm side of your ${lo} wrist`],
      ['wr_radial', 'Thumb side of wrist', 'radial wrist', `the thumb side of your ${lo} wrist`],
      ['wr_ulnar', 'Little-finger side of wrist', 'ulnar wrist', `the little-finger side of your ${lo} wrist`],
      ['wr_distal', 'Lower forearm', 'distal forearm', `just above your ${lo} wrist`]]);
    add(`${s}_hand`, A, { label: `${Sd} hand`, crumb: 'Hand', say: `your ${lo} hand` });
    leafSet(`${s}_hand`, s, [
      ['palm', 'Palm', 'palm · thenar muscles', `your ${lo} palm`],
      ['backhand', 'Back of hand', 'extensor tendons', `the back of your ${lo} hand`],
      ['thumb', 'Thumb', 'thumb and its base', `your ${lo} thumb`],
      ['fingers', 'Fingers', 'finger flexors · extensors', `the fingers of your ${lo} hand`],
      ['hand_edge', 'Little-finger edge', 'hypothenar', `the little-finger edge of your ${lo} hand`]]);
  }
  add('hips', 'body', { label: 'Hips & glutes', crumb: 'Hips', say: 'your hips' });
  for (const s of ['r', 'l']) {
    const Sd = SIDES[s], lo = Sd.toLowerCase();
    add(`${s}_hip`, 'hips', { side: s, label: `${Sd} hip`, say: `your ${lo} hip` });
    leafSet(`${s}_hip`, s, [
      ['hipflex', 'Hip flexor', 'iliopsoas', `your ${lo} hip flexor`],
      ['hipout', 'Outer hip', 'glute medius · TFL', `the outside of your ${lo} hip`],
      ['glute', 'Glute', 'gluteus maximus', `your ${lo} glute`]]);
  }
  for (const s of ['r', 'l']) {
    const Sd = SIDES[s], lo = Sd.toLowerCase(), L = `${s}_leg`;
    add(L, 'body', { side: s, label: `${Sd} leg`, say: `your ${lo} leg` });
    add(`${s}_thigh`, L, { label: `${Sd} thigh`, crumb: 'Thigh', say: `your ${lo} thigh` });
    leafSet(`${s}_thigh`, s, [
      ['th_front', 'Front of thigh', 'quadriceps', `the front of your ${lo} thigh`],
      ['th_outer', 'Outer thigh', 'IT band', `the outside of your ${lo} thigh`],
      ['th_back', 'Back of thigh', 'hamstrings', `the back of your ${lo} thigh`],
      ['th_inner', 'Inner thigh', 'adductors', `the inside of your ${lo} thigh`]]);
    add(`${s}_knee`, L, { label: `${Sd} knee`, crumb: 'Knee', say: `your ${lo} knee` });
    leafSet(`${s}_knee`, s, [
      ['kn_front', 'Kneecap', 'patellar tendon', `your ${lo} kneecap`],
      ['kn_outer', 'Outer knee', 'LCL · IT band', `the outside of your ${lo} knee`],
      ['kn_back', 'Back of knee', 'popliteus', `the back of your ${lo} knee`],
      ['kn_inner', 'Inner knee', 'MCL', `the inside of your ${lo} knee`]]);
    add(`${s}_lleg`, L, { label: `${Sd} lower leg`, crumb: 'Lower leg', say: `your ${lo} lower leg` });
    leafSet(`${s}_lleg`, s, [
      ['shin', 'Shin', 'tibialis anterior', `your ${lo} shin`],
      ['lc_outer', 'Outer calf', 'peroneals', `the outside of your ${lo} calf`],
      ['calf', 'Calf', 'gastrocnemius · soleus', `your ${lo} calf`],
      ['lc_inner', 'Inner calf', 'medial gastrocnemius', `the inside of your ${lo} calf`],
      ['achilles', 'Achilles', 'achilles tendon', `your ${lo} achilles`]]);
    add(`${s}_footg`, L, { label: `${Sd} ankle & foot`, crumb: 'Ankle & foot', say: `your ${lo} ankle and foot` });
    leafSet(`${s}_footg`, s, [
      ['ankle', 'Ankle', 'talocrural joint', `your ${lo} ankle`],
      ['foottop', 'Top of foot', 'extensor tendons', `the top of your ${lo} foot`],
      ['heel', 'Heel', 'calcaneus', `your ${lo} heel`],
      ['sole', 'Sole', 'plantar fascia', `the sole of your ${lo} foot`]]);
  }
  N.body.children = ['headneck', 'torso', 'r_arm', 'l_arm', 'hips', 'r_leg', 'l_leg'];

  const isLeaf = id => !N[id].children.length;
  const leavesOf = id => isLeaf(id) ? [id] : N[id].children.flatMap(leavesOf);
  const LEAVES = leavesOf('body');
  const LI = {}; LEAVES.forEach((id, i) => LI[id] = i);
  const pathTo = id => { const p = []; for (let n = id; n; n = N[n].parent) p.unshift(n); return p; };
  const lca = (a, b) => { const pa = pathTo(a), pb = pathTo(b); let r = 'body'; for (let i = 0; i < Math.min(pa.length, pb.length) && pa[i] === pb[i]; i++) r = pa[i]; return r; };
  const short = id => N[id].crumb || N[id].label;
  // Body Memory groups episodes at "joint / segment" level: r_sh_front → r_shoulder.
  const groupOf = id => { const p = pathTo(id); return p[2] || p[p.length - 1]; };
  const sideOf = id => N[id].side === 'l' ? 'left' : N[id].side === 'r' ? 'right' : 'centre';

  root.Lofer = root.Lofer || {};
  root.Lofer.Anatomy = { N, SIDES, isLeaf, leavesOf, LEAVES, LI, pathTo, lca, short, groupOf, sideOf };
})(typeof window !== 'undefined' ? window : globalThis);
