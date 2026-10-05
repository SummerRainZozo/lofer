// Entry point for the landing page: wires up the 3D device, the logo,
// the care-loop diagram, the exploded build view and scroll reveals.
import './styles.css';
import { deviceOutlineSvgPath } from './deviceShape.js';
import { logoMarkSvg } from './logo.js';
import { startLoop } from './loop.js';
import { startBuild } from './build.js';

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/** A flat SVG of the device outline (used when 3D isn't available). */
function deviceSvg(className) {
  const path = deviceOutlineSvgPath(100);
  return `<svg class="${className}" viewBox="-55 -55 110 110" aria-hidden="true"><path d="${path}"/></svg>`;
}

// ── The hero device ──
// three.js is large (~150 KB zipped), so it's loaded separately: the words
// appear straight away and the device fades in once the 3D code arrives.
const stage = document.querySelector('[data-device-stage]');
function showFallback() {
  // No WebGL (old browser, or it's switched off): show a glowing flat outline instead.
  stage.classList.add('hero__stage--fallback');
  stage.innerHTML = deviceSvg('hero__fallback');
}
import('./device3d.js')
  .then(({ mountDevice }) => {
    if (mountDevice(stage, { reducedMotion })) stage.classList.add('is-ready');
    else showFallback();
  })
  .catch(showFallback);

// ── Logo marks (in the nav and on the Lofer card) ──
document.querySelectorAll('[data-logo-mark]').forEach((slot) => {
  slot.innerHTML = logoMarkSvg('logo-mark');
});

// ── The closed-loop diagram ──
startLoop({ reducedMotion });

// ── Inside Lofer: the exploded view ──
startBuild({ reducedMotion });

// ── Fade sections in as they scroll into view ──
const revealItems = document.querySelectorAll('.reveal');
if (reducedMotion) {
  revealItems.forEach((item) => item.classList.add('is-visible'));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target); // only animate once
        }
      }
    },
    { threshold: 0.2 },
  );
  revealItems.forEach((item) => observer.observe(item));
}

// ── Waitlist ──
// Sign-up isn't connected to a service yet, so the page shows a disabled
// "Waitlist opening soon" button (in index.html) and collects nothing. Only show
// a success message once an email has actually been saved.

document.querySelector('[data-year]').textContent = new Date().getFullYear();
