// The outline of the Lofer device (and logo), seen from above.
//
// This is the ONE place the website defines the shape. The 3D model
// (device3d.js), the logo (logo.js) and the no-3D fallback are all built from
// it. The iOS app has the same numbers in Lofer/Components/LoferMark.swift, so
// if the shape ever changes, update both.
//
// How it's described: the shape is one "petal" repeated six times around the
// centre (it has six-fold symmetry). PETAL lists the distance from the centre
// to the edge every 3°, across one 60° petal. The values were measured from
// the official icon artwork, in units where the whole shape is 1 wide.
const PETAL = [
  0.4911, 0.4640, 0.4351, 0.4180, 0.4090, 0.4034, 0.4029, 0.4065, 0.4122, 0.4213,
  0.4333, 0.4464, 0.4609, 0.4751, 0.4860, 0.4942, 0.4996, 0.5005, 0.5008, 0.5016,
];
const PETALS = 6;
const STEP_DEGREES = 60 / PETAL.length; // 3°

/** The raw edge points, going clockwise on screen (y pointing down). */
function rawOutline() {
  const points = [];
  for (let i = 0; i < PETAL.length * PETALS; i++) {
    const angle = (i * STEP_DEGREES * Math.PI) / 180;
    const radius = PETAL[i % PETAL.length];
    points.push([Math.cos(angle) * radius, Math.sin(angle) * radius]);
  }
  return points;
}

// Catmull-Rom spline: a smooth curve that passes through every point.
// Returns `samplesPerSegment` points between each pair of outline points.
function smoothClosedCurve(points, samplesPerSegment) {
  const result = [];
  const n = points.length;
  for (let i = 0; i < n; i++) {
    const p0 = points[(i - 1 + n) % n];
    const p1 = points[i];
    const p2 = points[(i + 1) % n];
    const p3 = points[(i + 2) % n];
    for (let s = 0; s < samplesPerSegment; s++) {
      const t = s / samplesPerSegment;
      const t2 = t * t;
      const t3 = t2 * t;
      const coord = (a, b, c, d) =>
        0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
      result.push([coord(p0[0], p1[0], p2[0], p3[0]), coord(p0[1], p1[1], p2[1], p3[1])]);
    }
  }
  return result;
}

/**
 * The smooth outline, centred on (0, 0) and scaled so it is `size` units wide.
 * `flipY` is true for 3D (y points up) and false for SVG (y points down);
 * flipping keeps the shape looking the same way round in both.
 */
export function deviceOutline({ size = 1, flipY = true, samplesPerSegment = 2 } = {}) {
  return smoothClosedCurve(rawOutline(), samplesPerSegment).map(([x, y]) => [
    x * size,
    (flipY ? -1 : 1) * y * size,
  ]);
}

/** The outline as an SVG path string, centred on (0, 0) and `size` wide. */
export function deviceOutlineSvgPath(size = 100) {
  const points = deviceOutline({ size, flipY: false });
  return 'M' + points.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join('L') + 'Z';
}
