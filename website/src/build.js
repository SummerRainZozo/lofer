// "Inside Lofer": an exploded view of one tile. Four layers (lid, core, frame,
// skin side) are drawn as flat SVGs in the device outline, stacked in 3D with
// CSS, and spread apart as you scroll through the section. Each label lights
// up as its layer separates.
//
// Component positions and sizes come from the prototype drawings (the layout
// diagram and CAD renders). Units: the tile is 100 wide, centred on (0, 0);
// a 15 mm Peltier island is ~27 units, so 1 unit ≈ 0.55 mm.
import { deviceOutlineSvgPath } from './deviceShape.js';

const OUTLINE = deviceOutlineSvgPath(100);
const INNER = deviceOutlineSvgPath(78); // inner edge of the frame ring

// Edge contacts: three per edge (one edge per petal), in the order on the drawing.
const CONTACT_COLOURS = ['#d8643f', '#4e4a45', '#4f86d6']; // N magnet · TX, GND, S · RX
function contactDots() {
  const dots = [];
  for (let petal = 0; petal < 6; petal++) {
    CONTACT_COLOURS.forEach((colour, k) => {
      const angle = ((petal * 60 + 12 + k * 18) * Math.PI) / 180;
      const r = 41;
      dots.push(`<circle cx="${(Math.cos(angle) * r).toFixed(1)}" cy="${(Math.sin(angle) * r).toFixed(1)}" r="2.6" fill="${colour}"/>`);
    });
  }
  return dots.join('');
}

/** The four layers, top to bottom. `face` is the SVG content; `edge` its side colour. */
const LAYERS = [
  {
    name: 'lid',
    edge: '#2f2c29',
    face: `<defs><linearGradient id="lid-g" x1="0" y1="0" x2="1" y2="1">
             <stop offset="0" stop-color="#6a655f"/><stop offset="1" stop-color="#3d3a36"/></linearGradient></defs>
           <path d="${OUTLINE}" fill="url(#lid-g)"/>
           <path d="${deviceOutlineSvgPath(62)}" fill="none" stroke="#e4b598" stroke-opacity="0.6" stroke-width="0.8"/>`,
  },
  {
    name: 'core',
    edge: '#9e978d',
    face: `<path d="${deviceOutlineSvgPath(92)}" fill="#efe9e1" stroke="#cfc7bc" stroke-width="0.6"/>
           <rect x="-21" y="-34" width="42" height="15.6" rx="2.5" fill="#b9b4ac"/>
           <rect x="-21" y="12" width="28" height="16" rx="2.5" fill="#b9b4ac"/>
           <rect x="-34" y="-11.8" width="15.8" height="17.6" rx="2" fill="#4f8a64"/>
           <rect x="18.2" y="-11.8" width="15.8" height="17.6" rx="2" fill="#4f8a64"/>
           <circle cx="0" cy="-3" r="17" fill="#e2ddd5"/>
           <rect x="-13.5" y="-16.3" width="27" height="26.6" rx="2" fill="#e59b7c"/>
           <circle cx="16" cy="20.3" r="7.3" fill="#f0c46e" stroke="#c99a45" stroke-width="0.8"/>`,
  },
  {
    name: 'frame',
    edge: '#a8a196',
    face: `<path d="${OUTLINE} ${INNER}" fill="#d9d3ca" fill-rule="evenodd"/>${contactDots()}`,
  },
  {
    name: 'skin',
    edge: '#aaa398',
    face: `<path d="${OUTLINE}" fill="#e3ddd4"/>
           <rect x="-18" y="-27.5" width="36" height="55" rx="1.5" fill="#cd5b33" transform="rotate(35)"/>
           <circle cx="25.4" cy="17.8" r="7.3" fill="#a7a199" stroke="#8d877e" stroke-width="1"/>
           <circle cx="-25.4" cy="-17.8" r="7.3" fill="#a7a199" stroke="#8d877e" stroke-width="1"/>
           <rect x="9" y="30" width="8" height="3.5" rx="0.8" fill="#55514c" transform="rotate(35)"/>`,
  },
];

function layerSvg(content) {
  return `<svg viewBox="-55 -55 110 110" aria-hidden="true">${content}</svg>`;
}

const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

export function startBuild({ reducedMotion = false } = {}) {
  const stage = document.querySelector('[data-build]');
  const stack = document.querySelector('[data-build-stack]');
  if (!stage || !stack) return;
  const labels = [...document.querySelectorAll('[data-build-label]')];

  // Each layer = a darker "edge" copy just below a face, which reads as thickness.
  stack.innerHTML = LAYERS.map((layer, i) => `
    <div class="build__layer" style="--i:${i}">
      <div class="build__edge">${layerSvg(`<path d="${OUTLINE}" fill="${layer.edge}"/>`)}</div>
      <div class="build__face">${layerSvg(layer.face)}</div>
    </div>`).join('');

  /** 0 = assembled, 1 = fully apart. */
  function setExplode(e) {
    stack.style.setProperty('--explode', e.toFixed(3));
    labels.forEach((label, i) => label.classList.toggle('is-active', e > 0.15 + i * 0.18));
  }

  if (reducedMotion) {
    stage.classList.add('build__stage--static');
    setExplode(1);
    return;
  }

  // Progress through the tall stage → how far apart the layers are.
  function update() {
    const rect = stage.getBoundingClientRect();
    const travel = Math.max(1, rect.height - window.innerHeight);
    const progress = Math.min(1, Math.max(0, -rect.top / travel));
    setExplode(smooth(0.08, 0.75, progress));
  }
  let queued = false;
  window.addEventListener('scroll', () => {
    if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; update(); }); }
  }, { passive: true });
  window.addEventListener('resize', update);
  update();
}
