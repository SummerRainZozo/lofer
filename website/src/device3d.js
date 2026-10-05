// The Lofer device in the hero: a polished, high-tech take on the real shape,
// turning slowly. Both faces are identical.
//
// How the look is built:
//   1. a soft peach/lilac halo behind the device (a gradient on a big backdrop)
//   2. a "studio" of bright light panels the device reflects (an environment map):
//      that's what makes the highlights streak across the facets
//   3. the body: the Lofer outline, extruded with a crisp chamfered edge, in
//      polished titanium with a faint iridescent sheen
//   4. a thin glowing light seam running around the edge
//   5. a faint etched outline of the logo on each face
//   6. "bloom": a post-processing pass that makes the seam glow
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { deviceOutline } from './deviceShape.js';

// Same colours as the iOS app (Lofer/DesignSystem/Colors.swift).
const PEACH = 0xe4b598;
const LILAC = 0xb8b2c6;
const CREAM = 0xf3ebe2;    // also the page background
const TITANIUM = 0x8c857e; // warm titanium: metal shows its surroundings, so the colour stays light

const DEVICE_WIDTH = 2.6;
const DEPTH = 0.3;          // the flat part of the side wall
const CHAMFER = 0.07;       // the crisp bevel on each face edge

/** The outline as 2D points, `scale` × the device width. */
function outlinePoints(scale = 1) {
  return deviceOutline({ size: DEVICE_WIDTH * scale, samplesPerSegment: 2 }).map(([x, y]) => new THREE.Vector2(x, y));
}

/** The body: extruded outline with a chamfer (2 bevel steps = crisp facets, not a soft round). */
function createBodyGeometry() {
  const geometry = new THREE.ExtrudeGeometry(new THREE.Shape(outlinePoints()), {
    depth: DEPTH,
    bevelEnabled: true,
    bevelThickness: CHAMFER,
    bevelSize: CHAMFER,
    bevelSegments: 2,
    curveSegments: 12,
  });
  geometry.center();
  geometry.computeVertexNormals();
  return geometry;
}

/** A closed 3D loop through the outline, pushed out by `outset`, at height `z`. */
function outlineLoop(outset, z, scale = 1) {
  return outlinePoints(scale).map((p) => {
    const len = p.length();
    const k = (len + outset) / len;
    return new THREE.Vector3(p.x * k, p.y * k, z);
  });
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
 * A small photo studio, used only as something to reflect: a dim room with long
 * bright light panels (white, peach and lilac). Polished metal shows these as sharp
 * streaks of light on the facets, which is what gives the high-tech look.
 */
function createStudioEnvironment(renderer) {
  const studio = new THREE.Scene();
  studio.background = new THREE.Color(0x6e6862);   // a mid-grey room, so the metal isn't mirroring darkness
  const panel = (w, h, color, intensity, x, y, z) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), side: THREE.DoubleSide }));
    m.position.set(x, y, z);
    m.lookAt(0, 0, 0);
    studio.add(m);
  };
  panel(10, 1.2, 0xffffff, 4, 0, 6, 4);     // long strip above
  panel(1.2, 8, 0xffffff, 3, -7, 0, 3);     // tall strip on the left
  panel(1.2, 8, PEACH, 3, 7, 0, 2);         // warm strip on the right
  panel(8, 1.0, LILAC, 2.5, 0, -6, 3);      // cool strip below
  panel(6, 6, 0xffffff, 1.2, 0, 0, -8);     // soft fill behind
  panel(4, 4, 0xffffff, 1.5, 0, 0, 8);      // soft fill in front
  const pmrem = new THREE.PMREMGenerator(renderer);
  return pmrem.fromScene(studio, 0.02).texture;
}

/**
 * Starts the 3D device inside `container`.
 * Returns false if WebGL isn't available, so the page can show the SVG fallback.
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

  // 1. Halo behind the device. Big enough to fill the whole view.
  const halo = new THREE.Mesh(
    new THREE.PlaneGeometry(50, 50),
    new THREE.MeshBasicMaterial({ map: createHaloTexture(), toneMapped: false }),
  );
  halo.position.z = -2.5;
  scene.add(halo);

  // Everything that moves together lives in this group.
  const device = new THREE.Group();
  scene.add(device);

  // 3. The body: polished titanium with a clear lacquer and a faint iridescence.
  const body = new THREE.Mesh(
    createBodyGeometry(),
    new THREE.MeshPhysicalMaterial({
      color: TITANIUM,
      metalness: 1,
      roughness: 0.2,
      clearcoat: 1,
      clearcoatRoughness: 0.04,
      iridescence: 0.12,         // a faint thin-film sheen at grazing angles (more turns it green)
      iridescenceIOR: 1.6,
      iridescenceThicknessRange: [200, 500],
      envMapIntensity: 1.3,
    }),
  );
  device.add(body);

  // 4. The light seam: a thin glowing tube around the middle of the side wall.
  const seamMaterial = new THREE.MeshBasicMaterial({ color: new THREE.Color(PEACH).multiplyScalar(1.6), toneMapped: false });
  const seamCurve = new THREE.CatmullRomCurve3(outlineLoop(CHAMFER + 0.006, 0), true);
  device.add(new THREE.Mesh(new THREE.TubeGeometry(seamCurve, 480, 0.014, 8, true), seamMaterial));

  // 5. A faint etched outline of the logo on both faces (identical sides).
  const faceZ = DEPTH / 2 + CHAMFER + 0.002;
  const etchMaterial = new THREE.LineBasicMaterial({ color: PEACH, transparent: true, opacity: 0.55 });
  for (const z of [faceZ, -faceZ]) {
    const pts = outlinePoints(0.62).map((p) => new THREE.Vector3(p.x, p.y, z));
    device.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts), etchMaterial));
  }

  // A key light for a crisp highlight, plus a warm and a cool rim.
  const keyLight = new THREE.DirectionalLight(0xffffff, 1.2);
  keyLight.position.set(-3, 4, 5);
  scene.add(keyLight);
  const warmRim = new THREE.DirectionalLight(PEACH, 1.0);
  warmRim.position.set(5, -1, -2);
  scene.add(warmRim);
  const coolRim = new THREE.DirectionalLight(LILAC, 0.8);
  coolRim.position.set(-5, -2, -1);
  scene.add(coolRim);

  // 6. Bloom. A high threshold so only the brightest bits (the seam, highlights)
  //    glow; a low one would make the whole cream page bloom.
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.45, 0.5, 0.9);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  // Keep the canvas the size of its container, and the device comfortably inside it.
  function resize() {
    const { clientWidth: width, clientHeight: height } = container;
    renderer.setSize(width, height);
    composer.setSize(width, height);
    camera.aspect = width / height;
    // Distance that fits the device (plus margin) in both directions.
    const fit = (DEVICE_WIDTH * 1.55) / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)));
    camera.position.z = Math.max(fit, fit / camera.aspect);
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(container);
  resize();

  // The device leans towards the pointer a little (like Oura's product shots).
  const pointer = { x: 0, y: 0 };
  window.addEventListener('pointermove', (event) => {
    pointer.x = (event.clientX / window.innerWidth) * 2 - 1;
    pointer.y = (event.clientY / window.innerHeight) * 2 - 1;
  });

  const baseTiltX = -0.5;
  const startTurn = 0.4;
  const secondsPerTurn = 22;

  function renderFrame(timeMs) {
    const t = timeMs / 1000;
    if (!reducedMotion) {
      device.rotation.y = startTurn + (t / secondsPerTurn) * Math.PI * 2 + pointer.x * 0.25;
      const targetX = baseTiltX + Math.sin(t * 0.4) * 0.06 + pointer.y * 0.15;
      device.rotation.x += (targetX - device.rotation.x) * 0.05;
      device.position.y = Math.sin(t * 0.8) * 0.05;
      const breath = 0.5 + 0.5 * Math.sin(t * 1.1);       // the seam "breathes"
      bloom.strength = 0.38 + breath * 0.16;
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
