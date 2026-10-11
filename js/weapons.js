// Spariaps — Modelli delle armi, giocatore, comandi e sparo.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ weapon models
const gunMats = {
  metal: new THREE.MeshStandardMaterial({ color: 0x2b2f36, metalness: 0.8, roughness: 0.32 }),
  metalLight: new THREE.MeshStandardMaterial({ color: 0x70767f, metalness: 0.85, roughness: 0.28 }),
  tan: new THREE.MeshStandardMaterial({ color: 0x9a8566, metalness: 0.05, roughness: 0.55 }),
  polymer: new THREE.MeshStandardMaterial({ color: 0x1f2226, metalness: 0.15, roughness: 0.5 }),
  accent: new THREE.MeshStandardMaterial({ color: 0xff6b3d, metalness: 0.3, roughness: 0.4, emissive: 0xff4a1a, emissiveIntensity: 0.4 }),
  sleeve: new THREE.MeshStandardMaterial({ color: 0x2c3530, roughness: 0.8 }),
  glove: new THREE.MeshStandardMaterial({ color: 0x1c1d20, roughness: 0.6 }),
  blade: new THREE.MeshStandardMaterial({ color: 0xe8edf2, metalness: 0.75, roughness: 0.22, emissive: 0x202428 }),
  sight: new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xff3020, emissiveIntensity: 6 }),
  wood: new THREE.MeshStandardMaterial({ color: 0x7a5234, metalness: 0.05, roughness: 0.55 }),
  olive: new THREE.MeshStandardMaterial({ color: 0x4a5540, metalness: 0.1, roughness: 0.6 }),
  shell: new THREE.MeshStandardMaterial({ color: 0xb3261e, metalness: 0.3, roughness: 0.4 }),
  lens: new THREE.MeshStandardMaterial({ color: 0x0a1a2a, metalness: 1, roughness: 0.08, emissive: 0x12345a, emissiveIntensity: 0.7 }),
  dot: new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xffffff, emissiveIntensity: 0.5, roughness: 0.4 }),
  redDot: new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xff3020, emissiveIntensity: 2.6 }),
  glass: new THREE.MeshStandardMaterial({ color: 0xbfe4ff, metalness: 0, roughness: 0.05, transparent: true, opacity: 0.12, depthWrite: false, side: THREE.DoubleSide }),
  dotF: new THREE.MeshStandardMaterial({ color: 0xd8ffd8, emissive: 0x7dff7d, emissiveIntensity: 1.6, roughness: 0.4 }),
  chrome: new THREE.MeshStandardMaterial({ color: 0xc8ced6, metalness: 1, roughness: 0.18 }),
  rayRed: new THREE.MeshStandardMaterial({ color: 0xb8322a, metalness: 0.6, roughness: 0.3 }),
  rayGlow: new THREE.MeshStandardMaterial({ color: 0x0a2a10, emissive: 0x4dff6a, emissiveIntensity: 1.1 }),
};
// ---------------------------------------------------------------- weapon + hand surfaces
// each rounded-box face maps the whole texture, so a lighter rim painted on the border reads as worn edges
function gunTex(base, kind, pal) {
  const [c, g] = canvas(256);
  g.fillStyle = base; g.fillRect(0, 0, 256, 256);
  if (kind === 'metal') {
    for (let y = 0; y < 256; y++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '255,255,255' : '0,0,0'},${Math.random() * 0.06})`; g.fillRect(0, y, 256, 1); }
    g.lineCap = 'round';
    for (let i = 0; i < 60; i++) { const x = rand(0, 256), y = rand(0, 256), l = rand(4, 22); g.strokeStyle = `rgba(210,215,225,${rand(0.08, 0.28)})`; g.lineWidth = rand(0.5, 1.2); g.beginPath(); g.moveTo(x, y); g.lineTo(x + l, y + rand(-3, 3)); g.stroke(); }
  } else if (kind === 'polymer') {
    for (let i = 0; i < 9000; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '255,255,255' : '0,0,0'},${Math.random() * 0.12})`; g.fillRect(rand(0, 256), rand(0, 256), 1.6, 1.6); }
  } else if (kind === 'wood') {
    for (let i = 0; i < 70; i++) {
      const y0 = rand(0, 256), a = rand(2, 8), f = rand(0.01, 0.04), ph = rand(0, 6);
      g.strokeStyle = `rgba(${Math.random() < 0.7 ? '40,20,8' : '255,220,170'},${rand(0.08, 0.28)})`; g.lineWidth = rand(0.6, 2.2);
      g.beginPath(); for (let x = 0; x <= 256; x += 8) g.lineTo(x, y0 + Math.sin(x * f + ph) * a); g.stroke();
    }
  } else if (kind === 'leather') {
    for (let i = 0; i < 7000; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '255,255,255' : '0,0,0'},${Math.random() * 0.1})`; g.fillRect(rand(0, 256), rand(0, 256), 2, 2); }
    g.strokeStyle = 'rgba(0,0,0,.45)'; g.lineWidth = 2; g.setLineDash([6, 5]); g.strokeRect(14, 14, 228, 228); g.setLineDash([]);
  } else if (kind === 'camo') {
    // woodland-style camo: layered soft blobs, then the fabric weave on top
    for (const col of pal || ['#5a6246', '#3b4331', '#7a7453', '#2c2f25']) for (let i = 0; i < 34; i++) {
      g.fillStyle = col; g.beginPath();
      const x = rand(-10, 266), y = rand(-10, 266);
      for (let k = 0; k < 9; k++) { const a = k / 9 * Math.PI * 2, r = rand(6, 16); g.lineTo(x + Math.cos(a) * r * 1.5, y + Math.sin(a) * r); }
      g.fill();
    }
    for (let i = 0; i < 256; i += 3) { g.fillStyle = `rgba(0,0,0,${0.07 + Math.random() * 0.06})`; g.fillRect(i, 0, 1, 256); g.fillStyle = `rgba(255,255,255,${0.03 + Math.random() * 0.03})`; g.fillRect(0, i, 256, 1); }
  } else if (kind === 'skin') {
    for (let i = 0; i < 40; i++) { const x = rand(0, 256), y = rand(0, 256), r = rand(12, 40), gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, `rgba(${Math.random() < 0.5 ? '160,70,60' : '255,220,190'},.12)`); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, 2 * r, 2 * r); }
    for (let i = 0; i < 5000; i++) { g.fillStyle = `rgba(90,40,30,${Math.random() * 0.08})`; g.fillRect(rand(0, 256), rand(0, 256), 1, 1); }
  } else if (kind === 'fabric') {
    for (let i = 0; i < 256; i += 3) {
      g.fillStyle = `rgba(0,0,0,${0.06 + Math.random() * 0.06})`; g.fillRect(i, 0, 1, 256);
      g.fillStyle = `rgba(255,255,255,${0.03 + Math.random() * 0.04})`; g.fillRect(0, i, 256, 1);
    }
    for (let i = 0; i < 14; i++) { const x = rand(0, 256), y = rand(0, 256), r = rand(10, 34), gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(0,0,0,.18)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, 2 * r, 2 * r); }
  }
  if (kind !== 'fabric' && kind !== 'camo' && kind !== 'skin') {
    const e = kind === 'metal' ? 'rgba(200,205,215,' : 'rgba(255,255,255,';
    for (const [x, y, w, h] of [[0, 0, 256, 7], [0, 249, 256, 7], [0, 0, 7, 256], [249, 0, 7, 256]]) { g.fillStyle = e + (kind === 'metal' ? '.2)' : '.07)'); g.fillRect(x, y, w, h); }
    for (let i = 0; i < 30; i++) { const side = Math.random() < 0.5, p = rand(0, 256), q = Math.random() < 0.5 ? rand(0, 12) : rand(244, 256); g.fillStyle = e + rand(0.1, 0.35) + ')'; g.fillRect(side ? p : q, side ? q : p, rand(2, 8), rand(1, 3)); }
  }
  return finishTex(c);
}
{
  const M = gunMats, tex = (m, base, kind, bump = 0.6) => { const t = gunTex(base, kind); m.map = t; m.bumpMap = t; m.bumpScale = bump; m.color.set(0xffffff); m.needsUpdate = true; };
  tex(M.metal, '#2b2f36', 'metal'); tex(M.metalLight, '#6e747d', 'metal');
  tex(M.polymer, '#202328', 'polymer', 1.2); tex(M.tan, '#9a8566', 'polymer', 1.2); tex(M.olive, '#4a5540', 'polymer', 1.2);
  tex(M.wood, '#7a5234', 'wood', 0.8);
  tex(M.glove, '#5b4b3b', 'leather', 1); M.glove.roughness = 0.72;
  tex(M.sleeve, '#4b5240', 'camo', 1.4); M.sleeve.roughness = 0.92;
  M.skin = new THREE.MeshStandardMaterial({ roughness: 0.58 }); tex(M.skin, '#c48a68', 'skin', 0.3);
  M.knuckle = new THREE.MeshStandardMaterial({ roughness: 0.45, metalness: 0.1 }); tex(M.knuckle, '#26282c', 'polymer', 1.2);
  M.strap = new THREE.MeshStandardMaterial({ roughness: 0.85 }); tex(M.strap, '#2a2d27', 'fabric', 1.6);
  {
    // Italian flag patch with a stitched border
    const [c, pg] = canvas(128); c.height = 88;
    ['#1f8a4c', '#f2efe6', '#c9302c'].forEach((col, i) => { pg.fillStyle = col; pg.fillRect(8 + i * 37.3, 8, 37.3, 72); });
    pg.strokeStyle = '#2b2a24'; pg.lineWidth = 8; pg.strokeRect(4, 4, 120, 80);
    pg.strokeStyle = 'rgba(230,220,190,.55)'; pg.lineWidth = 1.5; pg.setLineDash([4, 3]); pg.strokeRect(4, 4, 120, 80); pg.setLineDash([]);
    for (let i = 0; i < 2500; i++) { pg.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`; pg.fillRect(Math.random() * 128, Math.random() * 88, 1, 1); }
    M.patch = new THREE.MeshStandardMaterial({ map: finishTex(c), roughness: 0.9 });
  }
  M.gloveDark = new THREE.MeshStandardMaterial({ color: 0x131417, roughness: 0.55, metalness: 0.2 });
  M.watch = new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0x3aff9a, emissiveIntensity: 0.9 });
}
// ---------------------------------------------------------------- unlockable looks: sleeve camo, gloves and weapon finish
const LOOKS = {
  camo: { name: 'MIMETICA', items: [
    { id: 'bosco',   name: 'BOSCO',   lvl: 1,  base: '#4b5240', pal: ['#5a6246', '#3b4331', '#7a7453', '#2c2f25'] },
    { id: 'deserto', name: 'DESERTO', lvl: 3,  base: '#b9a37a', pal: ['#cdb98f', '#9c8660', '#e0d3ae', '#7d6a4a'] },
    { id: 'urbano',  name: 'URBANO',  lvl: 6,  base: '#7b8088', pal: ['#9aa0a8', '#5a5f66', '#c3c7cc', '#34373c'] },
    { id: 'artico',  name: 'ARTICO',  lvl: 10, base: '#d4d9dd', pal: ['#eef1f3', '#aeb6bd', '#ffffff', '#7f8890'] },
    { id: 'notte',   name: 'NOTTE',   lvl: 14, base: '#1c2028', pal: ['#262b36', '#11141a', '#343b4a', '#0a0c10'] },
    { id: 'tigre',   name: 'TIGRE',   lvl: 20, base: '#c9772a', pal: ['#e08f3c', '#1a1410', '#f0b060', '#0f0b08'] },
  ] },
  glove: { name: 'GUANTI', items: [
    { id: 'cuoio',  name: 'CUOIO',  lvl: 1,  base: '#5b4b3b' },
    { id: 'nero',   name: 'NERI',   lvl: 2,  base: '#1d1e21' },
    { id: 'sabbia', name: 'SABBIA', lvl: 5,  base: '#b39b76' },
    { id: 'rosso',  name: 'ROSSI',  lvl: 9,  base: '#8d2a22' },
    { id: 'bianco', name: 'BIANCHI', lvl: 13, base: '#d8d6cf' },
    { id: 'viola',  name: 'VIOLA',  lvl: 18, base: '#5a2f8a' },
  ] },
  finish: { name: 'FINITURA ARMI', items: [
    { id: 'standard', name: 'STANDARD', lvl: 1,  metal: '#2b2f36', poly: '#202328' },
    { id: 'sabbia',   name: 'SABBIA',   lvl: 4,  metal: '#8c7a5c', poly: '#a8946e' },
    { id: 'oliva',    name: 'OLIVA',    lvl: 8,  metal: '#4a5540', poly: '#39422f' },
    { id: 'artico',   name: 'ARTICO',   lvl: 12, metal: '#c3c8ce', poly: '#dfe2e5' },
    { id: 'rosso',    name: 'CREMISI',  lvl: 16, metal: '#7a1f1c', poly: '#241416' },
    { id: 'oro',      name: 'ORO',      lvl: 25, metal: '#c9a227', poly: '#17171a' },
  ] },
};
const loadout = { camo: 'bosco', glove: 'cuoio', finish: 'standard' };
try { Object.assign(loadout, JSON.parse(store.get('spariaps-loadout', '{}'))); } catch {}
const lookOf = k => LOOKS[k].items.find(i => i.id === loadout[k]) || LOOKS[k].items[0];
function applyLoadout() {
  const M = gunMats, set = (m, base, kind, bump, pal) => { m.map?.dispose(); const t = gunTex(base, kind, pal); m.map = t; m.bumpMap = t; m.bumpScale = bump; m.needsUpdate = true; };
  const c = lookOf('camo'), g = lookOf('glove'), f = lookOf('finish');
  set(M.sleeve, c.base, 'camo', 1.4, c.pal); set(M.glove, g.base, 'leather', 1);
  set(M.metal, f.metal, 'metal', 0.6); set(M.polymer, f.poly, 'polymer', 1.2);
  M.metal.roughness = f.id === 'oro' ? 0.2 : 0.32;
}
if (loadout.camo !== 'bosco' || loadout.glove !== 'cuoio' || loadout.finish !== 'standard') applyLoadout();
function part(group, geo, mat, x, y, z, rx = 0, ry = 0, rz = 0) {
  const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.rotation.set(rx, ry, rz); group.add(m); return m;
}
function makeFlash(group, z, y, size) {
  const f = new THREE.Sprite(new THREE.SpriteMaterial({ map: flashTex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }));
  f.position.set(0, y, z); f.scale.setScalar(size); f.visible = false; group.add(f);
  f.userData.size = size;
  return f;
}
// capsule stretched between two points
const _zAxis = new V3(0, 0, 1);
function limb(g, a, b, r, mat) {
  const len = a.distanceTo(b);
  const m = new THREE.Mesh(new THREE.CapsuleGeometry(r, Math.max(0.001, len - 2 * r), 4, 12).rotateX(Math.PI / 2), mat);
  m.position.copy(a).lerp(b, 0.5);
  m.quaternion.setFromUnitVectors(_zAxis, b.clone().sub(a).normalize());
  g.add(m);
  return m;
}
// gloved hands: each finger is a bent 3-point chain of capsules; fingerless gloves leave the fingertips bare
const _yAxis = new V3(0, 1, 0);
function capsBetween(a, b, r) {
  const len = a.distanceTo(b);
  const geo = new THREE.CapsuleGeometry(r, Math.max(0.001, len - 2 * r), 3, 8).rotateX(Math.PI / 2);
  const q = new THREE.Quaternion().setFromUnitVectors(_zAxis, b.clone().sub(a).normalize());
  return geo.applyQuaternion(q).translate((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
}
// fingers: [[knuckle, middle joint, tip], radius]; the last one is the thumb. back = which way the back of the hand faces
function handGeo({ fingers, back }) {
  const glove = [], skin = [], knuckles = [], bn = new V3(...back).normalize();
  fingers.forEach(([pts, r0 = 0.0115]) => {
    const r = r0 * 1.12, [p0, p1, p2] = pts.map(p => new V3(...p));
    const cut = p1.clone().lerp(p2, 0.5);
    glove.push(capsBetween(p0, p1, r), capsBetween(p1, cut, r * 0.98));
    skin.push(capsBetween(cut.clone().lerp(p1, 0.12), p2, r * 0.9));
  });
  // hard knuckle guard: one low ridge across the four finger knuckles
  const ks = fingers.slice(0, -1).map(([pts, r = 0.0115]) => new V3(...pts[0]).addScaledVector(bn, r * 0.55));
  knuckles.push(capsBetween(ks[0], ks[ks.length - 1], 0.0085));
  return { glove: mergeGeometries(glove), skin: mergeGeometries(skin), knuckle: mergeGeometries(knuckles) };
}
const HAND = {
  // right hand on a pistol grip: palm on the right, three fingers wrap round the front, index to the trigger, thumb over the top
  grip: { palm: [0.055, 0.088, 0.085, 0.018, 0, 0.012], pad: [0.014, 0.07, 0.05, 0.044, -0.004, -0.008], back: [1, 0, 0.35], fingers: [
    [[[0.036, 0.006, -0.018], [0.014, 0.004, -0.047], [-0.029, 0.002, -0.036]]],
    [[[0.036, -0.02, -0.017], [0.015, -0.022, -0.046], [-0.027, -0.024, -0.034]]],
    [[[0.035, -0.045, -0.015], [0.016, -0.047, -0.042], [-0.023, -0.049, -0.031]], 0.0105],
    [[[0.031, 0.036, -0.018], [0.021, 0.04, -0.049], [0.004, 0.042, -0.07]]],
    [[[0.03, 0.044, 0.03], [0.004, 0.055, 0.016], [-0.028, 0.051, -0.01]], 0.013]] },
  // support hand under a handguard: palm below, fingers curl up the far side, thumb along the near side
  support: { palm: [0.07, 0.028, 0.1, 0, -0.018, 0], pad: [0.03, 0.012, 0.075, 0.018, -0.036, 0], back: [0.3, -1, 0], fingers: [
    ...[-0.035, -0.012, 0.012].map(z => [[[0.03, -0.024, z], [0.053, -0.002, z], [0.05, 0.031, z - 0.002]]]),
    [[[0.029, -0.024, 0.034], [0.05, -0.004, 0.035], [0.047, 0.026, 0.035]], 0.0105],
    [[[-0.03, -0.016, 0.03], [-0.047, 0.002, 0.004], [-0.048, 0.023, -0.03]], 0.013]] },
  // off hand cupping a pistol grip from the left, fingers over the shooting hand
  cup: { palm: [0.028, 0.072, 0.08, -0.012, 0, 0], pad: [0.012, 0.055, 0.045, -0.03, 0, 0.002], back: [-1, 0, 0.3], fingers: [
    [[[-0.02, 0.0, -0.026], [0.0, -0.001, -0.05], [0.034, -0.004, -0.045]]],
    [[[-0.02, -0.024, -0.024], [0.0, -0.025, -0.048], [0.034, -0.028, -0.042]]],
    [[[-0.019, -0.046, -0.022], [0.0, -0.047, -0.044], [0.03, -0.05, -0.038]], 0.0105],
    [[[-0.012, 0.03, -0.02], [-0.009, 0.033, -0.05], [-0.004, 0.034, -0.075]], 0.013]] },
};
for (const h of Object.values(HAND)) h.geo = handGeo(h);
function hand(parent, pos, kind, rotX = 0, flip = false) {
  const h = HAND[kind], g = new THREE.Group(); g.position.set(...pos); g.rotation.x = rotX;
  if (flip) g.scale.x = -1;
  const [pw, ph, pd, px, py, pz] = h.palm, [kw, kh, kd, kx, ky, kz] = h.pad;
  part(g, rbox(pw, ph, pd, 0.016), gunMats.glove, px, py, pz);
  part(g, rbox(kw, kh, kd, 0.006), gunMats.knuckle, kx, ky, kz);
  g.add(new THREE.Mesh(h.geo.glove, gunMats.glove), new THREE.Mesh(h.geo.skin, gunMats.skin), new THREE.Mesh(h.geo.knuckle, gunMats.knuckle));
  parent.add(g);
  return g;
}
// forearm from the wrist (a) back to the elbow (b): tapered camo sleeve with elbow folds, glove cuff with a velcro strap,
// flag patch on the right arm and a watch on the left one. Built in a local frame (y along the arm, z = up) then placed.
function forearm(g, a, b, r, watch) {
  const d = b.clone().sub(a), len = d.length() + 0.1; d.normalize();
  const up = _yAxis.clone().addScaledVector(d, -d.y).normalize(), side = d.clone().cross(up);
  const M4 = new THREE.Matrix4().makeBasis(side, d, up).setPosition(a);
  // taper toward the wrist, plus soft fabric folds bunched toward the elbow
  const rad = t => r * (0.9 + 0.36 * Math.pow(t, 0.75) + 0.05 * Math.sin(t * Math.PI) + (t > 0.42 ? 0.045 * Math.max(0, Math.sin((t - 0.42) * 26)) : 0));
  const put = (geo, mat) => { const m = new THREE.Mesh(geo.applyMatrix4(M4), mat); g.add(m); return m; };
  const prof = [new THREE.Vector2(0.001, 0.012)];
  for (let i = 0; i <= 40; i++) { const t = i / 40; prof.push(new THREE.Vector2(rad(t), 0.012 + t * (len - 0.012))); }
  prof.push(new THREE.Vector2(0.001, len));
  put(new THREE.LatheGeometry(prof, 20), gunMats.sleeve);
  // glove cuff over the sleeve end and the velcro strap around it
  put(new THREE.CylinderGeometry(r * 0.97, r * 0.9, 0.06, 20).translate(0, 0.012, 0), gunMats.glove);
  put(new THREE.CylinderGeometry(r * 1.02, r * 1.02, 0.02, 20).translate(0, 0.024, 0), gunMats.strap);
  put(rbox(r * 0.7, 0.012, 0.024, 0.004).translate(0, 0.024, r * 1.02), gunMats.strap);
  if (watch) {
    put(new THREE.CylinderGeometry(rad(0.09) * 1.05, rad(0.09) * 1.05, 0.016, 20).translate(0, 0.09 * len, 0), gunMats.gloveDark);
    put(rbox(0.032, 0.036, 0.012, 0.005).translate(0, 0.09 * len, rad(0.09) * 1.05 + 0.004), gunMats.gloveDark);
    put(new THREE.PlaneGeometry(0.022, 0.026).translate(0, 0.09 * len, rad(0.09) * 1.05 + 0.0105), gunMats.watch);
  } else {
    const R = rad(0.34) + 0.0015;
    put(new THREE.CylinderGeometry(R, R, 0.034, 12, 1, true, -0.5, 1).translate(0, 0.34 * len, 0), gunMats.patch);
  }
}
function addArms(g, right, left, leftKind = 'support') {
  const r = new V3(...right);
  hand(g, right, 'grip', -0.28);
  forearm(g, r.clone().add(new V3(0.025, -0.03, 0.045)), r.clone().add(new V3(0.16, -0.36, 0.34)), 0.04);
  if (left) {
    // the off hand lives in its own group so it can leave the weapon (reload)
    const l = new V3(...left), L = new THREE.Group(); g.add(L);
    if (leftKind === 'grip') hand(L, left, 'grip', -0.1, true);
    else if (leftKind === 'top') hand(L, left, 'support', 0, false).rotation.z = Math.PI;
    else hand(L, left, 'support');
    forearm(L, l.clone().add(new V3(-0.02, -0.045, 0.03)), l.clone().add(new V3(-0.1, -0.28, 0.5)), 0.04, true);
    g.userData.leftArm = L; g.userData.leftPos = l;
  }
}
// off hand for handguns (pistol, revolver, ray gun)
function supportHandgun(g, lg) {
  const L = new THREE.Group(); g.add(L);
  hand(L, [lg.x, lg.y, lg.z], 'cup', -0.25);
  forearm(L, lg.clone().add(new V3(-0.02, -0.03, 0.03)), lg.clone().add(new V3(-0.2, -0.33, 0.36)), 0.042, true);
  g.userData.leftArm = L; g.userData.leftPos = lg.clone();
}
// reflex sight: thin ring held by two side posts (nothing inside the ring), faint glass and a small red dot
function ringSight(g, y, z, r, base) {
  const M = gunMats, t = r * 0.22;
  part(g, new THREE.TorusGeometry(r, t, 10, 32), M.metal, 0, y, z);
  for (const s of [-1, 1]) {
    const h = y - base;
    part(g, rbox(t * 1.6, h, 0.022, 0.003), M.metal, s * (r + t * 0.3), base + h / 2, z);
  }
  part(g, new THREE.CircleGeometry(r, 28), M.glass, 0, y, z - 0.004);
  part(g, new THREE.SphereGeometry(0.0018, 8, 6), M.redDot, 0, y, z - 0.01);
}
function buildRifle() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.075, 0.1, 0.42, 0.022), M.metal, 0, 0, 0);
  part(g, rbox(0.086, 0.086, 0.28, 0.035), M.polymer, 0, 0.005, -0.33);
  part(g, rbox(0.088, 0.012, 0.2, 0.005), M.accent, 0, -0.022, -0.33);
  part(g, rbox(0.034, 0.014, 0.36, 0.006), M.metalLight, 0, 0.057, -0.12);
  part(g, new THREE.CylinderGeometry(0.014, 0.014, 0.3, 16), M.metalLight, 0, 0.02, -0.58, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.025, 0.022, 0.09, 16), M.metal, 0, 0.02, -0.76, Math.PI / 2);
  const mag = part(g, rbox(0.05, 0.19, 0.085, 0.02), M.polymer, 0, -0.12, -0.06, 0.25);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.1, 0.13, -0.3);
  part(g, rbox(0.06, 0.1, 0.26, 0.035), M.tan, 0, -0.01, 0.34);
  part(g, rbox(0.066, 0.13, 0.03, 0.013), M.polymer, 0, -0.03, 0.47);
  part(g, rbox(0.05, 0.016, 0.09, 0.006), M.metal, 0, 0.068, -0.02);
  ringSight(g, 0.105, -0.04, 0.03, 0.068);
  addArms(g, [0.01, -0.09, 0.12], [-0.01, -0.035, -0.34]);
  const flash = makeFlash(g, -0.84, 0.02, 0.32);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
// real handgun sights: a front post (tritium dot) seen through the notch between two rear posts (white dots)
function ironSights(g, baseY, frontZ, rearZ, h) {
  const M = gunMats, y = baseY + h / 2, dotY = baseY + h - 0.0035;
  part(g, rbox(0.0045, h, 0.012, 0.0015), M.metal, 0, y, frontZ);
  part(g, new THREE.SphereGeometry(0.0017, 8, 6), M.dotF, 0, dotY, frontZ + 0.0062);
  for (const s of [-1, 1]) {
    part(g, rbox(0.008, h, 0.012, 0.002), M.metal, s * 0.0088, y, rearZ);
    part(g, new THREE.SphereGeometry(0.0015, 8, 6), M.dot, s * 0.0088, dotY, rearZ + 0.0062);
  }
  part(g, rbox(0.03, 0.005, 0.012, 0.002), M.metal, 0, baseY + 0.0025, rearZ);
}
function buildPistol() {
  const g = new THREE.Group(), M = gunMats;
  const slide = part(g, rbox(0.046, 0.048, 0.2, 0.013), M.metalLight, 0, 0.03, -0.02);
  for (let i = 0; i < 4; i++) part(slide, rbox(0.048, 0.03, 0.004, 0.0015), M.metal, 0, 0, 0.05 + i * 0.011);
  ironSights(slide, 0.024, -0.085, 0.088, 0.014);
  part(g, rbox(0.042, 0.032, 0.18, 0.01), M.polymer, 0, -0.005, -0.015);
  part(g, rbox(0.047, 0.008, 0.11, 0.003), M.accent, 0, 0.013, -0.04);
  part(g, rbox(0.04, 0.125, 0.058, 0.017), M.polymer, 0, -0.07, 0.06, -0.25);
  const mag = part(g, rbox(0.034, 0.03, 0.05, 0.008), M.metal, 0, -0.13, 0.077, -0.25);
  part(g, new THREE.CylinderGeometry(0.009, 0.009, 0.03, 12), M.metal, 0, 0.03, -0.13, Math.PI / 2);
  addArms(g, [0, -0.08, 0.07]);
  const lg = new V3(-0.025, -0.07, 0.05);
  supportHandgun(g, lg);
  const flash = makeFlash(g, -0.17, 0.03, 0.22);
  return { group: g, flash, mag, magBase: mag.position.clone(), slide, slideBase: slide.position.z };
}
function buildKnife() {
  const g = new THREE.Group(), M = gunMats;
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.004); shape.lineTo(0.19, 0.004);
  shape.quadraticCurveTo(0.245, 0.01, 0.26, 0.026);
  shape.quadraticCurveTo(0.22, 0.04, 0.18, 0.04);
  shape.lineTo(0, 0.036);
  const blade = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 0.005, bevelEnabled: true, bevelThickness: 0.002, bevelSize: 0.002, bevelSegments: 2, curveSegments: 8 }), M.blade);
  blade.rotation.set(0, Math.PI / 2, 0); blade.position.set(0.004, -0.018, 0);
  g.add(blade);
  part(g, rbox(0.07, 0.014, 0.014, 0.006), M.metal, 0, 0, 0.005);
  part(g, new THREE.CapsuleGeometry(0.017, 0.09, 4, 12), M.polymer, 0, 0, 0.07, Math.PI / 2);
  hand(g, [0, -0.005, 0.07], 'grip', Math.PI / 2 - 0.1);
  forearm(g, new V3(0.01, -0.02, 0.11), new V3(0.12, -0.2, 0.45), 0.045);
  g.visible = false;
  return g;
}

function buildShotgun() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.07, 0.09, 0.32, 0.022), M.metal, 0, 0, 0);
  part(g, rbox(0.073, 0.008, 0.16, 0.003), M.accent, 0, -0.025, -0.02);
  part(g, new THREE.CylinderGeometry(0.019, 0.019, 0.56, 16), M.metalLight, 0, 0.025, -0.44, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.016, 0.016, 0.44, 14), M.metal, 0, -0.018, -0.38, Math.PI / 2);
  part(g, new THREE.SphereGeometry(0.006, 8, 6), M.sight, 0, 0.048, -0.7);
  part(g, rbox(0.05, 0.12, 0.06, 0.022), M.polymer, 0, -0.09, 0.12, -0.3);
  part(g, rbox(0.062, 0.11, 0.3, 0.04), M.wood, 0, -0.035, 0.31, 0.1);
  part(g, rbox(0.066, 0.13, 0.03, 0.013), M.polymer, 0, -0.06, 0.46, 0.1);
  const mag = part(g, new THREE.CylinderGeometry(0.012, 0.012, 0.06, 10), M.shell, 0, -0.06, -0.06, Math.PI / 2);
  // the pump carries the left hand with it
  const pump = new THREE.Group(); pump.position.set(0, -0.02, -0.34); g.add(pump);
  part(pump, rbox(0.074, 0.058, 0.18, 0.026), M.wood, 0, 0, 0);
  for (let i = 0; i < 4; i++) part(pump, rbox(0.076, 0.006, 0.01, 0.002), M.polymer, 0, 0, -0.06 + i * 0.04);
  hand(pump, [-0.01, -0.012, 0], 'support');
  forearm(pump, new V3(-0.03, -0.05, 0.03), new V3(-0.11, -0.3, 0.52), 0.04, true);
  addArms(g, [0.01, -0.09, 0.12]);
  const flash = makeFlash(g, -0.76, 0.025, 0.42);
  return { group: g, flash, mag, magBase: mag.position.clone(), pump, pumpBase: pump.position.z };
}
function buildSniper() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.07, 0.09, 0.38, 0.022), M.metal, 0, 0, 0);
  part(g, new THREE.CylinderGeometry(0.014, 0.017, 0.72, 16), M.metal, 0, 0.02, -0.55, Math.PI / 2);
  part(g, rbox(0.05, 0.05, 0.08, 0.012), M.metal, 0, 0.02, -0.94);
  part(g, rbox(0.064, 0.13, 0.4, 0.045), M.olive, 0, -0.03, 0.36);
  part(g, rbox(0.05, 0.05, 0.18, 0.02), M.olive, 0, 0.045, 0.34);
  part(g, rbox(0.074, 0.1, 0.3, 0.035), M.olive, 0, -0.01, -0.3);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.1, 0.13, -0.3);
  const mag = part(g, rbox(0.05, 0.08, 0.09, 0.015), M.metal, 0, -0.075, -0.03);
  part(g, new THREE.CylinderGeometry(0.028, 0.028, 0.3, 24), M.metal, 0, 0.1, -0.03, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.028, 0.042, 0.09, 24), M.metal, 0, 0.1, -0.22, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.034, 0.034, 0.06, 24), M.metal, 0, 0.1, 0.15, Math.PI / 2);
  part(g, new THREE.CircleGeometry(0.038, 24), M.lens, 0, 0.1, -0.266, 0, Math.PI, 0);
  for (const z of [-0.1, 0.06]) part(g, rbox(0.03, 0.05, 0.03, 0.008), M.metal, 0, 0.065, z);
  part(g, rbox(0.012, 0.03, 0.02, 0.005), M.accent, 0.03, 0.1, -0.02);
  const bolt = new THREE.Group(); bolt.position.set(0.04, 0.02, 0.08); g.add(bolt);
  part(bolt, new THREE.CylinderGeometry(0.007, 0.007, 0.06, 8), M.metalLight, 0.025, 0, 0, 0, 0, Math.PI / 2);
  part(bolt, new THREE.SphereGeometry(0.014, 10, 8), M.metalLight, 0.055, 0, 0);
  addArms(g, [0.01, -0.09, 0.12], [-0.01, -0.06, -0.3]);
  const flash = makeFlash(g, -1.0, 0.02, 0.45);
  return { group: g, flash, mag, magBase: mag.position.clone(), bolt };
}
function buildLMG() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.09, 0.12, 0.46, 0.028), M.metal, 0, 0, 0);
  part(g, rbox(0.095, 0.03, 0.22, 0.01), M.polymer, 0, 0.068, -0.02);
  part(g, rbox(0.08, 0.08, 0.34, 0.03), M.polymer, 0, 0.01, -0.4);
  for (let i = 0; i < 5; i++) part(g, new THREE.CylinderGeometry(0.009, 0.009, 0.084, 8), M.metal, 0, 0.03, -0.3 - i * 0.05, 0, 0, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.016, 0.016, 0.3, 14), M.metalLight, 0, 0.01, -0.7, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.024, 0.028, 0.09, 14), M.metal, 0, 0.01, -0.88, Math.PI / 2);
  part(g, rbox(0.022, 0.022, 0.2, 0.008), M.metal, 0, 0.13, -0.08);
  for (const z of [-0.16, 0]) part(g, rbox(0.018, 0.06, 0.02, 0.006), M.metal, 0, 0.1, z);
  const mag = part(g, new THREE.CylinderGeometry(0.085, 0.085, 0.075, 28), M.polymer, -0.015, -0.12, -0.04, 0, 0, Math.PI / 2);
  part(mag, new THREE.CylinderGeometry(0.05, 0.05, 0.08, 20), M.accent, 0, 0, 0);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.1, 0.14, -0.3);
  part(g, rbox(0.07, 0.12, 0.26, 0.04), M.polymer, 0, -0.02, 0.36);
  for (const s of [-1, 1]) part(g, new THREE.CylinderGeometry(0.007, 0.007, 0.26, 8), M.metal, 0.02 * s, -0.04, -0.62, Math.PI / 2);
  ringSight(g, 0.175, -0.1, 0.026, 0.14);
  addArms(g, [0.01, -0.1, 0.13], [-0.01, -0.05, -0.4]);
  const flash = makeFlash(g, -0.95, 0.01, 0.38);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildSMG() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.062, 0.09, 0.3, 0.022), M.metal, 0, 0, 0);
  part(g, rbox(0.07, 0.07, 0.13, 0.028), M.polymer, 0, -0.005, -0.2);
  part(g, rbox(0.072, 0.01, 0.12, 0.004), M.accent, 0, 0.03, -0.2);
  part(g, new THREE.CylinderGeometry(0.02, 0.02, 0.12, 14), M.metal, 0, 0.012, -0.32, Math.PI / 2);
  const mag = part(g, rbox(0.036, 0.2, 0.055, 0.014), M.metal, 0, -0.14, -0.06, 0.12);
  part(g, rbox(0.045, 0.12, 0.055, 0.02), M.polymer, 0, -0.09, 0.09, -0.3);
  for (const s of [-1, 1]) part(g, rbox(0.012, 0.012, 0.22, 0.005), M.metalLight, 0.022 * s, 0, 0.25);
  part(g, rbox(0.06, 0.09, 0.022, 0.01), M.polymer, 0, -0.015, 0.36);
  part(g, rbox(0.04, 0.012, 0.06, 0.004), M.metal, 0, 0.051, -0.02);
  ringSight(g, 0.08, -0.03, 0.022, 0.053);
  addArms(g, [0.01, -0.08, 0.09], [-0.01, -0.035, -0.2]);
  const flash = makeFlash(g, -0.4, 0.012, 0.26);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildMagnum() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.042, 0.055, 0.14, 0.012), M.chrome, 0, 0.022, -0.01);
  part(g, new THREE.CylinderGeometry(0.015, 0.015, 0.22, 16), M.chrome, 0, 0.036, -0.18, Math.PI / 2);
  part(g, rbox(0.026, 0.014, 0.22, 0.005), M.metal, 0, 0.054, -0.17);
  ironSights(g, 0.05, -0.262, 0.05, 0.027);
  const mag = part(g, new THREE.CylinderGeometry(0.032, 0.032, 0.058, 12), M.metal, 0, 0.022, -0.03, Math.PI / 2);
  part(g, rbox(0.044, 0.008, 0.07, 0.003), M.accent, 0, -0.004, -0.06);
  part(g, rbox(0.038, 0.13, 0.052, 0.02), M.wood, 0, -0.062, 0.075, -0.35);
  part(g, new THREE.TorusGeometry(0.02, 0.004, 8, 20, Math.PI), M.metal, 0, -0.012, 0.02, 0, Math.PI / 2, Math.PI);
  addArms(g, [0, -0.085, 0.085]);
  const lg = new V3(-0.025, -0.075, 0.065);
  supportHandgun(g, lg);
  const flash = makeFlash(g, -0.31, 0.036, 0.3);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildRaygun() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.06, 0.08, 0.2, 0.025), M.rayRed, 0, 0.02, 0);
  part(g, new THREE.CylinderGeometry(0.03, 0.05, 0.2, 24), M.rayRed, 0, 0.025, -0.19, Math.PI / 2);
  for (let i = 0; i < 3; i++) part(g, new THREE.TorusGeometry(0.047 - i * 0.005, 0.008, 10, 28), M.rayGlow, 0, 0.025, -0.12 - i * 0.055);
  part(g, new THREE.CylinderGeometry(0.02, 0.028, 0.04, 16), M.chrome, 0, 0.025, -0.305, Math.PI / 2);
  part(g, new THREE.SphereGeometry(0.014, 12, 10), M.rayGlow, 0, 0.025, -0.325);
  part(g, rbox(0.02, 0.03, 0.12, 0.008), M.chrome, 0, 0.07, -0.02);
  part(g, new THREE.SphereGeometry(0.005, 8, 6), M.sight, 0, 0.09, -0.07);
  part(g, rbox(0.04, 0.12, 0.055, 0.02), M.metal, 0, -0.07, 0.07, -0.3);
  const mag = part(g, new THREE.CylinderGeometry(0.016, 0.016, 0.06, 14), M.chrome, 0, -0.04, -0.06);
  part(mag, new THREE.CylinderGeometry(0.0165, 0.0165, 0.012, 14), M.rayGlow, 0, 0, 0);
  addArms(g, [0, -0.085, 0.085]);
  const lg = new V3(-0.025, -0.075, 0.065);
  supportHandgun(g, lg);
  const flash = makeFlash(g, -0.36, 0.025, 0.34);
  flash.material.color.set(0x7dff8a);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildUzi() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.052, 0.075, 0.24, 0.016), M.metal, 0, 0.01, -0.04);
  part(g, rbox(0.054, 0.012, 0.12, 0.004), M.accent, 0, 0.049, -0.06);
  part(g, new THREE.CylinderGeometry(0.012, 0.012, 0.07, 12), M.metalLight, 0, 0.015, -0.19, Math.PI / 2);
  const mag = part(g, rbox(0.032, 0.17, 0.04, 0.01), M.metal, 0, -0.1, 0.02, -0.1);
  part(g, rbox(0.04, 0.1, 0.05, 0.016), M.polymer, 0, -0.06, 0.03, -0.1);
  for (const z of [-0.14, 0.05]) part(g, rbox(0.012, 0.022, 0.012, 0.003), M.metal, 0, 0.058, z);
  part(g, new THREE.SphereGeometry(0.003, 8, 6), M.sight, 0, 0.07, -0.14);
  for (const s of [-1, 1]) part(g, rbox(0.008, 0.008, 0.16, 0.003), M.metalLight, 0.02 * s, 0.0, 0.16);
  addArms(g, [0, -0.07, 0.04], [-0.01, -0.03, -0.12]);
  const flash = makeFlash(g, -0.24, 0.015, 0.22);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildBurst() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.072, 0.1, 0.44, 0.022), M.olive, 0, 0, 0);
  part(g, rbox(0.08, 0.08, 0.3, 0.03), M.metal, 0, 0.005, -0.36);
  for (let i = 0; i < 3; i++) part(g, rbox(0.082, 0.01, 0.03, 0.004), M.accent, 0, -0.02, -0.28 - i * 0.06);
  part(g, new THREE.CylinderGeometry(0.014, 0.014, 0.28, 16), M.metalLight, 0, 0.02, -0.6, Math.PI / 2);
  part(g, rbox(0.05, 0.05, 0.06, 0.012), M.metal, 0, 0.02, -0.76);
  const mag = part(g, rbox(0.05, 0.17, 0.08, 0.02), M.metal, 0, -0.11, -0.06, 0.12);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.1, 0.13, -0.3);
  part(g, rbox(0.06, 0.12, 0.2, 0.04), M.olive, 0, -0.02, 0.33);
  part(g, rbox(0.034, 0.014, 0.34, 0.006), M.metal, 0, 0.057, -0.12);
  part(g, rbox(0.04, 0.016, 0.08, 0.006), M.metal, 0, 0.068, -0.03);
  ringSight(g, 0.105, -0.04, 0.03, 0.068);
  addArms(g, [0.01, -0.09, 0.12], [-0.01, -0.035, -0.34]);
  const flash = makeFlash(g, -0.82, 0.02, 0.3);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildDMR() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.07, 0.095, 0.4, 0.022), M.tan, 0, 0, 0);
  part(g, rbox(0.076, 0.085, 0.32, 0.03), M.polymer, 0, 0.005, -0.34);
  part(g, new THREE.CylinderGeometry(0.014, 0.016, 0.42, 16), M.metal, 0, 0.02, -0.68, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.022, 0.02, 0.07, 14), M.metal, 0, 0.02, -0.9, Math.PI / 2);
  const mag = part(g, rbox(0.05, 0.12, 0.08, 0.016), M.metal, 0, -0.09, -0.05, 0.1);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.1, 0.13, -0.3);
  part(g, rbox(0.062, 0.12, 0.3, 0.04), M.tan, 0, -0.02, 0.35);
  // low-power optic: open tube with clear glass, so aiming looks through it at a red dot
  const tubeM = M.metal.clone(); tubeM.side = THREE.DoubleSide;
  part(g, new THREE.CylinderGeometry(0.022, 0.022, 0.2, 24, 1, true), tubeM, 0, 0.09, -0.04, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.026, 0.022, 0.05, 24, 1, true), tubeM, 0, 0.09, -0.165, Math.PI / 2);
  for (const [z, r] of [[0.06, 0.022], [-0.19, 0.026]]) part(g, new THREE.TorusGeometry(r, 0.003, 8, 28), M.metal, 0, 0.09, z);
  part(g, new THREE.CircleGeometry(0.025, 24), M.glass, 0, 0.09, -0.185);
  part(g, new THREE.SphereGeometry(0.0012, 8, 6), M.redDot, 0, 0.09, -0.18);
  for (const z of [-0.08, 0.02]) part(g, rbox(0.024, 0.04, 0.02, 0.006), M.metal, 0, 0.058, z);
  addArms(g, [0.01, -0.09, 0.12], [-0.01, -0.04, -0.34]);
  const flash = makeFlash(g, -0.95, 0.02, 0.36);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}
function buildMinigun() {
  const g = new THREE.Group(), M = gunMats;
  part(g, rbox(0.13, 0.13, 0.3, 0.035), M.metal, 0, 0, 0.02);
  part(g, rbox(0.135, 0.02, 0.2, 0.008), M.accent, 0, 0.06, 0.02);
  const spin = new THREE.Group(); spin.position.set(0, 0, -0.14); g.add(spin);
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * Math.PI * 2;
    part(spin, new THREE.CylinderGeometry(0.012, 0.012, 0.56, 10), M.metalLight, Math.cos(a) * 0.035, Math.sin(a) * 0.035, -0.28, Math.PI / 2);
  }
  for (const z of [-0.1, -0.5]) part(spin, new THREE.CylinderGeometry(0.056, 0.056, 0.03, 20), M.metal, 0, 0, z, Math.PI / 2);
  const mag = part(g, rbox(0.1, 0.12, 0.14, 0.02), M.olive, -0.1, -0.09, 0.05);
  part(g, rbox(0.03, 0.03, 0.2, 0.008), M.metal, 0, 0.11, -0.04);
  part(g, rbox(0.03, 0.05, 0.03, 0.008), M.metal, 0, 0.085, 0.05);
  part(g, rbox(0.05, 0.13, 0.06, 0.022), M.polymer, 0, -0.12, 0.14, -0.2);
  addArms(g, [0.01, -0.12, 0.14], [-0.02, 0.13, -0.04], 'top');
  const flash = makeFlash(g, -0.76, 0, 0.4);
  return { group: g, flash, mag, magBase: mag.position.clone(), spin };
}
function buildRocket() {
  const g = new THREE.Group(), M = gunMats;
  part(g, new THREE.CylinderGeometry(0.068, 0.068, 0.95, 28), M.olive, 0, 0, -0.15, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.08, 0.072, 0.1, 28), M.metal, 0, 0, -0.6, Math.PI / 2);
  part(g, new THREE.CylinderGeometry(0.09, 0.07, 0.12, 28, 1, true), M.metal, 0, 0, 0.36, Math.PI / 2);
  for (const z of [-0.35, 0.05]) part(g, new THREE.CylinderGeometry(0.071, 0.071, 0.03, 28), M.accent, 0, 0, z, Math.PI / 2);
  const mag = part(g, new THREE.ConeGeometry(0.05, 0.16, 20), M.shell, 0, 0, -0.72, -Math.PI / 2);
  part(g, rbox(0.04, 0.12, 0.05, 0.016), M.polymer, 0, -0.11, 0.08, -0.25);
  part(g, rbox(0.04, 0.1, 0.05, 0.016), M.polymer, 0, -0.1, -0.2, -0.1);
  part(g, rbox(0.03, 0.06, 0.12, 0.01), M.metal, -0.075, 0.05, -0.08);
  part(g, new THREE.SphereGeometry(0.004, 8, 6), M.sight, -0.075, 0.085, -0.13);
  addArms(g, [0, -0.13, 0.1], [-0.01, -0.1, -0.2], 'grip');
  const flash = makeFlash(g, -0.8, 0, 0.45);
  return { group: g, flash, mag, magBase: mag.position.clone() };
}

// recoil patterns: v(n) scales the climb of shot n of a burst, h(n) is the sideways pull in radians (positive = right), jit the random part.
// Learnable shapes: the rifle goes up, then right, then left; the LMG kicks hard and settles; SMGs shake; single shots snap.
const seq = arr => n => arr[Math.min(n, arr.length - 1)], sway = (amp, period, from = 0) => n => n < from ? 0 : Math.sin((n - from) / period * Math.PI * 2) * amp;
const RECOIL = {
  rifle:   { v: n => n < 4 ? 1.35 : 0.8,              h: n => n < 4 ? 0 : sway(0.0075, 12)(n - 4), jit: 0.0008 },
  smg:     { v: n => n < 2 ? 1.1 : 0.7,               h: sway(0.003, 5),                        jit: 0.0042 },
  uzi:     { v: () => 0.75,                           h: () => 0,                               jit: 0.0065 },
  lmg:     { v: n => n < 6 ? 1.7 : 0.45,              h: sway(0.0045, 18, 6),                   jit: 0.0018 },
  minigun: { v: n => Math.max(0.25, 1.2 - n * 0.05),  h: sway(0.0035, 30),                      jit: 0.003 },
  burst:   { v: seq([0.8, 1.1, 1.5]),                 h: seq([0.001, 0.0035, 0.006]),           jit: 0.0006 },
  dmr:     { v: () => 1.15,                           h: n => (n % 2 ? -1 : 1) * 0.0045,        jit: 0.001 },
  pistol:  { v: n => 1 + Math.min(n, 4) * 0.12,       h: () => 0,                               jit: 0.003 },
  magnum:  { v: () => 1.3,                            h: () => 0.004,                           jit: 0.004 },
  shotgun: { v: () => 1.2,                            h: () => 0,                               jit: 0.009 },
  sniper:  { v: () => 1.2,                            h: () => -0.003,                          jit: 0.004 },
  rocket:  { v: () => 1,                              h: () => 0,                               jit: 0.006 },
  raygun:  { v: () => 0.8,                            h: sway(0.002, 4),                        jit: 0.001 },
};
const WEAPONS = {
  rifle: {
    name: 'FUCILE', auto: true, rate: 0.1, magSize: 30, reload: 1.6,
    dmg: { head: 100, body: 34, limb: 24 }, hip: 0.018, ads: 0.0015, move: 0.03, bloom: 0.006,
    recoil: 0.018, climb: 0.006, fov: 50, vol: 1, snd: SND.rifle, speed: 1, shake: 0.12,
    hipPos: new V3(0.2, -0.2, -0.72), adsPos: new V3(0, -0.105, -0.5), ...buildRifle(),
  },
  pistol: {
    name: 'PISTOLA', cues: 'pistol', auto: false, rate: 0.14, magSize: 12, reload: 1.2,
    dmg: { head: 100, body: 45, limb: 32 }, hip: 0.012, ads: 0.001, move: 0.02, bloom: 0.012,
    recoil: 0.032, climb: 0.009, fov: 60, vol: 0.8, snd: SND.pistol, speed: 1.05, shake: 0.1, kickRot: 0.18, kickBack: 0.04,
    hipPos: new V3(0.13, -0.14, -0.4), adsPos: new V3(0, -0.0675, -0.36), hipYaw: 0.1, ...buildPistol(),
  },
  shotgun: {
    name: 'FUCILE A POMPA', cues: 'shotgun', auto: false, rate: 0.85, magSize: 6, reload: 2.3, pellets: 8, pelletSpread: 0.05,
    dmg: { head: 30, body: 19, limb: 13 }, hip: 0.01, ads: 0.004, move: 0.02, bloom: 0,
    recoil: 0.06, climb: 0.02, fov: 62, vol: 1.1, snd: SND.shotgun, speed: 1, shake: 0.5, kickRot: 0.16, kickBack: 0.08,
    hipPos: new V3(0.2, -0.2, -0.66), adsPos: new V3(0, -0.05, -0.52), ...buildShotgun(),
  },
  sniper: {
    name: 'FUCILE DI PRECISIONE', cues: 'sniper', auto: false, rate: 1.25, magSize: 5, reload: 2.6, scope: true, adsSpeed: 5,
    dmg: { head: 300, body: 120, limb: 75 }, hip: 0.07, ads: 0.0002, move: 0.05, bloom: 0,
    recoil: 0.05, climb: 0.03, fov: 16, vol: 1.15, snd: SND.sniper, speed: 0.92, shake: 0.35, kickRot: 0.12, kickBack: 0.07,
    hipPos: new V3(0.2, -0.2, -0.7), adsPos: new V3(0, -0.1, -0.45), ...buildSniper(),
  },
  lmg: {
    name: 'MITRAGLIATRICE LEGGERA', cues: 'lmg', auto: true, rate: 0.075, magSize: 80, reload: 3.4, adsSpeed: 5,
    dmg: { head: 75, body: 28, limb: 20 }, hip: 0.03, ads: 0.004, move: 0.035, bloom: 0.004,
    recoil: 0.014, climb: 0.005, fov: 55, vol: 1, snd: SND.lmg, speed: 0.86, shake: 0.15,
    hipPos: new V3(0.21, -0.22, -0.72), adsPos: new V3(0, -0.175, -0.55), ...buildLMG(),
  },
  smg: {
    name: 'MITRAGLIETTA', auto: true, rate: 0.062, magSize: 35, reload: 1.35, adsSpeed: 9,
    dmg: { head: 65, body: 22, limb: 16 }, hip: 0.016, ads: 0.006, move: 0.012, bloom: 0.004,
    recoil: 0.011, climb: 0.004, fov: 62, vol: 0.85, snd: SND.smg, speed: 1.12, shake: 0.08,
    hipPos: new V3(0.17, -0.17, -0.55), adsPos: new V3(0, -0.08, -0.42), ...buildSMG(),
  },
  magnum: {
    name: 'REVOLVER MAGNUM', cues: 'magnum', auto: false, rate: 0.42, magSize: 6, reload: 2.1,
    dmg: { head: 240, body: 95, limb: 65 }, hip: 0.014, ads: 0.0008, move: 0.02, bloom: 0.02,
    recoil: 0.075, climb: 0.028, fov: 55, vol: 1.1, snd: SND.magnum, speed: 1.02, shake: 0.32, kickRot: 0.34, kickBack: 0.06,
    hipPos: new V3(0.13, -0.15, -0.42), adsPos: new V3(0, -0.0765, -0.38), hipYaw: 0.1, ...buildMagnum(),
  },
  uzi: {
    name: 'MICRO SMG', auto: true, rate: 0.055, magSize: 32, reload: 1.3, adsSpeed: 10,
    dmg: { head: 55, body: 18, limb: 13 }, hip: 0.02, ads: 0.008, move: 0.012, bloom: 0.005,
    recoil: 0.01, climb: 0.004, fov: 64, vol: 0.8, snd: SND.uzi, speed: 1.12, shake: 0.07,
    hipPos: new V3(0.15, -0.15, -0.46), adsPos: new V3(0, -0.07, -0.38), hipYaw: 0.1, ...buildUzi(),
  },
  burst: {
    name: 'FUCILE A RAFFICA', auto: false, burst: 3, burstDelay: 0.32, rate: 0.065, magSize: 30, reload: 1.7,
    dmg: { head: 115, body: 40, limb: 28 }, hip: 0.016, ads: 0.0012, move: 0.028, bloom: 0.004,
    recoil: 0.016, climb: 0.005, fov: 50, vol: 1, snd: SND.burst, speed: 1, shake: 0.12,
    hipPos: new V3(0.2, -0.2, -0.72), adsPos: new V3(0, -0.105, -0.5), ...buildBurst(),
  },
  dmr: {
    name: 'FUCILE TATTICO', auto: false, rate: 0.24, magSize: 15, reload: 2, adsSpeed: 6,
    dmg: { head: 190, body: 72, limb: 50 }, hip: 0.03, ads: 0.0004, move: 0.04, bloom: 0.01,
    recoil: 0.04, climb: 0.016, fov: 34, vol: 1.1, snd: SND.dmr, speed: 0.96, shake: 0.22, kickRot: 0.1, kickBack: 0.06,
    hipPos: new V3(0.2, -0.2, -0.72), adsPos: new V3(0, -0.09, -0.42), ...buildDMR(),
  },
  minigun: {
    name: 'MINIGUN', cues: 'lmg', auto: true, spinup: true, rate: 0.036, magSize: 200, reload: 4.6, adsSpeed: 4,
    dmg: { head: 55, body: 22, limb: 16 }, hip: 0.035, ads: 0.02, move: 0.03, bloom: 0.003,
    recoil: 0.007, climb: 0.0025, fov: 62, vol: 0.85, snd: SND.minigun, speed: 0.76, shake: 0.14, kickBack: 0.02,
    hipPos: new V3(0.2, -0.22, -0.62), adsPos: new V3(0.06, -0.19, -0.56), ...buildMinigun(),
  },
  rocket: {
    name: 'LANCIARAZZI', cues: 'rocket', auto: false, rate: 0.9, magSize: 3, reload: 2.8, projectile: 'rocket', projSpeed: 34, adsSpeed: 5,
    dmg: { head: 0, body: 0, limb: 0 }, hip: 0.01, ads: 0.002, move: 0.02, bloom: 0,
    recoil: 0.09, climb: 0.04, fov: 55, vol: 1, snd: null, speed: 0.88, shake: 0.6, kickRot: 0.2, kickBack: 0.12,
    hipPos: new V3(0.2, -0.13, -0.5), adsPos: new V3(0.075, -0.085, -0.42), ...buildRocket(),
  },
  raygun: {
    name: 'PISTOLA A RAGGI', cues: 'raygun', auto: false, rate: 0.26, magSize: 20, reload: 2.5, projectile: 'plasma', projSpeed: 48, splash: 2.8, splashDmg: 130,
    dmg: { head: 320, body: 210, limb: 160 }, hip: 0.008, ads: 0.002, move: 0.01, bloom: 0.004,
    recoil: 0.03, climb: 0.012, fov: 58, vol: 0.9, snd: null, speed: 1.03, shake: 0.22, kickRot: 0.22, kickBack: 0.05,
    hipPos: new V3(0.15, -0.16, -0.54), adsPos: new V3(0, -0.09, -0.44), hipYaw: 0.1, ...buildRaygun(),
  },
};
// mystery box rarity tiers (weights decide how often each weapon rolls)
const RARITY = {
  common:    { name: 'COMUNE',      css: '#c9d1db', color: 0xc9d1db },
  uncommon:  { name: 'NON COMUNE',  css: '#6bff8f', color: 0x6bff8f },
  rare:      { name: 'RARA',        css: '#5cb3ff', color: 0x5cb3ff },
  epic:      { name: 'EPICA',       css: '#c77dff', color: 0xc77dff },
  legendary: { name: 'LEGGENDARIA', css: '#ffc94d', color: 0xffc94d },
};
const BOX_POOL = [
  ['pistol', 'common', 11], ['uzi', 'common', 11],
  ['smg', 'uncommon', 14], ['shotgun', 'uncommon', 13],
  ['rifle', 'rare', 12], ['magnum', 'rare', 10], ['burst', 'rare', 10], ['dmr', 'rare', 9],
  ['lmg', 'epic', 8], ['sniper', 'epic', 8], ['minigun', 'epic', 7],
  ['raygun', 'legendary', 4], ['rocket', 'legendary', 4],
];
const rarityOf = k => RARITY[(BOX_POOL.find(e => e[0] === k) || [0, 'common'])[1]];
// classes: each picks the primary weapon; pistol and knife are always carried
const CLASSES = {
  assault: { name: 'ASSALTATORE', weapon: 'rifle', desc: 'Fucile d’assalto automatico e versatile, efficace a ogni distanza.', armor: 0, stats: [3, 3, 3, 3], perk: 'Equilibrato in tutto' },
  breacher: { name: 'INCURSORE', weapon: 'shotgun', desc: 'Fucile a pompa devastante a corto raggio. Perfetto contro le orde.', armor: 25, stats: [5, 1, 1, 3], perk: '+25 scudo iniziale' },
  sniper: { name: 'CECCHINO', weapon: 'sniper', desc: 'Fucile di precisione con mirino ottico: alla testa è sempre letale.', armor: 0, stats: [5, 1, 5, 2], perk: 'Mirino ottico ad alto ingrandimento' },
  gunner: { name: 'MITRAGLIERE', weapon: 'lmg', desc: 'Mitragliatrice leggera da 80 colpi. Lenta da ricaricare, inarrestabile.', armor: 50, stats: [3, 4, 2, 1], perk: '+50 scudo iniziale' },
  scout: { name: 'ESPLORATORE', weapon: 'smg', desc: 'Mitraglietta a cadenza altissima e ricarica rapida. Il più veloce.', armor: 0, stats: [2, 5, 3, 5], perk: 'Movimento +12%' },
};
let classKey = store.get('spariaps-class', 'assault');
if (!CLASSES[classKey]) classKey = 'assault';
let primary = CLASSES[classKey].weapon;
const KNIFE_DMG = 200;
// trigger + guard on every gun, picatinny teeth and handguard slots where they fit
{
  const guardGeo = new THREE.TorusGeometry(0.03, 0.0055, 6, 18, Math.PI).rotateY(Math.PI / 2).rotateX(Math.PI);
  const triggerGeo = rbox(0.007, 0.032, 0.009, 0.003);
  const TRIG = { rifle: [-0.05, 0.075], burst: [-0.05, 0.075], dmr: [-0.048, 0.075], sniper: [-0.045, 0.075], smg: [-0.045, 0.035], lmg: [-0.06, 0.085],
    shotgun: [-0.045, 0.065], uzi: [-0.028, -0.035], pistol: [-0.021, -0.01], minigun: [-0.065, 0.085], rocket: [-0.068, 0.025], raygun: [-0.02, 0.015] };
  for (const [k, [y, z]] of Object.entries(TRIG)) {
    const g = WEAPONS[k].group;
    part(g, guardGeo, gunMats.metal, 0, y, z);
    part(g, triggerGeo, gunMats.metalLight, 0, y - 0.012, z - 0.004, 0.35);
  }
  const rail = (len, n) => mergeGeometries([rbox(0.036, 0.006, len, 0.002), ...Array.from({ length: n }, (_, i) => rbox(0.04, 0.008, 0.009, 0.002).translate(0, 0.006, -len / 2 + (i + 0.5) * len / n))]);
  part(WEAPONS.rifle.group, rail(0.34, 14), gunMats.metal, 0, 0.066, -0.12);
  part(WEAPONS.burst.group, rail(0.32, 13), gunMats.metal, 0, 0.066, -0.12);
  part(WEAPONS.smg.group, rail(0.16, 7), gunMats.metal, 0, 0.049, -0.1);
  const slots = mergeGeometries([-1, 1].flatMap(s => [0, 1, 2, 3].map(i => rbox(0.004, 0.018, 0.035, 0.002).translate(s * 0.044, 0.01, -0.42 + i * 0.055))));
  part(WEAPONS.rifle.group, slots, gunMats.gloveDark, 0, 0, 0);
  part(WEAPONS.dmr.group, slots, gunMats.gloveDark, 0, 0, -0.02);
}
const holder = new THREE.Group();
gunScene.add(holder);
for (const w of Object.values(WEAPONS)) { w.group.visible = false; holder.add(w.group); }
const knife = buildKnife();
gunScene.add(knife);
// left arm used only for the throwing gesture
const throwArm = new THREE.Group();
{
  hand(throwArm, [0, 0, 0], 'grip', -0.5, true);
  forearm(throwArm, new V3(-0.02, -0.04, 0.03), new V3(-0.1, -0.3, 0.42), 0.04, true);
  throwArm.visible = false; gunScene.add(throwArm);
}

// ============================================================ player + weapon state
const player = {
  pos: new V3(), vel: new V3(), yaw: 0, pitch: 0, onGround: true, hp: 100, armor: 0, lastHit: -99, r: 0.4, h: 1.8,
  crouch: false, crouchT: 0, bob: 0, landOff: 0, shake: 0, roll: 0, sprintT: 0, airJumps: 1,
  lean: 0, leanT: 0, leanV: new V3(),
  slideT: 0, slideCD: 0, slideDir: new V3(), vaultCD: 0,
};
// arena power-ups: seconds left for each active bonus
const powers = { jump: 0, haste: 0, quad: 0, ammo: 0, god: 0 };
const pw = k => powers[k] > 0;
// weapon upgrades bought at the workbench: three tracks per weapon, three levels each, kept for the whole match
const UPGRADES = {
  dmg: { name: 'DANNO', text: l => `+${l * 20}% danno` },
  mag: { name: 'CARICATORE', text: l => `+${l * 25}% colpi` },
  rel: { name: 'RICARICA', text: l => `−${l * 15}% tempo` },
};
const UPG_COST = [600, 1100, 1800];
let upg = {};
const upgLv = (k, t) => upg[k]?.[t] || 0;
const magOf = k => Math.round(WEAPONS[k].magSize * (1 + 0.25 * upgLv(k, 'mag')));
const dmgMul = k => 1 + 0.2 * upgLv(k, 'dmg');
const reloadOf = (k = weapon.current) => WEAPONS[k].reload * (1 - 0.15 * upgLv(k, 'rel')) * (perks.reload ? 0.65 : 1);
const weapon = {
  current: primary, last: 'pistol', mags: { [primary]: WEAPONS[primary].magSize, pistol: 12 },
  reloading: false, reloadT: 0, cooldown: 0, bloom: 0, kick: 0, recoilOff: 0, flashT: 0, adsT: 0, slideKick: 0, spray: 0, sprayT: 0,
  switchT: 0, switchTo: null, meleeT: 0, meleeHit: false, throwT: 0, burstLeft: 0, spin: 0,
};
const W = () => WEAPONS[weapon.current];
const SWITCH_TIME = 0.4, MELEE_TIME = 0.5, THROW_TIME = 0.45;
// two gun slots (a weapon from the box or the floor replaces the one in hand) + throwables
let slots = [primary, 'pistol'];
const EQUIP_START = { frag: 0, stun: 0, smoke: 0, tknife: 0 };
const EQUIP_NAMES = { frag: 'GRANATA', stun: 'STORDENTE', smoke: 'FUMOGENO', tknife: 'COLTELLI DA LANCIO' };
const EQUIP_WEIGHTS = [['frag', 3], ['stun', 2], ['smoke', 2], ['tknife', 3]];
function randomEquip() { let r = Math.random() * 10; for (const [k, w] of EQUIP_WEIGHTS) { r -= w; if (r <= 0) return k; } return 'frag'; }
const EQUIP_MAX = { frag: 3, stun: 3, smoke: 2, tknife: 5 };
const equip = { ...EQUIP_START };
let cash = 0, blind = 0;
const otherSlot = () => { const i = slots.indexOf(weapon.switchTo || weapon.current); return i < 0 ? slots.find(Boolean) : slots[1 - i]; };
const eyeHeight = () => lerp(1.62, 1.02, smooth(player.crouchT));
const playerEye = () => new V3(player.pos.x, player.pos.y + eyeHeight(), player.pos.z).add(player.leanV);
const isAiming = () => aiming || (settings.autoAds && firing);

const keys = {};
// ---------------------------------------------------------------- remappable controls
// The game logic keeps reading the default key codes and button numbers: bindings translate what you press into those.
const ACTIONS = [
  ['fwd', 'Avanti', 'KeyW'], ['back', 'Indietro', 'KeyS'], ['left', 'Sinistra', 'KeyA'], ['right', 'Destra', 'KeyD'],
  ['fire', 'Spara', null, 7], ['aim', 'Mira', null, 6],
  ['jump', 'Salta', 'Space', 0], ['sprint', 'Corri', 'ShiftLeft', 10], ['crouch', 'Accucciati · scivola', 'KeyC', 1],
  ['reload', 'Ricarica (controller: anche usa)', 'KeyR', 2], ['interact', 'Usa · raccogli', 'KeyE'], ['swap', 'Cambia arma', 'KeyQ', 3],
  ['melee', 'Coltellata', 'KeyV', 5], ['melee2', 'Coltellata (stick destro)', null, 11],
  ['frag', 'Granata', 'KeyG', 4], ['stun', 'Stordente', 'KeyZ', 12], ['smoke', 'Fumogeno', 'KeyX', 13], ['tknife', 'Coltello da lancio', 'KeyT', 14],
  ['drop', 'Getta arma', 'KeyB', 15], ['skip', 'Avvia subito l’ondata', 'Enter', 8], ['pause', 'Pausa', 'KeyP', 9],
].map(([id, name, key, btn]) => ({ id, name, key, btn }));
const ACT = Object.fromEntries(ACTIONS.map(a => [a.id, a]));
const FIXED_KEYS = ['Escape', 'Digit1', 'Digit2', 'KeyM'];
const PAD_NAMES = ['A', 'B', 'X', 'Y', 'LB', 'RB', 'LT', 'RT', 'back', 'start', 'L3', 'R3', 'up', 'down', 'left', 'right'];
const KEY_NAMES = { Space: 'Spazio', ShiftLeft: 'Shift', ShiftRight: 'Shift dx', ControlLeft: 'Ctrl', ControlRight: 'Ctrl dx', AltLeft: 'Alt', AltRight: 'Alt dx', Enter: 'Invio', NumpadEnter: 'Invio tn',
  Tab: 'Tab', CapsLock: 'Bloc Maiusc', Backspace: 'Backspace', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→', Backquote: '\\', Minus: '-', Equal: '=', Comma: ',', Period: '.', Slash: '/' };
const keyName = code => KEY_NAMES[code] || code.replace(/^Key|^Digit/, '').replace(/^Numpad/, 'Tn ');
const bindOf = id => settings.binds[id] || ACT[id].key;
const padOf = i => settings.padBinds[i] ?? i;   // logical button -> the physical one that triggers it
let phys2log = {};
const KEY_DEFAULTS = new Set(ACTIONS.map(a => a.key).filter(Boolean));
function rebuildBinds() {
  phys2log = {};
  for (const a of ACTIONS) if (a.key) phys2log[bindOf(a.id)] = a.key;
}
// a key that lost its default job and was given no new one does nothing
const logical = code => phys2log[code] ?? (KEY_DEFAULTS.has(code) ? '' : code);
rebuildBinds();
let bindWait = null;   // { id, dev: 'key' | 'pad' } while the settings wait for the new key or button
function setKeyBind(id, code) {
  const old = bindOf(id), other = ACTIONS.find(a => a.key && a.id !== id && bindOf(a.id) === code);
  if (other) settings.binds[other.id] = old;
  settings.binds[id] = code;
  for (const a of ACTIONS) if (settings.binds[a.id] === a.key) delete settings.binds[a.id];
}
function setPadBind(logicalBtn, phys) {
  const old = padOf(logicalBtn), other = PAD_NAMES.findIndex((_, i) => i !== logicalBtn && padOf(i) === phys);
  if (other >= 0) settings.padBinds[other] = old;
  settings.padBinds[logicalBtn] = phys;
  for (const i of Object.keys(settings.padBinds)) if (settings.padBinds[i] === +i) delete settings.padBinds[i];
}
function bindsChanged() { bindWait = null; rebuildBinds(); saveSettings(); renderBinds(); }
function renderBinds() {
  const L = PL();
  $('bindList').innerHTML = '<div class="bind head"><span>COMANDO</span><span>TASTIERA</span><span>CONTROLLER</span></div>' + ACTIONS.map(a => {
    const w = bindWait?.id === a.id ? bindWait.dev : '';
    return `<div class="bind"><span>${a.name}</span>`
      + (a.key ? `<button data-id="${a.id}" data-dev="key" class="${w === 'key' ? 'wait' : ''}">${w === 'key' ? 'PREMI…' : keyName(bindOf(a.id))}</button>` : `<span class="na">${a.id === 'melee2' ? '—' : 'mouse'}</span>`)
      + (a.btn != null ? `<button data-id="${a.id}" data-dev="pad" class="${w === 'pad' ? 'wait' : ''}">${w === 'pad' ? 'PREMI…' : L[PAD_NAMES[padOf(a.btn)]]}</button>` : `<span class="na">${a.id === 'interact' ? 'come ricarica' : 'stick'}</span>`) + '</div>';
  }).join('');
  document.querySelectorAll('kbd[data-act]').forEach(k => k.textContent = keyName(bindOf(k.dataset.act)));
  renderPadLegend();
}
$('bindList').addEventListener('click', e => {
  const b = e.target.closest('button[data-id]');
  if (!b) return;
  bindWait = bindWait?.id === b.dataset.id && bindWait.dev === b.dataset.dev ? null : { id: b.dataset.id, dev: b.dataset.dev };
  renderBinds();
  if (padFocus) setPadFocus($('bindList').querySelector(`button[data-id="${b.dataset.id}"][data-dev="${b.dataset.dev}"]`), false);
});
$('bindReset').addEventListener('click', () => { settings.binds = {}; settings.padBinds = {}; bindsChanged(); });
// while waiting for a key nothing else must react to it
addEventListener('keydown', e => {
  if (bindWait?.dev !== 'key') return;
  e.preventDefault(); e.stopImmediatePropagation();
  if (e.code === 'Escape' || FIXED_KEYS.includes(e.code)) { bindWait = null; return renderBinds(); }
  setKeyBind(bindWait.id, e.code); bindsChanged();
}, true);
// controller state read by the gameplay code (filled by pollPad every frame)
const pad = { mx: 0, my: 0, jump: false, sprint: false };
// ---------------------------------------------------------------- touch controls (phones and tablets)
// Left side of the screen: a stick that appears where you put your thumb. Right side: drag to look. Buttons do the rest.
// The stick writes into the same `pad` state the controller uses.
let touchMode = false;
const TOUCH_LABELS = { E: 'RIC · USA', R: 'RIC · USA', INVIO: 'AVVIA L’ONDATA', 'Clic SX': 'SPARA', 'Clic DX': 'MIRA', Shift: 'levetta in fondo', Spazio: 'SALTA', C: 'GIÙ' };
const tch = { stick: null, look: new Map(), ox: 0, oy: 0 };
function enableTouch() {
  if (touchMode) return;
  touchMode = true; document.body.classList.add('touch');
  // first time on a touch device: lighter graphics and automatic aiming while shooting
  if (store.get('spariaps-touch', '0') !== '1') { store.set('spariaps-touch', '1'); settings.quality = 'low'; settings.autoAds = true; saveSettings(); applyQuality(); }
  promptKey = '';
}
addEventListener('touchstart', enableTouch, { passive: true });
function touchAction(a, down, el) {
  if (state !== 'playing') return;
  if (a === 'fire') { firing = down; if (down) { triggerQueued = true; triggerT = now; } }
  else if (a === 'jump') { pad.jump = down; if (down) gameKey('Space'); }
  if (a !== 'aim') el.classList.toggle('on', down);
  if (!down) return;
  if (a === 'aim') { aiming = !aiming; el.classList.toggle('on', aiming); }
  else if (a === 'reload') { if (interactTarget()) interact(); else startReload(); }
  else if (a === 'crouch') gameKey('KeyC');
  else if (a === 'swap') switchWeapon(otherSlot());
  else if (a === 'melee') startMelee();
  else if (a === 'pause') pause();
  else if (a === 'skip') gameKey('Enter');
  else if (a === 'frag' || a === 'stun' || a === 'smoke' || a === 'tknife') throwItem(a);
}
{
  const layer = $('touch'), stick = $('tStick'), knob = stick.firstElementChild;
  layer.addEventListener('touchstart', e => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const b = t.target.closest?.('[data-a]');
      if (b) { touchAction(b.dataset.a, true, b); if (b.dataset.a === 'fire') tch.look.set(t.identifier, [t.clientX, t.clientY, b]); else tch.look.set(t.identifier, [null, null, b]); }
      else if (t.clientX < innerWidth * 0.42 && tch.stick === null) {
        tch.stick = t.identifier; tch.ox = t.clientX; tch.oy = t.clientY;
        stick.style.display = 'block'; stick.style.left = t.clientX + 'px'; stick.style.top = t.clientY + 'px'; knob.style.transform = '';
      } else tch.look.set(t.identifier, [t.clientX, t.clientY, null]);
    }
  }, { passive: false });
  layer.addEventListener('touchmove', e => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      if (t.identifier === tch.stick) {
        let dx = (t.clientX - tch.ox) / 52, dy = (t.clientY - tch.oy) / 52; const m = Math.hypot(dx, dy);
        if (m > 1) { dx /= m; dy /= m; }
        pad.mx = Math.abs(dx) < 0.12 ? 0 : dx; pad.my = Math.abs(dy) < 0.12 ? 0 : -dy; pad.sprint = pad.my > 0.9;
        knob.style.transform = `translate(${dx * 40}px, ${dy * 40}px)`;
      } else {
        const l = tch.look.get(t.identifier);
        if (!l || l[0] === null || state !== 'playing') continue;
        const k = 0.0052 * settings.sens * (weapon.adsT > 0.5 ? (W().scope ? 0.28 : 0.6) : 1), dx = t.clientX - l[0], dy = t.clientY - l[1];
        player.yaw -= dx * k; player.pitch = clamp(player.pitch - dy * k, -1.5, 1.5);
        swayX += dx * 0.0003; swayY += dy * 0.0003;
        l[0] = t.clientX; l[1] = t.clientY;
      }
    }
  }, { passive: false });
  const end = e => {
    for (const t of e.changedTouches) {
      if (t.identifier === tch.stick) { tch.stick = null; pad.mx = pad.my = 0; pad.sprint = false; stick.style.display = 'none'; }
      const l = tch.look.get(t.identifier);
      if (l) { if (l[2]) touchAction(l[2].dataset.a, false, l[2]); tch.look.delete(t.identifier); }
    }
  };
  layer.addEventListener('touchend', end); layer.addEventListener('touchcancel', end);
}
// shown only while playing; the skip button appears during the break between waves
function updateTouchUi() {
  if (!touchMode) return;
  const on = state === 'playing';
  const layer = $('touch');
  if (layer.classList.contains('on') !== on) {
    layer.classList.toggle('on', on);
    if (!on) { tch.stick = null; tch.look.clear(); pad.mx = pad.my = 0; pad.jump = pad.sprint = false; firing = false; $('tStick').style.display = 'none'; layer.querySelectorAll('.tb.on').forEach(b => b.classList.remove('on')); }
  }
  if (on) { layer.querySelector('.skip').classList.toggle('show', wave > 0 && waveBreak > 3); layer.querySelector('.aim').classList.toggle('on', aiming); }
}
const padMode = () => settings.input === 'pad';
let firing = false, triggerQueued = false, triggerT = 0, aiming = false, swayX = 0, swayY = 0, throwCD = 0;
let state = 'menu', menuType = 'main', now = 0, score = 0, kills = 0, headshots = 0, shotsFired = 0, shotsHit = 0, hurt = 0;
const bestKey = () => `spariaps-best-${mode}-${diffKey}${MAP.key === 'arena' ? '' : '-' + MAP.key}`;
// per-match counters for the end screen, and career totals kept between matches
let earned = 0, spent = 0, bossKills = 0;
const career = { games: 0, kills: 0, headshots: 0, bosses: 0, time: 0, bestWave: 0, nightmareWave: 0, xp: 0 };
try { Object.assign(career, JSON.parse(store.get('spariaps-career', '{}'))); } catch {}
// levels: the points of every match and the challenges give experience; each level asks for 1000 more than the one before
const MAX_LEVEL = 30;
function levelOf(xp = career.xp) {
  let lvl = 1, need = 2000;
  while (lvl < MAX_LEVEL && xp >= need) { xp -= need; lvl++; need += 1000; }
  return { lvl, cur: lvl < MAX_LEVEL ? xp : need, need };
}
let lastGain = null;   // { xp, from, to, unlocked: [names] } for the end screen
function addXp(n) {
  const from = levelOf().lvl;
  career.xp += Math.max(0, Math.round(n));
  const to = levelOf().lvl;
  const unlocked = to > from ? Object.values(LOOKS).flatMap(g => g.items.filter(i => i.lvl > from && i.lvl <= to).map(i => `${g.name} ${i.name}`)) : [];
  return { xp: Math.round(n), from, to, unlocked };
}
// the running match is added to the career once: when you die, restart or go back to the menu
let banked = true, chalT = 1;
function bankMatch() {
  if (banked) return;
  banked = true; lastGain = null;
  if (now < 5 && !kills) return;
  career.games++; career.kills += kills; career.headshots += headshots; career.bosses += bossKills; career.time += now;
  career.bestWave = Math.max(career.bestWave, wave);
  if (diffKey === 'nightmare') career.nightmareWave = Math.max(career.nightmareWave, wave);
  lastGain = addXp(score);
  store.set('spariaps-career', JSON.stringify(career));
}
// challenges: career totals count the match in progress, the others are the best single match so far
const live = (k, cur) => career[k] + (banked ? 0 : cur);
const CHALLENGES = [
  { id: 'kills100',  name: 'PRIME ARMI',          desc: '100 uccisioni in carriera',                      goal: 100,   val: () => live('kills', kills) },
  { id: 'kills1000', name: 'VETERANO',            desc: '1000 uccisioni in carriera',                     goal: 1000,  val: () => live('kills', kills) },
  { id: 'heads100',  name: 'TIRATORE SCELTO',     desc: '100 headshot in carriera',                       goal: 100,   val: () => live('headshots', headshots) },
  { id: 'games25',   name: 'DI CASA',             desc: 'Gioca 25 partite',                               goal: 25,    val: () => live('games', 1) },
  { id: 'boss1',     name: 'AMMAZZAGIGANTI',      desc: 'Sconfiggi un boss',                              goal: 1,     val: () => live('bosses', bossKills) },
  { id: 'boss10',    name: 'CACCIATORE DI BOSS',  desc: 'Sconfiggi 10 boss in carriera',                  goal: 10,    val: () => live('bosses', bossKills) },
  { id: 'wave10',    name: 'RESISTENZA',          desc: 'Raggiungi l’ondata 10',                          goal: 10,    val: () => banked ? 0 : wave },
  { id: 'night20',   name: 'INCUBO A OCCHI APERTI', desc: 'Raggiungi l’ondata 20 a difficoltà Incubo',    goal: 20,    val: () => banked || diffKey !== 'nightmare' ? 0 : wave },
  { id: 'acc50',     name: 'OCCHIO DI FALCO',     desc: 'Chiudi una partita da almeno 150 colpi con il 50% di precisione', goal: 50, unit: '%', end: true, val: () => shotsFired >= 150 ? Math.round(shotsHit / shotsFired * 100) : 0 },
  { id: 'time15',    name: 'MARATONETA',          desc: 'Sopravvivi 15 minuti in una partita',            goal: 15,    unit: ' min', val: () => banked ? 0 : Math.floor(now / 60) },
  { id: 'houses4',   name: 'PADRONE DI CASA',     desc: 'Apri i 4 edifici del Quartiere in una partita',  goal: 4,     val: () => banked ? 0 : (MAP.houses || []).filter(h => h.open).length },
  { id: 'perks6',    name: 'TUTTO COMPRESO',      desc: 'Compra 6 perk in una partita',                   goal: 6,     val: () => banked ? 0 : Object.keys(perks).length },
  { id: 'spend15k',  name: 'SPENDACCIONE',        desc: 'Spendi 15000 crediti in una partita',            goal: 15000, val: () => banked ? 0 : spent },
];
const chal = {};
try { Object.assign(chal, JSON.parse(store.get('spariaps-challenges', '{}'))); } catch {}
// `ended` is true when the match is over: only then the challenges judged on the whole match are checked
function checkChallenges(ended = false) {
  let dirty = false;
  for (const c of CHALLENGES) {
    if (c.end && !ended) continue;
    const old = chal[c.id] || 0, v = Math.min(c.goal, c.val());
    if (v <= old) continue;
    chal[c.id] = v; dirty = true;
    if (v >= c.goal) {
      addXp(1500); store.set('spariaps-career', JSON.stringify(career));
      toast(`SFIDA COMPLETATA · ${c.name} · +1500 XP`, 'pu', 'box', '#8dffb0');
      sfxTone(660, 0.12, 0.1, 'sine', 660); sfxTone(880, 0.12, 0.1, 'sine', 880, 0.12); sfxTone(1320, 0.3, 0.1, 'sine', 1320, 0.24);
    }
  }
  if (dirty) store.set('spariaps-challenges', JSON.stringify(chal));
}
function renderChallenges() {
  const done = CHALLENGES.filter(c => (chal[c.id] || 0) >= c.goal).length;
  $('chalList').innerHTML = `<div class="chal-sum">${done} / ${CHALLENGES.length} COMPLETATE</div>` + CHALLENGES.map(c => {
    const v = chal[c.id] || 0, ok = v >= c.goal;
    return `<div class="chal${ok ? ' done' : ''}"><div class="top"><b>${ok ? '✓ ' : ''}${c.name}</b><span class="n">${v}${c.unit || ''} / ${c.goal}${c.unit || ''}</span></div><small>${c.desc}</small><div class="cbar"><u style="width:${Math.round(v / c.goal * 100)}%"></u></div></div>`;
  }).join('');
}
const clockStr = t => { t = Math.floor(t); const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60); return h ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}:${String(t % 60).padStart(2, '0')}`; };
const getBest = () => parseInt(store.get(bestKey(), '0'), 10) || 0;

addEventListener('keydown', e => {
  const code = logical(e.code);
  keys[code] = true;
  if (e.code === 'Space' || code === 'Space') e.preventDefault();
  // P pauses/resumes without touching fullscreen (Esc also leaves fullscreen in most browsers)
  if (code === 'KeyP' && !e.repeat) {
    if (state === 'playing') pauseGame();
    else if (state === 'paused' && $('settings').classList.contains('hidden')) enterGame();
    return;
  }
  if (state !== 'playing') return;
  gameKey(code, e.repeat);
});
// gameplay actions shared by the keyboard and the controller
function toggleLean(dir) {
  player.lean = player.lean === dir ? 0 : dir;
  withCat('weapons', () => sfxTone(700, 0.04, 0.03, 'triangle', 500));
}
function gameKey(code, repeat = false) {
  const e = { code, repeat };
  if (e.code === 'Space' && !e.repeat && arena.on && !player.onGround && player.airJumps > 0) {
    // arena double jump
    player.airJumps--; player.vel.y = Math.max(player.vel.y, pw('jump') ? 11 : 8);
    spawnParticles(player.pos.clone().setY(player.pos.y + 0.1), 0x3affe0, 12, new V3(0, -1, 0), 3);
    sfxTone(260, 0.16, 0.12, 'sine', 700);
  }
  if ((e.code === 'Enter' || e.code === 'NumpadEnter') && wave > 0 && waveBreak > 3) waveBreak = 3;
  if (e.code === 'KeyR') startReload();
  if (e.code === 'Digit1') switchWeapon(slots[0]);
  if (e.code === 'Digit2') switchWeapon(slots[1]);
  // Rainbow Six style lean: while aiming Q/E toggle leaning left/right instead of their usual action
  if ((e.code === 'KeyQ' || e.code === 'KeyE') && isAiming()) {
    if (!e.repeat) toggleLean(e.code === 'KeyQ' ? -1 : 1);
    return;
  }
  if (e.code === 'KeyQ') switchWeapon(otherSlot());
  if (e.code === 'KeyV' || e.code === 'KeyF') startMelee();
  if (e.code === 'KeyC' && !(e.repeat || startSlide())) player.crouch = !player.crouch;
  if (e.code === 'KeyE' && !e.repeat) interact();
  if (e.code === 'KeyB' && !e.repeat) dropCurrentWeapon();
  if (e.code === 'KeyG') throwItem('frag');
  if (e.code === 'KeyZ') throwItem('stun');
  if (e.code === 'KeyX') throwItem('smoke');
  if (e.code === 'KeyT') throwItem('tknife');
  if (e.code === 'Escape') pauseGame();
}
function pauseGame() {
  // leaving pointer lock fires pointerlockchange, which opens the pause menu
  if (document.pointerLockElement) document.exitPointerLock();
  else pause();
}
addEventListener('keyup', e => { keys[logical(e.code)] = false; });
addEventListener('blur', () => { firing = aiming = false; for (const k in keys) keys[k] = false; });
const mouseOff = () => touchMode || padMode() && !document.pointerLockElement;
addEventListener('mousedown', e => {
  if (state !== 'playing' || mouseOff()) return;
  // ctrl+click counts as right click (Mac trackpads)
  const right = e.button === 2 || (e.button === 0 && e.ctrlKey);
  if (right) aiming = settings.adsHold ? true : !aiming;
  else if (e.button === 0) { firing = true; triggerQueued = true; triggerT = now; }
});
addEventListener('mouseup', e => {
  if (touchMode) return;
  if (e.button === 0) firing = false;
  if ((e.button === 2 || (e.button === 0 && e.ctrlKey)) && settings.adsHold) aiming = false;
});
let wheelT = 0;
addEventListener('wheel', e => {
  if (state === 'playing' && !mouseOff() && Math.abs(e.deltaY) > 2 && performance.now() - wheelT > 250) { wheelT = performance.now(); switchWeapon(otherSlot()); }
}, { passive: true });
addEventListener('contextmenu', e => e.preventDefault());
addEventListener('mousemove', e => {
  if (state !== 'playing' || mouseOff()) return;
  const s = 0.0022 * settings.sens * (weapon.adsT > 0.5 ? (W().scope ? 0.28 : 0.6) : 1);
  player.yaw -= e.movementX * s;
  player.pitch = clamp(player.pitch - e.movementY * s, -1.5, 1.5);
  swayX += e.movementX * 0.00015; swayY += e.movementY * 0.00015;
});

function startReload() {
  if (weapon.reloading || weapon.switchT > 0 || weapon.meleeT > 0 || weapon.mags[weapon.current] === magOf(weapon.current)) return;
  if (pw('ammo')) { weapon.mags[weapon.current] = magOf(weapon.current); return; }
  weapon.reloading = true; weapon.reloadT = reloadOf(); weapon.burstLeft = 0; weapon.cueI = 0;
  triggerQueued = false;
}
function switchWeapon(to) {
  if (!WEAPONS[to] || weapon.meleeT > 0) return;
  if (to === weapon.current && weapon.switchT <= 0) return;
  weapon.switchTo = to; weapon.burstLeft = 0; weapon.spin = 0;
  if (weapon.switchT <= 0) weapon.switchT = SWITCH_TIME;
  weapon.reloading = false;
  withCat('weapons', () => sfxTone(900, 0.05, 0.08, 'triangle', 600));
}
function startMelee() {
  if (weapon.meleeT > 0) return;
  weapon.meleeT = MELEE_TIME; weapon.meleeHit = false;
  weapon.reloading = false;
  withCat('weapons', () => sfxSwoosh());
}
function doMeleeHit() {
  const fwd = new V3(-Math.sin(player.yaw), 0, -Math.cos(player.yaw));
  let target = null, bestD = 2.6;
  for (const b of enemies) {
    if (b.dead || Math.abs(player.pos.y - b.pos.y) > 1.4) continue;
    const to = new V3(b.pos.x - player.pos.x, 0, b.pos.z - player.pos.z);
    const d = to.length();
    if (d < bestD && d > 0 && to.divideScalar(d).dot(fwd) > 0.7) { target = b; bestD = d; }
  }
  if (target) {
    const hp = target.hp;
    target.damage(KNIFE_DMG * (pw('quad') ? 3 : 1), false, 'knife');
    showDamageNumber(target.pos.clone().setY(1.5), Math.min(hp, KNIFE_DMG), false, target.dead);
    spawnParticles(target.pos.clone().setY(1.2), target.sparkColor, 16, fwd.clone().negate(), 4);
    showHitmarker(target.dead);
    sfxTone(140, 0.12, 0.35, 'square', 60);
    sfxTone(700, 0.18, 0.2, 'triangle', 1600);
    player.vel.addScaledVector(fwd, 3);
    player.shake = Math.max(player.shake, 0.4);
    return;
  }
  camera.updateMatrixWorld();
  const dir = new V3(0, 0, -1).applyQuaternion(camera.quaternion);
  losRay.set(camera.position, dir); losRay.far = 2;
  const h = losRay.intersectObjects(worldMeshes, false)[0];
  if (h) {
    const n = h.face.normal.clone().transformDirection(h.object.matrixWorld);
    spawnParticles(h.point.clone().addScaledVector(n, 0.03), 0xffe0a0, 6, n, 3);
    sfxTone(2600, 0.06, 0.15, 'square', 1800);
  }
}

function damagePlayer(amount, from, raw = false) {
  if (state !== 'playing') return;
  if (pw('god')) { player.shake = Math.min(1, player.shake + 0.1); sfxTone(1400, 0.06, 0.08, 'triangle', 1900); return; }
  if (!raw) amount *= D.dmg;
  if (perks.tank) amount *= 0.7;
  if (player.armor > 0) {
    const absorbed = Math.min(player.armor, amount * 0.7);
    player.armor -= absorbed; amount -= absorbed;
  }
  player.hp -= amount; player.lastHit = now;
  rumble(0.7, 0.5, 200);
  hurt = Math.min(1, hurt + 0.7);
  player.shake = Math.min(1, player.shake + 0.5);
  sfxTone(200, 0.15, 0.25, 'sawtooth', 90);
  const v = from.clone().sub(player.pos);
  const rot = player.yaw + Math.PI - Math.atan2(v.x, v.z);
  const el = document.createElement('div');
  el.className = 'dmgdir'; el.style.transform = `rotate(${rot}rad)`;
  $('dmgdirs').appendChild(el);
  el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 1200, easing: 'ease-in' }).onfinish = () => el.remove();
  if (player.hp <= 0) { if (revives > 0) secondLife(); else gameOver(); }
}

// knocked down with a life in reserve: back on your feet, briefly untouchable, and everything around you is dazed
function secondLife() {
  revives--; renderPerks();
  player.hp = 60; player.lastHit = now; hurt = 0;
  powers.god = Math.max(powers.god, 3.5);
  blind = Math.max(blind, 0.55);
  player.shake = 1;
  const p = player.pos.clone().setY(player.pos.y + 0.12);
  addWave(p, 9, 0.5);
  spawnParticles(p.clone().setY(p.y + 1), 0xff5c7a, 40, new V3(0, 1, 0), 8);
  for (const b of enemies) {
    if (b.dead || Math.hypot(b.pos.x - player.pos.x, b.pos.z - player.pos.z) > 9) continue;
    b.stunT = Math.max(b.stunT, b.boss ? 0.9 : 2.4);
  }
  showBanner('SECONDA VITA', revives ? `TE NE RESTA ANCORA ${revives === 1 ? 'UNA' : revives}` : 'ERA L’ULTIMA · LA PROSSIMA CADUTA È LA FINE');
  rumble(1, 1, 500);
  withCat('fx', () => { sfxTone(110, 0.5, 0.3, 'sine', 55); [392, 523, 659, 784].forEach((f, i) => sfxTone(f, 0.3, 0.1, 'triangle', f, 0.12 + i * 0.09)); });
}
// slide: crouch while sprinting. A short burst of speed in the direction you were running, low profile, no steering
const SLIDE_T = 0.8;
function startSlide() {
  const hs = Math.hypot(player.vel.x, player.vel.z);
  if (state !== 'playing' || player.slideT > 0 || player.slideCD > 0 || !player.onGround || player.sprintT < 0.5 || hs < 6) return false;
  player.slideT = SLIDE_T; player.slideCD = 0.5; player.crouch = false;
  player.slideDir.set(player.vel.x / hs, 0, player.vel.z / hs);
  sfxTone(170, 0.45, 0.07, 'sawtooth', 60);
  return true;
}
// true when something solid crosses the column over (x, z) between the two heights
function columnBlocked(x, z, r, y0, y1) {
  const e = r * 0.6;
  for (const b of colliders) if (x + e > b.min.x && x - e < b.max.x && z + e > b.min.z && z - e < b.max.z && b.min.y < y1 && b.max.y > y0) return true;
  return false;
}
function updatePlayer(dt) {
  const fwd = new V3(-Math.sin(player.yaw), 0, -Math.cos(player.yaw));
  const right = new V3(Math.cos(player.yaw), 0, -Math.sin(player.yaw));
  // keyboard gives full-speed input, the left stick is analog (partial tilt = walk slower)
  const wish = new V3()
    .addScaledVector(fwd, (keys.KeyW ? 1 : 0) - (keys.KeyS ? 1 : 0) + pad.my)
    .addScaledVector(right, (keys.KeyD ? 1 : 0) - (keys.KeyA ? 1 : 0) + pad.mx);
  if (wish.lengthSq() > 1) wish.normalize();
  const wantSprint = ((keys.ShiftLeft || keys.ShiftRight) && keys.KeyW) || (pad.sprint && pad.my > 0.35);
  if (wantSprint && player.crouch) player.crouch = false;
  const sliding = player.slideT > 0;
  const sprint = wantSprint && !firing && weapon.adsT < 0.3 && player.onGround && weapon.meleeT <= 0 && !sliding;
  player.sprintT = clamp(player.sprintT + (sprint ? 1 : -1) * dt * 7, 0, 1);
  player.crouchT = clamp(player.crouchT + (player.crouch || sliding ? 1 : -1) * dt * (sliding ? 12 : 7), 0, 1);
  player.slideCD = Math.max(0, player.slideCD - dt); player.vaultCD = Math.max(0, player.vaultCD - dt);
  const A = arena.on;
  const speed = (sprint ? 8.5 : 5.5) * (A ? 1.1 : 1) * (weapon.adsT > 0.5 ? 0.6 : 1) * lerp(1, 0.5, player.crouchT) * (W().speed || 1) * (pw('haste') ? 1.4 : 1) * (perks.speed ? 1.12 : 1);
  if (sliding) {
    // fast at first, then friction wins; leaving the ground (a jump, a ledge) ends it with the momentum intact
    player.slideT -= dt;
    const v = lerp(4.5, 12, Math.max(0, player.slideT) / SLIDE_T) * (pw('haste') ? 1.2 : 1);
    if (player.onGround) { player.vel.x = player.slideDir.x * v; player.vel.z = player.slideDir.z * v; } else player.slideT = 0;
  } else if (player.onGround) {
    player.vel.x += (wish.x * speed - player.vel.x) * Math.min(1, 12 * dt);
    player.vel.z += (wish.z * speed - player.vel.z) * Math.min(1, 12 * dt);
    // vault: sprinting into something low (a crate, a car bonnet, a window sill) hops you onto it
    if (player.sprintT > 0.6 && player.vaultCD <= 0 && wish.lengthSq() > 0.25) {
      const px = player.pos.x + wish.x * (player.r + 0.35), pz = player.pos.z + wish.z * (player.r + 0.35);
      const top = groundAt(px, pz, player.pos.y + 0.79, player.r), rise = top - player.pos.y;
      if (rise > 0.45 && !columnBlocked(px, pz, player.r, top + 0.05, top + 1.3) && !columnBlocked(player.pos.x, player.pos.z, player.r, player.pos.y + 1.85, top + 1.85)) {
        player.vel.y = Math.sqrt(40 * (rise + 0.12)); player.onGround = false; player.vaultCD = 0.6;
        player.landOff = 0.06; sfxTone(240, 0.12, 0.06, 'sine', 420);
      }
    }
  } else {
    // air control keeps momentum (jump pads, strafe jumps) and only adds speed toward the input
    const cur = player.vel.x * wish.x + player.vel.z * wish.z;
    const add = Math.min(Math.max(0, speed - cur), speed * (A || pw('jump') ? 5 : 2.5) * dt);
    player.vel.x += wish.x * add; player.vel.z += wish.z * add;
  }
  if ((keys.Space || pad.jump) && player.onGround) {
    player.slideT = 0;
    if (player.crouch) player.crouch = false;
    else if (pw('jump')) { player.vel.y = A ? 14 : 12.5; player.onGround = false; sfxTone(320, 0.22, 0.14, 'sine', 900); }
    else { player.vel.y = A ? 8.8 : 7; player.onGround = false; }
  }
  player.vel.y -= 20 * dt;
  const height = lerp(1.8, 1.25, player.crouchT);

  player.pos.x += player.vel.x * dt;
  player.pos.z += player.vel.z * dt;
  collideCircle(player.pos, player.r, player.pos.y, height);
  for (const b of enemies) {
    if (b.dead || Math.abs(player.pos.y - b.pos.y) > 1.5) continue;
    const dx = player.pos.x - b.pos.x, dz = player.pos.z - b.pos.z, d = Math.hypot(dx, dz);
    if (d < 0.8 && d > 1e-4) { player.pos.x += dx / d * (0.8 - d); player.pos.z += dz / d * (0.8 - d); }
  }
  const prevFeet = player.pos.y, prevVy = player.vel.y, wasGround = player.onGround;
  player.pos.y += player.vel.y * dt;
  if (player.vel.y > 0) {
    const c = ceilingAt(player.pos.x, player.pos.z, player.r, prevFeet + height, player.pos.y + height);
    if (c !== null) { player.pos.y = c - height - 0.01; player.vel.y = 0; }
  }
  const g = groundAt(player.pos.x, player.pos.z, prevFeet, player.r);
  if (player.pos.y <= g) {
    player.pos.y = g; player.vel.y = 0; player.onGround = true;
    player.airJumps = 1;
    if (!wasGround && prevVy < -4) { player.landOff = Math.min(pw('jump') ? 0.12 : 0.2, -prevVy * 0.016); sfxTone(90, 0.08, 0.15, 'sine', 50); }
  } else player.onGround = false;
  tryJumpPad();

  if (now - player.lastHit > D.regenDelay * (perks.regen ? 0.5 : 1)) player.hp = Math.min(100, player.hp + D.regen * (perks.regen ? 2 : 1) * dt);

  // camera: head bob, strafe roll, landing dip, shake
  const hs = Math.hypot(player.vel.x, player.vel.z);
  if (player.onGround) player.bob += hs * dt * 1.55;
  const bobAmt = clamp(hs / 8.5, 0, 1) * (player.onGround ? 1 : 0) * (1 - weapon.adsT * 0.75);
  const lat = player.vel.dot(right);
  player.roll = lerp(player.roll, -lat * 0.0035, Math.min(1, dt * 8));
  player.landOff *= Math.exp(-dt * 9);
  player.shake *= Math.exp(-dt * 7);
  const sh = player.shake * 0.012;
  const bobY = Math.sin(player.bob * 2) * 0.035 * bobAmt;
  const bobX = Math.cos(player.bob) * 0.022 * bobAmt;
  // lean: shift the eye sideways (stopping short of walls) and roll the view
  if (!isAiming() || player.sprintT > 0.3) player.lean = 0;
  player.leanT += (player.lean - player.leanT) * Math.min(1, dt * 10);
  let leanDist = 0.45 * player.leanT;
  if (Math.abs(leanDist) > 0.01) {
    const eye0 = new V3(player.pos.x, player.pos.y + eyeHeight(), player.pos.z), side = right.clone().multiplyScalar(Math.sign(leanDist));
    losRay.set(eye0, side); losRay.far = Math.abs(leanDist) + 0.25;
    const h = losRay.intersectObjects(worldMeshes, false)[0];
    if (h) leanDist = Math.sign(leanDist) * Math.max(0, Math.min(Math.abs(leanDist), h.distance - 0.25));
  }
  player.leanV.copy(right).multiplyScalar(leanDist).setY(-Math.abs(player.leanT) * 0.07);
  camera.position.set(player.pos.x + right.x * bobX, player.pos.y + eyeHeight() + bobY - player.landOff, player.pos.z + right.z * bobX).add(player.leanV);
  const sway = W().scope && weapon.adsT > 0.85 ? 1 - player.crouchT * 0.6 : 0; // breathing through the scope
  camera.rotation.set(player.pitch + weapon.recoilOff + rand(-sh, sh) + Math.sin(now * 0.8) * 0.0018 * sway,
    player.yaw + rand(-sh, sh) + Math.cos(now * 1.1) * 0.0022 * sway, player.roll + Math.sin(player.bob) * 0.005 * bobAmt - player.leanT * 0.24);
}

// ============================================================ shooting
const shootRay = new THREE.Raycaster();
function currentSpread() {
  const w = W(), speed = Math.hypot(player.vel.x, player.vel.z);
  return (lerp(w.hip, w.ads, weapon.adsT) + speed / 8.5 * lerp(w.move, w.move * 0.33, weapon.adsT) + (player.onGround ? 0 : 0.06) + weapon.bloom) * lerp(1, 0.65, player.crouchT);
}
function muzzleWorld() {
  holder.updateMatrixWorld();
  return camera.localToWorld(W().flash.getWorldPosition(new V3()));
}
let shotTargets = [];
function castShot(origin, dir, w, agg) {
  shootRay.set(origin, dir); shootRay.far = 250;
  const hit = shootRay.intersectObjects(shotTargets, false)[0];
  let end = origin.clone().addScaledVector(dir, 150);
  if (hit) {
    end = hit.point;
    const enemy = hit.object.userData.enemy;
    if (enemy) {
      if (!enemy.dead) {
        const part = hit.object.userData.part, head = part === 'head', prev = enemy.hp;
        const dmg = w.dmg[part] * (pw('quad') ? 3 : 1) * dmgMul(weapon.current);
        const killed = enemy.damage(dmg, head, weapon.current);
        const a = agg.get(enemy) || { sum: 0, point: hit.point, head: false, killed: false };
        a.sum += Math.min(prev, dmg); a.head ||= head; a.killed ||= killed;
        agg.set(enemy, a);
      }
      spawnParticles(hit.point, enemy.sparkColor, w.pellets ? 3 : 7, dir.clone().negate(), 3);
    } else {
      const n = hit.face.normal.clone().transformDirection(hit.object.matrixWorld);
      const p = hit.point.clone().addScaledVector(n, 0.03);
      spawnParticles(p, 0xffc680, w.pellets ? 1 : 3, n, 3);
      spawnParticles(p, 0x9a948a, w.pellets ? 2 : 4, n, 2.5, false);
      if (!w.pellets || Math.random() < 0.3) spawnSmoke(p, 0xd6cec2, 0.5);
      addDecal(hit.point, n);
    }
  }
  spawnTracer(muzzleWorld(), end, pw('quad') ? 0xd08cff : 0xffe29a);
}
function shoot() {
  const w = W();
  if (!pw('ammo')) weapon.mags[weapon.current]--;
  weapon.cooldown = w.rate * (pw('haste') ? 0.75 : 1) * (perks.rate ? 0.8 : 1);
  shotsFired++;
  rumble(w.pellets || w.projectile ? 0.55 : w.scope ? 0.7 : 0.18, 0.4, w.scope || w.pellets ? 120 : 60);
  camera.updateMatrixWorld();
  const origin = camera.getWorldPosition(new V3());
  shotTargets = worldMeshes.concat(...enemies.filter(b => !b.dead).map(b => b.parts));
  const agg = new Map(), spread = currentSpread();
  if (w.projectile) {
    // energy bolt: aim where the crosshair points, launch it from the muzzle
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * spread;
    const dir = new V3(Math.cos(a) * r, Math.sin(a) * r, -1).normalize().applyQuaternion(camera.quaternion);
    shootRay.set(origin, dir); shootRay.far = 120;
    const h = shootRay.intersectObjects(shotTargets, false)[0];
    const target = h ? h.point : origin.clone().addScaledVector(dir, 120);
    const m = muzzleWorld();
    launchProjectile(w.projectile, m, target.sub(m).normalize().multiplyScalar(w.projSpeed));
  }
  for (let i = 0; i < (w.projectile ? 0 : w.pellets || 1); i++) {
    const sp = w.pellets ? w.pelletSpread * lerp(1, 0.75, weapon.adsT) + spread * 0.5 : spread;
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * sp;
    castShot(origin, new V3(Math.cos(a) * r, Math.sin(a) * r, -1).normalize().applyQuaternion(camera.quaternion), w, agg);
  }
  let anyKill = false;
  for (const a of agg.values()) { showDamageNumber(a.point, a.sum, a.head, a.killed); anyKill ||= a.killed; }
  if (agg.size) {
    shotsHit++;
    showHitmarker(anyKill);
    sfxTone(anyKill ? 700 : 1500, anyKill ? 0.18 : 0.05, anyKill ? 0.25 : 0.12, anyKill ? 'triangle' : 'square', anyKill ? 1600 : 1500);
  }
  weapon.flashT = 0.05; weapon.kick = 1; weapon.slideKick = 1;
  weapon.bloom = Math.min(0.05, weapon.bloom + w.bloom);
  // every weapon has its own spray: `n` counts the shots of the current burst and resets when you let go for a moment
  const rc = RECOIL[weapon.current] || RECOIL.rifle, n = weapon.spray++, steady = lerp(1, 0.6, weapon.adsT) * lerp(1, 0.7, player.crouchT);
  weapon.sprayT = w.rate + 0.28;
  weapon.recoilOff += w.recoil * lerp(1, 0.5, weapon.adsT) * lerp(1, 0.7, player.crouchT);
  player.pitch = clamp(player.pitch + w.climb * rc.v(n) * steady, -1.5, 1.5);
  player.yaw -= (rc.h(n) + rand(-rc.jit, rc.jit)) * steady;
  player.shake = Math.max(player.shake, w.shake ?? 0.12);
  if (w.projectile === 'plasma') sfxRay(); else if (w.projectile) sfxRocketLaunch(); else sfxShot(w.snd, w.vol);
  if (w.projectile) {}
  else if (w.pump) { sfxTone(900, 0.05, 0.12, 'square', 500, 0.28); sfxTone(650, 0.06, 0.12, 'square', 380, 0.46); }
  else if (w.bolt) { sfxTone(1300, 0.04, 0.1, 'square', 700, 0.4); sfxTone(900, 0.05, 0.1, 'square', 600, 0.7); }
  else sfxShell(rand(0.3, 0.45));
  if (weapon.mags[weapon.current] === 0) startReload();
}

let hitmarkerAnim = null;
function showHitmarker(kill) {
  const el = $('hitmarker');
  el.classList.toggle('kill', kill);
  hitmarkerAnim?.cancel();
  hitmarkerAnim = el.animate([{ opacity: 1, transform: 'rotate(45deg) scale(1.35)' }, { opacity: 0, transform: 'rotate(45deg) scale(1)' }], { duration: kill ? 450 : 220, easing: 'ease-out' });
}

function updateWeapon(dt) {
  weapon.cooldown -= dt;
  let lower = 0;
  if (weapon.switchT > 0) {
    weapon.switchT -= dt;
    if (weapon.switchT <= SWITCH_TIME / 2 && weapon.switchTo && weapon.switchTo !== weapon.current) {
      weapon.last = weapon.current; weapon.current = weapon.switchTo;
      weapon.bloom = 0;
    }
    if (weapon.switchT <= 0) weapon.switchTo = null;
    const t = clamp(weapon.switchT / SWITCH_TIME, 0, 1);
    lower = t > 0.5 ? (1 - t) * 2 : t * 2;
  }
  let meleeP = 0;
  if (weapon.meleeT > 0) {
    weapon.meleeT -= dt;
    meleeP = 1 - clamp(weapon.meleeT / MELEE_TIME, 0, 1);
    if (!weapon.meleeHit && meleeP > 0.32) { weapon.meleeHit = true; doMeleeHit(); }
  }
  if (weapon.throwT > 0) weapon.throwT -= dt;
  const busy = weapon.switchT > 0 || weapon.meleeT > 0 || weapon.throwT > 0;
  const w = W();

  if (weapon.reloading) {
    weapon.reloadT -= dt;
    // mechanical reload sounds, cued along the animation
    const cues = RELOAD_CUES[w.cues || 'default'], rp = 1 - weapon.reloadT / reloadOf();
    while (weapon.cueI < cues.length && rp >= cues[weapon.cueI][0]) sfxMech(cues[weapon.cueI++][1]);
    if (weapon.reloadT <= 0) { weapon.reloading = false; weapon.mags[weapon.current] = magOf(weapon.current); }
  }
  // simplified aiming: holding fire also aims, and shots wait until the sights are up
  const autoAim = settings.autoAds && firing && !aiming && !w.projectile;
  const needAds = autoAim ? (w.scope ? 0.85 : 0.3) : 0;
  // no shot queue: clicks while reloading/switching are dropped, early clicks are buffered only briefly
  if (triggerQueued && (weapon.reloading || busy)) triggerQueued = false;
  if (triggerQueued && now - triggerT > 0.18 && !autoAim) triggerQueued = false;
  // minigun: barrels must spin up before it fires
  if (w.spinup) {
    const was = weapon.spin;
    weapon.spin = clamp(weapon.spin + ((firing || aiming) && !busy && !weapon.reloading ? 1.8 : -1.2) * dt, 0, 1);
    if (was === 0 && weapon.spin > 0) sfxTone(90, 0.5, 0.06, 'sawtooth', 320);
    w.spin.rotation.z += weapon.spin * dt * 38;
  }
  const wantsFire = (w.auto ? firing : triggerQueued) && (!w.spinup || weapon.spin > 0.7) && weapon.adsT >= needAds;
  if (w.burst && weapon.burstLeft > 0) {
    if (!busy && !weapon.reloading && weapon.cooldown <= 0) {
      if (weapon.mags[weapon.current] > 0) { shoot(); if (--weapon.burstLeft === 0) weapon.cooldown = w.burstDelay; }
      else weapon.burstLeft = 0;
    }
  } else if (wantsFire && !busy && !weapon.reloading && weapon.cooldown <= 0 && player.sprintT < 0.4) {
    if (weapon.mags[weapon.current] > 0) {
      shoot();
      if (w.burst) { weapon.burstLeft = w.burst - 1; if (!weapon.burstLeft) weapon.cooldown = w.burstDelay; }
    } else startReload();
    triggerQueued = false;
  }
  weapon.bloom = Math.max(0, weapon.bloom - dt * 0.08);
  if ((weapon.sprayT -= dt) <= 0) weapon.spray = 0;
  weapon.recoilOff *= Math.exp(-dt * 12);
  weapon.kick *= Math.exp(-dt * 18);
  weapon.slideKick *= Math.exp(-dt * 28);
  weapon.flashT -= dt;
  weapon.adsT = clamp(weapon.adsT + (((aiming || autoAim) && !weapon.reloading && !busy && player.sprintT < 0.5) ? 1 : -1) * dt * (w.adsSpeed || 7), 0, 1);

  camera.fov = lerp(75, w.fov, weapon.adsT) + player.sprintT * 5; camera.updateProjectionMatrix();
  gunCam.fov = lerp(60, 45, weapon.adsT); gunCam.updateProjectionMatrix();

  for (const [k, def] of Object.entries(WEAPONS)) def.group.visible = k === weapon.current;

  // pose: hip/ads, bob, sway, strafe tilt, jump lag, sprint, kick, reload, switch, melee
  swayX *= Math.exp(-dt * 8); swayY *= Math.exp(-dt * 8);
  const speed = Math.hypot(player.vel.x, player.vel.z);
  const bobAmt = (player.onGround ? speed / 8 : 0) * (1 - weapon.adsT * 0.85);
  const bt = player.bob;
  const sp = smooth(player.sprintT), ads = weapon.adsT;
  holder.position.lerpVectors(w.hipPos, w.adsPos, ads);
  holder.position.x += Math.sin(bt) * 0.014 * bobAmt - clamp(swayX, -0.03, 0.03);
  holder.position.y += Math.abs(Math.cos(bt)) * 0.014 * bobAmt + clamp(swayY, -0.03, 0.03) + Math.sin(now * 1.7) * 0.0025 * (1 - ads);
  holder.position.y += clamp(-player.vel.y * 0.004, -0.04, 0.04) - player.landOff * 0.35;
  holder.position.z += weapon.kick * (w.kickBack ?? 0.05);
  holder.position.x -= sp * 0.06; holder.position.y -= sp * 0.05;
  // hip pose: the weapon is held a little higher and turned toward the crosshair, so its side and both hands are in view
  const hip = (1 - smooth(ads)) * (w.hipYaw ?? 0.2) / 0.2;
  holder.position.x -= hip * 0.03; holder.position.y += hip * 0.045;
  holder.rotation.set(
    weapon.kick * (w.kickRot ?? 0.06) - sp * 0.25 + hip * 0.02,
    sp * 0.75 + hip * 0.2,
    player.roll * 3 + sp * 0.3 + Math.sin(now * 1.1) * 0.004 * (1 - ads) - hip * 0.06);
  // reload: tilt, mag drops out and a new one slides in
  if (weapon.reloading) {
    const p = 1 - weapon.reloadT / reloadOf();
    const tilt = Math.sin(Math.min(1, p * 1.1) * Math.PI);
    holder.rotation.x -= tilt * 0.3; holder.rotation.z += tilt * 0.5; holder.position.y -= tilt * 0.06;
    if (p > 0.74 && p < 0.86) holder.position.y += Math.sin((p - 0.74) / 0.12 * Math.PI) * 0.018;
    let off = 0, vis = true;
    if (p < 0.12) off = 0;
    else if (p < 0.34) off = -smooth((p - 0.12) / 0.22) * 0.32;
    else if (p < 0.5) vis = false;
    else if (p < 0.76) off = -(1 - smooth((p - 0.5) / 0.26)) * 0.32;
    w.mag.visible = vis;
    w.mag.position.y = w.magBase.y + off;
    // the off hand lets go, pulls the magazine down and out of view, brings the new one up, taps it home and returns
    const L = w.group.userData.leftArm;
    if (L) {
      const D = w.group.userData.reloadD ||= w.magBase.clone().sub(w.group.userData.leftPos).add(new V3(-0.01, -0.07, 0.03));
      const k = p < 0.12 ? smooth(p / 0.12) : p > 0.88 ? 1 - smooth((p - 0.88) / 0.12) : 1;
      L.position.copy(D).multiplyScalar(k); L.position.y += vis ? off : -0.4;
      L.rotation.z = k * 0.3;
    }
  } else {
    w.mag.visible = true; w.mag.position.y = w.magBase.y;
    const L = w.group.userData.leftArm;
    if (L) { L.position.set(0, 0, 0); L.rotation.z = 0; }
  }
  if (w.slide) {
    const locked = weapon.mags.pistol === 0 && !(weapon.reloading && 1 - weapon.reloadT / reloadOf() > 0.8);
    w.slide.position.z = w.slideBase + (locked ? 0.035 : weapon.slideKick * 0.045);
  }
  // pump / bolt cycling after each shot
  if ((w.pump || w.bolt) && weapon.cooldown > 0 && !weapon.reloading) {
    const p = 1 - weapon.cooldown / w.rate;
    const cyc = Math.sin(clamp((p - 0.18) / 0.6, 0, 1) * Math.PI);
    if (w.pump) { w.pump.position.z = w.pumpBase + cyc * 0.11; holder.rotation.x += cyc * 0.06; }
    if (w.bolt) { w.bolt.rotation.z = cyc * 1.3; w.bolt.position.z = 0.08 + Math.sin(clamp((p - 0.3) / 0.4, 0, 1) * Math.PI) * 0.07; holder.rotation.z += cyc * 0.18; }
  } else {
    if (w.pump) w.pump.position.z = w.pumpBase;
    if (w.bolt) { w.bolt.rotation.z = 0; w.bolt.position.z = 0.08; }
  }
  const scoped = !!w.scope && weapon.adsT > 0.85 && weapon.switchT <= 0;
  $('scope').classList.toggle('on', scoped);
  holder.visible = !scoped;
  holder.position.y -= smooth(lower) * 0.4;
  holder.rotation.x -= smooth(lower) * 0.6;
  holder.rotation.z += smooth(lower) * 0.5;
  const throwP = weapon.throwT > 0 ? Math.sin((1 - weapon.throwT / THROW_TIME) * Math.PI) : 0;
  holder.position.y -= throwP * 0.22; holder.rotation.x -= throwP * 0.35; holder.position.x += throwP * 0.08;
  // throw: the left arm comes up from below, winds back and swings forward, then drops away
  throwArm.visible = weapon.throwT > 0;
  if (throwArm.visible) {
    const t = 1 - weapon.throwT / THROW_TIME, up = smooth(clamp(t / 0.3, 0, 1)), fw = smooth(clamp((t - 0.25) / 0.35, 0, 1)), out = smooth(clamp((t - 0.7) / 0.3, 0, 1));
    throwArm.position.set(-0.26 + fw * 0.14, -0.52 + up * 0.42 - fw * 0.06 - out * 0.45, -0.4 - fw * 0.34);
    throwArm.rotation.set(0.9 - fw * 1.5, 0.25 - fw * 0.2, 0.2);
  }
  const meleeDip = meleeP > 0 ? Math.sin(meleeP * Math.PI) : 0;
  holder.position.y -= meleeDip * 0.3;
  holder.position.x += meleeDip * 0.1;

  knife.visible = weapon.meleeT > 0;
  if (knife.visible) {
    const a = smooth(clamp((meleeP - 0.12) / 0.3, 0, 1));
    const o = smooth(clamp((meleeP - 0.6) / 0.4, 0, 1));
    knife.position.set(lerp(0.32, -0.22, a), lerp(-0.12, -0.2, a) - o * 0.35 - (1 - smooth(clamp(meleeP / 0.12, 0, 1))) * 0.3, lerp(-0.42, -0.55, a));
    knife.rotation.set(lerp(0.1, -0.3, a), lerp(0.9, -0.5, a), lerp(-0.9, 0.3, a));
  }

  const flash = w.flash;
  flash.visible = weapon.flashT > 0;
  if (flash.visible) { flash.material.rotation = Math.random() * 6.28; flash.scale.setScalar(rand(0.8, 1.2) * flash.userData.size); }
  muzzleLight.intensity = weapon.flashT > 0 ? 30 : 0;
  gunMuzzleLight.intensity = weapon.flashT > 0 ? 4 : 0;
  if (weapon.flashT > 0) gunMuzzleLight.position.copy(holder.position).add(new V3(0, 0.05, -0.3));
}
