/* Regenerates Lofer/Resources/Body/BodyMesh.bin from the original prototype geometry
   (docs/artifact-reference/geo.js + anatomy.js). Run:  node tools/generate-body-mesh.js
   Output format (little-endian):
     uint32 vertexCount, uint32 indexCount,
     float32[vertexCount*3] positions, float32[vertexCount*3] normals,
     uint16[vertexCount] region (index into BodyMeshRegions.json), uint32[indexCount] indices */
const fs = require('fs'), path = require('path');
const ref = path.join(__dirname, '..', 'docs', 'artifact-reference');
require(path.join(ref, 'anatomy.js'));
const { LEAVES, LI } = globalThis.Lofer.Anatomy;
const g = require(path.join(ref, 'geo.js'));
const P = g.makePrims();
const m = g.buildMesh(P, [-0.4, -0.03, -0.2, 0.4, 1.78, 0.2], 0.0075, LI);
const V = m.pos.length / 3, I = m.idx.length;
const buf = Buffer.alloc(8 + V * 12 * 2 + V * 2 + I * 4);
let o = 0;
buf.writeUInt32LE(V, o); o += 4; buf.writeUInt32LE(I, o); o += 4;
for (const v of m.pos) { buf.writeFloatLE(v, o); o += 4; }
for (const v of m.nor) { buf.writeFloatLE(v, o); o += 4; }
for (const v of m.reg) { buf.writeUInt16LE(v, o); o += 2; }
for (const v of m.idx) { buf.writeUInt32LE(v, o); o += 4; }
const out = path.join(__dirname, '..', 'Lofer', 'Resources', 'Body');
fs.writeFileSync(path.join(out, 'BodyMesh.bin'), buf);
fs.writeFileSync(path.join(out, 'BodyMeshRegions.json'), JSON.stringify(LEAVES));
console.log(`BodyMesh.bin: ${V} vertices, ${I / 3} triangles, ${(buf.length / 1e6).toFixed(2)} MB; ${LEAVES.length} regions`);
