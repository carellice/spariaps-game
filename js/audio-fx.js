// Spariaps — Audio di base ed effetti visivi.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ audio
const VOLUME = 0.45;
let actx = null, master = null, noiseBuf = null, reverb = null;
let muted = store.get('spariaps-muted', '0') === '1';
// every sound goes through a category bus so each one has its own volume slider
const SFX_CATS = { weapons: 'volWeapons', enemies: 'volEnemies', fx: 'volFx', ui: 'volUi', music: 'volMusic' };
const buses = {}, revSends = {};
let sfxCat = 'fx';
const sfxOut = () => buses[sfxCat] || master;
const revIn = () => revSends[sfxCat] || reverb;
function withCat(cat, fn) { const prev = sfxCat; sfxCat = cat; try { fn(); } finally { sfxCat = prev; } }
function applyVolumes() {
  if (actx) {
    master.gain.setTargetAtTime(muted ? 0 : VOLUME * settings.volMaster, actx.currentTime, 0.03);
    for (const [c, k] of Object.entries(SFX_CATS)) {
      buses[c].gain.setTargetAtTime(settings[k], actx.currentTime, 0.03);
      revSends[c].gain.setTargetAtTime(settings[k], actx.currentTime, 0.03);
    }
  }
  updateSongVolume();
}
function setMuted(v) {
  muted = v;
  store.set('spariaps-muted', v ? '1' : '0');
  applyVolumes();
  $('soundBtn').classList.toggle('muted', v);
}
$('soundBtn').classList.toggle('muted', muted);
$('soundBtn').addEventListener('click', e => { e.stopPropagation(); setMuted(!muted); e.currentTarget.blur(); });
addEventListener('keydown', e => { if (e.code === 'KeyM') setMuted(!muted); });
function initAudio() {
  if (actx) { actx.resume(); return; }
  actx = new (window.AudioContext || window.webkitAudioContext)();
  master = actx.createGain(); master.gain.value = muted ? 0 : VOLUME; master.connect(actx.destination);
  noiseBuf = actx.createBuffer(1, actx.sampleRate * 2, actx.sampleRate);
  const d = noiseBuf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  // generated impulse response: the arena's echo tail behind every shot
  reverb = actx.createConvolver();
  const len = Math.floor(actx.sampleRate * 1.6), ir = actx.createBuffer(2, len, actx.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const b = ir.getChannelData(ch);
    for (let i = 0; i < len; i++) b[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3.2) * Math.min(1, i / 600);
  }
  reverb.buffer = ir;
  const rg = actx.createGain(); rg.gain.value = 0.32;
  reverb.connect(rg).connect(master);
  for (const c of Object.keys(SFX_CATS)) {
    buses[c] = actx.createGain(); buses[c].connect(master);
    revSends[c] = actx.createGain(); revSends[c].connect(reverb);
  }
  applyVolumes();
}
function out(pan) {
  if (pan && actx.createStereoPanner) { const p = actx.createStereoPanner(); p.pan.value = clamp(pan, -1, 1); p.connect(sfxOut()); return p; }
  return sfxOut();
}
const panOf = pos => { const v = pos.clone().sub(player.pos); return Math.sin(player.yaw + Math.PI - Math.atan2(v.x, v.z)) * 0.8; };
// gunshot = supersonic crack + muzzle blast + low-end punch + echo; distance makes it duller and wetter
const SND = {
  rifle:   { crack: 0.9,  body: 1.0,  freq: 1500, len: 0.22, sub: 0.8,  tail: 0.35 },
  pistol:  { crack: 0.8,  body: 0.75, freq: 2000, len: 0.14, sub: 0.45, tail: 0.28 },
  shotgun: { crack: 0.75, body: 1.35, freq: 950,  len: 0.4,  sub: 1.3,  tail: 0.5 },
  sniper:  { crack: 1.25, body: 1.2,  freq: 1200, len: 0.38, sub: 1.1,  tail: 0.85 },
  lmg:     { crack: 0.9,  body: 1.05, freq: 1300, len: 0.24, sub: 0.95, tail: 0.35 },
  smg:     { crack: 0.7,  body: 0.7,  freq: 2300, len: 0.11, sub: 0.4,  tail: 0.22 },
  bot:     { crack: 0.8,  body: 0.95, freq: 1400, len: 0.22, sub: 0.7,  tail: 0.45 },
  uzi:     { crack: 0.65, body: 0.65, freq: 2500, len: 0.1,  sub: 0.35, tail: 0.2 },
  burst:   { crack: 0.9,  body: 0.95, freq: 1600, len: 0.2,  sub: 0.75, tail: 0.32 },
  dmr:     { crack: 1.1,  body: 1.1,  freq: 1300, len: 0.3,  sub: 0.95, tail: 0.6 },
  minigun: { crack: 0.7,  body: 0.9,  freq: 1400, len: 0.12, sub: 0.7,  tail: 0.25 },
  magnum:  { crack: 1.15, body: 1.2,  freq: 1250, len: 0.32, sub: 1.1,  tail: 0.65 },
};
function noiseSrc(t, dur) {
  const src = actx.createBufferSource(); src.buffer = noiseBuf;
  src.playbackRate.value = rand(0.92, 1.08);
  src.start(t, Math.random() * 1.4, dur);
  return src;
}
function sfxShot(snd, vol = 1, pan = 0, far = 0) {
  if (!actx) return;
  const t = actx.currentTime, dest = out(pan);
  const lp = actx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = lerp(12000, 1000, far); lp.connect(dest);
  const wet = actx.createGain(); wet.gain.value = snd.tail * vol * (0.6 + far * 1.3); wet.connect(revIn());
  const bus = actx.createGain(); bus.connect(lp); bus.connect(wet);
  const c = noiseSrc(t, 0.06), chp = actx.createBiquadFilter(); chp.type = 'highpass'; chp.frequency.value = 2500;
  const cg = actx.createGain(); cg.gain.setValueAtTime(snd.crack * vol * (1 - far * 0.7), t); cg.gain.exponentialRampToValueAtTime(0.001, t + 0.045);
  c.connect(chp).connect(cg).connect(bus);
  const b = noiseSrc(t, snd.len + 0.05), blp = actx.createBiquadFilter(); blp.type = 'lowpass'; blp.frequency.value = snd.freq; blp.Q.value = 0.5;
  const bg = actx.createGain(); bg.gain.setValueAtTime(0.0001, t); bg.gain.exponentialRampToValueAtTime(snd.body * vol, t + 0.003); bg.gain.exponentialRampToValueAtTime(0.001, t + snd.len);
  b.connect(blp).connect(bg).connect(bus);
  const sb = noiseSrc(t, 0.22), slp = actx.createBiquadFilter(); slp.type = 'lowpass'; slp.frequency.value = 160; slp.Q.value = 1.2;
  const sg = actx.createGain(); sg.gain.setValueAtTime(snd.sub * vol * 2.2, t); sg.gain.exponentialRampToValueAtTime(0.001, t + 0.17);
  sb.connect(slp).connect(sg).connect(bus);
}
function sfxShell(delay) {
  if (!actx) return;
  for (let i = 0; i < 2; i++) sfxTone(rand(3600, 5400), 0.035, 0.02, 'sine', rand(3000, 5000), delay + i * rand(0.06, 0.12));
}
function sfxSwoosh(vol = 0.5) {
  if (!actx) return;
  const t = actx.currentTime;
  const src = actx.createBufferSource(); src.buffer = noiseBuf;
  const f = actx.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 2;
  f.frequency.setValueAtTime(700, t); f.frequency.exponentialRampToValueAtTime(3500, t + 0.14);
  const g = actx.createGain(); g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.06); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
  src.connect(f).connect(g).connect(sfxOut()); src.start(t); src.stop(t + 0.2);
}
function sfxTone(freq, dur, vol, type = 'square', endFreq = freq, delay = 0) {
  if (!actx) return;
  const t = actx.currentTime + delay;
  const o = actx.createOscillator(); o.type = type;
  o.frequency.setValueAtTime(freq, t); o.frequency.exponentialRampToValueAtTime(endFreq, t + dur);
  const g = actx.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.connect(g).connect(sfxOut()); o.start(t); o.stop(t + dur + 0.02);
}
let lastGroan = 0;
// zombie voice: raspy pitch-wobbling source + vocal fry flutter, shaped by two throat formants, plus breath noise
function sfxGroan(vol, pan, kind = 'idle') {
  if (!actx) return;
  const t = actx.currentTime;
  if (kind === 'idle') { if (t - lastGroan < 0.7) return; lastGroan = t; }
  const bus = sfxBus(pan, clamp(0.9 - vol, 0, 0.8), 0.3 * vol);
  const dur = kind === 'attack' ? rand(0.35, 0.55) : kind === 'death' ? rand(0.8, 1.2) : rand(0.9, 1.7);
  const base = kind === 'attack' ? rand(115, 160) : kind === 'death' ? rand(80, 110) : rand(58, 92);
  const o = actx.createOscillator(); o.type = 'sawtooth';
  const pc = new Float32Array(9);
  for (let i = 0; i < pc.length; i++) pc[i] = base * (1 + (Math.random() - 0.5) * 0.28) * (kind === 'death' ? 1 - i / pc.length * 0.5 : 1);
  o.frequency.setValueCurveAtTime(pc, t, dur);
  const fry = actx.createOscillator(); fry.type = 'square'; fry.frequency.value = rand(20, 36);
  const fryG = actx.createGain(); fryG.gain.value = 0.42;
  const am = actx.createGain(); am.gain.value = 0.55;
  fry.connect(fryG).connect(am.gain);
  const f1 = actx.createBiquadFilter(); f1.type = 'bandpass'; f1.frequency.value = rand(420, 680); f1.Q.value = 4.5;
  const f2 = actx.createBiquadFilter(); f2.type = 'bandpass'; f2.frequency.value = rand(950, 1400); f2.Q.value = 6;
  const g2 = actx.createGain(); g2.gain.value = 0.55;
  const lp = actx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = kind === 'attack' ? 3200 : 2200;
  const peak = (kind === 'attack' ? 0.9 : 0.6) * vol;
  const env = actx.createGain();
  env.gain.setValueCurveAtTime(new Float32Array([0.0001, peak * 0.6, peak, peak * rand(0.45, 0.85), peak * rand(0.6, 1), peak * 0.35, 0.0001]), t, dur);
  o.connect(am); am.connect(f1); am.connect(f2); f1.connect(env); f2.connect(g2).connect(env); env.connect(lp).connect(bus);
  // wet, breathy rasp on top
  const nz = actx.createBufferSource(); nz.buffer = noiseBuf;
  const nf = actx.createBiquadFilter(); nf.type = 'bandpass'; nf.frequency.value = rand(900, 1500); nf.Q.value = 0.9;
  const ne = actx.createGain();
  ne.gain.setValueCurveAtTime(new Float32Array([0.0001, peak * 0.35, peak * 0.2, peak * 0.3, 0.0001]), t, dur);
  nz.connect(nf).connect(ne).connect(lp);
  o.start(t); fry.start(t); nz.start(t, Math.random(), dur + 0.05);
  o.stop(t + dur + 0.05); fry.stop(t + dur + 0.05);
}
function sfxBite(vol) {
  if (!actx) return;
  const t = actx.currentTime;
  sfxBurst(t, 0.14, 'lowpass', 320, 1, 1.1 * vol, sfxOut());
  sfxBurst(t + 0.02, 0.08, 'bandpass', 2400, 1.5, 0.45 * vol, sfxOut());
}
function sfxPowerup(type) {
  const base = { jump: 440, haste: 520, ammo: 392, quad: 294, god: 587 }[type] || 440;
  [1, 1.26, 1.5, 2].forEach((m, i) => sfxTone(base * m, 0.22, 0.13, i % 2 ? 'triangle' : 'sawtooth', base * m * 1.01, i * 0.06));
  sfxTone(base / 2, 0.5, 0.18, 'sine', base / 4, 0);
}
function sfxPowerSpawn(vol) {
  sfxTone(330, 0.3, 0.1 * vol, 'sine', 990, 0);
  sfxTone(660, 0.3, 0.06 * vol, 'triangle', 1320, 0.08);
}
function sfxPickup(high) {
  const b = high ? 660 : 520;
  sfxTone(b, 0.09, 0.14, 'triangle', b, 0);
  sfxTone(b * 1.25, 0.09, 0.14, 'triangle', b * 1.25, 0.07);
  sfxTone(b * 1.5, 0.16, 0.14, 'triangle', b * 1.5, 0.14);
}

// ============================================================ effects
const particles = [], tracers = [], decals = [], smokes = [];
const partGeo = new THREE.SphereGeometry(0.028, 6, 4);
const partMats = {};
function spawnParticles(p, color, n, normal, speed = 4, glow = true) {
  const key = color + (glow ? 'g' : '');
  const mat = partMats[key] ||= new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(glow ? 4 : 1), toneMapped: !glow });
  for (let i = 0; i < n; i++) {
    const m = new THREE.Mesh(partGeo, mat);
    m.position.copy(p);
    const v = new V3(rand(-1, 1), rand(-0.2, 1.2), rand(-1, 1));
    if (normal) v.addScaledVector(normal, 1.5);
    v.normalize().multiplyScalar(rand(0.4, 1) * speed);
    m.userData = { v, life: rand(0.25, 0.6) };
    m.scale.setScalar(rand(0.6, 1.3));
    scene.add(m); particles.push(m);
  }
}
function spawnSmoke(p, color = 0xbbbbbb, size = 0.5, life = 0.9, rise = 0.5, dense = 0.5) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: life > 1.5 ? puffTex : smokeTex, color, transparent: true, depthWrite: false, opacity: 0.6 }));
  s.position.copy(p); s.scale.setScalar(size * 0.4); s.material.rotation = rand(0, 6.28);
  s.userData = { life, max: life, size, dense, spin: rand(-0.4, 0.4), v: new V3(rand(-0.2, 0.2), rise + rand(-0.2, 0.2), rand(-0.2, 0.2)) };
  scene.add(s); smokes.push(s);
}
const tracerGeo = new THREE.CylinderGeometry(1, 1, 1, 6, 1, true).rotateX(Math.PI / 2);
function spawnTracer(a, b, color) {
  const len = a.distanceTo(b);
  const m = new THREE.Mesh(tracerGeo, new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(3), transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
  m.position.copy(a).lerp(b, 0.5);
  m.scale.set(0.011, 0.011, len);
  m.lookAt(b);
  m.userData.life = 0.07;
  scene.add(m); tracers.push(m);
}
const decalGeo = new THREE.PlaneGeometry(0.16, 0.16);
const decalMat = new THREE.MeshBasicMaterial({ map: holeTex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 });
function addDecal(p, n) {
  const m = new THREE.Mesh(decalGeo, decalMat);
  m.position.copy(p).addScaledVector(n, 0.01);
  m.lookAt(p.clone().add(n));
  m.rotateZ(Math.random() * 6.28);
  scene.add(m); decals.push(m);
  if (decals.length > 100) scene.remove(decals.shift());
}
function updateFx(dt) {
  for (let i = particles.length - 1; i >= 0; i--) {
    const m = particles[i], u = m.userData;
    u.life -= dt; u.v.y -= 12 * dt;
    m.position.addScaledVector(u.v, dt);
    if (m.position.y < 0.03) { m.position.y = 0.03; u.v.multiplyScalar(0.4); u.v.y *= -0.3; }
    if (u.life <= 0) { scene.remove(m); particles.splice(i, 1); }
  }
  for (let i = smokes.length - 1; i >= 0; i--) {
    const s = smokes[i], u = s.userData;
    u.life -= dt;
    const t = 1 - u.life / u.max;
    s.position.addScaledVector(u.v, dt);
    s.scale.setScalar(u.size * (0.4 + t));
    s.material.opacity = (u.dense ?? 0.5) * (1 - t) * Math.min(1, t * 8 + 0.3);
    if (u.spin) s.material.rotation += u.spin * dt;
    u.v.multiplyScalar(Math.exp(-dt * 0.6));
    if (u.life <= 0) { scene.remove(s); s.material.dispose(); smokes.splice(i, 1); }
  }
  for (let i = tracers.length - 1; i >= 0; i--) {
    const m = tracers[i];
    m.userData.life -= dt; m.material.opacity = Math.max(0, m.userData.life / 0.07);
    if (m.userData.life <= 0) { scene.remove(m); m.material.dispose(); tracers.splice(i, 1); }
  }
}

const dmgNums = [];
function showDamageNumber(point, amount, head, kill) {
  const el = document.createElement('div');
  el.className = 'dn' + (head ? ' head' : '') + (kill ? ' kill' : '');
  el.textContent = Math.round(amount);
  $('dmgnums').appendChild(el);
  dmgNums.push({ el, pos: point.clone(), t: 0, dx: rand(-0.3, 0.3) });
}
const _proj = new V3();
function updateDamageNumbers(dt) {
  for (let i = dmgNums.length - 1; i >= 0; i--) {
    const d = dmgNums[i];
    d.t += dt;
    _proj.copy(d.pos).add(new V3(d.dx * d.t, 0.4 + d.t * 0.9, 0)).project(camera);
    const vis = _proj.z < 1;
    const x = (_proj.x * 0.5 + 0.5) * innerWidth, y = (-_proj.y * 0.5 + 0.5) * innerHeight;
    const pop = d.t < 0.12 ? 1 + (0.12 - d.t) * 4 : 1;
    d.el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%) scale(${pop})`;
    d.el.style.opacity = vis ? Math.min(1, (0.9 - d.t) * 3) : 0;
    if (d.t > 0.9) { d.el.remove(); dmgNums.splice(i, 1); }
  }
}
function toast(text, cls, icon, color) {
  const el = document.createElement('div');
  el.className = `toast glass ${cls}`;
  if (color) el.style.setProperty('--c', color);
  el.innerHTML = (icon ? ICONS[icon] : cls === 'hp' ? ICONS.cross : ICONS.shield) + text;
  $('toasts').appendChild(el);
  setTimeout(() => el.remove(), 1650);
}
