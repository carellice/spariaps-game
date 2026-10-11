// Spariaps — Mappe (arena e quartiere), negozi, atmosfera, collisioni e navigazione.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ level
const worldMeshes = [];
const colliders = [];
// every map is built into its own root group; the active map's meshes and boxes are copied into worldMeshes / colliders
const MAPS = {};
let B = null;        // map being built
let MAP = null;      // map in play
let mapVersion = 0;  // bumped on every map switch (cached minimap, thumbnails)
function newMap(key, info) {
  B = MAPS[key] = { key, ...info, root: new THREE.Group(), meshes: [], boxes: [], layer: { solids: [], pads: [], deco: new THREE.Group() } };
  B.root.add(B.layer.deco); B.root.visible = false; scene.add(B.root);
  return B;
}

// ------------------------------------------------------------ map 1: the test arena
newMap('arena', {
  name: 'ARENA', tag: 'CAMPO DI PROVA', desc: 'L’arena di allenamento: muri bassi, casse e pilastri in uno spazio aperto e simmetrico.',
  start: [0, 1, 0], fallback: [-37.5, -37.5], orbit: [46, 20], shot: [36, 30, 46, 0, 0, 0],
  boxSpots: [[0, -11.5], [11.5, 0], [-11.5, 0], [0, 11.5], [30, -19], [-30, 19], [19, 30], [-19, -30]],
  pickups: {
    equip: [[7, 3], [-7, -3], [-3, 7], [3, -7], [-34, -8], [34, 8], [8, 34], [-8, -34]],
    health: [[0, -10.5], [0, 10.5], [-20, -12], [20, 12], [-34, -12], [34, 12], [-10, 34], [10, -34]],
    armor: [[-30, -29], [30, 29], [26, -18], [-26, 18]],
  },
  power: { jump: [[-19, 0], [19, 0]], haste: [[0, -19], [0, 19]], ammo: [[-31, 31], [31, -31]], quad: [[0, 0]], god: [[35, 35], [-35, -35]] },
});

const floorSurf = surface({ base: '#7c828a', seam: '#686d74', cells: 1, blotch: 0.12 });
floorSurf.map.repeat.set(20, 20); floorSurf.bumpMap.repeat.set(20, 20);
const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.MeshStandardMaterial({ ...floorSurf, bumpScale: 1.2, roughness: 0.82, metalness: 0.05 }));
floor.rotation.x = -Math.PI / 2;
floor.receiveShadow = true;
B.root.add(floor); B.meshes.push(floor);

const paint = new THREE.MeshStandardMaterial({ color: 0xf0b43a, roughness: 0.7, polygonOffset: true, polygonOffsetFactor: -2 });
const addMark = (geo, x, z, ry = 0) => { const m = new THREE.Mesh(geo, paint); m.rotation.set(-Math.PI / 2, 0, ry); m.position.set(x, 0.005, z); m.receiveShadow = true; B.root.add(m); };
addMark(new THREE.RingGeometry(9, 9.22, 96), 0, 0);
addMark(new THREE.RingGeometry(9.5, 9.58, 96), 0, 0);
for (const a of [0, Math.PI / 2]) {
  addMark(new THREE.PlaneGeometry(0.22, 18), Math.sin(a) * 26, Math.cos(a) * 26, a);
  addMark(new THREE.PlaneGeometry(0.22, 18), -Math.sin(a) * 26, -Math.cos(a) * 26, a);
}

const mats = {
  wall: new THREE.MeshStandardMaterial({ ...surface({ base: '#bab3a7', seam: '#a29b8e', cells: 2, dirt: 0.28, blotch: 0.08 }), bumpScale: 1.2, roughness: 0.78 }),
  concrete: new THREE.MeshStandardMaterial({ ...surface({ base: '#8e959d', seam: '#7a8189', cells: 2, blotch: 0.12 }), bumpScale: 1.2, roughness: 0.8 }),
  trim: new THREE.MeshStandardMaterial({ color: 0x262b33, roughness: 0.4, metalness: 0.6 }),
  pillar: new THREE.MeshStandardMaterial({ color: 0x3b4655, roughness: 0.32, metalness: 0.75 }),
  crate: new THREE.MeshStandardMaterial({ ...crateTex(), bumpScale: 1.5, roughness: 0.75 }),
  cover: new THREE.MeshStandardMaterial({ color: 0x2f353e, roughness: 0.4, metalness: 0.55 }),
  neon: new THREE.MeshStandardMaterial({ color: 0x331100, emissive: 0xff6a2a, emissiveIntensity: 4.5 }),
  neonBlue: new THREE.MeshStandardMaterial({ color: 0x001133, emissive: 0x3aa8ff, emissiveIntensity: 4 }),
  city: new THREE.MeshStandardMaterial({ color: 0x46505e, roughness: 0.6, metalness: 0.3 }),
  windows: new THREE.MeshStandardMaterial({ color: 0x111111, emissive: 0xffc070, emissiveIntensity: 1.6 }),
};

function addSolid(mesh) {
  mesh.castShadow = mesh.receiveShadow = true;
  B.root.add(mesh);
  mesh.updateMatrixWorld();
  B.meshes.push(mesh);
  B.boxes.push(new THREE.Box3().setFromObject(mesh));
  return mesh;
}
function addBox(x, z, w, h, d, mat, y = 0, { r = 0.12, tile = 4 } = {}) {
  const geo = rbox(w, h, d, r);
  if (tile) boxUV(geo, tile, h / 2);
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y + h / 2, z);
  return addSolid(m);
}
function addDeco(geo, mat, x, y, z, rx = 0, ry = 0, rz = 0) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z); m.rotation.set(rx, ry, rz);
  B.root.add(m); return m;
}
function addTube(x, y, z, len, axis, mat = mats.neon, r = 0.035) {
  addDeco(new THREE.CapsuleGeometry(r, len, 4, 10), mat, x, y, z, axis === 'z' ? Math.PI / 2 : 0, 0, axis === 'x' ? Math.PI / 2 : 0);
}
function addSkirt(x, z, w, d) { addDeco(rbox(w + 0.06, 0.35, d + 0.06, 0.08), mats.trim, x, 0.175, z).receiveShadow = true; }

for (const s of [-1, 1]) {
  addBox(0, 40.5 * s, 82, 6, 1, mats.wall, 0, { r: 0.2 });
  addBox(40.5 * s, 0, 1, 6, 82, mats.wall, 0, { r: 0.2 });
  addSkirt(0, 40.5 * s, 80, 1); addSkirt(40.5 * s, 0, 1, 80);
  addTube(0, 5.2, 39.96 * s, 80, 'x', mats.neonBlue);
  addTube(39.96 * s, 5.2, 0, 80, 'z', mats.neonBlue);
}
addBox(0, 0, 6, 1, 6, mats.concrete, 0, { r: 0.18, tile: 2 });
for (const s of [-1, 1]) {
  addTube(3.03 * s, 0.82, 0, 5.4, 'z'); addTube(0, 0.82, 3.03 * s, 5.4, 'x');
  for (const z of [-7, 7]) {
    addBox(14 * s, z, 1, 3, 8, mats.wall, 0, { r: 0.18 }); addSkirt(14 * s, z, 1, 8);
    addBox(z, 14 * s, 8, 3, 1, mats.wall, 0, { r: 0.18 }); addSkirt(z, 14 * s, 8, 1);
    addTube(14 * s, 3.01, z, 7.4, 'z'); addTube(z, 3.01, 14 * s, 7.4, 'x');
  }
}
for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
  addBox(28 * sx, 24 * sz, 12, 4, 1, mats.wall, 0, { r: 0.18 }); addSkirt(28 * sx, 24 * sz, 12, 1);
  addBox(22.5 * sx, 30 * sz, 1, 4, 11, mats.wall, 0, { r: 0.18 }); addSkirt(22.5 * sx, 30 * sz, 1, 11);
  addTube(28 * sx, 4.01, 24 * sz, 11.4, 'x', mats.neonBlue, 0.03);
}
const pillarGeo = new THREE.CylinderGeometry(1.1, 1.1, 6, 40);
const ringGeo = new THREE.TorusGeometry(1.13, 0.04, 8, 48);
for (const [x, z] of [[26, 0], [-26, 0], [0, 27], [0, -27]]) {
  const m = new THREE.Mesh(pillarGeo, mats.pillar); m.position.set(x, 3, z); addSolid(m);
  for (const y of [0.6, 3, 5.4]) addDeco(ringGeo, mats.neon, x, y, z, Math.PI / 2);
}
for (const [x, z, w, d] of [[-30, 12, 6, 0.6], [30, -12, 6, 0.6], [12, 30, 0.6, 6], [-12, -30, 0.6, 6], [-6, 20, 4, 0.6], [6, -20, 4, 0.6]]) {
  addBox(x, z, w, 1.1, d, mats.cover, 0, { r: 0.2, tile: 0 });
  const len = Math.max(w, d) - 0.6;
  for (const s of [-1, 1]) {
    if (w > d) addTube(x, 0.75, z + s * (d / 2 + 0.005), len, 'x', mats.neon, 0.022);
    else addTube(x + s * (w / 2 + 0.005), 0.75, z, len, 'z', mats.neon, 0.022);
  }
}
for (const [x, z, y] of [
  [-8, -22, 0], [-6.8, -22, 0], [-8, -22, 1.2], [8, 22, 0], [9.2, 22, 0], [8, 22, 1.2],
  [22, -8, 0], [22, -6.8, 0], [-22, 8, 0], [-22, 9.2, 0], [-22, 8, 1.2],
  [-18, -18, 0], [18, 18, 0], [18, -18, 0], [-18, 18, 0], [-33, 0, 0], [33, 0, 0], [0, -34, 0], [0, 34, 0],
  [-30, -34, 0], [30, 34, 0], [-34, 30, 0], [34, -30, 0], [10, -5, 0], [-10, 5, 0], [-4, -9, 0], [4, 9, 0],
]) addBox(x, z, 1.2, 1.2, 1.2, mats.crate, y, { r: 0.06, tile: 0 });
const barrelGeo = new THREE.CylinderGeometry(0.42, 0.42, 1.15, 28);
const barrelMats = [barrelTex('#b0382a'), barrelTex('#2d628f'), barrelTex('#3d6e3a')].map(map => new THREE.MeshStandardMaterial({ map, roughness: 0.38, metalness: 0.55 }));
for (const [x, z] of [[-12, -12], [-12.9, -11.6], [12, 12], [12.8, 12.6], [-35, -20], [35, 20], [20, -34], [-20, 34], [-3, 30], [3, -30], [30, 5], [-30, -5]]) {
  const m = new THREE.Mesh(barrelGeo, barrelMats[Math.floor(Math.random() * 3)]);
  m.position.set(x, 0.575, z); m.rotation.y = Math.random() * 6;
  addSolid(m);
}
for (let i = 0; i < 70; i++) {
  const a = i / 70 * Math.PI * 2 + rand(-0.03, 0.03), r = rand(75, 140);
  const w = rand(8, 20), h = rand(12, 60), d = rand(8, 20);
  const m = new THREE.Mesh(rbox(w, h, d, 1.2, 2), mats.city);
  m.position.set(Math.cos(a) * r, h / 2, Math.sin(a) * r); m.rotation.y = -a;
  scene.add(m);
  if (Math.random() < 0.55) { const s = new THREE.Mesh(new THREE.BoxGeometry(w * 0.85, 0.35, d + 0.1), mats.windows); s.position.set(0, rand(-h / 4, h / 3), 0); m.add(s); }
}

// ============================================================ set dressing: skyline windows, screens, floodlights, wall props, floor wear, ambient particles
const decoMats = {
  screen: new THREE.MeshStandardMaterial({ color: 0x050608, emissive: 0xffffff, emissiveIntensity: 1.1, roughness: 0.35 }),
  lens: new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.95, 0.85).multiplyScalar(2.2), toneMapped: false }),
  lamp: new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.8, 0.55).multiplyScalar(2), toneMapped: false }),
  puddle: null, stain: null,
};
const beams = [];
{
  // city: lit window grids instead of flat blocks
  const [c, g] = canvas(256); g.fillStyle = '#000'; g.fillRect(0, 0, 256, 256);
  for (let y = 6; y < 256; y += 16) for (let x = 6; x < 256; x += 12) {
    if (Math.random() < 0.42) { g.fillStyle = `rgba(255,${(190 + rand(0, 50)) | 0},${(120 + rand(0, 80)) | 0},${rand(0.35, 1)})`; g.fillRect(x, y, 7, 9); }
  }
  const t = finishTex(c); t.repeat.set(2, 3);
  Object.assign(mats.city, { emissiveMap: t, emissive: new THREE.Color(0xffc070), emissiveIntensity: 0.5 }); mats.city.needsUpdate = true;

  // big arena screens on top of the north and south walls
  const [sc, sg] = canvas(1); sc.width = 1024; sc.height = 288;
  const drawScreen = () => {
    const gr = sg.createLinearGradient(0, 0, 1024, 288); gr.addColorStop(0, '#0b1426'); gr.addColorStop(1, '#261018');
    sg.fillStyle = gr; sg.fillRect(0, 0, 1024, 288);
    sg.strokeStyle = 'rgba(120,170,255,.12)'; sg.lineWidth = 1;
    for (let x = 0; x < 1024; x += 32) { sg.beginPath(); sg.moveTo(x, 0); sg.lineTo(x, 288); sg.stroke(); }
    for (let y = 0; y < 288; y += 32) { sg.beginPath(); sg.moveTo(0, y); sg.lineTo(1024, y); sg.stroke(); }
    sg.font = '700 150px Rajdhani, Inter, sans-serif'; sg.textBaseline = 'middle';
    const tg = sg.createLinearGradient(0, 70, 0, 220); tg.addColorStop(0, '#ffffff'); tg.addColorStop(0.6, '#ffd2b8'); tg.addColorStop(1, '#ff6b3d');
    sg.shadowColor = 'rgba(255,107,61,.8)'; sg.shadowBlur = 30; sg.fillStyle = tg; sg.fillText('SPARIAPS', 50, 150, 570);
    sg.shadowBlur = 0; sg.font = '700 44px Rajdhani, Inter, sans-serif'; sg.fillStyle = '#9ad4ff'; sg.fillText('ARENA · LIVE', 660, 110, 290);
    sg.fillStyle = '#ff4d4d'; sg.beginPath(); sg.arc(978, 110, 10, 0, 7); sg.fill();
    sg.font = '600 27px Inter, sans-serif'; sg.fillStyle = 'rgba(238,242,247,.7)'; sg.fillText('SOPRAVVIVI ALLE ONDATE', 660, 170, 336);
    for (let y = 0; y < 288; y += 4) { sg.fillStyle = 'rgba(0,0,0,.18)'; sg.fillRect(0, y, 1024, 1.5); }
  };
  drawScreen();
  const st = new THREE.CanvasTexture(sc); st.colorSpace = THREE.SRGBColorSpace;
  decoMats.screen.emissiveMap = st;
  document.fonts?.ready.then(() => { drawScreen(); st.needsUpdate = true; });
  for (const s of [-1, 1]) {
    const g2 = new THREE.Group(); g2.position.set(0, 0, 40.9 * s); g2.rotation.y = s > 0 ? Math.PI : 0; B.root.add(g2);
    const frame = new THREE.Mesh(rbox(17, 5.4, 0.5, 0.2), mats.trim); frame.position.y = 9.4; frame.castShadow = true; g2.add(frame);
    const scr = new THREE.Mesh(new THREE.PlaneGeometry(16.2, 4.56), decoMats.screen); scr.position.set(0, 9.4, 0.26); g2.add(scr);
    for (const x of [-6, 6]) { const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.18, 1.2, 12), mats.trim); leg.position.set(x, 6.5, 0); g2.add(leg); }
  }

  // floodlight towers behind the corners, with soft light cones
  const coneMat = k => new THREE.ShaderMaterial({
    uniforms: { color: { value: new THREE.Color(1, 0.93, 0.8) }, k: { value: k } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
    fragmentShader: 'uniform vec3 color; uniform float k; varying vec2 vUv; void main(){ float a = pow(clamp(vUv.y, 0.0, 1.0), 1.6) * k * (0.75 + 0.25 * sin(vUv.x * 6.2832)); gl_FragColor = vec4(color * a, a); }',
  });
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    const base = new V3(44 * sx, 0, 44 * sz), head = new V3(43 * sx, 18, 43 * sz);
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.4, 18, 16), mats.pillar); pole.position.copy(base).setY(9); B.root.add(pole);
    const target = new V3(12 * sx, 0, 12 * sz), dir = target.clone().sub(head), L = dir.length(); dir.normalize();
    const hg = new THREE.Group(); hg.position.copy(head); hg.lookAt(target); B.root.add(hg);
    const hb = new THREE.Mesh(rbox(2.6, 1.3, 0.7, 0.15), mats.trim); hg.add(hb);
    const lens = new THREE.Mesh(new THREE.PlaneGeometry(2.3, 1.05), decoMats.lens); lens.position.z = 0.36; hg.add(lens);
    const cone = new THREE.Mesh(new THREE.ConeGeometry(6.5, L, 32, 1, true).translate(0, -L / 2, 0), coneMat(0.12));
    cone.position.copy(head); cone.quaternion.setFromUnitVectors(new V3(0, -1, 0), dir); B.root.add(cone);
    beams.push(cone);
  }

  // outer walls: pipe runs with brackets and caged wall lamps (merged per material)
  const pipes = [], brackets = [], lampBodies = [], lampLenses = [];
  for (const [ax, s] of [['x', -1], ['x', 1], ['z', -1], ['z', 1]]) {
    const off = 39.72 * s, place = (geo, a, y, d = 0) => {
      const g = geo.clone();
      if (ax === 'x') { if (s > 0) g.rotateY(Math.PI); g.translate(a, y, off - d * s); } else { g.rotateY(s > 0 ? -Math.PI / 2 : Math.PI / 2); g.translate(off - d * s, y, a); }
      return g;
    };
    pipes.push(place(new THREE.CylinderGeometry(0.12, 0.12, 79, 12).rotateZ(Math.PI / 2), 0, 4.75, 0.05));
    pipes.push(place(new THREE.CylinderGeometry(0.07, 0.07, 79, 10).rotateZ(Math.PI / 2), 0, 4.45, 0.05));
    for (let a = -36; a <= 36; a += 8) brackets.push(place(rbox(0.12, 0.55, 0.3, 0.03), a, 4.6, 0));
    for (let a = -35; a <= 35; a += 10) {
      lampBodies.push(place(rbox(0.7, 0.3, 0.32, 0.06), a, 3.35, 0));
      lampLenses.push(place(new THREE.PlaneGeometry(0.56, 0.16).rotateX(-Math.PI / 2 + 0.6), a, 3.2, 0.2));
    }
  }
  const addMerged = (arr, mat) => { const m = new THREE.Mesh(mergeGeometries(arr), mat); m.castShadow = false; m.receiveShadow = true; B.root.add(m); return m; };
  addMerged(pipes, mats.pillar); addMerged(brackets, mats.trim); addMerged(lampBodies, mats.trim); addMerged(lampLenses, decoMats.lamp);

  // floor wear: reflective puddles, oil stains and cracks
  const blobTex = (draw) => { const [bc, bg] = canvas(256); bg.clearRect(0, 0, 256, 256); draw(bg); const t = new THREE.CanvasTexture(bc); return t; };
  const puddleA = blobTex(g => {
    for (let i = 0; i < 12; i++) { const x = 128 + rand(-55, 55), y = 128 + rand(-40, 40), r = rand(35, 75), gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.7, 'rgba(255,255,255,.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 256, 256); }
  });
  const stainT = blobTex(g => {
    for (let i = 0; i < 9; i++) { const x = 128 + rand(-60, 60), y = 128 + rand(-60, 60), r = rand(20, 60), gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(12,10,8,.55)'); gr.addColorStop(1, 'rgba(12,10,8,0)'); g.fillStyle = gr; g.fillRect(0, 0, 256, 256); }
    g.strokeStyle = 'rgba(10,10,10,.6)'; g.lineWidth = 1.5;
    for (let i = 0; i < 3; i++) { let x = rand(40, 216), y = rand(40, 216), a = rand(0, 6.28); g.beginPath(); g.moveTo(x, y); for (let k = 0; k < 14; k++) { a += rand(-0.7, 0.7); x += Math.cos(a) * 7; y += Math.sin(a) * 7; g.lineTo(x, y); } g.stroke(); }
  });
  stainT.colorSpace = THREE.SRGBColorSpace;
  decoMats.puddle = new THREE.MeshStandardMaterial({ color: 0x0c0f14, roughness: 0.04, metalness: 0.5, alphaMap: puddleA, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 });
  decoMats.stain = new THREE.MeshStandardMaterial({ map: stainT, transparent: true, depthWrite: false, roughness: 0.9, polygonOffset: true, polygonOffsetFactor: -1 });
  const pud = [], stn = [];
  for (let i = 0; i < 16; i++) pud.push(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2).rotateY(rand(0, 6.28)).scale(rand(1.6, 3.6), 1, rand(1.2, 2.6)).translate(rand(-37, 37), 0.012, rand(-37, 37)));
  for (let i = 0; i < 26; i++) stn.push(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2).rotateY(rand(0, 6.28)).scale(rand(1.5, 4), 1, rand(1.5, 4)).translate(rand(-38, 38), 0.008, rand(-38, 38)));
  const pm = addMerged(pud, decoMats.puddle); pm.renderOrder = 1;
  addMerged(stn, decoMats.stain);
}
// drifting dust by day, falling ash and rising embers at night
const AMB_N = 520;
const amb = (() => {
  const pos = new Float32Array(AMB_N * 3), vel = new Float32Array(AMB_N * 3);
  for (let i = 0; i < AMB_N; i++) { pos[i * 3] = rand(-22, 22); pos[i * 3 + 1] = rand(0, 12); pos[i * 3 + 2] = rand(-22, 22); }
  const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const mat = new THREE.PointsMaterial({ map: glowTex, size: 0.06, transparent: true, depthWrite: false, opacity: 0.4, color: 0xfff1dc });
  const pts = new THREE.Points(geo, mat); pts.frustumCulled = false; scene.add(pts);
  return { pts, pos, vel, mat, mode: null };
})();
function updateAmbient(dt) {
  amb.pts.visible = settings.quality !== 'low';
  if (!amb.pts.visible) return;
  if (amb.mode !== mode) {
    amb.mode = mode;
    const z = mode === 'zombie';
    Object.assign(amb.mat, { size: z ? 0.075 : 0.05, opacity: z ? 0.85 : 0.35, blending: z ? THREE.AdditiveBlending : THREE.NormalBlending });
    amb.mat.color.set(z ? 0xff7a3a : 0xfff1dc); amb.mat.needsUpdate = true;
    for (let i = 0; i < AMB_N; i++) { amb.vel[i * 3] = rand(-0.3, 0.3); amb.vel[i * 3 + 1] = z ? (i % 3 ? rand(-0.5, -0.2) : rand(0.3, 0.9)) : rand(-0.06, 0.06); amb.vel[i * 3 + 2] = rand(-0.3, 0.3); }
  }
  const c = camera.position, p = amb.pos, v = amb.vel, t = performance.now() * 0.001;
  for (let i = 0; i < AMB_N; i++) {
    const k = i * 3;
    p[k] += (v[k] + Math.sin(t * 0.7 + i) * 0.15) * dt; p[k + 1] += v[k + 1] * dt; p[k + 2] += (v[k + 2] + Math.cos(t * 0.6 + i) * 0.15) * dt;
    // keep the cloud centred on the camera
    if (p[k] - c.x > 22) p[k] -= 44; else if (p[k] - c.x < -22) p[k] += 44;
    if (p[k + 2] - c.z > 22) p[k + 2] -= 44; else if (p[k + 2] - c.z < -22) p[k + 2] += 44;
    if (p[k + 1] < 0) p[k + 1] += 12; else if (p[k + 1] > 12) p[k + 1] -= 12;
  }
  amb.pts.geometry.attributes.position.needsUpdate = true;
}

// ============================================================ arena layer (classic mode only): floating platforms + jump pads
const arena = { on: false, get solids() { return MAP.layer.solids; }, get pads() { return MAP.layer.pads; } };
const padMats = {
  base: new THREE.MeshStandardMaterial({ color: 0x252a33, roughness: 0.35, metalness: 0.8 }),
  ring: new THREE.MeshBasicMaterial({ color: new THREE.Color(0x3affe0).multiplyScalar(2.6), toneMapped: false }),
  disc: new THREE.MeshBasicMaterial({ map: glowTex, color: 0x3affe0, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false }),
  under: new THREE.MeshBasicMaterial({ color: new THREE.Color(0x3aa8ff).multiplyScalar(2), toneMapped: false }),
};
function arenaMesh(geo, mat, x, y, z, rx = 0, rz = 0) {
  const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, 0, rz); B.layer.deco.add(m); return m;
}
function arenaPlatform(x, z, w, d, top, thick = 0.5) {
  const m = arenaMesh(boxUV(rbox(w, thick, d, 0.14), 2, 0), mats.concrete, x, top - thick / 2, z);
  m.castShadow = m.receiveShadow = true; m.updateMatrixWorld();
  B.layer.solids.push({ mesh: m, box: new THREE.Box3().setFromObject(m) });
  // neon trim on the edges, hover emitters underneath
  for (const s of [-1, 1]) {
    arenaMesh(new THREE.CapsuleGeometry(0.03, w - 0.3, 4, 8), mats.neon, x, top - 0.12, z + s * (d / 2 + 0.01), 0, Math.PI / 2);
    arenaMesh(new THREE.CapsuleGeometry(0.03, d - 0.3, 4, 8), mats.neon, x + s * (w / 2 + 0.01), top - 0.12, z, Math.PI / 2);
  }
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    arenaMesh(new THREE.CylinderGeometry(0.28, 0.2, 0.18, 20), padMats.base, x + sx * (w / 2 - 0.7), top - thick - 0.08, z + sz * (d / 2 - 0.7));
    arenaMesh(new THREE.CircleGeometry(0.17, 20), padMats.under, x + sx * (w / 2 - 0.7), top - thick - 0.175, z + sz * (d / 2 - 0.7), Math.PI / 2);
  }
}
// jump pad: launch velocity solved so the arc lands on the target in T seconds (gravity 20)
function jumpPad(x, y, z, tx, ty, tz, T = 1) {
  const g = new THREE.Group(); g.position.set(x, y, z); B.layer.deco.add(g);
  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.95, 1.02, 0.12, 36), padMats.base); base.position.y = 0.06; base.receiveShadow = true;
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.78, 0.035, 8, 48), padMats.ring); ring.rotation.x = Math.PI / 2; ring.position.y = 0.13;
  const disc = new THREE.Mesh(new THREE.PlaneGeometry(1.8, 1.8).rotateX(-Math.PI / 2), padMats.disc); disc.position.y = 0.125;
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.78, 2.2, 32, 1, true).translate(0, 1.1, 0), beamMat(0x3affe0, 0.4));
  g.add(base, ring, disc, beam);
  B.layer.pads.push({ pos: new V3(x, y, z), vel: new V3((tx - x) / T, (ty - y + 10 * T * T) / T, (tz - z) / T), ring, beam, t: 0 });
}
{
  const MID = 3.4, SKY = 7.2;
  for (const [sx, sz] of [[-1, -1], [1, 1], [1, -1], [-1, 1]]) arenaPlatform(20 * sx, 20 * sz, 6, 6, MID);
  arenaPlatform(0, 0, 6, 6, SKY);
  // ground -> mid platforms
  jumpPad(13.5, 0, 20, 19.5, MID, 20, 0.9); jumpPad(-13.5, 0, -20, -19.5, MID, -20, 0.9);
  jumpPad(20, 0, -13.5, 20, MID, -19.5, 0.9); jumpPad(-20, 0, 13.5, -20, MID, 19.5, 0.9);
  // mid platforms -> sky platform over the centre
  for (const [sx, sz] of [[-1, -1], [1, 1], [1, -1], [-1, 1]]) jumpPad(18.2 * sx, MID, 18.2 * sz, 1.4 * sx, SKY, 1.4 * sz, 1.3);
}
function setArena(on) {
  MAP.layer.deco.visible = on;
  if (on === arena.on) return;
  arena.on = on;
  for (const s of MAP.layer.solids) {
    if (on) { worldMeshes.push(s.mesh); colliders.push(s.box); }
    else { worldMeshes.splice(worldMeshes.indexOf(s.mesh), 1); colliders.splice(colliders.indexOf(s.box), 1); }
  }
}
function updateArena(dt) {
  if (!arena.on) return;
  for (const p of arena.pads) {
    p.t = Math.max(0, p.t - dt);
    p.ring.scale.setScalar(1 + Math.sin(now * 4) * 0.04 + p.t * 0.6);
    p.beam.scale.y = 1 + p.t * 1.5;
  }
}
function tryJumpPad() {
  if (!arena.on || !player.onGround) return;
  for (const p of arena.pads) {
    if (Math.abs(player.pos.y - p.pos.y) > 0.3 || Math.hypot(player.pos.x - p.pos.x, player.pos.z - p.pos.z) > 0.95) continue;
    player.vel.copy(p.vel); player.onGround = false; player.airJumps = 1; player.crouch = false;
    p.t = 0.5;
    sfxBoing();
    spawnParticles(p.pos.clone().setY(p.pos.y + 0.3), 0x3affe0, 22, new V3(0, 1, 0), 5);
    return;
  }
}

// ============================================================ map 2: "Quartiere" — a small Italian neighbourhood around a crossroads
const CITY = { facades: [], signs: [], redraw: [], glass: null, pool: null, lightI: 0 };
// plastered facade, 4 bays x 4 floors per tile: windows with shutters, sills and string courses; a second canvas lights some windows at night
function facadeTex(wall, shutter, frame = '#e9e2d2') {
  const S = 512, n = 4, cs = S / n, [c, g] = canvas(S), [ec, eg] = canvas(S);
  g.fillStyle = wall; g.fillRect(0, 0, S, S);
  eg.fillStyle = '#000'; eg.fillRect(0, 0, S, S);
  for (let i = 0; i < 50; i++) {
    const x = rand(0, S), y = rand(0, S), r = rand(30, 110), gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, Math.random() < 0.6 ? 'rgba(0,0,0,.07)' : 'rgba(255,255,255,.06)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(x - r, y - r, 2 * r, 2 * r);
  }
  for (let i = 0; i < 6000; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,255,255'},${Math.random() * 0.05})`; g.fillRect(rand(0, S), rand(0, S), 2, 2); }
  for (let j = 0; j < n; j++) {
    g.fillStyle = 'rgba(255,255,255,.18)'; g.fillRect(0, j * cs, S, 5);
    g.fillStyle = 'rgba(0,0,0,.22)'; g.fillRect(0, j * cs + 5, S, 2);
    for (let i = 0; i < n; i++) {
      const x = i * cs + cs * 0.31, w = cs * 0.38, y = j * cs + cs * 0.2, h = cs * 0.56, sw = w * 0.42;
      const dirt = g.createLinearGradient(0, y + h, 0, y + h + 36); dirt.addColorStop(0, 'rgba(30,22,14,.3)'); dirt.addColorStop(1, 'rgba(30,22,14,0)');
      g.fillStyle = dirt; g.fillRect(x - 2, y + h, w + 4, 36);
      g.fillStyle = frame; g.fillRect(x - 5, y - 5, w + 10, h + 10);
      const closed = Math.random() < 0.3, lit = !closed && Math.random() < 0.45;
      if (closed) {
        g.fillStyle = shutter; g.fillRect(x, y, w, h);
        g.fillStyle = 'rgba(0,0,0,.28)'; for (let k = y + 3; k < y + h; k += 5) g.fillRect(x, k, w, 1.5);
        g.fillRect(x + w / 2 - 1, y, 2, h);
      } else {
        g.fillStyle = '#16202b'; g.fillRect(x, y, w, h);
        g.fillStyle = 'rgba(235,225,205,.22)'; g.fillRect(x, y, w * 0.3, h);
        g.fillStyle = 'rgba(140,180,220,.16)'; g.beginPath(); g.moveTo(x + w * 0.5, y); g.lineTo(x + w, y); g.lineTo(x + w, y + h * 0.5); g.fill();
        g.fillStyle = frame; g.fillRect(x + w / 2 - 1.5, y, 3, h); g.fillRect(x, y + h * 0.36, w, 3);
        // open shutters folded back against the wall
        g.fillStyle = shutter; g.fillRect(x - 5 - sw, y - 2, sw, h + 4); g.fillRect(x + w + 5, y - 2, sw, h + 4);
        g.fillStyle = 'rgba(0,0,0,.25)'; for (let k = y + 2; k < y + h; k += 5) { g.fillRect(x - 5 - sw, k, sw, 1.5); g.fillRect(x + w + 5, k, sw, 1.5); }
        if (lit) {
          eg.fillStyle = `rgba(255,${(195 + rand(0, 45)) | 0},${(130 + rand(0, 70)) | 0},${rand(0.5, 1)})`; eg.fillRect(x, y, w, h);
          eg.fillStyle = '#000'; eg.fillRect(x + w / 2 - 1.5, y, 3, h); eg.fillRect(x, y + h * 0.36, w, 3);
        }
      }
      g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(x - 8, y + h + 6, w + 16, 4);
      g.fillStyle = frame; g.fillRect(x - 8, y + h + 2, w + 16, 5);
    }
  }
  return { map: finishTex(c), emissiveMap: finishTex(ec) };
}
// box whose side faces show a whole number of window bays and floors; the roof samples plain wall
function facadeGeo(w, h, d) {
  const geo = new THREE.BoxGeometry(w, h, d), pos = geo.attributes.position, nor = geo.attributes.normal, uv = geo.attributes.uv;
  const nf = Math.max(1, Math.round(h / 3.2)), nx = Math.max(1, Math.round(w / 3.2)), nz = Math.max(1, Math.round(d / 3.2));
  for (let i = 0; i < pos.count; i++) {
    const v = (pos.getY(i) / h + 0.5) * nf / 4;
    if (Math.abs(nor.getX(i)) > 0.5) uv.setXY(i, (pos.getZ(i) / d + 0.5) * nz / 4, v);
    else if (Math.abs(nor.getZ(i)) > 0.5) uv.setXY(i, (pos.getX(i) / w + 0.5) * nx / 4, v);
    else uv.setXY(i, 0.004, 0.004);
  }
  return geo;
}
// glowing shop sign with text
function signMat(text, col = '#ffd45a', bg = '#10141b') {
  const [c, g] = canvas(1); c.width = 512; c.height = 128;
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const draw = () => {
    g.shadowBlur = 0; g.fillStyle = bg; g.fillRect(0, 0, 512, 128);
    g.strokeStyle = col; g.lineWidth = 6; g.strokeRect(7, 7, 498, 114);
    g.font = '700 78px Rajdhani, Inter, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.shadowColor = col; g.shadowBlur = 18; g.fillStyle = col; g.fillText(text, 256, 68, 460);
    t.needsUpdate = true;
  };
  draw(); CITY.redraw.push(draw);
  const m = new THREE.MeshStandardMaterial({ color: 0x08090c, emissive: 0xffffff, emissiveMap: t, emissiveIntensity: 1, roughness: 0.5 });
  CITY.signs.push(m);
  return m;
}
{
  newMap('city', {
    name: 'QUARTIERE', tag: 'CITTÀ', desc: 'Un incrocio di quartiere: piazza con fontana, vicoli, parcheggio e benzinaio. Quattro edifici da aprire con i crediti per ripararsi all’interno.',
    start: [0, 0, 0], fallback: [-37.5, -37.5], orbit: [47, 27], shot: [-30, 28, 40, 2, 1, -4],
    roads: [[-5, -40, 5, 40], [-40, -5, 40, 5]],
    boxSpots: [[27.5, -17], [9.5, -27], [-23, -37.4], [-37.6, -14], [-23.5, 18], [-11.5, 37.5], [14, 37.6], [37, 16]],
    pickups: {
      equip: [[-22.5, -30], [-9, -25], [9.5, -9.5], [37, -34], [-18.5, 38], [-36.5, 9.5], [10, 28], [36.5, 8.5]],
      health: [[6.3, -13], [-6.3, 13], [-13, 6.3], [13, -6.3], [-22.5, -19.5], [18.5, -18.5], [-30, 18], [30, 27.5]],
      armor: [[-37.5, -37.5], [37, -27], [-37, 24], [38.2, 38.4]],
    },
    power: { jump: [[-29, -11], [29.5, 10]], haste: [[2.5, -35], [-2.5, 35]], ammo: [[-18, 27], [26, -9]], quad: [[22, 20]], god: [[-37.5, -24], [38, 33]] },
  });
  // static decoration is merged into one mesh per material; anything you can bump into goes through addSolid/addBox
  const batch = new Map();
  const put = (geo, mat, x = 0, y = 0, z = 0, ry = 0) => {
    const g = geo.index ? geo.toNonIndexed() : geo;
    if (ry) g.rotateY(ry);
    g.translate(x, y, z);
    if (!batch.has(mat)) batch.set(mat, []);
    batch.get(mat).push(g);
  };
  const std = (color, roughness = 0.8, metalness = 0, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness, metalness, ...extra });
  const CM = {
    asphalt: new THREE.MeshStandardMaterial({ ...surface({ base: '#3c3f45', seam: '#3c3f45', cells: 1, blotch: 0.16 }), bumpScale: 1.4, roughness: 0.88 }),
    outer: std(0x34373c, 0.95),
    sidewalk: new THREE.MeshStandardMaterial({ ...surface({ base: '#a5a39c', seam: '#85837c', cells: 4, blotch: 0.1 }), bumpScale: 1, roughness: 0.85 }),
    plaza: new THREE.MeshStandardMaterial({ ...surface({ base: '#c2b092', seam: '#96846a', cells: 4, blotch: 0.1 }), bumpScale: 1, roughness: 0.8 }),
    fore: new THREE.MeshStandardMaterial({ ...surface({ base: '#8f949a', seam: '#7b8086', cells: 2, blotch: 0.14 }), bumpScale: 1.2, roughness: 0.8 }),
    brick: new THREE.MeshStandardMaterial({ ...surface({ base: '#a25d45', seam: '#7a4332', cells: 8, blotch: 0.1, dirt: 0.2 }), bumpScale: 1.2, roughness: 0.85 }),
    curb: std(0x8a8a86), white: std(0xa9a9a3, 0.8, 0, { polygonOffset: true, polygonOffsetFactor: -2 }),
    cornice: std(0xd9d2c2), plinth: std(0x55585d, 0.7), door: std(0x3d2c1e, 0.6), shutter: std(0x7d8288, 0.5, 0.5),
    leaf: std(0x45733a, 0.95, 0, { flatShading: true }), trunk: std(0x5a4532, 0.9), soil: std(0x3a2e24, 1),
    water: std(0x2c6f8f, 0.05, 0.4, { transparent: true, opacity: 0.85 }), stone: std(0xcfc8b8, 0.7), wood: std(0x7a5234, 0.7),
    carGlass: std(0x0d1218, 0.08, 0.8), tire: std(0x121214, 0.9), hub: std(0xb9bec6, 0.35, 0.8),
    head: new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.96, 0.85).multiplyScalar(1.6), toneMapped: false }),
    tail: new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.12, 0.08).multiplyScalar(1.5), toneMapped: false }),
    amber: new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.75, 0.15).multiplyScalar(1.5), toneMapped: false }),
    paints: [0xb3261e, 0x1f4e8c, 0xd8d8d2, 0x2b2f36, 0x3f6b45, 0xc9a227].map(c => std(c, 0.32, 0.55)),
    bus: std(0xe07a1f, 0.4, 0.4), taxi: std(0xf2f2ee, 0.32, 0.5), dump: std(0x2f5d3a, 0.6, 0.3), kiosk: std(0x26513a, 0.6, 0.3),
    awnR: std(0xa8322a), awnG: std(0x2f6b45), awnB: std(0x27507f), awnY: std(0xd9a441),
    canopy: std(0xe9e9e4, 0.5, 0.1), pump: std(0xc0281f, 0.4, 0.4),
    shelter: std(0x9fc4d8, 0.1, 0.3, { transparent: true, opacity: 0.35 }),
  };
  CM.asphalt.map.repeat.set(16, 16); CM.asphalt.bumpMap.repeat.set(16, 16);
  // ground floors you can walk into: rendered base outside, plaster or tiles inside
  const surf = (base, seam, cells, rough = 0.85, blotch = 0.12) => new THREE.MeshStandardMaterial({ ...surface({ base, seam, cells, blotch }), bumpScale: 1, roughness: rough });
  Object.assign(CM, {
    extA: surf('#b3915a', '#b3915a', 1, 0.9, 0.16), extB: surf('#a56a50', '#a56a50', 1, 0.9, 0.16),
    plaster: surf('#d6cdb8', '#d6cdb8', 1, 0.92), tileW: surf('#d5dade', '#a9b0b7', 6, 0.35), wallGrey: surf('#8b8f93', '#74787c', 2, 0.85, 0.18),
    floorTile: surf('#b3a995', '#8a8170', 4, 0.5), floorShop: surf('#c9ccd0', '#9a9fa5', 4, 0.35), floorGarage: surf('#5d6064', '#4c4f53', 2, 0.7, 0.22),
    ceil: std(0xe4e1d8, 0.95), roofing: std(0x4b4e53, 0.9), rack: std(0x4a4f57, 0.55, 0.45),
    neonG: new THREE.MeshStandardMaterial({ color: 0x06200c, emissive: 0x3dff7a, emissiveIntensity: 3 }),
  });
  {
    const [rc, rg] = canvas(64); rg.fillStyle = '#8b9097'; rg.fillRect(0, 0, 64, 64);
    for (let y = 0; y < 64; y += 16) { rg.fillStyle = 'rgba(0,0,0,.38)'; rg.fillRect(0, y, 64, 3); rg.fillStyle = 'rgba(255,255,255,.2)'; rg.fillRect(0, y + 3, 64, 3); }
    CM.roller = new THREE.MeshStandardMaterial({ map: finishTex(rc), roughness: 0.45, metalness: 0.6 });
  }
  for (const k of ['sidewalk', 'plaza', 'fore']) CM[k].userData.hit = true;
  {
    const [fc, fg] = canvas(64); fg.strokeStyle = '#a8aeb6'; fg.lineWidth = 3;
    fg.beginPath(); fg.moveTo(0, 32); fg.lineTo(32, 0); fg.lineTo(64, 32); fg.lineTo(32, 64); fg.closePath(); fg.stroke();
    CM.fence = new THREE.MeshStandardMaterial({ map: finishTex(fc), alphaTest: 0.4, side: THREE.DoubleSide, roughness: 0.5, metalness: 0.6 });
    // shop windows: warm interior with shelf silhouettes, lit at night
    const [gc, gg] = canvas(256); const gr = gg.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, '#fff3d6'); gr.addColorStop(1, '#8a6a3c');
    gg.fillStyle = gr; gg.fillRect(0, 0, 256, 256);
    for (let y = 60; y < 256; y += 62) { gg.fillStyle = 'rgba(20,14,8,.75)'; gg.fillRect(0, y, 256, 6); for (let x = 6; x < 250; x += rand(14, 30)) { gg.fillStyle = `rgba(${(rand(20, 120)) | 0},${(rand(20, 90)) | 0},${(rand(10, 70)) | 0},.8)`; const h = rand(14, 40); gg.fillRect(x, y - h, rand(8, 18), h); } }
    CITY.glass = new THREE.MeshStandardMaterial({ color: 0x0c1118, roughness: 0.08, metalness: 0.7, emissive: 0xffd9a0, emissiveMap: finishTex(gc), emissiveIntensity: 0.25 });
    CITY.pool = new THREE.MeshBasicMaterial({ map: glowTex, color: 0xffc98a, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false });
  }
  const FAC = [['#d9b36a', '#3f6a4a'], ['#c98566', '#5a4332'], ['#cfc9bb', '#3c5a78'], ['#e0c9a0', '#7a2e2a']].map(([w, sh]) => {
    const m = new THREE.MeshStandardMaterial({ ...facadeTex(w, sh), emissive: 0xffd9a0, emissiveIntensity: 0.12, roughness: 0.88 });
    CITY.facades.push(m); return m;
  });

  // ---- ground: asphalt everywhere, raised paving on the blocks, road markings
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), CM.asphalt);
  floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; B.root.add(floor); B.meshes.push(floor);
  const outer = new THREE.Mesh(new THREE.PlaneGeometry(320, 320), CM.outer);
  outer.rotation.x = -Math.PI / 2; outer.position.y = -0.04; outer.receiveShadow = true; B.root.add(outer);
  const slab = (x0, z0, x1, z1, mat, h = 0.07, tile = 4) => put(boxUV(new THREE.BoxGeometry(x1 - x0, h, z1 - z0), tile), mat, (x0 + x1) / 2, h / 2, (z0 + z1) / 2);
  slab(-40, -40, -5, -5, CM.sidewalk);
  slab(5, -40, 40, -5, CM.plaza, 0.07, 3);
  slab(-40, 5, -5, 7.5, CM.sidewalk); slab(-7.5, 7.5, -5, 40, CM.sidewalk);
  slab(5, 5, 40, 7.5, CM.sidewalk); slab(5, 7.5, 7.5, 40, CM.sidewalk);
  slab(7.5, 7.5, 40, 40, CM.fore, 0.04);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    put(new THREE.BoxGeometry(35, 0.1, 0.24), CM.curb, sx * 22.5, 0.05, sz * 5.02);
    put(new THREE.BoxGeometry(0.24, 0.1, 35), CM.curb, sx * 5.02, 0.05, sz * 22.5);
  }
  const mark = (w, d, x, z, mat = CM.white, y = 0.012) => put(new THREE.PlaneGeometry(w, d).rotateX(-Math.PI / 2), mat, x, y, z);
  for (const s of [-1, 1]) {
    for (let t = 11; t < 39; t += 4) { mark(0.16, 2, 0, s * t); mark(2, 0.16, s * t, 0); }
    for (let k = -4; k <= 4; k++) { mark(0.5, 2.6, k, s * 7); mark(2.6, 0.5, s * 7, k); }
  }
  for (const z of [13, 23]) for (let i = 0; i <= 10; i++) mark(0.12, 5, -36.6 + i * 2.7, z);
  put(new THREE.CylinderGeometry(0.5, 0.5, 0.02, 20), mats.trim, 1.6, 0.012, 1.3);
  put(new THREE.CylinderGeometry(0.5, 0.5, 0.02, 20), mats.trim, -2.4, 0.012, -19);
  const blot = (mat, x, z, w, d, y) => put(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2).rotateY(rand(0, 6.28)).scale(w, 1, d), mat, x, y, z);
  for (const [x, z, w, d, y] of [[-2, 24, 3, 2, 0.014], [3, -9, 2.4, 1.6, 0.014], [-22, 2, 3, 1.8, 0.014], [-22.5, -27, 2, 3, 0.085], [-33, -37.5, 3, 1.6, 0.085], [-20, 18, 3, 2.2, 0.014], [27, 13, 2.4, 1.8, 0.055], [12, -20, 2.6, 2, 0.085]]) blot(decoMats.puddle, x, z, w, d, y);
  for (const [x, z, w, d, y] of [[-19, 13, 2, 2, 0.013], [-29.8, 13, 2.2, 2.2, 0.013], [-24.4, 23, 2, 2.4, 0.013], [22, 14.5, 3, 2, 0.053], [24, 20, 3, 3, 0.053], [2.5, -22, 3, 6, 0.013], [-37.5, -27, 3, 4, 0.083], [-25, 30, 3, 3, 0.013], [0, 0, 4, 4, 0.013]]) blot(decoMats.stain, x, z, w, d, y);

  // ---- buildings
  // `base` lifts the facade off the ground for buildings with a hollow ground floor
  const bld = (x, z, w, h, d, mat, base = 0) => {
    const m = new THREE.Mesh(facadeGeo(w, h - base, d), mat); m.position.set(x, (h + base) / 2, z); addSolid(m);
    for (const s of [-1, 1]) {
      put(new THREE.BoxGeometry(w + 0.3, 0.5, 0.3), CM.cornice, x, h + 0.1, z + s * d / 2);
      put(new THREE.BoxGeometry(0.3, 0.5, d + 0.3), CM.cornice, x + s * w / 2, h + 0.1, z);
    }
    put(new THREE.BoxGeometry(1.4, 0.9, 1), CM.shutter, x + rand(-w / 4, w / 4), h + 0.45, z + rand(-d / 4, d / 4));
    put(new THREE.CylinderGeometry(0.03, 0.03, 2.6, 6), mats.trim, x + rand(-w / 3, w / 3), h + 1.3, z + rand(-d / 3, d / 3));
    return { x, z, w, h, d };
  };
  // place geometry on a wall: local +z points away from the wall, `a` runs along it
  const onFace = (b, side) => (geo, mat, a, y, out = 0) => {
    if (side === 'S') put(geo, mat, b.x + a, y, b.z + b.d / 2 + out, 0);
    else if (side === 'N') put(geo, mat, b.x - a, y, b.z - b.d / 2 - out, Math.PI);
    else if (side === 'E') put(geo, mat, b.x + b.w / 2 + out, y, b.z - a, Math.PI / 2);
    else put(geo, mat, b.x - b.w / 2 - out, y, b.z + a, -Math.PI / 2);
  };
  const faceLen = (b, side) => side === 'S' || side === 'N' ? b.w : b.d;
  // awning and glowing sign over a shop front
  const front = (b, side, a, len, text, awn, col) => {
    const F = onFace(b, side);
    if (awn) F(new THREE.BoxGeometry(len + 0.2, 0.06, 1.5).rotateX(0.32), awn, a, 3.05, 0.8);
    if (text) { F(new THREE.BoxGeometry(4, 1, 0.1), mats.trim, a, 3.72, 0.05); F(new THREE.PlaneGeometry(3.7, 0.92), signMat(text, col), a, 3.72, 0.11); }
  };
  const shop = (b, side, a, len, text, awn, col) => {
    const F = onFace(b, side);
    F(new THREE.BoxGeometry(len + 0.3, 3.1, 0.12), mats.trim, a, 1.55, 0.02);
    F(new THREE.PlaneGeometry(len - 0.3, 2.3), CITY.glass, a, 1.6, 0.09);
    F(new THREE.BoxGeometry(len + 0.3, 0.4, 0.2), CM.plinth, a, 0.2, 0.06);
    const n = Math.max(1, Math.round(len / 2.6));
    for (let k = 0; k <= n; k++) F(new THREE.BoxGeometry(0.12, 2.4, 0.16), mats.trim, a - len / 2 + k * len / n, 1.6, 0.08);
    F(new THREE.BoxGeometry(1.1, 2.3, 0.1), CM.door, a + len / 2 - 0.85, 1.5, 0.12);
    front(b, side, a, len, text, awn, col);
  };
  const balcony = (b, side, a, fl) => {
    const F = onFace(b, side), y = fl * 3.2 + 0.55;
    F(new THREE.BoxGeometry(2.4, 0.14, 0.9), CM.cornice, a, y, 0.45);
    F(new THREE.BoxGeometry(2.4, 0.05, 0.05), mats.trim, a, y + 0.95, 0.87);
    for (let k = -1.15; k <= 1.16; k += 0.23) F(new THREE.BoxGeometry(0.03, 0.9, 0.03), mats.trim, a + k, y + 0.5, 0.87);
    for (const s of [-1, 1]) F(new THREE.BoxGeometry(0.05, 0.05, 0.9), mats.trim, a + s * 1.18, y + 0.95, 0.45);
  };
  // balconies on a third of the windows, a drainpipe at one end
  const dress = (b, side, from = 2) => {
    const len = faceLen(b, side), nb = Math.max(1, Math.round(len / 3.2)), nf = Math.round(b.h / 3.2);
    for (let f = from; f < nf; f++) for (let i = 0; i < nb; i++) if ((i + f * 2) % 3 === 0) balcony(b, side, -len / 2 + (i + 0.5) * len / nb, f);
    onFace(b, side)(new THREE.CylinderGeometry(0.06, 0.06, b.h, 8), mats.pillar, len / 2 - 0.25, b.h / 2, 0.08);
  };
  const ring = {};
  const HS = [12.8, 9.6, 16, 12.8, 16, 9.6];
  [[-41, -30], [-30, -19], [-19, -7.5], [7.5, 19], [19, 30], [30, 41]].forEach(([a, b], i) => {
    const c = (a + b) / 2, w = b - a;
    ring['N' + i] = bld(c, -43, w, HS[i], 6, FAC[i % 4]);
    ring['S' + i] = bld(c, 43, w, HS[(i + 2) % 6], 6, FAC[(i + 1) % 4]);
    ring['W' + i] = bld(-43, c, 6, HS[(i + 3) % 6], w, FAC[(i + 2) % 4]);
    ring['E' + i] = bld(43, c, 6, HS[(i + 4) % 6], w, FAC[(i + 3) % 4]);
    dress(ring['N' + i], 'S'); dress(ring['S' + i], 'N'); dress(ring['W' + i], 'E'); dress(ring['E' + i], 'W');
  });
  // the streets carry on past the roadblocks
  for (const s of [-1, 1]) for (const side of [-1, 1]) for (const [t, h, k] of [[54, 16, 0], [69, 12.8, 2]]) {
    put(facadeGeo(11, h, 14), FAC[(k + (s + side + 2)) % 4], side * 13, h / 2, s * t);
    put(facadeGeo(14, h, 11), FAC[(k + 1 + (s + side + 2)) % 4], s * t, h / 2, side * 13);
  }

  // ---- enterable buildings: a hollow ground floor shut behind roller shutters until you pay for it.
  // Doors let everyone through; windows have a sill that only zombies (and a jumping player) get over.
  B.houses = [];
  const SIDES = { S: [0, 4], N: [Math.PI, 5], E: [Math.PI / 2, 0], W: [-Math.PI / 2, 1] };   // yaw, box face looking outward
  const tiled = (w, d, tile) => {
    const geo = new THREE.PlaneGeometry(w, d), pos = geo.attributes.position, uv = geo.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / tile, pos.getY(i) / tile);
    return geo;
  };
  const house = (b, { name, cost, H = 3.2, ext, int, floor, roof, ops, lights }) => {
    // openings are 3 m high: enemy collisions reach 2.9 m
    const T = 0.3, TOP = 3, x0 = b.x - b.w / 2, x1 = b.x + b.w / 2, z0 = b.z - b.d / 2, z1 = b.z + b.d / 2;
    const h = { name, cost, open: false, t: 0, shutters: [], doors: [], lights: [], fill: new THREE.Box3(new V3(x0, 0, z0), new V3(x1, TOP, z1)) };
    const at = (side, a, out = 0) => side === 'S' ? [b.x + a, z1 + out] : side === 'N' ? [b.x - a, z0 - out] : side === 'E' ? [x1 + out, b.z - a] : [x0 - out, b.z + a];
    const piece = (side, a0, a1, y0, y1) => {
      if (a1 - a0 < 0.02 || y1 - y0 < 0.02) return;
      const ns = side === 'S' || side === 'N', len = a1 - a0;
      const mm = Array(6).fill(ext); mm[SIDES[side][1] ^ 1] = int;
      const m = new THREE.Mesh(boxUV(new THREE.BoxGeometry(ns ? len : T, y1 - y0, ns ? T : len), 3, (y0 + y1) / 2), mm);
      const [px, pz] = at(side, (a0 + a1) / 2, -T / 2);
      m.position.set(px, (y0 + y1) / 2, pz); addSolid(m);
    };
    const tag = signMat(`APRI · ${cost}`, '#ff6a5a');
    for (const side of 'SNEW') {
      const L = faceLen(b, side), end = L / 2 - (side === 'E' || side === 'W' ? T : 0), F = onFace(b, side);
      let a = -end;
      for (const [, c, w, kind] of ops.filter(o => o[0] === side).sort((p, q) => p[1] - q[1])) {
        const sill = kind === 'win' ? 1 : 0;
        piece(side, a, c - w / 2, 0, H); piece(side, c - w / 2, c + w / 2, TOP, H); piece(side, c - w / 2, c + w / 2, 0, sill);
        if (sill) F(new THREE.BoxGeometry(w + 0.2, 0.08, T + 0.24), CM.stone, c, sill + 0.04, -T / 2);
        for (const s of [-1, 1]) F(new THREE.BoxGeometry(0.1, TOP - sill, T + 0.08), mats.trim, c + s * (w / 2 - 0.05), (TOP + sill) / 2, -T / 2);
        F(new THREE.BoxGeometry(w, 0.1, T + 0.08), mats.trim, c, TOP - 0.05, -T / 2);
        F(new THREE.BoxGeometry(w + 0.1, 0.24, 0.2), CM.shutter, c, TOP + 0.1, 0.1);
        // roller shutter hanging from the lintel: it rolls up when the building is bought
        const sw = w - 0.2, sh = TOP - sill - 0.1, geo = new THREE.BoxGeometry(sw, sh, 0.06).translate(0, -sh / 2, 0), uv = geo.attributes.uv;
        for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * sw, uv.getY(i) * sh * 1.6);
        const m = new THREE.Mesh(geo, CM.roller), [sx, sz] = at(side, c, -0.1);
        m.position.set(sx, TOP - 0.1, sz); m.rotation.y = SIDES[side][0]; m.castShadow = m.receiveShadow = true;
        if (!sill) {
          const lbl = new THREE.Mesh(new THREE.PlaneGeometry(1.7, 0.44), tag); lbl.position.set(0, -1.15, 0.04); m.add(lbl);
          h.doors.push(at(side, c, 0.5));
        }
        B.root.add(m); m.updateMatrixWorld(true); B.meshes.push(m); h.shutters.push(m);
        a = c + w / 2;
      }
      piece(side, a, end, 0, H);
    }
    put(tiled(b.w - 2 * T, b.d - 2 * T, 3).rotateX(-Math.PI / 2), floor, b.x, 0.085, b.z);
    if (roof) {
      const [top, mat] = roof, m = new THREE.Mesh(boxUV(new THREE.BoxGeometry(b.w, top - H, b.d), 4, (top + H) / 2), [mat, mat, CM.roofing, CM.ceil, mat, mat]);
      m.position.set(b.x, (top + H) / 2, b.z); addSolid(m);
    } else {
      put(new THREE.PlaneGeometry(b.w - 2 * T, b.d - 2 * T).rotateX(Math.PI / 2), CM.ceil, b.x, H - 0.01, b.z);
      for (const s of [-1, 1]) { put(new THREE.BoxGeometry(b.w + 0.16, 0.22, 0.14), CM.cornice, b.x, H, b.z + s * (b.d / 2 + 0.02)); put(new THREE.BoxGeometry(0.14, 0.22, b.d + 0.16), CM.cornice, b.x + s * (b.w / 2 + 0.02), H, b.z); }
    }
    for (const [lx, lz] of lights) {
      put(new THREE.BoxGeometry(1.5, 0.06, 0.34), mats.trim, lx, H - 0.04, lz); put(new THREE.PlaneGeometry(1.4, 0.24).rotateX(Math.PI / 2), decoMats.lamp, lx, H - 0.075, lz);
      const l = new THREE.PointLight(0xffe6c4, 0, 14, 1.6); l.position.set(lx, H - 0.5, lz); B.root.add(l); h.lights.push(l);
    }
    B.boxes.push(h.fill); B.houses.push(h);
    return h;
  };
  // shop furniture
  const stock = [...CM.paints, CM.cornice, CM.awnY, CM.awnR, CM.awnB];
  // shelving along x or z: a steel core with rows of stock on the open sides (-1 / +1 across the run)
  const shelf = (x, z, len, alongX, h = 1.7, sides = [-1, 1]) => {
    const P = (t, o) => alongX ? [x + t, z + o] : [x + o, z + t], G = (l, hh, dd) => new THREE.BoxGeometry(alongX ? l : dd, hh, alongX ? dd : l);
    addBox(x, z, alongX ? len : 0.3, h, alongX ? 0.3 : len, CM.rack, 0, { r: 0.02, tile: 0 });
    const lo = sides.includes(-1) ? 0.39 : 0.17, hi = sides.includes(1) ? 0.39 : 0.17;
    B.boxes.push(new THREE.Box3(new V3(x - (alongX ? len / 2 : lo), 0, z - (alongX ? lo : len / 2)), new V3(x + (alongX ? len / 2 : hi), h, z + (alongX ? hi : len / 2))));
    put(G(len + 0.04, 0.05, 0.8), CM.rack, x, h + 0.02, z);
    for (const s of sides) for (let y = 0.3; y < h - 0.3; y += 0.48) {
      const [bx, bz] = P(0, s * 0.27); put(G(len, 0.03, 0.24), CM.cornice, bx, y, bz);
      for (let t = -len / 2 + 0.08; t < len / 2 - 0.3;) {
        const w = rand(0.14, 0.32), hh = rand(0.16, 0.34), [px, pz] = P(t + w / 2, s * 0.27);
        if (Math.random() < 0.85) put(G(w, hh, 0.18), stock[(Math.random() * stock.length) | 0], px, y + 0.015 + hh / 2, pz);
        t += w + rand(0.02, 0.1);
      }
    }
  };
  // glass-fronted fridge against a wall, `face` is the way the doors look
  const fridge = (x, z, len, face) => {
    const ns = face === 'N' || face === 'S', k = { x, z, w: ns ? len : 0.75, d: ns ? 0.75 : len }, F = onFace(k, face);
    addBox(x, z, k.w, 2.1, k.d, mats.trim, 0, { r: 0.03, tile: 0 });
    F(new THREE.PlaneGeometry(len - 0.2, 1.6), CITY.glass, 0, 1.15, 0.012);
    for (let t = -len / 2 + 0.1; t <= len / 2 - 0.09; t += (len - 0.2) / Math.max(1, Math.round(len / 1.1))) F(new THREE.BoxGeometry(0.06, 1.6, 0.05), CM.rack, t, 1.15, 0.03);
    F(new THREE.BoxGeometry(len - 0.2, 0.05, 0.04), decoMats.lamp, 0, 2, 0.02);
  };
  const counter = (x, z, w, d, top = CM.stone) => {
    addBox(x, z, w, 1, d, CM.wood, 0, { r: 0.03, tile: 0 });
    put(new THREE.BoxGeometry(w + 0.12, 0.06, d + 0.12), top, x, 1.03, z);
    put(new THREE.BoxGeometry(0.42, 0.26, 0.36), mats.trim, x, 1.19, z + (d > w ? d / 2 - 0.5 : 0)); put(new THREE.BoxGeometry(0.3, 0.2, 0.02), decoMats.screen, x, 1.42, z + (d > w ? d / 2 - 0.5 : 0));
  };

  // ---- props
  // quarter-turn helper: local (lx, lz) -> world, plus a box whose footprint swaps on odd turns
  const turned = (x, z, rot) => {
    const R = -rot * Math.PI / 2, c = Math.round(Math.cos(R)), s = Math.round(Math.sin(R)), odd = rot % 2 !== 0;
    const W = (lx, lz) => [x + lx * c + lz * s, z - lx * s + lz * c];
    return {
      box: (lx, lz, w, h, d, m, y, r = 0.15) => { const [wx, wz] = W(lx, lz); return addBox(wx, wz, odd ? d : w, h, odd ? w : d, m, y, { r, tile: 0 }); },
      put: (geo, m, lx, y, lz) => { const [wx, wz] = W(lx, lz); put(geo, m, wx, y, wz, R); },
    };
  };
  // vehicles: rot 0 = nose toward -z, each step is a quarter turn
  const car = (x, z, rot, paint, kind = 'car') => {
    const T = turned(x, z, rot);
    const S = { car: [1.8, 4.3, 0.33, 1.35], taxi: [1.8, 4.3, 0.33, 1.35], van: [1.95, 5, 0.36, 1.6], bus: [2.6, 10.5, 0.5, 3.4] }[kind], [w, len, wr, wz] = S;
    if (kind === 'bus') {
      T.box(0, 0, w, 2.65, len, paint, 0.35, 0.2);
      T.put(new THREE.BoxGeometry(w + 0.04, 0.95, len - 1), CM.carGlass, 0, 2.15, 0);
      T.put(new THREE.BoxGeometry(w - 0.3, 1.1, 0.06), CM.carGlass, 0, 2.05, -len / 2 - 0.01);
      T.put(new THREE.PlaneGeometry(1.6, 0.3).rotateY(Math.PI), signMat('64 CENTRO', '#ffb347'), 0, 2.78, -len / 2 - 0.02);
    } else if (kind === 'van') {
      T.box(0, 0, w, 1.8, len, paint, 0.35, 0.18);
      T.put(new THREE.BoxGeometry(w - 0.2, 0.7, 0.06), CM.carGlass, 0, 1.65, -len / 2 - 0.01);
      for (const s of [-1, 1]) T.put(new THREE.BoxGeometry(0.06, 0.6, 1), CM.carGlass, s * (w / 2 + 0.005), 1.65, -len / 2 + 0.9);
    } else {
      T.box(0, 0, w, 0.62, len, paint, 0.3, 0.2);
      T.box(0, 0.25, w - 0.18, 0.55, 2.3, paint, 0.92, 0.2);
      for (const s of [-1, 1]) {
        T.put(new THREE.BoxGeometry(w - 0.5, 0.36, 0.05), CM.carGlass, 0, 1.2, 0.25 + s * 1.14);
        T.put(new THREE.BoxGeometry(0.05, 0.34, 1.75), CM.carGlass, s * (w / 2 - 0.08), 1.2, 0.25);
      }
      if (kind === 'taxi') T.put(new THREE.BoxGeometry(0.5, 0.17, 0.22), CM.amber, 0, 1.6, 0.1);
    }
    const yb = kind === 'car' || kind === 'taxi' ? 0.72 : 0.9;
    for (const s of [-1, 1]) {
      for (const lz of [-wz, wz]) {
        T.put(new THREE.CylinderGeometry(wr, wr, 0.24, 16).rotateZ(Math.PI / 2), CM.tire, s * (w / 2 - 0.08), wr, lz);
        T.put(new THREE.CylinderGeometry(wr * 0.55, wr * 0.55, 0.26, 12).rotateZ(Math.PI / 2), CM.hub, s * (w / 2 - 0.08), wr, lz);
      }
      T.put(new THREE.BoxGeometry(0.36, 0.14, 0.06), CM.head, s * (w / 2 - 0.3), yb, -len / 2 - 0.01);
      T.put(new THREE.BoxGeometry(0.34, 0.12, 0.06), CM.tail, s * (w / 2 - 0.3), yb, len / 2 + 0.01);
    }
    for (const s of [-1, 1]) T.put(rbox(w + 0.04, 0.2, 0.16, 0.06), mats.trim, 0, 0.45, s * (len / 2 - 0.04));
  };
  const tree = (x, z, s = 1) => {
    addBox(x, z, 1.5, 0.5, 1.5, mats.concrete, 0, { r: 0.08, tile: 2 });
    put(new THREE.BoxGeometry(1.2, 0.06, 1.2), CM.soil, x, 0.5, z);
    const t = new THREE.Mesh(new THREE.CylinderGeometry(0.14 * s, 0.2 * s, 3.2 * s, 10), CM.trunk); t.position.set(x, 0.5 + 1.6 * s, z); addSolid(t);
    for (const [dx, dy, dz, r] of [[0, 0, 0, 1.5], [0.8, -0.3, 0.3, 1.1], [-0.7, -0.2, -0.4, 1.2], [0.1, 0.7, -0.2, 1.1], [-0.2, -0.4, 0.8, 1]])
      put(new THREE.IcosahedronGeometry(r * s, 1), CM.leaf, x + dx * s, 0.5 + 3.7 * s + dy * s, z + dz * s, rand(0, 6));
  };
  // street lamp with its arm reaching toward (ax, az); the ground pool only shows at night
  const lamp = (x, z, ax, az) => {
    const ry = Math.atan2(ax, az);
    put(new THREE.CylinderGeometry(0.07, 0.1, 6, 10), mats.pillar, x, 3, z);
    put(new THREE.CylinderGeometry(0.16, 0.2, 0.5, 10), mats.trim, x, 0.25, z);
    put(new THREE.BoxGeometry(0.08, 0.08, 1.6), mats.pillar, x + ax * 0.8, 5.95, z + az * 0.8, ry);
    put(new THREE.BoxGeometry(0.34, 0.12, 0.7), mats.trim, x + ax * 1.5, 5.9, z + az * 1.5, ry);
    put(new THREE.PlaneGeometry(0.26, 0.56).rotateX(Math.PI / 2), decoMats.lamp, x + ax * 1.5, 5.83, z + az * 1.5, ry);
    put(new THREE.PlaneGeometry(10, 10).rotateX(-Math.PI / 2), CITY.pool, x + ax * 1.5, 0.1, z + az * 1.5);
  };
  const bench = (x, z, rot) => {
    const T = turned(x, z, rot);
    T.box(0, 0, 1.9, 0.45, 0.5, CM.wood, 0, 0.05);
    T.put(new THREE.BoxGeometry(1.9, 0.5, 0.07), CM.wood, 0, 0.75, 0.24);
  };
  const dumpster = (x, z, rot) => {
    const T = turned(x, z, rot);
    T.box(0, 0, 2, 1.15, 1.1, CM.dump, 0.1, 0.08);
    T.put(new THREE.BoxGeometry(2.06, 0.08, 1.16), mats.trim, 0, 1.29, 0);
  };
  const table = (x, z, awn) => {
    const t = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.42, 0.76, 14), CM.stone); t.position.set(x, 0.38 + 0.07, z); addSolid(t);
    for (const [dx, dz] of [[0.95, 0], [-0.95, 0]]) { put(new THREE.BoxGeometry(0.42, 0.05, 0.42), mats.trim, x + dx, 0.52, z + dz); put(new THREE.BoxGeometry(0.42, 0.45, 0.05), mats.trim, x + dx * 1.2, 0.76, z); put(new THREE.CylinderGeometry(0.03, 0.03, 0.45, 6), mats.trim, x + dx, 0.29, z + dz); }
    put(new THREE.CylinderGeometry(0.03, 0.03, 2.5, 6), mats.trim, x, 1.3, z);
    put(new THREE.ConeGeometry(1.5, 0.5, 8), awn, x, 2.7, z);
  };
  const scooter = (x, z, ry, paint) => {
    const g = (geo, m, lx, y, lz) => put(geo, m, x + lx * Math.cos(ry) + lz * Math.sin(ry), y, z - lx * Math.sin(ry) + lz * Math.cos(ry), ry);
    g(rbox(0.36, 0.5, 0.9, 0.12), paint, 0, 0.55, 0.2); g(rbox(0.3, 0.1, 0.7, 0.04), mats.trim, 0, 0.84, 0.3);
    g(rbox(0.34, 0.7, 0.12, 0.05), paint, 0, 0.7, -0.45); g(new THREE.BoxGeometry(0.6, 0.04, 0.04), mats.trim, 0, 1.08, -0.5);
    for (const lz of [-0.6, 0.65]) g(new THREE.CylinderGeometry(0.22, 0.22, 0.12, 14).rotateZ(Math.PI / 2), CM.tire, 0, 0.22, lz);
  };

  // street furniture shared by the whole map
  for (const s of [-1, 1]) for (const t of [14, 30]) for (const side of [-1, 1]) { lamp(side * 6.2, s * t, -side, 0); lamp(s * t, side * 6.2, 0, -side); }
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    put(new THREE.CylinderGeometry(0.06, 0.08, 3.4, 8), mats.pillar, sx * 5.7, 1.7, sz * 5.7);
    put(new THREE.BoxGeometry(0.3, 0.9, 0.3), mats.trim, sx * 5.7, 3.7, sz * 5.7);
    put(new THREE.SphereGeometry(0.09, 10, 8), CM.tail, sx * 5.7 - sx * 0.16, 3.98, sz * 5.7);
    put(new THREE.SphereGeometry(0.09, 10, 8), CM.amber, sx * 5.7, 3.7, sz * 5.7 - sz * 0.16);
  }
  // roadblocks where the streets leave the map: jersey barriers, a chain-link fence and a sign
  for (const s of [-1, 1]) {
    for (const k of [-5.4, -1.8, 1.8, 5.4]) {
      addBox(k, s * 38.3, 3.2, 0.9, 0.6, mats.concrete, 0, { r: 0.12, tile: 2 });
      addBox(s * 38.3, k, 0.6, 0.9, 3.2, mats.concrete, 0, { r: 0.12, tile: 2 });
      put(new THREE.BoxGeometry(2.6, 0.18, 0.62), CM.awnR, k, 0.6, s * 38.3); put(new THREE.BoxGeometry(0.62, 0.18, 2.6), CM.awnR, s * 38.3, 0.6, k);
    }
    addBox(0, s * 39.75, 15, 3.2, 0.08, CM.fence, 0, { r: 0.01, tile: 0.25 }).castShadow = false;
    addBox(s * 39.75, 0, 0.08, 3.2, 15, CM.fence, 0, { r: 0.01, tile: 0.25 }).castShadow = false;
    for (let k = -7.5; k <= 7.5; k += 3) { put(new THREE.CylinderGeometry(0.05, 0.05, 3.3, 8), mats.pillar, k, 1.65, s * 39.75); put(new THREE.CylinderGeometry(0.05, 0.05, 3.3, 8), mats.pillar, s * 39.75, 1.65, k); }
    put(new THREE.PlaneGeometry(3.6, 0.9), signMat('STRADA CHIUSA', '#ff6a5a'), 0, 2.2, s * 39.68, s > 0 ? Math.PI : 0);
    put(new THREE.PlaneGeometry(3.6, 0.9), signMat('STRADA CHIUSA', '#ff6a5a'), s * 39.68, 2.2, 0, s > 0 ? -Math.PI / 2 : Math.PI / 2);
  }
  // traffic left in the streets
  car(2.6, -22, 0, CM.bus, 'bus'); car(-2.5, -33, 2, CM.paints[1]);
  car(-2.4, 16, 0, CM.taxi, 'taxi'); car(2.5, 29, 2, CM.paints[0]);
  car(-26, 2.4, 1, CM.paints[3]); car(-15, -2.4, 3, CM.paints[2], 'van');
  car(17, -2.4, 3, CM.paints[5]); car(30, 2.5, 1, CM.paints[4]);

  // ---- north-west: two apartment blocks, back alleys, a newsstand and the bus stop
  const A = bld(-29, -26, 10, 12.8, 18, FAC[0], 3.2), Bb = bld(-16.5, -28.5, 9, 9.6, 13, FAC[1], 3.2);
  front(A, 'S', 0, 8, 'ALIMENTARI', CM.awnG, '#8dffb0');
  front(Bb, 'E', 0, 9, 'FARMACIA', null, '#5dff8a');
  front(Bb, 'S', 0, 6, 'TABACCHI', CM.awnB, '#ffd45a');
  // grocer: front door and window on the street, back door on the alley, a window on each side
  house(A, { name: 'ALIMENTARI', cost: 3500, ext: CM.extA, int: CM.plaster, floor: CM.floorTile, lights: [[-29, -21.5], [-29, -30.5]],
    ops: [['S', 2, 2.6, 'door'], ['S', -2, 2.6, 'win'], ['N', 2, 2.6, 'door'], ['E', 2, 2.6, 'win'], ['W', 4, 2.6, 'win']] });
  shelf(-31, -28.5, 7, false); shelf(-28, -28.5, 7, false); shelf(-33.5, -29, 8, false, 2.1, [1]);
  fridge(-27, -34.32, 4.6, 'S'); counter(-25.3, -21.5, 1, 3.2);
  for (const [x, z] of [[-31.6, -19.3], [-30.3, -19.3], [-33, -19.6]]) {
    addBox(x, z, 1.1, 0.55, 0.8, mats.crate, 0, { r: 0.04, tile: 0 });
    for (let i = 0; i < 9; i++) put(new THREE.IcosahedronGeometry(0.1, 1), stock[(x * 3 + i) & 1 ? 0 : 5], x - 0.36 + (i % 3) * 0.36, 0.62, z - 0.22 + ((i / 3) | 0) * 0.22);
  }
  // pharmacy with the tobacconist's door round the corner
  house(Bb, { name: 'FARMACIA', cost: 3000, ext: CM.extB, int: CM.tileW, floor: CM.floorShop, lights: [[-16.5, -28.5]],
    ops: [['E', -0.5, 2.6, 'door'], ['E', 3.5, 2.6, 'win'], ['E', -4.5, 2.6, 'win'], ['S', -0.5, 2.6, 'door'], ['W', -1.5, 2.6, 'win']] });
  counter(-18.5, -30, 0.7, 7, CM.cornice);
  shelf(-20.52, -33, 3, false, 2.2, [1]); shelf(-20.52, -27.2, 2.4, false, 2.2, [1]); shelf(-15.6, -34.3, 5.6, true, 2.2, [1]); shelf(-15, -25.3, 2, true, 1.25);
  put(new THREE.BoxGeometry(0.9, 0.3, 0.06), CM.neonG, -20.66, 2.55, -24.2, Math.PI / 2); put(new THREE.BoxGeometry(0.3, 0.9, 0.06), CM.neonG, -20.66, 2.55, -24.2, Math.PI / 2);
  dress(A, 'S'); dress(A, 'E', 2); dress(Bb, 'E'); dress(Bb, 'S'); dress(Bb, 'W', 2);
  {
    const F = onFace(Bb, 'E');   // pharmacy cross
    F(new THREE.BoxGeometry(0.9, 0.3, 0.1), mats.neonBlue, 3.2, 5.2, 0.5); F(new THREE.BoxGeometry(0.3, 0.9, 0.1), mats.neonBlue, 3.2, 5.2, 0.5); F(new THREE.BoxGeometry(0.08, 0.08, 0.5), mats.trim, 3.2, 5.2, 0.25);
    for (const [b, side, a] of [[A, 'N', -3], [A, 'W', -5], [A, 'W', 0.5], [Bb, 'N', 1], [A, 'E', 6]]) onFace(b, side)(new THREE.BoxGeometry(0.9, 0.6, 0.4), CM.shutter, a, 3.9, 0.2);
    for (const [b, side] of [[A, 'E'], [Bb, 'W'], [A, 'N'], [A, 'W']]) { const G = onFace(b, side); G(new THREE.BoxGeometry(0.34, 0.14, 0.3), mats.trim, 0, 3.5, 0.15); G(new THREE.PlaneGeometry(0.26, 0.22).rotateX(Math.PI / 2), decoMats.lamp, 0, 3.42, 0.17); }
  }
  dumpster(-29, -38.55, 0); dumpster(-26.6, -38.55, 0); dumpster(-38.55, -29, 1); dumpster(-38.55, -20, 1);
  for (const [x, z, y] of [[-38.7, -33.5, 0], [-37.5, -34, 0], [-38.7, -33.5, 1.2], [-18, -38.8, 0], [-13.5, -38.8, 0], [-13.5, -38.8, 1.2]]) addBox(x, z, 1.2, 1.2, 1.2, mats.crate, y + 0.07, { r: 0.06, tile: 0 });
  // newsstand
  addBox(-10.5, -12.5, 3, 2.6, 2.4, CM.kiosk, 0.07, { r: 0.1, tile: 0 });
  put(new THREE.BoxGeometry(3.7, 0.12, 3.1), CM.dump, -10.5, 2.75, -12.5);
  put(new THREE.PlaneGeometry(2.4, 0.6), signMat('EDICOLA', '#ffe9a8'), -10.5, 2.3, -11.28);
  put(new THREE.PlaneGeometry(2.4, 1.1), CITY.glass, -10.5, 1.35, -11.28);
  for (let i = 0; i < 5; i++) put(new THREE.BoxGeometry(0.4, 0.55, 0.06), CM.paints[i], -11.4 + i * 0.45, 0.6, -11.2);
  // bus stop
  { const m = addBox(-18, -7.3, 3.6, 2.3, 0.1, CM.shelter, 0.07, { r: 0.02, tile: 0 }); m.castShadow = false; }
  put(new THREE.BoxGeometry(3.9, 0.1, 1.6), mats.trim, -18, 2.45, -6.7);
  for (const s of [-1, 1]) put(new THREE.CylinderGeometry(0.05, 0.05, 2.4, 8), mats.pillar, -18 + s * 1.8, 1.27, -6.05);
  put(new THREE.BoxGeometry(2.6, 0.08, 0.4), CM.wood, -18, 0.55, -6.95);
  put(new THREE.CylinderGeometry(0.04, 0.04, 2.8, 8), mats.pillar, -15.4, 1.45, -5.6); put(new THREE.BoxGeometry(0.5, 0.5, 0.05), CM.awnB, -15.4, 2.7, -5.6);
  tree(-19, -14.5); tree(-33, -11); tree(-9, -20.5);
  scooter(-13.6, -9.2, 0.15, CM.paints[0]); scooter(-12.6, -9.3, -0.1, CM.paints[4]); scooter(-31, -15.6, 1.4, CM.paints[5]);
  bench(-27.5, -9, 0);

  // ---- north-east: the piazza with its fountain, café tables and a drinks kiosk
  {
    const basin = new THREE.Mesh(new THREE.CylinderGeometry(3.2, 3.3, 0.65, 36), CM.stone); basin.position.set(23, 0.325 + 0.07, -23); addSolid(basin);
    put(new THREE.CylinderGeometry(2.85, 2.85, 0.04, 36), CM.water, 23, 0.74, -23);
    const ped = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.75, 1.9, 16), CM.stone); ped.position.set(23, 1.67, -23); addSolid(ped);
    put(new THREE.CylinderGeometry(1.5, 0.5, 0.4, 24), CM.stone, 23, 2.75, -23);
    put(new THREE.CylinderGeometry(1.38, 1.38, 0.03, 24), CM.water, 23, 2.96, -23);
    put(new THREE.CylinderGeometry(0.16, 0.22, 0.7, 12), CM.stone, 23, 3.3, -23); put(new THREE.SphereGeometry(0.26, 14, 10), CM.stone, 23, 3.8, -23);
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; put(new THREE.PlaneGeometry(0.7, 3.2).rotateX(-Math.PI / 2), CM.cornice, 23 + Math.cos(a) * 5.6, 0.078, -23 + Math.sin(a) * 5.6, -a + Math.PI / 2); }
  }
  tree(13, -13, 1.1); tree(33, -13, 1.1); tree(13, -33, 1.1); tree(33, -33, 1.1);
  bench(23, -15, 2); bench(23, -31, 0); bench(15, -23, 1); bench(31, -23, 3);
  table(17.5, -36.6, CM.awnR); table(23, -36.6, CM.awnG); table(28.5, -36.6, CM.awnY); table(36.8, -24.5, CM.awnB);
  shop(ring.N3, 'S', 0, 8, 'BAR', CM.awnR, '#ffb36b'); shop(ring.N4, 'S', 0, 8, 'PIZZERIA', CM.awnG, '#ff8a7a'); shop(ring.N5, 'S', 0, 8, 'GELATERIA', CM.awnY, '#ffb3e6');
  shop(ring.E1, 'W', 0, 8, 'LIBRERIA', CM.awnB, '#9ad4ff'); shop(ring.E2, 'W', 0, 8, 'FIORI', CM.awnG, '#b6ff9a');
  {
    const k = { x: 35.5, z: -12, w: 5, h: 3.2, d: 4 };
    addBox(k.x, k.z, k.w, k.h - 0.07, k.d, CM.kiosk, 0.07, { r: 0.08, tile: 0 });
    put(new THREE.BoxGeometry(5.6, 0.14, 4.6), CM.dump, k.x, k.h - 0.06, k.z);
    const F = onFace(k, 'W');
    F(new THREE.PlaneGeometry(2.8, 1.2), CITY.glass, 0, 1.7, 0.02); F(new THREE.BoxGeometry(3.2, 0.1, 0.5), CM.stone, 0, 1.05, 0.25);
    F(new THREE.PlaneGeometry(2.6, 0.65), signMat('BIBITE', '#7fd0ff'), 0, 2.72, 0.03);
    F(new THREE.BoxGeometry(3.6, 0.06, 1.3).rotateX(0.3), CM.awnB, 0, 2.3, 0.7);
  }

  // ---- south-west: car park and the mechanic's garage
  for (const [i, z, rot, p] of [[0, 13, 0, 4], [2, 13, 2, 2], [6, 13, 0, 0], [8, 13, 0, 3], [1, 23, 2, 5], [4, 23, 0, 1], [9, 23, 2, 2]]) car(-35.25 + i * 2.7, z, rot, CM.paints[p]);
  car(-14, 32, 1, CM.paints[2], 'van');
  {
    const g = { x: -32, z: 33, w: 12, h: 3.4, d: 12 };
    // mechanic's garage: both roller doors on the car park and a side door
    house(g, { name: 'OFFICINA', cost: 2000, H: 3, ext: CM.brick, int: CM.wallGrey, floor: CM.floorGarage, roof: [g.h, CM.brick], lights: [[-32, 33]],
      ops: [['E', 3, 3.6, 'door'], ['E', -3, 3.6, 'door'], ['N', 3, 2.6, 'door']] });
    car(-31.5, 30, 1, CM.paints[1]);
    addBox(-37.1, 35, 1.1, 0.95, 5, CM.rack, 0, { r: 0.03, tile: 0 }); put(new THREE.BoxGeometry(1.2, 0.07, 5.1), CM.wood, -37.1, 0.98, 35);
    put(new THREE.BoxGeometry(0.06, 1.2, 4.4), mats.trim, -37.66, 1.9, 35);
    for (let i = 0; i < 9; i++) put(new THREE.BoxGeometry(0.04, rand(0.25, 0.6), 0.07), i % 3 ? mats.pillar : CM.awnR, -37.6, 1.9 + rand(-0.2, 0.2), 33.1 + i * 0.47);
    put(new THREE.BoxGeometry(0.4, 0.3, 0.5), CM.awnR, -37.1, 1.17, 33.4); put(new THREE.BoxGeometry(0.3, 0.24, 0.3), mats.pillar, -37.2, 1.14, 36.6);
    shelf(-31.5, 38.3, 6, true, 2.1, [-1]);
    for (const z of [34.7, 37.3]) { addBox(-33.5, z, 0.3, 2.5, 0.3, CM.awnY, 0, { r: 0.03, tile: 0 }); put(new THREE.BoxGeometry(4.2, 0.12, 0.5), CM.awnY, -33.5, 0.16, z + (z < 36 ? 0.75 : -0.75)); }
    for (const [x, z] of [[-36.9, 28.2], [-27, 33]]) { const t = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 1.1, 18), x < -30 ? CM.tire : barrelMats[0]); t.position.set(x, 0.55, z); addSolid(t); }
    for (const s of [-1, 1]) { put(new THREE.BoxGeometry(12.3, 0.4, 0.3), CM.cornice, g.x, 3.5, g.z + s * 6); put(new THREE.BoxGeometry(0.3, 0.4, 12.3), CM.cornice, g.x + s * 6, 3.5, g.z); }
    const F = onFace(g, 'E');
    F(new THREE.BoxGeometry(2.2, 0.38, 0.1), mats.trim, 0, 3.2, 0.04); F(new THREE.PlaneGeometry(2, 0.34), signMat('OFFICINA', '#ffb36b'), 0, 3.2, 0.1);
    onFace(g, 'N')(new THREE.BoxGeometry(0.9, 0.6, 0.4), CM.shutter, -2, 2.4, 0.2);
    for (const [x, z] of [[-24.9, 26.8], [-24.2, 27.4], [-24.9, 39]]) { const t = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.9, 16), CM.tire); t.position.set(x, 0.45, z); addSolid(t); }
    addBox(-28.5, 25.6, 1.2, 1.2, 1.2, mats.crate, 0, { r: 0.06, tile: 0 });
  }
  addBox(-9.6, 10.3, 1.6, 2.4, 1.6, CM.canopy, 0, { r: 0.08, tile: 0 });
  put(new THREE.BoxGeometry(2, 0.1, 2), mats.trim, -9.6, 2.45, 10.3); put(new THREE.PlaneGeometry(1, 0.8), CM.carGlass, -9.6, 1.6, 9.49, Math.PI);
  put(new THREE.BoxGeometry(3.6, 0.1, 0.1), CM.white, -12.4, 1.05, 9.3); put(new THREE.BoxGeometry(0.2, 1.05, 0.2), CM.awnR, -10.55, 0.52, 9.3);
  lamp(-22.5, 18, 0, 1); lamp(-22.5, 18, 0, -1); lamp(-9, 27, -1, 0);
  shop(ring.W3, 'E', 0, 8, 'FERRAMENTA', null, '#ffd45a');
  tree(-9.2, 20, 0.9); tree(-9.2, 37.5, 0.9);

  // ---- south-east: petrol station with its canopy, pumps and a small market
  addBox(22, 20, 14, 0.5, 9, CM.canopy, 4.8, { r: 0.08, tile: 0 });
  for (const s of [-1, 1]) { addTube(22, 5.05, 20 + s * 4.53, 13.4, 'x', mats.neon, 0.045); addTube(22 + s * 7.03, 5.05, 20, 8.4, 'z', mats.neon, 0.045); }
  for (const x of [16.5, 27.5]) for (const z of [17, 23]) {
    addBox(x, z, 0.5, 4.8, 0.5, CM.canopy, 0, { r: 0.06, tile: 0 });
    put(new THREE.PlaneGeometry(1.4, 0.5).rotateX(Math.PI / 2), decoMats.lamp, x + (x < 22 ? 2.8 : -2.8), 4.79, z);
  }
  for (const z of [17, 23]) {
    put(rbox(4.4, 0.18, 1.2, 0.06), CM.curb, 22, 0.13, z);
    for (const x of [21, 23]) {
      addBox(x, z, 0.8, 1.6, 0.5, CM.pump, 0.2, { r: 0.08, tile: 0 });
      put(new THREE.BoxGeometry(0.84, 0.22, 0.54), CM.canopy, x, 1.9, z);
      for (const s of [-1, 1]) put(new THREE.PlaneGeometry(0.5, 0.34), CM.carGlass, x, 1.45, z + s * 0.26, s > 0 ? 0 : Math.PI);
    }
  }
  {
    const m = { x: 29, z: 35.5, w: 14, h: 3.6, d: 7 };
    // mini-market: glass front on the forecourt, side door toward the fence
    house(m, { name: 'MARKET 24H', cost: 2500, H: 3, ext: CM.canopy, int: CM.tileW, floor: CM.floorShop, roof: [m.h, CM.canopy], lights: [[29, 35.5]],
      ops: [['N', 0, 2.6, 'door'], ['N', 4, 2.6, 'win'], ['N', -4, 2.6, 'win'], ['E', -0.5, 2.6, 'door']] });
    fridge(27.5, 38.32, 10, 'N'); shelf(25.2, 35.4, 3.6, true); shelf(32, 35.4, 3, true); shelf(22.7, 35.2, 4.4, false, 2.1, [1]);
    counter(34.9, 33.5, 1, 2);
    for (const s of [-1, 1]) { put(new THREE.BoxGeometry(14.3, 0.4, 0.3), mats.trim, m.x, 3.7, m.z + s * 3.5); put(new THREE.BoxGeometry(0.3, 0.4, 7.3), mats.trim, m.x + s * 7, 3.7, m.z); }
    front(m, 'N', 0, 11, 'MARKET 24H', null, '#7fd0ff');
    onFace(m, 'W')(new THREE.BoxGeometry(0.9, 0.6, 0.4), CM.shutter, 0, 2.3, 0.2);
  }
  // price totem
  addBox(10.5, 10.5, 0.5, 7.2, 0.5, mats.trim, 0, { r: 0.05, tile: 0 });
  put(new THREE.BoxGeometry(2.4, 3, 0.36), mats.trim, 10.5, 5.6, 10.5);
  for (const s of [-1, 1]) {
    put(new THREE.PlaneGeometry(2.2, 0.55), signMat('CARBURANTI', '#ffb36b'), 10.5, 6.6, 10.5 + s * 0.19, s > 0 ? 0 : Math.PI);
    put(new THREE.PlaneGeometry(2.2, 0.55), signMat('SELF 1.839', '#8dffb0'), 10.5, 5.85, 10.5 + s * 0.19, s > 0 ? 0 : Math.PI);
    put(new THREE.PlaneGeometry(2.2, 0.55), signMat('DIESEL 1.729', '#ffe9a8'), 10.5, 5.1, 10.5 + s * 0.19, s > 0 ? 0 : Math.PI);
  }
  car(22, 14.3, 1, CM.paints[0]); car(33.5, 23, 0, CM.paints[3]);
  dumpster(38.5, 28, 1);
  addBox(37.6, 12, 0.6, 1.4, 0.5, CM.awnB, 0.04, { r: 0.06, tile: 0 });
  for (const [x, z] of [[12.5, 38.6], [13.3, 38.2]]) { const t = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 1.15, 20), barrelMats[1]); t.position.set(x, 0.615, z); addSolid(t); }
  lamp(38.5, 20, -1, 0); tree(9.2, 36, 0.9);

  // ---- classic mode: jump pads up to the low roofs
  jumpPad(-22, 0, 33, -30, 3.4, 33, 0.9);        // car park -> garage roof
  jumpPad(17, 0.04, 35.5, 25, 3.6, 35.5, 0.9);   // forecourt -> market roof
  jumpPad(23.5, 3.6, 33.4, 22, 5.3, 21, 1.1);    // market roof -> canopy
  jumpPad(-22.5, 0.07, -12, -16.5, 9.6, -27, 1.5); // courtyard -> apartment roof
  jumpPad(-2, 0, -13, 2.6, 3, -20, 0.85);        // street -> bus roof
  jumpPad(29.5, 0.07, -12, 35.5, 3.2, -12, 0.95); // piazza -> kiosk roof

  for (const [mat, arr] of batch) {
    const geo = mergeGeometries(arr);
    if (!geo) { console.warn('city: merge failed', mat); continue; }
    const m = new THREE.Mesh(geo, mat);
    m.castShadow = !mat.transparent && !mat.isMeshBasicMaterial; m.receiveShadow = true;
    B.root.add(m);
    if (mat.userData.hit) B.meshes.push(m);
  }
  document.fonts?.ready.then(() => CITY.redraw.forEach(d => d()));
}

// ============================================================ shop stations, placed on every map
// perks sold by the vending machine between waves: permanent for the match, one of each
const PERKS = {
  tank:   { name: 'PELLE DURA',      tag: 'PD', css: '#ff6b5c', cost: 2500, desc: 'Subisci il 30% di danni in meno.' },
  reload: { name: 'MANI SVELTE',     tag: 'MS', css: '#7dff8a', cost: 2000, desc: 'Ricarichi tutte le armi il 35% più in fretta.' },
  rate:   { name: 'DOPPIO COLPO',    tag: 'DC', css: '#ffb347', cost: 2000, desc: 'Cadenza di fuoco +25% con ogni arma.' },
  speed:  { name: 'GAMBE D’ACCIAIO', tag: 'GA', css: '#ffe45c', cost: 1500, desc: 'Ti muovi il 12% più veloce.' },
  regen:  { name: 'SANGUE FREDDO',   tag: 'SF', css: '#6cd4ff', cost: 2000, desc: 'La vita inizia a rigenerarsi in metà tempo e al doppio della velocità.' },
  loot:   { name: 'SCIACALLO',       tag: 'SC', css: '#c98bff', cost: 1500, desc: 'Guadagni il 30% di crediti in più da ogni uccisione.' },
  revive: { name: 'SECONDA VITA',    tag: '♥',  css: '#ff5c7a', cost: 3000, desc: 'Una vita di scorta: se cadi ti rialzi subito. Ne puoi tenere due.' },
};
let perks = {};
// second lives: one at the start of every match, one more from each boss or from the perk machine
const MAX_REVIVES = 2;
let revives = 1;
// built facing local +z; the body is the only part with a collider
function station(kind, x, z, ry) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = ry; B.root.add(g);
  const add = (geo, mat, px, py, pz) => { const m = new THREE.Mesh(geo, mat); m.position.set(px, py, pz); m.castShadow = m.receiveShadow = true; g.add(m); return m; };
  let body;
  if (kind === 'bench') {
    // weapon workbench: steel cabinet, wooden top, pegboard with tools and a rifle, vise, ammo tins
    const steel = mats.pillar, olive = new THREE.MeshStandardMaterial({ color: 0x4a5540, roughness: 0.6, metalness: 0.2 });
    body = add(rbox(2.4, 0.9, 0.9, 0.06), mats.cover, 0, 0.45, 0);
    add(rbox(2.5, 0.08, 1, 0.03), mats.crate, 0, 0.94, 0);
    for (const dx of [-0.6, 0.6]) add(rbox(1.05, 0.3, 0.03, 0.01), mats.trim, dx, 0.6, 0.455);
    add(rbox(2.4, 1.4, 0.08, 0.03), mats.trim, 0, 1.68, -0.42);
    add(rbox(0.95, 0.09, 0.05, 0.02), steel, 0.35, 1.9, -0.36); add(rbox(0.3, 0.16, 0.05, 0.02), mats.crate, 0.95, 1.86, -0.36); add(rbox(0.08, 0.26, 0.05, 0.02), steel, 0.45, 1.74, -0.36);
    add(rbox(0.07, 0.5, 0.03, 0.01), steel, -0.95, 1.75, -0.37); add(rbox(0.07, 0.42, 0.03, 0.01), steel, -0.75, 1.79, -0.37); add(rbox(0.26, 0.07, 0.03, 0.01), steel, -0.5, 1.95, -0.37); add(rbox(0.05, 0.36, 0.03, 0.01), mats.neon, -0.5, 1.72, -0.37);
    add(rbox(0.26, 0.24, 0.32, 0.03), steel, -0.85, 1.1, 0.1); add(rbox(0.1, 0.1, 0.5, 0.02), steel, -0.85, 1.14, 0.12);
    add(rbox(0.32, 0.2, 0.22, 0.02), olive, 0.75, 1.08, 0.12); add(rbox(0.32, 0.2, 0.22, 0.02), olive, 0.82, 1.28, 0.1); add(rbox(0.3, 0.2, 0.22, 0.02), olive, 0.35, 1.08, 0.2);
    add(new THREE.CapsuleGeometry(0.03, 2.2, 4, 10).rotateZ(Math.PI / 2), mats.neon, 0, 2.44, -0.37);
    add(rbox(2.1, 0.56, 0.06, 0.02), mats.trim, 0, 2.78, -0.42);
    add(new THREE.PlaneGeometry(2, 0.5), signMat('BANCO ARMI', '#ffb36b'), 0, 2.78, -0.385).castShadow = false;
  }
  if (kind === 'perks') {
    // perk vending machine: tall cabinet with a glowing front showing the six bottles
    const shell = new THREE.MeshStandardMaterial({ color: 0x3a1f5c, roughness: 0.35, metalness: 0.6 });
    body = add(rbox(1.5, 2.3, 0.9, 0.08), shell, 0, 1.15, 0);
    const [c, cg] = canvas(256); c.height = 384;
    const gr = cg.createLinearGradient(0, 0, 0, 384); gr.addColorStop(0, '#2a1244'); gr.addColorStop(1, '#0c0616'); cg.fillStyle = gr; cg.fillRect(0, 0, 256, 384);
    Object.values(PERKS).slice(0, 6).forEach((pk, i) => {
      const bx = 44 + (i % 3) * 84, by = 96 + ((i / 3) | 0) * 130;
      cg.fillStyle = 'rgba(255,255,255,.08)'; cg.fillRect(bx - 34, by + 62, 68, 6);
      cg.shadowColor = pk.css; cg.shadowBlur = 16; cg.fillStyle = pk.css;
      cg.fillRect(bx - 16, by, 32, 60); cg.fillRect(bx - 7, by - 22, 14, 24);
      cg.shadowBlur = 0; cg.fillStyle = 'rgba(0,0,0,.45)'; cg.fillRect(bx - 16, by + 20, 32, 20);
    });
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
    const front = new THREE.MeshStandardMaterial({ color: 0x050308, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: 1.3, roughness: 0.2 });
    CITY.signs.push(front);
    add(new THREE.PlaneGeometry(1.2, 1.7), front, 0, 1.35, 0.455).castShadow = false;
    add(rbox(1.1, 0.22, 0.06, 0.02), mats.trim, 0, 0.3, 0.45);
    for (const s of [-1, 1]) add(new THREE.CapsuleGeometry(0.03, 1.9, 4, 10), mats.neonBlue, s * 0.72, 1.2, 0.46);
    add(rbox(1.6, 0.5, 0.5, 0.05), shell, 0, 2.55, 0.1);
    add(new THREE.PlaneGeometry(1.4, 0.35), signMat('PERK', '#d9a8ff'), 0, 2.55, 0.36).castShadow = false;
  }
  g.updateMatrixWorld(true);
  B.meshes.push(body); B.boxes.push(new THREE.Box3().setFromObject(body));
  B[kind] = new V3(x, 0, z);
}
B = MAPS.arena; station('bench', 8, 38.9, Math.PI); station('perks', -8, -38.9, 0);
B = MAPS.city; station('bench', -39.2, 19.5, Math.PI / 2); station('perks', 38.9, -17.5, -Math.PI / 2);

// ============================================================ atmosphere per mode
const ATMOS = {
  classic: { fog: 0xc4d3e2, near: 45, far: 175, top: 0x2a64b0, bottom: 0x8c98a6, sun: 0xfff0dd, sunI: 2.4, hemi: 0.5, exposure: 0.95, glow: 1,
    neon: 0xff6a2a, neonB: 0x3aa8ff, windows: 0xffc070, tint: [1, 1, 1], bloom: 0.5, env: 1, gunEnv: 1, torch: 0 },
  zombie: { fog: 0x241c2a, near: 14, far: 85, top: 0x07060f, bottom: 0x151016, sun: 0x9fb4ff, sunI: 0.7, hemi: 0.22, exposure: 1.05, glow: 0.35,
    neon: 0xff2a1a, neonB: 0x7a3aff, windows: 0xff5030, tint: [0.92, 1.0, 0.95], bloom: 0.75, env: 0.12, gunEnv: 0.35, torch: 1 },
};
function applyAtmosphere(m) {
  const a = ATMOS[m];
  setArena(m === 'classic');
  scene.fog.color.set(a.fog); scene.fog.near = a.near; scene.fog.far = a.far;
  scene.background.set(a.fog);
  skyMat.uniforms.top.value.set(a.top); skyMat.uniforms.mid.value.set(a.fog); skyMat.uniforms.bottom.value.set(a.bottom);
  skyMat.uniforms.glow.value = a.glow;
  sun.color.set(a.sun); sun.intensity = a.sunI; hemi.intensity = a.hemi;
  const L = settings.lights;
  renderer.toneMappingExposure = a.exposure * settings.bright;
  mats.neon.emissive.set(a.neon); mats.neonBlue.emissive.set(a.neonB); mats.windows.emissive.set(a.windows);
  mats.neon.emissiveIntensity = 4.5 * L; mats.neonBlue.emissiveIntensity = 4 * L; mats.windows.emissiveIntensity = 1.6 * L;
  const night = m === 'zombie';
  mats.city.emissiveIntensity = (night ? 1.3 : 0.35) * L;
  decoMats.screen.emissive.set(night ? 0xff8080 : 0xffffff); decoMats.screen.emissiveIntensity = (night ? 0.8 : 1.1) * Math.max(0.3, L);
  decoMats.lamp.color.setRGB(1, 0.8, 0.55).multiplyScalar(0.5 + 1.8 * L);
  decoMats.lens.color.setRGB(1, 0.95, 0.85).multiplyScalar(0.6 + 1.8 * L);
  beams.forEach(b => b.material.uniforms.k.value = (night ? 0.28 : 0.1) * L);
  // city: windows, shop fronts, signs and street-lamp pools come alive at night
  CITY.facades.forEach(f => f.emissiveIntensity = (night ? 1.5 : 0.1) * L);
  CITY.signs.forEach(f => f.emissiveIntensity = (night ? 2.2 : 0.9) * Math.max(0.3, L));
  CITY.glass.emissiveIntensity = (night ? 1.3 : 0.22) * L;
  CITY.pool.opacity = night ? 0.5 * Math.min(1, L) : 0; CITY.pool.visible = night;
  CITY.lightI = (night ? 9 : 13) * (0.4 + 0.6 * Math.min(1, L)); houseLights();
  PU_MATS.health.emissiveIntensity = 1.4 * lightK(); PU_MATS.armor.emissiveIntensity = 1.3 * lightK();
  PU_MATS.healthRing.color.set(0x2dff7a).multiplyScalar(0.6 + 1.9 * L); PU_MATS.armorRing.color.set(0x3aa8ff).multiplyScalar(0.6 + 1.9 * L);
  gradePass.uniforms.tint.value.set(...a.tint);
  bloomPass.strength = a.bloom * L;
  // image-based light would make the night look like day: scale it per mode
  scene.traverse(o => { if (o.material) for (const mt of [].concat(o.material)) if (mt.isMeshStandardMaterial) mt.envMapIntensity = a.env; });
  gunScene.traverse(o => { if (o.material?.isMeshStandardMaterial) o.material.envMapIntensity = a.gunEnv; });
  torch.intensity = a.torch * 40 * (0.4 + 0.6 * Math.min(1, L));
  gunLight.intensity = a.torch ? 1.2 : 2.2;
}

// ============================================================ collision helpers
function collideCircle(pos, r, feetY, height) {
  for (const b of colliders) {
    if (b.max.y <= feetY + 0.36 || b.min.y >= feetY + height) continue;
    const cx = clamp(pos.x, b.min.x, b.max.x), cz = clamp(pos.z, b.min.z, b.max.z);
    const dx = pos.x - cx, dz = pos.z - cz, d2 = dx * dx + dz * dz;
    if (d2 >= r * r) continue;
    if (d2 > 1e-8) {
      const d = Math.sqrt(d2);
      pos.x += dx / d * (r - d); pos.z += dz / d * (r - d);
    } else {
      const opts = [[pos.x - b.min.x + r, -1, 0], [b.max.x - pos.x + r, 1, 0], [pos.z - b.min.z + r, 0, -1], [b.max.z - pos.z + r, 0, 1]];
      opts.sort((a, c) => a[0] - c[0]);
      pos.x += opts[0][1] * opts[0][0]; pos.z += opts[0][2] * opts[0][0];
    }
  }
  pos.x = clamp(pos.x, -40 + r, 40 - r); pos.z = clamp(pos.z, -40 + r, 40 - r);
}
function groundAt(x, z, feetY, r) {
  let g = 0; const e = r * 0.6;
  for (const b of colliders) {
    if (x + e > b.min.x && x - e < b.max.x && z + e > b.min.z && z - e < b.max.z && b.max.y <= feetY + 0.36) g = Math.max(g, b.max.y);
  }
  return g;
}
// lowest overhead surface the head would pass through this step
function ceilingAt(x, z, r, h0, h1) {
  let c = null; const e = r * 0.6;
  for (const b of colliders) {
    if (x + e > b.min.x && x - e < b.max.x && z + e > b.min.z && z - e < b.max.z && b.min.y >= h0 - 0.05 && b.min.y < h1) c = c === null ? b.min.y : Math.min(c, b.min.y);
  }
  return c;
}
const losRay = new THREE.Raycaster();
function worldClear(a, b) {
  const dir = b.clone().sub(a), d = dir.length();
  if (d < 1e-4) return true;
  dir.divideScalar(d);
  losRay.set(a, dir); losRay.far = d;
  return losRay.intersectObjects(worldMeshes, false).length === 0;
}
// smoke clouds (from smoke grenades) block sight like walls do
const clouds = [];
const _seg = new V3();
function smokeBlocks(a, b) {
  for (const c of clouds) {
    if (c.r < 1) continue;
    const ab = _seg.copy(b).sub(a), t = clamp(c.pos.clone().sub(a).dot(ab) / ab.lengthSq(), 0, 1);
    if (a.clone().addScaledVector(ab, t).distanceTo(c.pos) < c.r * 0.9) return true;
  }
  return false;
}
const lineOfSight = (a, b) => !smokeBlocks(a, b) && worldClear(a, b);

// ============================================================ navigation grid + A*
const G = 80, HALF = 40;
function buildGrid(maxClimb, colliders) {
  const g = new Uint8Array(G * G);
  for (let j = 0; j < G; j++) for (let i = 0; i < G; i++) {
    const x = i - HALF + 0.5, z = j - HALF + 0.5;
    let b = (i === 0 || j === 0 || i === G - 1 || j === G - 1) ? 1 : 0;
    for (const c of colliders) {
      if (b) break;
      if (c.max.y <= maxClimb || c.min.y > 2.2) continue;
      if (x > c.min.x - 0.55 && x < c.max.x + 0.55 && z > c.min.z - 0.55 && z < c.max.z + 0.55) b = 1;
    }
    g[i + j * G] = b;
  }
  return g;
}
let grid = null;      // walkers: every obstacle blocks
let climbGrid = null; // climbers (zombies) step onto crates, cover and low roofs
const cellIdx = (x, z) => clamp(Math.floor(x + HALF), 0, G - 1) + clamp(Math.floor(z + HALF), 0, G - 1) * G;
const blockedAt = (x, z, g = grid) => g[cellIdx(x, z)] === 1;
function nearestFree(idx, grid_ = grid) {
  const grid = grid_;
  if (!grid[idx]) return idx;
  const i0 = idx % G, j0 = (idx / G) | 0;
  for (let r = 1; r < 12; r++) for (let dj = -r; dj <= r; dj++) for (let di = -r; di <= r; di++) {
    if (Math.max(Math.abs(di), Math.abs(dj)) !== r) continue;
    const i = i0 + di, j = j0 + dj;
    if (i < 0 || j < 0 || i >= G || j >= G) continue;
    if (!grid[i + j * G]) return i + j * G;
  }
  return idx;
}
function walkLine(ax, az, bx, bz, g = grid) {
  const dx = bx - ax, dz = bz - az, n = Math.ceil(Math.hypot(dx, dz) / 0.3);
  for (let s = 1; s <= n; s++) if (blockedAt(ax + dx * s / n, az + dz * s / n, g)) return false;
  return true;
}
const gScore = new Float32Array(G * G), fScore = new Float32Array(G * G), came = new Int32Array(G * G);
const seen = new Uint32Array(G * G), closedSet = new Uint32Array(G * G);
let searchId = 0;
function findPath(sx, sz, tx, tz, navGrid = grid) {
  const grid = navGrid;
  const start = nearestFree(cellIdx(sx, sz), grid), goal = nearestFree(cellIdx(tx, tz), grid);
  if (start === goal) return [];
  searchId++;
  const heap = [];
  const push = k => {
    heap.push(k);
    for (let i = heap.length - 1; i > 0;) {
      const p = (i - 1) >> 1;
      if (fScore[heap[p]] <= fScore[heap[i]]) break;
      [heap[p], heap[i]] = [heap[i], heap[p]]; i = p;
    }
  };
  const pop = () => {
    const top = heap[0], last = heap.pop();
    if (heap.length) {
      heap[0] = last;
      for (let i = 0; ;) {
        const l = 2 * i + 1, r = l + 1; let m = i;
        if (l < heap.length && fScore[heap[l]] < fScore[heap[m]]) m = l;
        if (r < heap.length && fScore[heap[r]] < fScore[heap[m]]) m = r;
        if (m === i) break;
        [heap[m], heap[i]] = [heap[i], heap[m]]; i = m;
      }
    }
    return top;
  };
  const gi = goal % G, gj = (goal / G) | 0;
  const h = k => { const dx = Math.abs(k % G - gi), dy = Math.abs(((k / G) | 0) - gj); return dx + dy - 0.5858 * Math.min(dx, dy); };
  seen[start] = searchId; gScore[start] = 0; fScore[start] = h(start); came[start] = -1; push(start);
  let iter = 0;
  while (heap.length && iter++ < 6000) {
    const cur = pop();
    if (cur === goal) break;
    if (closedSet[cur] === searchId) continue;
    closedSet[cur] = searchId;
    const ci = cur % G, cj = (cur / G) | 0;
    for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
      if (!di && !dj) continue;
      const ni = ci + di, nj = cj + dj;
      if (ni < 0 || nj < 0 || ni >= G || nj >= G) continue;
      const nk = ni + nj * G;
      if (grid[nk] || closedSet[nk] === searchId) continue;
      if (di && dj && (grid[ci + di + cj * G] || grid[ci + (cj + dj) * G])) continue;
      const ng = gScore[cur] + (di && dj ? 1.4142 : 1);
      if (seen[nk] !== searchId || ng < gScore[nk]) {
        seen[nk] = searchId; gScore[nk] = ng; fScore[nk] = ng + h(nk); came[nk] = cur; push(nk);
      }
    }
  }
  if (seen[goal] !== searchId) return [];
  const pts = [];
  for (let k = goal; k !== start && k !== -1; k = came[k]) pts.push([k % G - HALF + 0.5, ((k / G) | 0) - HALF + 0.5]);
  pts.reverse();
  const out = []; let cx = sx, cz = sz;
  for (let i = 0; i < pts.length;) {
    let far = i;
    for (let k = Math.min(pts.length - 1, i + 25); k > i; k--) if (walkLine(cx, cz, pts[k][0], pts[k][1], grid)) { far = k; break; }
    out.push(pts[far]); cx = pts[far][0]; cz = pts[far][1]; i = far + 1;
  }
  return out;
}

for (const m of Object.values(MAPS)) { m.grid = buildGrid(0, m.boxes); m.climbGrid = buildGrid(1.3, m.boxes); }
// swap the active map: geometry, collisions and navigation (callers re-place the mystery box and re-apply the atmosphere)
function setMap(key) {
  if (MAP) { setArena(false); MAP.root.visible = false; }
  MAP = MAPS[key] || MAPS.city;
  MAP.root.visible = true; MAP.layer.deco.visible = false;
  worldMeshes.length = 0; worldMeshes.push(...MAP.meshes);
  colliders.length = 0; colliders.push(...MAP.boxes);
  grid = MAP.grid; climbGrid = MAP.climbGrid;
  mapVersion++;
}
setMap(store.get('spariaps-map', 'city'));
// enterable buildings: buying one rolls its shutters up and removes the solid volume that kept everyone out.
// Navigation is rebuilt in place because enemies hold a reference to the grid they walk on.
function houseLights() { for (const h of MAPS.city.houses) for (const l of h.lights) l.intensity = h.open ? CITY.lightI : 0; }
function setHouse(h, open) {
  h.open = open; h.t = open ? 1 : 0;
  for (const [list, items] of [[MAP.meshes, h.shutters], [worldMeshes, h.shutters], [MAP.boxes, [h.fill]], [colliders, [h.fill]]]) for (const it of items) {
    const i = list.indexOf(it);
    if (open && i >= 0) list.splice(i, 1); else if (!open && i < 0) list.push(it);
  }
  for (const s of h.shutters) { s.visible = true; s.scale.y = 1; s.updateMatrixWorld(true); s.children.forEach(c => c.visible = !open); }
  MAP.grid.set(buildGrid(0, MAP.boxes)); MAP.climbGrid.set(buildGrid(1.3, MAP.boxes));
  houseLights(); mapVersion++;
}
function updateHouses(dt) {
  for (const h of MAP.houses || []) {
    if (h.t <= 0) continue;
    h.t -= dt * 1.1;
    for (const s of h.shutters) { s.scale.y = Math.max(0.03, h.t); s.visible = h.t > 0; }
  }
}
