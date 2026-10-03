/* SYMPTOM / CONTEXT MODEL — turns what the user says into structured fields.
   This is a keyword stand-in. In the product an LLM fills the same fields
   (same names, same allowed values), so nothing downstream changes. */
(function (root) {
  const O = "(?:my |the |your )?(?:left |right )?";
  const R = s => new RegExp(s);

  // Body area phrases → area ids. '{s}' is replaced by the side (r/l).
  const PARTS = [
    [R(`front of ${O}neck|throat`), { id: 'neck_f' }],
    [R(`side of ${O}neck`), { s: '{s}_neckside', noun: 'neck' }],
    [R(`back of ${O}neck|\\bneck\\b`), { id: 'neck_b' }],
    [/rotator cuff/, { s: '{s}_sh_back', noun: 'shoulder' }],
    [/between (my |the )?shoulder ?blades|rhomboid|mid(dle)? back/, { id: 'mid_back' }],
    [/shoulder ?blade|scapula/, { s: '{s}_scap', noun: 'shoulder blade' }],
    [/\btraps?\b|trapezius/, { s: '{s}_trap', id: 'upperback' }],
    [/upper back|thoracic/, { id: 'upperback' }],
    [/lower back|lumbar|\bql\b|\bmy back\b|\bback pain|\bback (is|feels|has|hurts)/, { id: 'lowerback', s: '{s}_lowback' }],
    [/\blats?\b|latissimus/, { s: '{s}_lat', noun: 'lat' }],
    [/back of (my |the )?head|headache/, { id: 'backhead' }],
    [/\bjaw\b|\bface\b|temple/, { id: 'face' }],
    [/(?<!(above|over|behind|on top of) (my |your |the )?)\bhead\b/, { id: 'headneck' }],   // "above my head" describes a movement, not a place
    [R(`front of ${O}shoulder|front delt`), { s: '{s}_sh_front', noun: 'shoulder' }],
    [R(`back of ${O}shoulder|rear delt`), { s: '{s}_sh_back', noun: 'shoulder' }],
    [R(`top of ${O}shoulder`), { s: '{s}_sh_top', noun: 'shoulder' }],
    [R(`outside of ${O}shoulder|outer shoulder|side delt`), { s: '{s}_sh_outer', noun: 'shoulder' }],
    [/shoulder|\bdelts?\b|deltoid/, { s: '{s}_shoulder', noun: 'shoulder' }],
    [/bicep/, { s: '{s}_ua_front', noun: 'arm' }],
    [/tricep/, { s: '{s}_ua_back', noun: 'arm' }],
    [/upper arm/, { s: '{s}_uarm', noun: 'upper arm' }],
    [/tennis elbow|outer elbow|outside of (my )?(left |right )?elbow/, { s: '{s}_el_outer', noun: 'elbow' }],
    [/golfer'?s elbow|inner elbow|inside of (my )?(left |right )?elbow/, { s: '{s}_el_inner', noun: 'elbow' }],
    [/elbow/, { s: '{s}_elbow', noun: 'elbow' }],
    [/forearm/, { s: '{s}_farm', noun: 'forearm' }],
    [R(`back of ${O}wrist|top of ${O}wrist`), { s: '{s}_wr_dorsal', noun: 'wrist' }],
    [R(`thumb side of ${O}wrist|base of ${O}thumb`), { s: '{s}_wr_radial', noun: 'wrist' }],
    [R(`(little|pinky|small) finger side|outside of ${O}wrist`), { s: '{s}_wr_ulnar', noun: 'wrist' }],
    [R(`inside of ${O}wrist|inner wrist|palm side of ${O}wrist|underside of ${O}wrist`), { s: '{s}_wr_palm', noun: 'wrist' }],
    [/wrist|carpal/, { s: '{s}_wrist', noun: 'wrist' }],
    [/\bthumb/, { s: '{s}_thumb', noun: 'thumb' }],
    [/\bfingers?\b|knuckle/, { s: '{s}_fingers', noun: 'hand' }],
    [/\bpalm/, { s: '{s}_palm', noun: 'hand' }],
    [R(`back of ${O}hand`), { s: '{s}_backhand', noun: 'hand' }],
    [/\bhands?\b/, { s: '{s}_hand', noun: 'hand' }],
    [/\barms?\b/, { s: '{s}_arm', noun: 'arm' }],
    [/chest|\bpecs?\b/, { id: 'chest', s: '{s}_chest' }],
    [/oblique|love handle/, { s: '{s}_oblique', id: 'abdomen' }],
    [/\babs\b|stomach|abdom|\bcore\b|belly/, { id: 'abdomen' }],
    [/hip flexor|psoas/, { s: '{s}_hipflex', noun: 'hip' }],
    [/glute|\bbum\b|\bbutt|buttock|piriformis/, { s: '{s}_glute', id: 'hips' }],
    [/outer hip|side of (my )?hip/, { s: '{s}_hipout', noun: 'hip' }],
    [/\bhips?\b/, { s: '{s}_hip', id: 'hips' }],
    [/groin|inner thigh|adductor/, { s: '{s}_th_inner', noun: 'thigh' }],
    [/\bit ?band|outer thigh/, { s: '{s}_th_outer', noun: 'thigh' }],
    [/hamstring|\bhammy|back of (my )?(left |right )?thigh/, { s: '{s}_th_back', noun: 'hamstring' }],
    [/\bquads?\b|quadricep/, { s: '{s}_th_front', noun: 'quad' }],
    [/thigh/, { s: '{s}_thigh', noun: 'thigh' }],
    [/kneecap|patella/, { s: '{s}_kn_front', noun: 'knee' }],
    [R(`back of ${O}knee|behind ${O}knee`), { s: '{s}_kn_back', noun: 'knee' }],
    [R(`inside of ${O}knee|inner knee`), { s: '{s}_kn_inner', noun: 'knee' }],
    [R(`outside of ${O}knee|outer knee`), { s: '{s}_kn_outer', noun: 'knee' }],
    [/\bknees?\b/, { s: '{s}_knee', noun: 'knee' }],
    [/\bshins?\b/, { s: '{s}_shin', noun: 'shin' }],
    [/\bcalf\b|calves/, { s: '{s}_calf', noun: 'calf' }],
    [/achilles/, { s: '{s}_achilles', noun: 'achilles' }],
    [/ankle/, { s: '{s}_ankle', noun: 'ankle' }],
    [/heel/, { s: '{s}_heel', noun: 'heel' }],
    [/plantar|\bsole\b|\barch\b/, { s: '{s}_sole', noun: 'foot' }],
    [/\bfoot\b|\bfeet\b|\btoes?\b/, { s: '{s}_footg', noun: 'foot' }],
    [/\blower legs?\b/, { s: '{s}_lleg', noun: 'lower leg' }],
    [/\blegs?\b/, { s: '{s}_leg', noun: 'leg' }],
  ];
  const PLURAL = /\b(both|calves|shoulders|knees|hamstrings|quads|thighs|legs|arms|hips|elbows|wrists|ankles|feet|shins)\b/;

  // Symptom types, in neutral wording for the Care Record.
  const TYPES = [
    { id: 'tightness', label: 'Tightness', re: /tight|stiff|tense|tension|knot/ },
    { id: 'cramp', label: 'Cramping', re: /cramp|spasm/ },
    { id: 'sharp', label: 'Sharp pain', re: /sharp|stabbing|shooting|pinch/ },
    { id: 'soreness', label: 'Soreness', re: /\bsore|destroyed|wrecked|\bdead\b|doms|battered/ },
    { id: 'ache', label: 'Dull ache', re: /\bach(e|es|y|ing)\b|dull|nagging|throb/ },
    { id: 'burning', label: 'Burning', re: /burn/ },
    { id: 'unclear', label: 'Feels off', re: /weird|funny|strange|\boff\b|not right|odd/ },   // the user can't name it yet → Lofer helps
    { id: 'pain', label: 'Discomfort', re: /pain|hurt|uncomfortable/ }        // too vague to act on → Lofer asks
  ];
  const TYPE_LABEL = Object.fromEntries(TYPES.map(t => [t.id, t.label]));

  const ACTS = [[/tennis|padel|squash|badminton/, 'tennis'], [/\brun\b|running|\bran\b|\bjog/, 'running'], [/lifting|deadlift|squat|bench|weights/, 'lifting'],
    [/\bgym\b|workout|training|crossfit/, 'training'], [/sitting|desk|laptop|computer/, 'sitting'], [/working|at work|work all day|long day/, 'work'], [/slept|sleeping|\bsleep\b/, 'sleeping'],
    [/cycling|\bbike\b|\bride\b/, 'cycling'], [/golf/, 'golf'], [/yoga|pilates/, 'yoga'], [/football|soccer|basketball|rugby/, 'team sport'],
    [/climb/, 'climbing'], [/\bhik/, 'hiking'], [/swim/, 'swimming'], [/flight|plane|driving|long drive/, 'travelling'], [/garden|lifting boxes|moving house/, 'lifting at home']];
  const ACT_PHRASE = { running: 'running', tennis: 'tennis', lifting: 'lifting', training: 'training', sitting: 'sitting', sleeping: 'sleeping', cycling: 'cycling', golf: 'golf', yoga: 'yoga', 'team sport': 'a team sport', climbing: 'climbing', hiking: 'hiking', swimming: 'swimming', travelling: 'travelling', 'lifting at home': 'lifting at home' };

  const TRIGGERS = [[/(above|over) my head|overhead|reach(ing)? up/, 'Raising the arm overhead'],
    [/(lift|raise|raising|lifting) (my |the )?arm(?! (above|over))/, 'Lifting the arm'],
    [/reach(ing)? (back|behind|backwards)|behind my back/, 'Reaching backwards'],
    [/rotat(e|ing)|twist(ing)?/, 'Rotating'],
    [/(lift|lifting|raise|raising) (my |the )?hand|bend(ing)? (my )?wrist (back|up)/, 'Lifting the hand'],
    [/push(ing)? up|press(ing)? (on|down)|weight through/, 'Pushing or leaning on it'],
    [/turn(ing)? my head|look(ing)? over my shoulder/, 'Turning the head'], [/bend(ing)? (over|down|forward)|bending/, 'Bending forward'],
    [/when i sit|sitting for|after sitting/, 'Prolonged sitting'], [/walking|when i walk/, 'Walking'], [/stairs/, 'Stairs'],
    [/grip|gripping|holding|opening jars/, 'Gripping'], [/squat|kneel/, 'Squatting or kneeling'], [/stand(ing)? up|getting up/, 'Standing up'],
    [/typing|mouse/, 'Typing'], [/when i run|running uphill/, 'Running'], [/serv(e|ing)|throw/, 'Overhead throwing or serving']];

  // Warning signs. 'urgent' = seek urgent care now, 'stop' = see a professional before using Lofer, 'caution' = keep it conservative.
  const FLAGS = [
    ['urgent', /chest pain|pain in (my )?chest|chest (feels )?(tight|heavy|crushing)|short(ness)? of breath|can'?t breathe|struggling to breathe|fainted|passed out|slurred|face (is )?drooping/, 'Chest symptoms or breathing difficulty'],
    ['urgent', /worst headache|sudden severe headache|thunderclap/, 'Sudden severe headache'],
    ['urgent', /(lost|losing|loss of) (control of )?(my )?(bladder|bowel)|numb (between|in) (my )?(legs|groin|saddle)/, 'Bladder, bowel or saddle numbness'],
    ['stop', /numb|tingl|pins and needles|electric shock/, 'Numbness or tingling'],
    ['stop', /\bweak(ness)?\b|gives way|giving way|can'?t (move|lift|bear weight|walk|straighten|bend|grip)/, 'Weakness or loss of movement'],
    ['stop', /swollen|swelling|bruis|deform|out of place|dislocat/, 'Swelling, bruising or deformity'],
    ['stop', /popped|\bsnap|heard a (pop|crack|click)|\bfell\b|\bfall\b|crash|accident|got hit|was hit|knock(ed)?|twisted/, 'Recent fall, knock or injury'],
    ['stop', /fever|night sweats|unexplained weight|wakes me (up )?at night|night pain|constant pain at night/, 'Fever, night pain or unexplained weight loss'],
    ['stop', /(calf|leg) (is |feels )?(hot|red|swollen|warm)|hot and swollen|red and hot/, 'Hot, red or swollen calf'],
    ['caution', /sharp|shooting|stabbing/, 'Sharp pain'],
    ['caution', /getting worse|worse (every|each) day|keeps getting worse/, 'Getting worse over time']];

  // Changes the user asks for when Lofer suggests a session.
  function prefsFrom(t) {
    const p = {};
    if (/more heat|warmer|hotter|add (some )?heat|with heat|extra heat/.test(t)) p.heat = 1;
    if (/no heat|less heat|cooler|too (hot|warm)|without heat/.test(t)) p.heat = -1;
    if (/gentle|gently|softer|lighter|keep it (easy|light|soft)|go easy/.test(t)) p.intensity = -1;
    if (/stronger|firmer|deeper|harder|more pressure|more intense/.test(t)) p.intensity = 1;
    if (/no (electrical|electric|ems|stim|tens|pulses|muscle stim)|without (ems|electric|stim)|not the electric/.test(t)) p.ems = false;
    else if (/(add|with|use|include) (some )?(ems|electrical|electric|stim|tens|muscle stim)/.test(t)) p.ems = true;
    if (/no vibration|without vibration/.test(t)) p.vibration = false;
    if (/more vibration|add vibration/.test(t)) p.vibration = true;
    const fm = t.match(/focus (higher|lower|further (?:out|in)|more (?:to the )?(?:front|back))|(higher|lower) (up|down)/);
    if (fm) p.focus = /higher|up/.test(fm[0]) ? 'up' : /lower|down/.test(fm[0]) ? 'down' : /out/.test(fm[0]) ? 'out' : /in\b/.test(fm[0]) ? 'in' : /front/.test(fm[0]) ? 'front' : 'back';
    const mm = t.match(/(\d{1,2}) ?(min|minute)/); if (mm) p.minutes = +mm[1];
    else if (/shorter|quick|quicker/.test(t)) p.minutes = 'shorter';
    else if (/longer/.test(t)) p.minutes = 'longer';
    return Object.keys(p).length ? p : null;
  }

  // Feedback during treatment.
  function feedbackFrom(t) {
    if (/worse|more pain|more painful|hurts more|increas|getting sore|starting to hurt|really hurts/.test(t)) return 'worse';
    if (/too (strong|much|hard|intense)|slightly too|bit much|softer|ease off|ouch|gentler|turn it down/.test(t)) return 'too strong';
    if (/too (weak|soft|light|gentle)|can'?t feel|barely|stronger|firmer|turn it up/.test(t)) return 'too weak';
    if (/\b(good|nice|fine|great|perfect|lovely|ok|okay|comfortable|just right)\b/.test(t)) return 'good';
    return null;
  }

  // "How does it feel now?" answers.
  function responseFrom(t) {
    if (/much better|way better|loads better|a lot better|great|amazing|fixed|gone/.test(t)) return 'much';
    if (/worse/.test(t)) return 'worse';
    if (/same|no (different|change)|not really|didn'?t help|nothing changed/.test(t)) return 'same';
    if (/better|easier|looser|eased/.test(t)) return 'little';
    return null;
  }

  function severityFrom(t) {
    const m = t.match(/\b(10|[0-9])( ?\/ ?10| out of (ten|10))\b/) || t.match(/\b(?:about|around|maybe|like) (?:a )?(10|[0-9])\b/) || t.match(/^ ?(10|[0-9]) ?$/);
    if (m) return +m[1];
    if (/unbearable|worst|excruciating|agony/.test(t)) return 9;
    if (/destroyed|killing|terrible|awful|really bad|very bad|wrecked|a lot\b(?! better)/.test(t) && !/quite a lot/.test(t)) return 7;
    if (/quite a lot|really|very|quite bad|pretty bad/.test(t)) return 6;
    if (/moderate(ly)?|a fair bit|quite a bit|somewhat/.test(t)) return 4;
    if (/a (little|bit)|slight|mild|niggle|not (much|too bad)/.test(t)) return /not (much|too bad)|a little/.test(t) ? 2 : 3;
    return null;
  }

  function onsetFrom(t) {
    if (/just now|this morning|today|an hour ago|earlier today/.test(t)) return 'today';
    if (/last night/.test(t)) return 'last night';
    if (/yesterday/.test(t)) return 'yesterday';
    if (/few days|couple of days|since (monday|tuesday|wednesday|thursday|friday|saturday|sunday|the weekend)|this week/.test(t)) return 'a few days ago';
    if (/(a|one|two|three|couple of|few) weeks?|last week|fortnight/.test(t)) return 'weeks ago';
    if (/months?|years?|for ages|always|forever/.test(t)) return 'months ago';
    return null;
  }

  // Details that change what Lofer does, pulled straight from the user's story.
  function storyDetails(t) {
    const d = {};
    const dm = t.match(/for (about |around |roughly |nearly |over )?(an? |one |two |three |four |five |half an |\d+ )(hours?|hrs?|minutes?|mins?)/);
    if (dm) d.activityDuration = dm[0].replace(/^for /, '');
    if (/(mostly|generally|usually|otherwise) (okay|ok|fine|alright)|doesn'?t (really )?hurt (normally|at rest|when i'?m still)|fine (at rest|normally|when i'?m still)|only (hurts|bothers me) when|fine until/.test(t)) d.atRest = 'minimal';
    if (/all the time|constant(ly)?|even (at rest|when i'?m still|lying down)|keeps me up|doesn'?t go away/.test(t)) d.atRest = 'present';
    const rm = t.match(/(better|easier|eases) (when|after|with|if) (i )?([a-z ]{3,24}?)(?= and | but |$)/) || t.match(/(heat|warmth|stretching|rest|resting|moving|massage|a shower|ice) (helps|makes it better)/);
    if (rm) d.relieving = (rm[4] || rm[1]).trim();
    if (/getting better|improving|easing (off)?|better than (it was|yesterday)/.test(t)) d.progression = 'improving';
    if (/getting worse|worse (each|every)|worsening|worse than (it was|yesterday)/.test(t)) d.progression = 'worsening';
    if (/(same|hasn'?t changed|not changing|about the same) (since|as)/.test(t)) d.progression = 'stable';
    if (/suddenly|all of a sudden|out of nowhere|felt a (pop|twinge|ping)/.test(t)) d.onsetType = 'sudden';
    else if (/gradually|crept up|built up|over time|slowly got/.test(t)) d.onsetType = 'gradual';
    return d;
  }
  // How a movement check felt, in the user's words.
  function movementFrom(t) {
    const m = {};
    if (/can'?t|couldn'?t|unable|too (painful|sore)|not comfortably/.test(t)) m.feel = 'cannot';
    else if (/quite (uncomfortable|sore|painful)|really (hurt|uncomfortable)|a lot/.test(t)) m.feel = 'quite';
    else if (/halfway|half way|middle|starts (hurting|pulling)|a (little|bit) uncomfortable|bit (sore|tight)|slightly|uncomfortable at the|until i get to/.test(t)) m.feel = 'little';
    else if (/\b(fine|easy|easier|no problem|comfortable|felt okay|feels okay|nothing|looser|better)\b/.test(t)) m.feel = 'fine';
    if (/halfway|half way|middle/.test(t)) m.where = 'about halfway';
    else if (/(the )?top|the end|all the way|until i get to|at the end|furthest/.test(t)) m.where = 'near the end of the movement';
    else if (/straight away|as soon as|right at the start/.test(t)) m.where = 'right from the start';
    if (/pull/.test(t)) m.quality = 'pulling'; else if (/pinch/.test(t)) m.quality = 'pinching'; else if (/tight/.test(t)) m.quality = 'tightness'; else if (/sharp/.test(t)) m.quality = 'sharp';
    if (/outside|outer/.test(t)) m.side = 'outside'; else if (/inside|inner/.test(t)) m.side = 'inside'; else if (/front/.test(t)) m.side = 'front'; else if (/\bback\b/.test(t)) m.side = 'back';
    return Object.keys(m).length ? m : null;
  }

  function parse(raw) {
    const t = ' ' + raw.toLowerCase().replace(/[’‘]/g, "'").replace(/[^a-z0-9/' ]+/g, ' ').replace(/\s+/g, ' ') + ' ';
    const r = { raw, entry: null, side: null, bilateral: false, type: null, severity: null, onset: null, activity: null,
      triggers: [], previous: false, flags: [], prefs: null, feedback: null, response: null,
      dir: null, slight: false, confirm: false, deny: false, turn: null, zoom: false, start: false };
    let t2 = t.replace(/all right|right now|right away|right after|right before|right there|that's right|thats right/g, ' ');
    const lr = t2.match(/(?:to|towards?) the (left|right)|more (?:to the )?(left|right)|further (left|right)/);
    if (lr) t2 = t2.replace(lr[0], ' ');
    const sm = t2.match(/\b(right|left)\b/); if (sm) r.side = sm[1][0];
    if (PLURAL.test(t) && !r.side) r.bilateral = true;
    const dirOnly = /^( (actually|um|uh|no|yes|and|it's|its|it is|a|bit|little|slightly|more|mostly|further|toward|towards|to|the|of|it|on|at|that|one|side|part|area|spot|than|there|same|just|higher|lower|up|down|above|below|outside|outer|inside|inner|front|back|left|right|focus|move|can|you|please))+ $/.test(t);
    if (!dirOnly) for (const [re, e] of PARTS) if (re.test(t)) { r.entry = e; break; }
    if (/\b(lower|down|below|beneath|underneath)\b/.test(t)) r.dir = 'down';
    else if (/\b(higher|up|above)\b/.test(t)) r.dir = 'up';
    else if (/\b(front of it|to the front|toward the front|towards the front|more front|at the front|on the front)\b/.test(t)) r.dir = 'front';
    else if (/\b(back of it|further back|to the back|toward the back|towards the back|more back|at the back|on the back)\b/.test(t)) r.dir = 'back';
    else if (/\b(outside|outer|outwards?)\b/.test(t)) r.dir = 'out';
    else if (/\b(inside|inner|inwards?)\b/.test(t)) r.dir = 'in';
    else if (lr) r.dir = (lr[1] || lr[2] || lr[3]) === 'left' ? 'L' : 'R';
    r.slight = /slight|little|\bbit\b|\btad\b|touch/.test(t);
    const tm = t.match(/\b(turn|flip|rotate|spin)\b|show (me )?(the )?(back|front|side)/);
    if (tm && !/turn(ing)? my head/.test(t)) r.turn = /back/.test(tm[0]) ? 'back' : /front/.test(tm[0]) ? 'front' : /side/.test(tm[0]) ? 'side' : 'toggle';
    r.zoom = /zoom|closer|narrow/.test(t);
    r.confirm = /\b(yes|yep|yeah|yup|correct|exactly|perfect)\b|that'?s (it|the spot|right)|spot on|right there|looks (right|good)|sounds good/.test(t);
    r.deny = /\b(no|nope|not quite|not really|wrong)\b/.test(t);
    r.start = /\b(start|begin|go ahead|let'?s go|let'?s do it|try (it|this)|ready)\b/.test(t);
    for (const ty of TYPES) if (ty.re.test(t)) { r.type = ty.id; break; }
    r.severity = severityFrom(t);
    r.onset = onsetFrom(t);
    for (const [re, v] of ACTS) if (re.test(t)) { r.activity = v; break; }
    for (const [re, v] of TRIGGERS) if (re.test(t) && !r.triggers.includes(v)) r.triggers.push(v);
    r.previous = /again|keeps|always|every time|recurring|comes back|keeps coming back|usual|as usual|same as last/.test(t);
    for (const [level, re, label] of FLAGS) if (re.test(t)) r.flags.push({ level, label });
    r.prefs = prefsFrom(t);
    r.feedback = feedbackFrom(t);
    r.response = responseFrom(t);
    r.story = storyDetails(t);
    r.movement = movementFrom(t);
    return r;
  }

  root.Lofer = root.Lofer || {};
  root.Lofer.Symptom = { parse, TYPES, TYPE_LABEL, ACT_PHRASE, prefsFrom, feedbackFrom, responseFrom, severityFrom, movementFrom, storyDetails };
})(typeof window !== 'undefined' ? window : globalThis);
