/* Lofer body geometry: a signed-distance body, a surface-nets mesher and the
   region classifier. Plain function declarations so they can be shipped into
   a Web Worker with Function.prototype.toString. Units are metres, y up,
   +z faces the viewer, +x is the figure's LEFT side. */

function sdRoundCone(px, py, pz, ax, ay, az, bx, by, bz, r1, r2) {
  const bax = bx - ax, bay = by - ay, baz = bz - az;
  const l2 = bax * bax + bay * bay + baz * baz, rr = r1 - r2, a2 = l2 - rr * rr, il2 = 1 / l2;
  const pax = px - ax, pay = py - ay, paz = pz - az;
  const y = pax * bax + pay * bay + paz * baz, z = y - l2;
  const qx = pax * l2 - bax * y, qy = pay * l2 - bay * y, qz = paz * l2 - baz * y;
  const x2 = qx * qx + qy * qy + qz * qz, y2 = y * y * l2, z2 = z * z * l2;
  const k = Math.sign(rr) * rr * rr * x2;
  if (Math.sign(z) * a2 * z2 > k) return Math.sqrt(x2 + z2) * il2 - r2;
  if (Math.sign(y) * a2 * y2 < k) return Math.sqrt(x2 + y2) * il2 - r1;
  return (Math.sqrt(x2 * a2 * il2) + y * rr) * il2 - r1;
}

function sdEll(px, py, pz, cx, cy, cz, rx, ry, rz) {
  const x = px - cx, y = py - cy, z = pz - cz;
  const k0 = Math.sqrt((x / rx) ** 2 + (y / ry) ** 2 + (z / rz) ** 2);
  const k1 = Math.sqrt((x / (rx * rx)) ** 2 + (y / (ry * ry)) ** 2 + (z / (rz * rz)) ** 2);
  return k1 < 1e-9 ? -Math.min(rx, ry, rz) : k0 * (k0 - 1) / k1;
}

function primDist(p, x, y, z) {
  return p.t === 0
    ? sdRoundCone(x, y, z, p.a[0], p.a[1], p.a[2], p.b[0], p.b[1], p.b[2], p.r1, p.r2)
    : sdEll(x, y, z, p.c[0], p.c[1], p.c[2], p.r[0], p.r[1], p.r[2]);
}

function sdf(P, x, y, z) {
  let d = primDist(P[0], x, y, z);
  for (let i = 1; i < P.length; i++) {
    const di = primDist(P[i], x, y, z), k = P[i].k;
    const h = Math.max(k - Math.abs(d - di), 0) / k;
    d = Math.min(d, di) - h * h * k * 0.25;
  }
  return d;
}

function grad(P, x, y, z) {
  const e = 0.002;
  const gx = sdf(P, x + e, y, z) - sdf(P, x - e, y, z);
  const gy = sdf(P, x, y + e, z) - sdf(P, x, y - e, z);
  const gz = sdf(P, x, y, z + e) - sdf(P, x, y, z - e);
  const l = Math.hypot(gx, gy, gz) || 1;
  return [gx / l, gy / l, gz / l];
}

function makePrims() {
  const P = [];
  const E = (c, r, part, k, side) => P.push({ t: 1, c, r, part, k, side: side || null });
  const C = (a, b, r1, r2, part, k, side) => P.push({ t: 0, a, b, r1, r2, part, k, side: side || null });
  E([0, 0.965, -0.005], [0.15, 0.105, 0.098], 'hips', 0.05);
  E([0, 1.10, 0], [0.125, 0.13, 0.085], 'torso', 0.07);
  E([0, 1.27, -0.008], [0.15, 0.13, 0.097], 'torso', 0.07);
  E([0, 1.375, -0.012], [0.16, 0.055, 0.078], 'torso', 0.05);
  C([0, 1.41, -0.012], [0, 1.55, 0], 0.056, 0.048, 'neck', 0.045);
  E([0, 1.645, 0.005], [0.077, 0.103, 0.09], 'head', 0.035);
  E([0, 1.588, 0.028], [0.058, 0.048, 0.058], 'head', 0.03);
  for (const s of ['l', 'r']) {
    const x = s === 'l' ? 1 : -1;
    E([x * 0.072, 1.29, 0.05], [0.074, 0.056, 0.045], 'torso', 0.04);
    C([x * 0.035, 1.46, -0.02], [x * 0.15, 1.405, -0.02], 0.042, 0.036, 'torso', 0.05);
    E([x * 0.08, 0.93, -0.05], [0.09, 0.095, 0.075], 'hips', 0.045, s);
    E([x * 0.185, 1.37, 0], [0.056, 0.062, 0.058], 'shoulder', 0.04, s);
    C([x * 0.195, 1.335, 0], [x * 0.265, 1.08, -0.005], 0.047, 0.036, 'uarm', 0.03, s);
    E([x * 0.222, 1.22, 0.022], [0.033, 0.07, 0.03], 'uarm', 0.03, s);        // biceps
    E([x * 0.228, 1.23, -0.024], [0.034, 0.08, 0.03], 'uarm', 0.03, s);       // triceps
    C([x * 0.265, 1.08, -0.005], [x * 0.31, 0.85, 0.02], 0.037, 0.025, 'farm', 0.025, s);
    E([x * 0.262, 1.005, 0.0], [0.034, 0.07, 0.035], 'farm', 0.03, s);        // forearm muscle belly
    E([x * 0.266, 1.078, -0.034], [0.017, 0.02, 0.014], 'elbow', 0.015, s);   // point of the elbow
    // Hand: arms hang with palms facing the thighs, thumbs forward.
    E([x * 0.32, 0.785, 0.027], [0.019, 0.047, 0.04], 'palm', 0.026, s);
    E([x * 0.317, 0.716, 0.031], [0.015, 0.045, 0.033], 'fingers', 0.012, s);
    C([x * 0.311, 0.808, 0.06], [x * 0.306, 0.752, 0.082], 0.012, 0.0095, 'thumb', 0.012, s);
    C([x * 0.088, 0.93, 0], [x * 0.1, 0.53, 0.005], 0.087, 0.052, 'thigh', 0.05, s);
    E([x * 0.1, 0.5, 0.012], [0.05, 0.056, 0.052], 'knee', 0.03, s);
    C([x * 0.1, 0.49, 0], [x * 0.105, 0.085, -0.018], 0.05, 0.032, 'lleg', 0.03, s);
    E([x * 0.103, 0.355, -0.03], [0.047, 0.1, 0.05], 'lleg', 0.035, s);
    E([x * 0.108, 0.035, 0.045], [0.042, 0.035, 0.115], 'foot', 0.025, s);
  }
  return P;
}

/* Which named area does a surface point (with normal) belong to? */
function classify(P, x, y, z, nx, ny, nz) {
  const WRIST = { outer: '_wr_dorsal', inner: '_wr_palm', front: '_wr_radial', back: '_wr_ulnar' };  // kept inside: this function also runs in the worker
  let bi = 0, bd = 1e9;
  for (let i = 0; i < P.length; i++) { const d = primDist(P[i], x, y, z); if (d < bd) { bd = d; bi = i; } }
  const p = P[bi], part = p.part;
  const s = p.side || (x >= 0 ? 'l' : 'r');
  const out = nx * (s === 'l' ? 1 : -1);
  const facet = Math.abs(nz) >= Math.abs(out) ? (nz > 0 ? 'front' : 'back') : (out > 0 ? 'outer' : 'inner');
  let t = 0.5;
  if (p.t === 0) {
    const bx = p.b[0] - p.a[0], by = p.b[1] - p.a[1], bz = p.b[2] - p.a[2];
    t = ((x - p.a[0]) * bx + (y - p.a[1]) * by + (z - p.a[2]) * bz) / (bx * bx + by * by + bz * bz);
    t = Math.max(0, Math.min(1, t));
  }
  switch (part) {
    case 'head': return nz > 0.05 ? 'face' : 'backhead';
    case 'neck': return nz > 0.45 ? 'neck_f' : nz < -0.3 ? 'neck_b' : s + '_neckside';
    case 'torso':
      if (y > 1.37 && (ny > 0.45 || nz < -0.1)) return s + '_trap';
      if (nz > 0.3) return y > 1.19 ? s + '_chest' : y > 1.07 ? 'upper_abs' : 'lower_abs';
      if (nz < -0.3) return y > 1.17 ? (Math.abs(x) < 0.035 ? 'mid_back' : s + '_scap') : s + '_lowback';
      return y > 1.18 ? s + '_lat' : s + '_oblique';
    case 'hips':
      if (nz > 0.3) return s + '_hipflex';
      if (nz < -0.2) return s + '_glute';
      return Math.abs(x) > 0.1 ? s + '_hipout' : (nz > 0 ? s + '_hipflex' : s + '_glute');
    case 'shoulder':
      if (ny > 0.6) return s + '_sh_top';
      return s + '_sh_' + (facet === 'inner' ? (nz >= 0 ? 'front' : 'back') : facet);
    case 'uarm': return t > 0.86 ? s + '_el_' + facet : s + '_ua_' + facet;
    case 'elbow': return s + '_el_back';
    case 'farm':
      if (t < 0.1) return s + '_el_' + facet;
      if (t > 0.86) return s + WRIST[facet];
      if (t > 0.72) return s + '_wr_distal';
      return s + '_fa_' + facet;
    // With palms facing in: inner = palm side, outer = back of hand, front = thumb side, back = little-finger side.
    case 'palm':
      if (y > 0.82) return s + WRIST[facet];
      return s + { inner: '_palm', outer: '_backhand', front: '_thumb', back: '_hand_edge' }[facet];
    case 'fingers': return s + '_fingers';
    case 'thumb': return s + '_thumb';
    case 'thigh': return t > 0.9 ? s + '_kn_' + facet : s + '_th_' + facet;
    case 'knee': return s + '_kn_' + facet;
    case 'lleg':
      if (y > 0.46) return s + '_kn_' + facet;
      if (y < 0.1) return s + '_ankle';
      if (facet === 'back' && y < 0.2) return s + '_achilles';
      return s + { front: '_shin', back: '_calf', outer: '_lc_outer', inner: '_lc_inner' }[facet];
    case 'foot':
      if (z < -0.02) return s + '_heel';
      if (ny < -0.4) return s + '_sole';
      if (y > 0.065 && z < 0.03) return s + '_ankle';
      return s + '_foottop';
  }
  return 'face';
}

/* Naive surface nets over a regular grid. B = [x0,y0,z0,x1,y1,z1]. */
function buildMesh(P, B, h, LI) {
  const nx = Math.ceil((B[3] - B[0]) / h), ny = Math.ceil((B[4] - B[1]) / h), nz = Math.ceil((B[5] - B[2]) / h);
  const sx = nx + 1, sy = ny + 1, sz = nz + 1;
  const F = new Float32Array(sx * sy * sz);
  for (let k = 0; k < sz; k++) {
    const z = B[2] + k * h;
    for (let j = 0; j < sy; j++) {
      const y = B[1] + j * h;
      for (let i = 0; i < sx; i++) F[i + sx * (j + sy * k)] = sdf(P, B[0] + i * h, y, z);
    }
  }
  const g = (i, j, k) => i + sx * (j + sy * k);
  const C = new Int32Array(nx * ny * nz).fill(-1);
  const pos = [];
  const cx = [0, 1, 0, 1, 0, 1, 0, 1], cy = [0, 0, 1, 1, 0, 0, 1, 1], cz = [0, 0, 0, 0, 1, 1, 1, 1];
  const E = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]];
  const v = new Float32Array(8);
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    let mask = 0;
    for (let c = 0; c < 8; c++) { v[c] = F[g(i + cx[c], j + cy[c], k + cz[c])]; if (v[c] < 0) mask |= 1 << c; }
    if (mask === 0 || mask === 255) continue;
    let ax = 0, ay = 0, az = 0, n = 0;
    for (const [a, b] of E) {
      if ((v[a] < 0) !== (v[b] < 0)) {
        const t = v[a] / (v[a] - v[b]);
        ax += cx[a] + (cx[b] - cx[a]) * t; ay += cy[a] + (cy[b] - cy[a]) * t; az += cz[a] + (cz[b] - cz[a]) * t; n++;
      }
    }
    C[i + nx * (j + ny * k)] = pos.length / 3;
    pos.push(B[0] + (i + ax / n) * h, B[1] + (j + ay / n) * h, B[2] + (k + az / n) * h);
  }
  const cell = (i, j, k) => C[i + nx * (j + ny * k)];
  const idx = [];
  const quad = (a, b, c, d, flip) => {
    if (a < 0 || b < 0 || c < 0 || d < 0) return;
    if (flip) idx.push(a, d, c, a, c, b); else idx.push(a, b, c, a, c, d);
  };
  for (let k = 1; k < nz; k++) for (let j = 1; j < ny; j++) for (let i = 0; i < nx; i++) {
    const a = F[g(i, j, k)], b = F[g(i + 1, j, k)];
    if ((a < 0) !== (b < 0)) quad(cell(i, j - 1, k - 1), cell(i, j, k - 1), cell(i, j, k), cell(i, j - 1, k), a < 0);
  }
  for (let k = 1; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 1; i < nx; i++) {
    const a = F[g(i, j, k)], b = F[g(i, j + 1, k)];
    if ((a < 0) !== (b < 0)) quad(cell(i - 1, j, k - 1), cell(i - 1, j, k), cell(i, j, k), cell(i, j, k - 1), a < 0);
  }
  for (let k = 0; k < nz; k++) for (let j = 1; j < ny; j++) for (let i = 1; i < nx; i++) {
    const a = F[g(i, j, k)], b = F[g(i, j, k + 1)];
    if ((a < 0) !== (b < 0)) quad(cell(i - 1, j - 1, k), cell(i, j - 1, k), cell(i, j, k), cell(i - 1, j, k), a < 0);
  }
  const V = pos.length / 3, nor = new Float32Array(V * 3), reg = new Float32Array(V);
  for (let i = 0; i < V; i++) {
    const x = pos[i * 3], y = pos[i * 3 + 1], z = pos[i * 3 + 2];
    const n = grad(P, x, y, z);
    nor[i * 3] = n[0]; nor[i * 3 + 1] = n[1]; nor[i * 3 + 2] = n[2];
    const id = classify(P, x, y, z, n[0], n[1], n[2]);
    reg[i] = id in LI ? LI[id] : 0;
  }
  // Make every triangle wind outward (agree with the surface normal), so the
  // renderer can draw front faces only. Mixed winding is what made the
  // translucent skin shimmer.
  for (let t = 0; t < idx.length; t += 3) {
    const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
    const ux = pos[b] - pos[a], uy = pos[b + 1] - pos[a + 1], uz = pos[b + 2] - pos[a + 2];
    const vx = pos[c] - pos[a], vy = pos[c + 1] - pos[a + 1], vz = pos[c + 2] - pos[a + 2];
    const fx = uy * vz - uz * vy, fy = uz * vx - ux * vz, fz = ux * vy - uy * vx;
    const nx = nor[a] + nor[b] + nor[c], ny = nor[a + 1] + nor[b + 1] + nor[c + 1], nz = nor[a + 2] + nor[b + 2] + nor[c + 2];
    if (fx * nx + fy * ny + fz * nz < 0) { const tmp = idx[t + 1]; idx[t + 1] = idx[t + 2]; idx[t + 2] = tmp; }
  }
  return { pos: new Float32Array(pos), nor, reg, idx: new Uint32Array(idx) };
}

const LOFER_GEO_FNS = [sdRoundCone, sdEll, primDist, sdf, grad, classify, buildMesh];
if (typeof module !== 'undefined') module.exports = { makePrims, buildMesh, classify, sdf, grad };
