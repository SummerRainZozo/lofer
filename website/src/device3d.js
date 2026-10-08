// The Lofer tile in the hero, turning slowly. It follows the real design
// (56 × 53.5 × 6.2 mm, from the product renders):
//   1. a soft-touch silicone cover that wraps the top and sides, in clay
//   2. a stitched seam, with the logo and wordmark debossed into the top
//   3. a small status light, and 18 gold edge contacts around the side wall
//   4. a skin side: a hydrogel liner with two EMG electrodes (you see it as the tile turns)
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
import { deviceOutline, deviceOutlineSvgPath } from './deviceShape.js';

// Same colours as the iOS app (Lofer/DesignSystem/Colors.swift).
const PEACH = 0xe4b598;
const LILAC = 0xb8b2c6;
const CREAM = 0xf3ebe2;    // also the page background
const CLAY = 0xa95a42;     // the terracotta colourway of the silicone cover
const GOLD = 0xd6ae6c;     // edge contacts

// 1 mm of the real tile = 0.0464 units (56 mm wide = 2.6 units).
const DEVICE_WIDTH = 2.6;
const DEPTH = 0.14;         // the flat part of the side wall
const BEVEL = 0.074;        // the soft rounded edge: DEPTH + 2 × BEVEL = 6.2 mm
const TOP_Z = DEPTH / 2 + BEVEL;

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
  return geometry;
}

/** The backdrop: page-coloured, with a soft radial glow in the middle. */
function createHaloTexture() {
  const size = 1024;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#f3ebe2'; // the page's cream, so the edges blend into the page
  ctx.fillRect(0, 0, size, size);
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size * 0.11);
  gradient.addColorStop(0, 'rgba(238,186,154,0.75)');   // peach
  gradient.addColorStop(0.4, 'rgba(232,196,180,0.42)');
  gradient.addColorStop(0.7, 'rgba(190,178,204,0.22)'); // lilac
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
    ctx.save(); ctx.translate(2.5 / unit, 2.5 / unit); draw('rgba(255, 226, 214, 0.38)'); ctx.restore();
    draw('rgba(96, 44, 32, 0.42)');
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
    ctx.strokeStyle = 'rgba(70, 25, 15, 0.35)'; ctx.stroke(seam);
    ctx.restore();
    ctx.strokeStyle = 'rgba(222, 186, 174, 0.9)'; ctx.stroke(seam);
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

  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(PLANE, PLANE),
    new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }),
  );
  plane.position.z = TOP_Z + 0.001;
  return plane;
}

/** The skin side: a hydrogel liner (a soft translucent blue) with two grey EMG electrodes. Drawn on the bottom face. */
function createSkinSide() {
  const group = new THREE.Group();
  const z = -TOP_Z - 0.002;
  const offset = { polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 };

  const liner = new THREE.Mesh(
    new THREE.ShapeGeometry(new THREE.Shape(outlinePoints(0.93))),
    new THREE.MeshPhysicalMaterial({ color: 0x8fb2d4, roughness: 0.22, clearcoat: 0.6, clearcoatRoughness: 0.3, side: THREE.DoubleSide, ...offset }),
  );
  liner.position.z = z;
  group.add(liner);

  // The heater film sits behind the liner: a faint warm rectangle showing through.
  const heater = new THREE.Mesh(
    new THREE.PlaneGeometry(0.93, 1.39),
    new THREE.MeshBasicMaterial({ color: 0xd98c58, transparent: true, opacity: 0.22, side: THREE.DoubleSide, ...offset }),
  );
  heater.position.z = z - 0.001;
  heater.rotation.z = THREE.MathUtils.degToRad(-35);
  group.add(heater);

  const electrodeMaterial = new THREE.MeshStandardMaterial({ color: 0x7d8590, roughness: 0.5, metalness: 0.2, side: THREE.DoubleSide, ...offset });
  for (const [x, y] of [[0.66, -0.46], [-0.66, 0.46]]) {
    const electrode = new THREE.Mesh(new THREE.CircleGeometry(0.19, 40), electrodeMaterial);
    electrode.position.set(x, y, z - 0.002);
    group.add(electrode);
  }
  return group;
}

/** 18 gold edge contacts, three on each of the six edges, set into the side wall. */
function createEdgeContacts() {
  const group = new THREE.Group();
  const points = outlinePoints();
  const material = new THREE.MeshStandardMaterial({ color: GOLD, metalness: 0.7, roughness: 0.35 });
  const n = points.length;
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
      const dot = new THREE.Mesh(new THREE.CircleGeometry(0.036, 16), material);
      dot.position.set(p.x + normal.x * (BEVEL + 0.002), p.y + normal.y * (BEVEL + 0.002), 0);
      dot.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), new THREE.Vector3(normal.x, normal.y, 0));
      group.add(dot);
    }
  }
  return group;
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
    new THREE.MeshPhysicalMaterial({
      color: CLAY,
      roughness: 0.6,
      metalness: 0,
      sheen: 0.5,
      sheenColor: new THREE.Color(0xe8b8a4),
      sheenRoughness: 0.45,
      clearcoat: 0.12,
      clearcoatRoughness: 0.5,
      envMapIntensity: 0.5,
    }),
  ));

  device.add(createTopArtwork(renderer.capabilities.getMaxAnisotropy()));
  device.add(createSkinSide());
  device.add(createEdgeContacts());

  // The status light, at the lower left of the top face (as on the real tile).
  const ledMaterial = new THREE.MeshBasicMaterial({ color: new THREE.Color(0xffc98e).multiplyScalar(2), toneMapped: false });
  const led = new THREE.Mesh(new THREE.CircleGeometry(0.028, 20), ledMaterial);
  led.position.set(-0.55, -0.46, TOP_Z + 0.003);
  device.add(led);

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
