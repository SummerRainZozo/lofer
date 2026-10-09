// The Lofer tile in the hero, turning slowly. It follows the real design
// (56 × 53.5 × 6.2 mm, from the product renders):
//   1. a soft-touch silicone cover that wraps the top and sides, in cream
//   2. a stitched seam, with the logo and wordmark debossed into the top
//   3. a small status light, and 18 gold edge contacts around the side wall
//   4. a skin side: a matte, slightly raised hydrogel liner with two EMG electrodes, and the
//      heater film showing through it (you see it as the tile turns)
//   5. a slow ripple, like thick paper in a breeze, to show the tile is flexible
//
// How the look is built:
//   - a soft peach/lilac halo behind the tile (a gradient on a big backdrop)
//   - a gentle "studio" of light panels for the silicone to pick up
//   - the body: the Lofer outline, extruded thin with a rounded edge
//   - the seam, logo and wordmark: drawn once onto a canvas, then laid on the top face
//   - a touch of bloom, so the status light glows
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { TessellateModifier } from 'three/examples/jsm/modifiers/TessellateModifier.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { deviceOutline, deviceOutlineSvgPath } from './deviceShape.js';

// Same colours as the iOS app (Lofer/DesignSystem/Colors.swift).
const PEACH = 0xe4b598;
const LILAC = 0xb8b2c6;
const CREAM = 0xf3ebe2;    // also the page background
const CLAY = 0xcdbb9f;     // the cream (oat) colourway of the silicone cover
const GOLD = 0xd6ae6c;     // edge contacts

// 1 mm of the real tile = 0.0464 units (56 mm wide = 2.6 units).
const DEVICE_WIDTH = 2.6;
const DEPTH = 0.14;         // the flat part of the side wall
const BEVEL = 0.074;        // the soft rounded edge: DEPTH + 2 × BEVEL = 6.2 mm
const TOP_Z = DEPTH / 2 + BEVEL;

// ── Flexing ──
// The tile is flexible, so it ripples slowly, like thick paper in a breeze. The bend is
// worked out per vertex in the shader, from each point's position on the tile, so the
// cover, the artwork, the contacts and the skin side all bend together and stay lined up.
// (Every geometry below is built in the tile's own coordinates for this reason.)
const flexTime = { value: 0 };
const FLEX_GLSL = `
uniform float uFlex;
// Height of the bend at point p on the tile, and its slope (g).
float flexDz(vec2 p, out vec2 g) {
  vec2 d1 = vec2(0.912, 0.410);
  vec2 d2 = vec2(0.514, -0.858);
  float ph1 = 2.1 * dot(p, d1) - uFlex * 1.5;
  float ph2 = 3.4 * dot(p, d2) - uFlex * 2.3 + 1.3;
  float r = length(p);
  float edge = 1.0;                                      // the same bend at the edges as in the middle
  float dz = edge * (0.055 * sin(ph1) + 0.022 * sin(ph2));
  g = edge * (0.055 * 2.1 * cos(ph1) * d1 + 0.022 * 3.4 * cos(ph2) * d2);
  float bow = 0.045 * sin(uFlex * 0.6);                    // and the whole tile bows a little
  dz += bow * (r * r - 0.8) * 0.5;
  g += bow * p;
  return dz;
}
`;
/** Makes a material bend with the ripple. */
function makeFlexible(material) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uFlex = flexTime;
    shader.vertexShader = FLEX_GLSL + shader.vertexShader
      .replace('#include <beginnormal_vertex>', `#include <beginnormal_vertex>
        vec2 flexSlope;
        flexDz(position.xy, flexSlope);
        objectNormal = normalize(vec3(objectNormal.x - objectNormal.z * flexSlope.x, objectNormal.y - objectNormal.z * flexSlope.y, objectNormal.z + objectNormal.x * flexSlope.x + objectNormal.y * flexSlope.y));`)
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        vec2 flexSlope2;
        transformed.z += flexDz(position.xy, flexSlope2);`);
  };
  return material;
}

/** Cuts a geometry's triangles into small ones, so the ripple has points to bend. */
function tessellate(geometry, maxEdge = 0.07) {
  const flat = geometry.index ? geometry.toNonIndexed() : geometry;
  return new TessellateModifier(maxEdge, 12).modify(flat);
}

/** Fine random grain, used to make a surface look matte and slightly rough. */
function createGrainTexture(size = 256) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  const image = ctx.createImageData(size, size);
  for (let i = 0; i < size * size; i++) {
    const v = 128 + (Math.random() - 0.5) * 120;
    image.data[i * 4] = image.data[i * 4 + 1] = image.data[i * 4 + 2] = v;
    image.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  return texture;
}

/**
 * The heater film as it looks behind the gel: an amber polyimide sheet with a serpentine
 * copper trace and two gold pads. Returns the colour map and a mask of the metal parts
 * (used for how shiny, and how raised, the copper is).
 */
function createHeaterTextures(maxAnisotropy) {
  const W = 512, H = 768;
  const make = () => { const c = document.createElement('canvas'); c.width = W; c.height = H; return c; };
  const colour = make(), mask = make();
  const c = colour.getContext('2d'), m = mask.getContext('2d');

  // film
  const film = c.createLinearGradient(0, 0, W, H);
  film.addColorStop(0, '#dca05c'); film.addColorStop(0.55, '#cf8a47'); film.addColorStop(1, '#c47b3b');
  c.fillStyle = film; c.fillRect(0, 0, W, H);
  for (let i = 0; i < 9000; i++) {   // faint speckle in the film
    c.fillStyle = `rgba(${Math.random() < 0.5 ? '255,220,170' : '120,60,20'},${Math.random() * 0.06})`;
    c.fillRect(Math.random() * W, Math.random() * H, 2, 2);
  }
  m.fillStyle = '#000'; m.fillRect(0, 0, W, H);

  // the serpentine trace: horizontal runs joined by turns
  const left = 56, right = W - 56, top = 70, bottom = H - 150, runs = 11;
  const path = new Path2D();
  path.moveTo(left, top);
  for (let i = 0; i < runs; i++) {
    const y = top + ((bottom - top) * i) / (runs - 1);
    const next = top + ((bottom - top) * (i + 1)) / (runs - 1);
    const goingRight = i % 2 === 0;
    path.lineTo(goingRight ? right : left, y);
    if (i < runs - 1) path.lineTo(goingRight ? right : left, next);
  }
  // leads from the last run down to the two pads
  const endX = (runs - 1) % 2 === 0 ? right : left;
  path.lineTo(endX, H - 70);
  const strokeTrace = (ctx, style, width) => { ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.strokeStyle = style; ctx.lineWidth = width; ctx.stroke(path); };
  strokeTrace(c, 'rgba(70,32,10,0.55)', 24);    // shadow edge
  strokeTrace(c, '#b0652d', 20);                // copper
  strokeTrace(c, '#d8894a', 11);                // lighter centre
  strokeTrace(c, '#f0b27a', 3);                 // bright highlight
  strokeTrace(m, '#fff', 20);
  // the other lead, from the first run's start down the left edge to the second pad
  const lead = new Path2D(); lead.moveTo(left, top); lead.lineTo(left - 28 < 20 ? 28 : left - 28, top); lead.lineTo(28, H - 70);
  for (const [ctx, style, w] of [[c, 'rgba(70,32,10,0.55)', 24], [c, '#b0652d', 20], [c, '#d8894a', 11], [m, '#fff', 20]]) {
    ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.strokeStyle = style; ctx.lineWidth = w; ctx.stroke(lead);
  }
  // gold pads
  for (const x of [28, endX]) {
    const pad = [x - 26, H - 92, 52, 58];
    c.fillStyle = '#d9b35f'; c.fillRect(...pad);
    c.strokeStyle = '#f2d98f'; c.lineWidth = 2; c.strokeRect(pad[0] + 3, pad[1] + 3, pad[2] - 6, pad[3] - 6);
    m.fillStyle = '#fff'; m.fillRect(...pad);
  }
  // darker rim, like a cut film edge
  c.strokeStyle = 'rgba(120,60,20,0.5)'; c.lineWidth = 8; c.strokeRect(0, 0, W, H);

  const map = new THREE.CanvasTexture(colour);
  map.colorSpace = THREE.SRGBColorSpace;
  map.anisotropy = maxAnisotropy;
  const metal = new THREE.CanvasTexture(mask);
  metal.anisotropy = maxAnisotropy;
  return { map, metal };
}

/** The outline as 2D points, `scale` × the device width. */
function outlinePoints(scale = 1) {
  return deviceOutline({ size: DEVICE_WIDTH * scale, samplesPerSegment: 2 }).map(([x, y]) => new THREE.Vector2(x, y));
}

/** The body: the outline extruded thin, with a rounded edge like soft silicone. */
function createBodyGeometry() {
  const geometry = new THREE.ExtrudeGeometry(new THREE.Shape(outlinePoints()), {
    depth: DEPTH,
    bevelEnabled: true,
    bevelThickness: BEVEL,
    bevelSize: BEVEL,
    bevelSegments: 6,
    curveSegments: 12,
  });
  // Centre it front to back only. Keeping x and y as they are keeps the artwork
  // drawn on the top face lined up with the outline.
  geometry.translate(0, 0, -DEPTH / 2);
  geometry.computeVertexNormals();
  return tessellate(geometry, 0.07);   // many small triangles, so the cover can ripple smoothly
}

/** The backdrop: page-coloured, with a soft radial glow in the middle. */
function createHaloTexture() {
  const size = 1024;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#f3ebe2'; // the page's cream, so the edges blend into the page
  ctx.fillRect(0, 0, size, size);
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size * 0.14);
  gradient.addColorStop(0, 'rgba(224,138,108,0.95)');   // a deeper terracotta-peach, so the cream tile stands out
  gradient.addColorStop(0.4, 'rgba(226,160,134,0.62)');
  gradient.addColorStop(0.7, 'rgba(196,170,196,0.34)'); // lilac
  gradient.addColorStop(1, 'rgba(243,235,226,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/**
 * A small photo studio, used only as something to reflect: a warm, soft room with
 * a few wide light panels. Silicone is matte, so this just gives it gentle shading.
 */
function createStudioEnvironment(renderer) {
  const studio = new THREE.Scene();
  studio.background = new THREE.Color(0xb9aea3);
  const panel = (w, h, color, intensity, x, y, z) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), side: THREE.DoubleSide }));
    m.position.set(x, y, z);
    m.lookAt(0, 0, 0);
    studio.add(m);
  };
  panel(12, 4, 0xffffff, 2.2, 0, 6, 4);     // wide soft box above
  panel(3, 8, 0xffffff, 1.6, -7, 0, 3);     // strip on the left
  panel(3, 8, PEACH, 1.6, 7, 0, 2);         // warm strip on the right
  panel(8, 2, LILAC, 1.2, 0, -6, 3);        // cool strip below
  panel(8, 8, 0xffffff, 1.0, 0, 0, 8);      // soft fill in front
  panel(8, 8, 0xffffff, 1.0, 0, 0, -8);     // soft fill behind
  const pmrem = new THREE.PMREMGenerator(renderer);
  return pmrem.fromScene(studio, 0.04).texture;
}

/**
 * The top-face artwork: the stitched seam, the logo and the "Lofer" wordmark, drawn
 * once onto a transparent canvas. Each line is drawn twice (a pale copy just below a
 * darker one) so it reads as pressed into the silicone.
 */
function createTopArtwork(maxAnisotropy) {
  const SIZE = 2048;
  const PLANE = DEVICE_WIDTH * 1.2;                 // world size of the square the canvas covers
  const px = SIZE / PLANE;                           // canvas pixels per world unit
  const toCanvas = DEVICE_WIDTH / 100 * px;          // SVG outline units (100 wide) → canvas pixels
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = SIZE;
  const ctx = canvas.getContext('2d');

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = maxAnisotropy;

  // `unit` = canvas pixels per drawing unit in the current transform, so the offset is a few pixels either way.
  const deboss = (draw, unit = 1) => {
    // pale edge, then the darker groove on top
    ctx.save(); ctx.translate(2.5 / unit, 2.5 / unit); draw('rgba(255, 252, 244, 0.55)'); ctx.restore();
    draw('rgba(110, 90, 72, 0.4)');
  };

  function paint() {
    ctx.clearRect(0, 0, SIZE, SIZE);
    ctx.save();
    ctx.translate(SIZE / 2, SIZE / 2);

    // Stitched seam: dashes of pale thread along a smaller copy of the outline,
    // each with a soft shadow just below it.
    const seam = new Path2D(deviceOutlineSvgPath(100));
    const seamUnit = toCanvas * 0.84;
    ctx.save();
    ctx.scale(seamUnit, seamUnit);
    ctx.lineWidth = 1.3;            // in outline units, so ~1.3% of the tile width
    ctx.setLineDash([2.9, 2.1]);    // dash, gap
    ctx.lineCap = 'butt';
    ctx.save(); ctx.translate(3 / seamUnit, 3 / seamUnit);
    ctx.strokeStyle = 'rgba(90, 68, 50, 0.28)'; ctx.stroke(seam);
    ctx.restore();
    ctx.strokeStyle = 'rgba(158, 136, 118, 0.95)'; ctx.stroke(seam);
    ctx.restore();

    // Logo mark above the centre.
    ctx.save();
    ctx.translate(0, -0.22 * px);
    ctx.scale(toCanvas * 0.12, toCanvas * 0.12);   // the logo is about 12% of the tile width
    deboss((colour) => {
      ctx.strokeStyle = colour;
      ctx.lineWidth = 6;
      ctx.lineJoin = 'round';
      ctx.stroke(new Path2D(deviceOutlineSvgPath(100)));
    }, toCanvas * 0.12);
    ctx.restore();

    // Wordmark below it, in the brand font (Quicksand Light).
    const wordWidth = 0.9 * px;
    ctx.font = '300 200px Quicksand, Figtree, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    const fit = wordWidth / ctx.measureText('Lofer').width;
    ctx.font = `300 ${Math.round(200 * fit)}px Quicksand, Figtree, sans-serif`;
    deboss((colour) => {
      ctx.fillStyle = colour;
      ctx.fillText('Lofer', 0, 0.26 * px);
    });
    ctx.restore();
    texture.needsUpdate = true;
  }

  paint();
  // Redraw once the web font has arrived, so the wordmark isn't in a fallback face.
  if (document.fonts?.load) document.fonts.load('300 100px Quicksand').then(paint).catch(() => {});

  // Built in the tile's own coordinates (lifted onto the top face), with enough points to bend with it.
  const geometry = new THREE.PlaneGeometry(PLANE, PLANE, 90, 90);
  geometry.translate(0, 0, TOP_Z + 0.001);
  return new THREE.Mesh(
    geometry,
    makeFlexible(new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 })),
  );
}

/**
 * The skin side. From the outside in: two grey EMG electrodes, a matte hydrogel liner (a soft,
 * slightly translucent blue that stands a little proud of the tile), and, seen through the
 * liner, the heater film with its copper trace.
 */
function createSkinSide(maxAnisotropy) {
  const group = new THREE.Group();
  const GEL_DEPTH = 0.05;                              // how far the liner stands out of the tile
  const GEL_BEVEL = 0.012;
  const gelTop = -TOP_Z + 0.003;                       // the liner's inner face, just inside the tile
  const gelOuter = gelTop - GEL_DEPTH - 2 * GEL_BEVEL; // the face that touches skin

  // The heater film: a thin sheet sitting inside the liner, against the tile.
  const { map, metal } = createHeaterTextures(maxAnisotropy);
  const heaterGeometry = new THREE.BoxGeometry(0.93, 1.39, 0.014, 18, 28, 1);
  heaterGeometry.rotateZ(THREE.MathUtils.degToRad(-35));
  heaterGeometry.translate(0, 0, -TOP_Z - 0.012);
  const heater = new THREE.Mesh(heaterGeometry, makeFlexible(new THREE.MeshStandardMaterial({
    map, metalnessMap: metal, metalness: 1, roughness: 0.48, bumpMap: metal, bumpScale: 1.5, envMapIntensity: 1.8,
  })));
  group.add(heater);

  // The pale chassis seen behind the film (the cover only wraps the top and sides), so the
  // liner's blue isn't muddied by the terracotta.
  let chassisGeometry = new THREE.ShapeGeometry(new THREE.Shape(outlinePoints(0.93)));
  chassisGeometry.translate(0, 0, -TOP_Z - 0.002);
  chassisGeometry = tessellate(chassisGeometry, 0.09);
  group.add(new THREE.Mesh(chassisGeometry, makeFlexible(new THREE.MeshStandardMaterial({ color: 0xbdb5a8, roughness: 0.85, side: THREE.DoubleSide, envMapIntensity: 0.5 }))));

  // The hydrogel liner: a thick slab in the outline, matte, with a fine grain.
  const grain = createGrainTexture();
  let gelGeometry = new THREE.ExtrudeGeometry(new THREE.Shape(outlinePoints(0.93)), {
    depth: GEL_DEPTH, bevelEnabled: true, bevelThickness: GEL_BEVEL, bevelSize: GEL_BEVEL * 0.9, bevelSegments: 3, curveSegments: 12,
  });
  gelGeometry.translate(0, 0, gelTop - GEL_DEPTH - GEL_BEVEL);
  gelGeometry.computeVertexNormals();
  gelGeometry = tessellate(gelGeometry, 0.09);
  const gel = new THREE.Mesh(gelGeometry, makeFlexible(new THREE.MeshPhysicalMaterial({
    color: 0x6b97c4,            // a soft blue, toned down a little from before
    transparent: true,
    opacity: 0.6,               // see-through enough for the heater film behind it
    depthWrite: false,
    roughness: 0.72,            // matte
    roughnessMap: grain,
    bumpMap: grain,
    bumpScale: 2,               // the fine grain you can see in the light
    sheen: 0.15,
    sheenColor: new THREE.Color(0xb9d0e6),
    sheenRoughness: 0.8,
    envMapIntensity: 0.4,
  })));
  gel.renderOrder = 2;          // drawn after the things behind it
  group.add(gel);

  // The two EMG electrodes, set into the outer face of the liner.
  const electrodeMaterial = makeFlexible(new THREE.MeshStandardMaterial({ color: 0x8a9096, roughness: 0.4, metalness: 0.6, envMapIntensity: 1 }));
  for (const [x, y] of [[0.66, -0.46], [-0.66, 0.46]]) {
    const geometry = new THREE.CylinderGeometry(0.19, 0.19, 0.02, 40);
    geometry.rotateX(Math.PI / 2);                     // the disc's axis points along z
    geometry.translate(x, y, gelOuter - 0.004);
    group.add(new THREE.Mesh(geometry, electrodeMaterial));
  }
  return group;
}

/** 18 gold edge contacts, three on each of the six edges, set into the side wall (merged into one mesh). */
function createEdgeContacts() {
  const points = outlinePoints();
  const material = makeFlexible(new THREE.MeshStandardMaterial({ color: GOLD, metalness: 0.7, roughness: 0.35 }));
  const n = points.length;
  const geometries = [];
  for (let petal = 0; petal < 6; petal++) {
    for (let k = 0; k < 3; k++) {
      // Same angles as the build drawing (12°, 30°, 48° into each 60° petal); world y points up, so negate.
      const angle = -THREE.MathUtils.degToRad(petal * 60 + 12 + k * 18);
      let best = 0, bestDiff = Infinity;
      points.forEach((p, i) => {
        const d = Math.abs(Math.atan2(Math.sin(p.angle() - angle), Math.cos(p.angle() - angle)));
        if (d < bestDiff) { bestDiff = d; best = i; }
      });
      const p = points[best];
      const tangent = points[(best + 1) % n].clone().sub(points[(best - 1 + n) % n]).normalize();
      let normal = new THREE.Vector2(tangent.y, -tangent.x);
      if (normal.dot(p) < 0) normal = normal.negate();
      const dot = new THREE.CircleGeometry(0.036, 16);
      // Turn the disc to face outward, and move it onto the wall (so every mesh stays in tile coordinates).
      dot.applyMatrix4(new THREE.Matrix4().compose(
        new THREE.Vector3(p.x + normal.x * (BEVEL + 0.002), p.y + normal.y * (BEVEL + 0.002), 0),
        new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), new THREE.Vector3(normal.x, normal.y, 0)),
        new THREE.Vector3(1, 1, 1),
      ));
      geometries.push(dot);
    }
  }
  return new THREE.Mesh(mergeGeometries(geometries), material);
}

/**
 * Starts the 3D tile inside `container`.
 * Returns false if WebGL isn't available, so the page can show the fallback.
 */
export function mountDevice(container, { reducedMotion = false } = {}) {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  } catch {
    return false;
  }

  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  // No tone mapping: it would dim the cream backdrop so it no longer matched the page.
  renderer.toneMapping = THREE.NoToneMapping;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(CREAM);
  scene.environment = createStudioEnvironment(renderer);

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0, 9);

  // Halo behind the tile. Big enough to fill the whole view.
  const halo = new THREE.Mesh(
    new THREE.PlaneGeometry(50, 50),
    new THREE.MeshBasicMaterial({ map: createHaloTexture(), toneMapped: false }),
  );
  halo.position.z = -2.5;
  scene.add(halo);

  // Everything that moves together lives in this group.
  const device = new THREE.Group();
  scene.add(device);

  // The silicone body: matte, with the soft sheen that fabric-like silicone has.
  device.add(new THREE.Mesh(
    createBodyGeometry(),
    makeFlexible(new THREE.MeshPhysicalMaterial({
      color: CLAY,
      roughness: 0.6,
      metalness: 0,
      sheen: 0.5,
      sheenColor: new THREE.Color(0xf0e2cc),
      sheenRoughness: 0.45,
      clearcoat: 0.12,
      clearcoatRoughness: 0.5,
      envMapIntensity: 0.5,
    })),
  ));

  device.add(createTopArtwork(renderer.capabilities.getMaxAnisotropy()));
  device.add(createSkinSide(renderer.capabilities.getMaxAnisotropy()));
  device.add(createEdgeContacts());

  // The status light, at the lower left of the top face (as on the real tile).
  const ledMaterial = makeFlexible(new THREE.MeshBasicMaterial({ color: new THREE.Color(0xffc98e).multiplyScalar(2), toneMapped: false }));
  const ledGeometry = new THREE.CircleGeometry(0.028, 20);
  ledGeometry.translate(-0.55, -0.46, TOP_Z + 0.003);
  device.add(new THREE.Mesh(ledGeometry, ledMaterial));

  // Soft key light from the upper left, and a warm fill from the right.
  const keyLight = new THREE.DirectionalLight(0xfff1e4, 1.5);
  keyLight.position.set(-3, 4, 5);
  scene.add(keyLight);
  const warmFill = new THREE.DirectionalLight(PEACH, 0.8);
  warmFill.position.set(5, -1, 3);
  scene.add(warmFill);
  scene.add(new THREE.HemisphereLight(0xffffff, 0xd8c3b2, 0.3));

  // Bloom. A high threshold so only the brightest bits (the status light) glow;
  // a low one would make the whole cream page bloom.
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.35, 0.5, 0.92);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  // Keep the canvas the size of its container, and the tile comfortably inside it.
  function resize() {
    const { clientWidth: width, clientHeight: height } = container;
    renderer.setSize(width, height);
    composer.setSize(width, height);
    camera.aspect = width / height;
    // Distance that fits the tile (plus margin) in both directions.
    const fit = (DEVICE_WIDTH * 1.45) / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)));
    camera.position.z = Math.max(fit, fit / camera.aspect);
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(container);
  resize();

  // The tile leans towards the pointer a little (like Oura's product shots).
  const pointer = { x: 0, y: 0 };
  window.addEventListener('pointermove', (event) => {
    pointer.x = (event.clientX / window.innerWidth) * 2 - 1;
    pointer.y = (event.clientY / window.innerHeight) * 2 - 1;
  });

  const baseTiltX = -0.62;   // tipped back, so the top face is mostly visible
  const startTurn = 0.3;
  const secondsPerTurn = 26;

  function renderFrame(timeMs) {
    const t = timeMs / 1000;
    flexTime.value = reducedMotion ? 1.0 : t;            // reduced motion: a still, gently rippled tile
    if (!reducedMotion) {
      device.rotation.y = startTurn + (t / secondsPerTurn) * Math.PI * 2 + pointer.x * 0.25;
      const targetX = baseTiltX + Math.sin(t * 0.4) * 0.06 + pointer.y * 0.15;
      device.rotation.x += (targetX - device.rotation.x) * 0.05;
      device.position.y = Math.sin(t * 0.8) * 0.05;
      const breath = 0.5 + 0.5 * Math.sin(t * 1.4);       // the status light "breathes"
      ledMaterial.color.set(0xffc98e).multiplyScalar(1.3 + breath * 1.1);
    }
    composer.render();
  }

  device.rotation.set(baseTiltX, startTurn, 0);

  if (reducedMotion) {
    // One still frame; redraw only when the size changes.
    renderFrame(0);
    new ResizeObserver(() => renderFrame(0)).observe(container);
    return true;
  }

  // Only animate while the hero is on screen, to save battery.
  let visible = true;
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(container);
  renderer.setAnimationLoop((timeMs) => { if (visible) renderFrame(timeMs); });
  return true;
}
