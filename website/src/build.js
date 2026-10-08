// "Inside Lofer": the exploded view of one tile. The picture is the real product render
// (public/renders/exploded.webp), with a numbered marker on each of its seven layers.
// As you scroll through the section, one layer at a time lights up: its number on the
// picture and its label beside it. Click or tap a label to jump to that layer.
//
// The markup (index.html) holds the picture, the markers and the labels in the same order,
// so marker 3 and label 3 are the same layer.
const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

export function startBuild({ reducedMotion = false } = {}) {
  const stage = document.querySelector('[data-build]');
  if (!stage) return;
  const labels = [...stage.querySelectorAll('[data-build-label]')];
  const markers = [...stage.querySelectorAll('[data-build-marker]')];

  /** Light up layer `index` (or none, with -1). */
  function setActive(index) {
    labels.forEach((label, i) => label.classList.toggle('is-active', i === index));
    markers.forEach((marker, i) => marker.classList.toggle('is-active', i === index));
  }

  if (reducedMotion) {
    // No scrolling stage: show every layer as active.
    stage.classList.add('build__stage--static');
    labels.forEach((label) => label.classList.add('is-active'));
    markers.forEach((marker) => marker.classList.add('is-active'));
    return;
  }

  // Progress through the tall stage → which layer is lit.
  function update() {
    const rect = stage.getBoundingClientRect();
    const travel = Math.max(1, rect.height - window.innerHeight);
    const progress = Math.min(1, Math.max(0, -rect.top / travel));
    const position = smooth(0.04, 0.96, progress) * (labels.length - 1);
    setActive(Math.round(position));
  }
  let queued = false;
  window.addEventListener('scroll', () => {
    if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; update(); }); }
  }, { passive: true });
  window.addEventListener('resize', update);

  // Clicking a label lights that layer until the next scroll.
  labels.forEach((label, i) => label.addEventListener('click', () => setActive(i)));
  update();
}
