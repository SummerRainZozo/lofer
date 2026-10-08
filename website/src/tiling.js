// The tiling background: a faint cluster of Lofer tiles that sits behind the page and
// regroups as you scroll, the way real tiles latch edge to edge (3, 4, 5, then 7).
//
// The tiles fit on a hexagonal grid: each tile touches six neighbours. I measured the
// outline (see deviceShape.js): neighbours just clear each other, with about a 1-unit
// gap, when their centres are 88 units apart (on the 100-unit outline) along the six
// edge directions. The groupings below are the ones from the product renders.
//
// One pool of seven tiles is always on the page. Each grouping says which ones show.
// When the grouping or the side changes, the whole cluster spins away, and the next one
// spins in on its new side (it never slides across the page). Two sections that use the
// same grouping on the same side share it, with no change at all.
import { deviceOutlineSvgPath } from './deviceShape.js';

const PITCH = 88;
const toXY = (angleDeg) => [PITCH * Math.cos((angleDeg * Math.PI) / 180), PITCH * Math.sin((angleDeg * Math.PI) / 180)];
// The six neighbour directions (y points down): 90° = below, 270° = above, and so on.
const [DOWN_RIGHT, DOWN, DOWN_LEFT, UP_LEFT, UP, UP_RIGHT] = [30, 90, 150, 210, 270, 330].map(toXY);

// The seven slots: the centre, then its six neighbours. `colour` is a colourway from the renders.
const TILES = [
  { at: [0, 0], colour: '#d9c8ae' },            // oat
  { at: DOWN, colour: '#b9735a' },              // clay
  { at: UP, colour: '#a3a88d' },                // sage
  { at: DOWN_RIGHT, colour: '#cdb594' },        // sand
  { at: UP_RIGHT, colour: '#a3a88d' },          // sage
  { at: UP_LEFT, colour: '#876552' },           // cocoa
  { at: DOWN_LEFT, colour: '#b9735a' },         // clay
];

// Each grouping lists the slots that show (by index into TILES).
const GROUPINGS = {
  column3: [2, 0, 1],                 // 3 tiles, vertical column
  parallelogram4: [2, 0, 4, 3],       // 4 tiles
  columns5: [2, 0, 1, 4, 3],          // 5 tiles, two columns
  flower7: [0, 1, 2, 3, 4, 5, 6],     // 7 tiles, 2 – 3 – 2
};

// Which grouping each section uses, and where the cluster sits for it.
// `peek` is how much of the cluster's width shows when it sits at the edge of the screen.
const PLAN = {
  hero: { hidden: true },   // the hero has its own big tile, so the background rests
  why: { grouping: 'column3', side: 'right', tilt: -4 },
  checks: { grouping: 'parallelogram4', side: 'left', tilt: 3 },
  loop: { grouping: 'columns5', side: 'right', tilt: -3 },
  history: { grouping: 'columns5', side: 'right', tilt: -3 },    // same as the loop: no change between the two
  device: { grouping: 'flower7', side: 'right', tilt: 0, peek: 0.42 },   // the labels sit to its left, so show less
  waitlist: { hidden: true },   // no tiles behind the sign-up
};

const planKey = (plan) => `${plan.grouping}|${plan.side}|${plan.tilt}|${plan.peek ?? ''}`;

function tileMarkup({ at, colour }, i) {
  // The logo is the same outline as the tile, just smaller, and both are centred on (0, 0): it sits in the middle.
  return `<g class="tiling__tile" data-tile="${i}" style="--x:${at[0].toFixed(1)}px;--y:${at[1].toFixed(1)}px">
    <path class="tiling__body" d="${deviceOutlineSvgPath(100)}" fill="${colour}"/>
    <path class="tiling__seam" d="${deviceOutlineSvgPath(84)}"/>
    <path class="tiling__mark" d="${deviceOutlineSvgPath(11)}"/>
  </g>`;
}

// The spin: away (turn, shrink, fade) and back in (the same, reversed).
const SPIN_OUT = [{ opacity: 1, rotate: '0deg', scale: 1 }, { opacity: 0, rotate: '70deg', scale: 0.7 }];
const SPIN_IN = [{ opacity: 0, rotate: '-70deg', scale: 0.7 }, { opacity: 1, rotate: '0deg', scale: 1 }];

export function startTiling({ reducedMotion = false } = {}) {
  const layer = document.createElement('div');
  layer.className = 'tiling';
  layer.setAttribute('aria-hidden', 'true');
  // `pos` puts the cluster on a side; the svg inside it is what spins (about its own centre).
  // The cluster is about 270 × 290 units; the viewBox leaves a little room around it.
  layer.innerHTML = `<div class="tiling__pos"><svg class="tiling__svg" viewBox="-140 -150 280 300">${TILES.map(tileMarkup).join('')}</svg></div>`;
  document.body.prepend(layer);

  const pos = layer.querySelector('.tiling__pos');
  const svg = layer.querySelector('.tiling__svg');
  const tiles = [...layer.querySelectorAll('.tiling__tile')];

  let wanted = null;   // the section name we should be showing
  let current = null;  // what is showing now (a planKey), or null for nothing
  let busy = false;

  function apply(plan) {
    const visible = new Set(GROUPINGS[plan.grouping]);
    tiles.forEach((tile, i) => tile.classList.toggle('is-shown', visible.has(i)));
    layer.dataset.side = plan.side;
    pos.style.setProperty('--tilt', `${plan.tilt}deg`);
    pos.style.setProperty('--peek', plan.peek ?? 0.68);
  }

  const spin = (keyframes, duration, easing) => svg.animate(keyframes, { duration, easing, fill: 'forwards' });

  // Bring the page in line with `wanted`, one step at a time (if you scroll fast it still
  // finishes each spin before starting the next).
  async function sync() {
    if (busy) return;
    busy = true;
    try {
      for (;;) {
        const plan = PLAN[wanted];
        const key = plan && !plan.hidden ? planKey(plan) : null;
        if (key === current) break;

        let away = null;
        if (current !== null && !reducedMotion) {
          away = spin(SPIN_OUT, 480, 'cubic-bezier(0.5, 0, 0.9, 0.6)');
          await away.finished;
        }
        if (key === null) {
          layer.classList.remove('is-on');
          current = null;
          away?.cancel();
          continue;
        }
        apply(plan);
        current = key;
        layer.classList.add('is-on');
        if (!reducedMotion) {
          const arrive = spin(SPIN_IN, 850, 'cubic-bezier(0.2, 0.7, 0.2, 1)');
          away?.cancel();
          await arrive.finished;
          arrive.cancel();
        }
      }
    } finally {
      busy = false;
    }
  }

  // Use whichever section is crossing the middle of the screen.
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) { wanted = entry.target.dataset.tiling; sync(); }
      }
    },
    { rootMargin: '-45% 0px -45% 0px' },
  );
  document.querySelectorAll('[data-tiling]').forEach((section) => observer.observe(section));
}
