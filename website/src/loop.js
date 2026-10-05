// Animates "The care loop" diagram: a glowing dot travels around the circle,
// and as it reaches each stage (Listen → Consider → Check → Act → Reassess →
// Learn) that stage lights up in the diagram AND in the list beside it. Then it
// starts again: it's a connected loop. The number of stages comes from the
// diagram itself, so adding or removing a node in index.html just works.

const SECONDS_PER_STAGE = 2.5;

export function startLoop({ reducedMotion = false } = {}) {
  const svg = document.querySelector('[data-loop-diagram]');
  if (!svg) return;
  const path = svg.querySelector('[data-loop-path]');
  const dot = svg.querySelector('[data-loop-dot]');
  const nodes = [...svg.querySelectorAll('[data-loop-node]')];
  const stages = [...document.querySelectorAll('[data-loop-stage]')];
  const pathLength = path.getTotalLength();
  const stageCount = nodes.length;
  const loopDurationMs = stageCount * SECONDS_PER_STAGE * 1000; // one full lap

  function setActive(index) {
    nodes.forEach((node, i) => node.classList.toggle('is-active', i === index));
    stages.forEach((stage, i) => stage.classList.toggle('is-active', i === index));
  }

  if (reducedMotion) {
    // No movement: park the dot on "Listen" and show every stage as lit.
    dot.setAttribute('transform', 'translate(300 100)');
    nodes.forEach((node) => node.classList.add('is-active'));
    stages.forEach((stage) => stage.classList.add('is-active'));
    return;
  }

  // Only animate while the diagram is on screen.
  let visible = false;
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(svg);

  function frame(timeMs) {
    if (visible) {
      const progress = (timeMs % loopDurationMs) / loopDurationMs; // 0 → 1 around the circle
      const point = path.getPointAtLength(progress * pathLength);
      dot.setAttribute('transform', `translate(${point.x} ${point.y})`);
      // A stage stays lit from when the dot arrives until just before the next one.
      const stageProgress = progress * stageCount;
      const index = Math.floor(stageProgress);
      setActive(stageProgress - index < 0.8 ? index : -1);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}
