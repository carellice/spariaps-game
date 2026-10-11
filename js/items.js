// Spariaps — Oggetti, suoni, musica, granate, armi a terra e cassa misteriosa.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ pickups: health packs + armor
const PU = {
  ring: new THREE.TorusGeometry(0.42, 0.025, 8, 48),
  crossA: rbox(0.34, 0.11, 0.11, 0.04), crossB: rbox(0.11, 0.34, 0.11, 0.04),
  disc: new THREE.PlaneGeometry(1.5, 1.5).rotateX(-Math.PI / 2),
};
{
  const s = new THREE.Shape();
  s.moveTo(0, 0.2); s.quadraticCurveTo(0.12, 0.19, 0.17, 0.15); s.lineTo(0.16, 0.0);
  s.quadraticCurveTo(0.14, -0.14, 0, -0.22); s.quadraticCurveTo(-0.14, -0.14, -0.16, 0.0); s.lineTo(-0.17, 0.15); s.quadraticCurveTo(-0.12, 0.19, 0, 0.2);
  PU.shield = new THREE.ExtrudeGeometry(s, { depth: 0.05, bevelEnabled: true, bevelThickness: 0.02, bevelSize: 0.02, bevelSegments: 3, curveSegments: 10 }).center();
}
const PU_MATS = {
  health: new THREE.MeshStandardMaterial({ color: 0xeafff0, emissive: 0x2dff7a, emissiveIntensity: 1.4, roughness: 0.3, metalness: 0.1 }),
  armor: new THREE.MeshStandardMaterial({ color: 0x1d4f9a, emissive: 0x3aa8ff, emissiveIntensity: 1.3, roughness: 0.25, metalness: 0.6 }),
  healthRing: new THREE.MeshBasicMaterial({ color: new THREE.Color(0x2dff7a).multiplyScalar(2.5), toneMapped: false }),
  armorRing: new THREE.MeshBasicMaterial({ color: new THREE.Color(0x3aa8ff).multiplyScalar(2.5), toneMapped: false }),
  healthDisc: new THREE.MeshBasicMaterial({ map: glowTex, color: 0x2dff7a, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false }),
  armorDisc: new THREE.MeshBasicMaterial({ map: glowTex, color: 0x3aa8ff, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false }),
};
PU_MATS.equipRing = new THREE.MeshBasicMaterial({ color: new THREE.Color(0xffa040).multiplyScalar(2.5), toneMapped: false });
PU_MATS.equipDisc = new THREE.MeshBasicMaterial({ map: glowTex, color: 0xffa040, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
// arena power-ups: timed bonuses on fixed spots, the strongest ones arrive later and respawn slowly
const POWERUPS = {
  jump:  { name: 'SUPER SALTO',        color: 0x7dff4a, css: '#9dff75', dur: 15, respawn: 35, first: 0 },
  haste: { name: 'VELOCITÀ',           color: 0xffd23a, css: '#ffdc5e', dur: 12, respawn: 40, first: 8 },
  ammo:  { name: 'MUNIZIONI INFINITE', color: 0xff8a2a, css: '#ffa35c', dur: 15, respawn: 45, first: 15 },
  quad:  { name: 'DANNO x3',           color: 0xb04dff, css: '#c98bff', dur: 12, respawn: 60, first: 30 },
  god:   { name: 'INVULNERABILE',      color: 0x3affe6, css: '#7cfff0', dur: 8,  respawn: 80, first: 50 },
};
const puMatCache = {};
function puMats(type) {
  if (puMatCache[type]) return puMatCache[type];
  const c = POWERUPS[type].color;
  return puMatCache[type] = {
    body: new THREE.MeshStandardMaterial({ color: new THREE.Color(c).lerp(new THREE.Color(0xffffff), 0.35), emissive: c, emissiveIntensity: 1.6, roughness: 0.25, metalness: 0.3, flatShading: type === 'quad' || type === 'god' }),
    ring: new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(2.5), toneMapped: false }),
    disc: new THREE.MeshBasicMaterial({ map: glowTex, color: c, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false }),
    beam: new THREE.ShaderMaterial({
      uniforms: { color: { value: new THREE.Color(c) } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
      fragmentShader: 'uniform vec3 color; varying vec2 vUv; void main(){ float a = pow(clamp(1.0 - vUv.y, 0.0, 1.0), 2.2) * 0.55 * (0.6 + 0.4 * sin(vUv.x * 6.2832 * 3.0)); gl_FragColor = vec4(color * a, a); }',
    }),
  };
}
PU.beam = new THREE.CylinderGeometry(0.5, 0.62, 5, 32, 1, true).translate(0, 2.5, 0);
PU.pad = new THREE.CylinderGeometry(0.72, 0.8, 0.08, 40);
PU.padMat = new THREE.MeshStandardMaterial({ color: 0x2a2f38, roughness: 0.4, metalness: 0.7 });
function buildPowerModel(type, m) {
  const g = new THREE.Group();
  if (type === 'jump') {
    const cone = new THREE.ConeGeometry(0.2, 0.2, 24);
    for (const y of [-0.12, 0.1]) { const a = new THREE.Mesh(cone, m); a.position.y = y; g.add(a); }
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.22, 16), m); stem.position.y = -0.3; g.add(stem);
  } else if (type === 'haste') {
    const sh = new THREE.Shape();
    sh.moveTo(0.05, 0.3); sh.lineTo(-0.16, -0.02); sh.lineTo(-0.02, -0.02); sh.lineTo(-0.08, -0.3); sh.lineTo(0.16, 0.05); sh.lineTo(0.02, 0.05); sh.lineTo(0.05, 0.3);
    g.add(new THREE.Mesh(new THREE.ExtrudeGeometry(sh, { depth: 0.07, bevelEnabled: true, bevelThickness: 0.02, bevelSize: 0.015, bevelSegments: 2 }).center(), m));
  } else if (type === 'ammo') {
    const geo = new THREE.CapsuleGeometry(0.05, 0.22, 6, 16);
    for (let i = 0; i < 3; i++) { const b = new THREE.Mesh(geo, m); b.position.x = (i - 1) * 0.13; g.add(b); }
  } else if (type === 'quad') {
    g.add(new THREE.Mesh(new THREE.IcosahedronGeometry(0.26, 0), m));
    const shell = new THREE.Mesh(new THREE.IcosahedronGeometry(0.4, 0), new THREE.MeshBasicMaterial({ color: POWERUPS.quad.color, wireframe: true, transparent: true, opacity: 0.5 }));
    g.add(shell); g.userData.spin = shell;
  } else {
    const sh = new THREE.Shape();
    for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 + Math.PI / 2, r = i % 2 ? 0.13 : 0.3; sh[i ? 'lineTo' : 'moveTo'](Math.cos(a) * r, Math.sin(a) * r); }
    g.add(new THREE.Mesh(new THREE.ExtrudeGeometry(sh, { depth: 0.06, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.02, bevelSegments: 2 }).center(), m));
  }
  g.children.forEach(c => c.castShadow = true);
  return g;
}

let pickups = [];
class Pickup {
  constructor(type, x, z, temp = false) {
    this.type = type; this.temp = temp; this.power = POWERUPS[type];
    this.active = true; this.respawn = 0; this.life = temp ? 20 : Infinity; this.phase = rand(0, 6);
    this.group = new THREE.Group();
    this.item = new THREE.Group(); this.group.add(this.item);
    if (this.power) {
      // power-ups keep their exact spot (the quad sits on top of the central platform)
      this.pos = new V3(x, groundAt(x, z, 10, 0.3), z);
      const m = puMats(type);
      this.item.add(buildPowerModel(type, m.body));
      this.ring = new THREE.Mesh(PU.ring, m.ring);
      this.ring.rotation.x = Math.PI / 2; this.ring.position.y = 0.1; this.ring.scale.setScalar(1.35);
      const pad = new THREE.Mesh(PU.pad, PU.padMat); pad.position.y = 0.04; pad.receiveShadow = true;
      const disc = this.disc = new THREE.Mesh(PU.disc, m.disc); disc.position.y = 0.09; disc.scale.setScalar(1.6);
      this.beam = new THREE.Mesh(PU.beam, m.beam);
      this.light = new THREE.PointLight(this.power.color, 0, 7, 2); this.light.position.y = 1.1; this.light.visible = settings.quality !== 'low';
      this.group.add(pad, this.ring, disc, this.beam, this.light);
      this.group.position.copy(this.pos);
      scene.add(this.group);
      if (this.power.first > 0) { this.active = false; this.respawn = this.power.first; this.setShown(false); }
      return;
    }
    const idx = nearestFree(cellIdx(x, z));
    this.pos = temp ? new V3(x, 0, z) : new V3(idx % G - HALF + 0.5, 0, ((idx / G) | 0) - HALF + 0.5);
    if (type === 'equip') this.setKind(randomEquip());
    else if (type === 'health') {
      this.item.add(new THREE.Mesh(PU.crossA, PU_MATS.health), new THREE.Mesh(PU.crossB, PU_MATS.health));
    } else {
      this.item.add(new THREE.Mesh(PU.shield, PU_MATS.armor));
    }
    this.item.children.forEach(m => m.castShadow = true);
    this.ring = new THREE.Mesh(PU.ring, PU_MATS[type + 'Ring']);
    this.ring.rotation.x = Math.PI / 2; this.ring.position.y = 0.06;
    const disc = new THREE.Mesh(PU.disc, PU_MATS[type + 'Disc']);
    disc.position.y = 0.02;
    this.group.add(this.ring, disc);
    this.group.position.copy(this.pos);
    scene.add(this.group);
  }
  get color() { return this.power ? this.power.color : { health: 0x2dff7a, armor: 0x3aa8ff, equip: 0xffa040 }[this.type]; }
  // throwable crate: shows the item it contains, rerolled at every respawn
  setKind(kind) {
    this.kind = kind;
    this.item.clear();
    const m = PROJ_BUILD[kind]();
    m.scale.setScalar(kind === 'tknife' ? 2.6 : 2.4);
    if (kind === 'tknife') m.rotation.set(Math.PI / 2, 0, 0.5);
    m.traverse(o => { if (o.isMesh) o.castShadow = true; });
    this.item.add(m);
  }
  setShown(on) {
    if (!this.power) { this.group.visible = on; return; }
    // the pad stays on the floor while a power-up is recharging
    this.item.visible = this.ring.visible = this.beam.visible = on;
    this.disc.visible = on;
    this.light.intensity = on ? 3 * lightK() : 0;
  }
  update(dt) {
    if (!this.active) {
      this.respawn -= dt;
      if (this.respawn <= 0) {
        if (this.type === 'equip') this.setKind(randomEquip());
        this.active = true; this.setShown(true);
        spawnParticles(this.pos.clone().setY(this.pos.y + 0.6), this.color, this.power ? 24 : 12, new V3(0, 1, 0), this.power ? 3.5 : 2);
        if (this.power) {
          const d = Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
          if (this.power.first >= 30 && now - (this.power.told ?? -99) > 5) { this.power.told = now; toast(`${this.power.name} DISPONIBILE`, 'pu', this.type, this.power.css); }
          sfxPowerSpawn(clamp(1 - d / 45, 0.15, 1));
        }
      }
      return true;
    }
    if (this.temp) {
      this.life -= dt;
      if (this.life <= 0) { scene.remove(this.group); return false; }
      this.group.visible = this.life > 4 || Math.sin(this.life * 20) > 0;
    }
    this.phase += dt;
    this.item.position.y = (this.power ? 1.05 : 0.75) + Math.sin(this.phase * 2.2) * 0.08;
    this.item.rotation.y += dt * (this.power ? 2.2 : 1.6);
    this.ring.scale.setScalar((this.power ? 1.35 : 1) * (1 + Math.sin(this.phase * 3) * 0.06));
    const d = Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
    if (this.power) {
      const spin = this.item.children[0].userData.spin;
      if (spin) { spin.rotation.x += dt * 1.3; spin.rotation.z -= dt * 0.9; }
      this.beam.rotation.y += dt * 0.8;
      this.light.intensity = (2.4 + Math.sin(this.phase * 4) * 0.6) * lightK();
      if (d < 1.2 && Math.abs(player.pos.y - this.pos.y) < 1.3) { activatePower(this.type); return this.consume(); }
      return true;
    }
    if (d < 1.1 && Math.abs(player.pos.y - this.pos.y) < 1.3) {
      if (this.type === 'health' && player.hp < 100) {
        const gain = Math.min(35, 100 - player.hp);
        player.hp += gain; toast(`+${Math.ceil(gain)} SALUTE`, 'hp'); sfxPickup(false);
        return this.consume();
      }
      if (this.type === 'equip' && equip[this.kind] < EQUIP_MAX[this.kind]) {
        const k = this.kind, n = k === 'tknife' ? 2 : 1;
        equip[k] = Math.min(EQUIP_MAX[k], equip[k] + n);
        toast(`+${n} ${EQUIP_NAMES[k]}`, 'pu', k, '#ffb36b'); sfxPickup(true);
        return this.consume();
      }
      if (this.type === 'armor' && player.armor < 100) {
        const gain = Math.min(50, 100 - player.armor);
        player.armor += gain; toast(`+${Math.ceil(gain)} SCUDO`, 'ar'); sfxPickup(true);
        return this.consume();
      }
    }
    return true;
  }
  consume() {
    spawnParticles(this.pos.clone().setY(this.pos.y + 0.8), this.color, this.power ? 30 : 16, new V3(0, 1, 0), this.power ? 5 : 3);
    if (this.temp) { scene.remove(this.group); return false; }
    this.active = false; this.setShown(false);
    this.respawn = this.power ? this.power.respawn : { health: 22, armor: 38, equip: 18 }[this.type];
    return true;
  }
}
function resetPickups() {
  pickups.forEach(p => scene.remove(p.group));
  pickups = [];
  for (const [type, spots] of Object.entries(MAP.pickups)) for (const [x, z] of spots) pickups.push(new Pickup(type, x, z));
  for (const [type, def] of Object.entries(POWERUPS)) { def.told = -99; for (const [x, z] of MAP.power[type]) pickups.push(new Pickup(type, x, z)); }
  for (const k in powers) powers[k] = 0;
  $('powerups').innerHTML = ''; puEls = {};
  $('puGlow').style.opacity = 0;
}
function updatePickups(dt) { pickups = pickups.filter(p => p.update(dt)); updatePowers(dt); }

let puEls = {};
function activatePower(type) {
  const def = POWERUPS[type];
  powers[type] = def.dur;
  toast(def.name, 'pu', type, def.css);
  sfxPowerup(type);
  hurt = 0;
  if (type === 'ammo') for (const k in weapon.mags) weapon.mags[k] = magOf(k);
  if (type === 'ammo' && weapon.reloading) { weapon.reloading = false; weapon.mags[weapon.current] = magOf(weapon.current); }
  if (!puEls[type]) {
    const el = document.createElement('div');
    el.className = 'pu glass'; el.style.setProperty('--c', def.css);
    el.innerHTML = `${ICONS[type]}<div><div class="nm">${def.name}</div><div class="bar"><i></i></div></div><span class="t"></span>`;
    $('powerups').appendChild(el);
    puEls[type] = { el, bar: el.querySelector('.bar i'), t: el.querySelector('.t'), last: 0 };
  }
}
function updatePowers(dt) {
  let glow = null;
  for (const [type, def] of Object.entries(POWERUPS)) {
    if (powers[type] <= 0) continue;
    powers[type] = Math.max(0, powers[type] - dt);
    const e = puEls[type], left = powers[type];
    if (!e) continue;
    e.bar.style.width = (left / def.dur * 100) + '%';
    e.t.textContent = Math.ceil(left);
    e.el.classList.toggle('ending', left < 3);
    if (left < 3 && Math.ceil(left) !== e.last) { e.last = Math.ceil(left); sfxTone(880, 0.05, 0.08, 'triangle', 880); }
    if (left <= 0) {
      e.el.remove(); delete puEls[type];
      sfxTone(600, 0.25, 0.12, 'triangle', 220);
      continue;
    }
    glow = def.css;
  }
  const g = $('puGlow');
  if (glow) { g.style.boxShadow = `inset 0 0 140px 10px ${glow}55`; g.style.opacity = 1; }
  else g.style.opacity = 0;
}

// ============================================================ sounds: explosions, throwables, mystery box
function sfxBurst(t, dur, type, freq, q, vol, dest, attack = 0) {
  const src = actx.createBufferSource(); src.buffer = noiseBuf;
  src.start(t, Math.random() * 0.4, dur + 0.05);
  const f = actx.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
  const g = actx.createGain();
  if (attack) { g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(vol, t + attack); }
  else g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  src.connect(f).connect(g).connect(dest);
}
function sfxBus(pan, far, wetK) {
  const dest = out(pan);
  const lp = actx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = lerp(8000, 900, far); lp.connect(dest);
  const wet = actx.createGain(); wet.gain.value = wetK * (0.7 + far); wet.connect(revIn());
  const bus = actx.createGain(); bus.connect(lp); bus.connect(wet);
  return bus;
}
function sfxBoom(vol = 1, pan = 0, far = 0) {
  if (!actx) return;
  const t = actx.currentTime, bus = sfxBus(pan, far, vol);
  sfxBurst(t, 0.08, 'highpass', 1800, 0.7, vol * 1.1 * (1 - far * 0.7), bus);
  sfxBurst(t, 1.3, 'lowpass', 650, 0.8, vol * 1.7, bus);
  const o = actx.createOscillator(); o.type = 'sine';
  o.frequency.setValueAtTime(115, t); o.frequency.exponentialRampToValueAtTime(30, t + 0.75);
  const g = actx.createGain(); g.gain.setValueAtTime(vol * 1.5, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.85);
  o.connect(g).connect(bus); o.start(t); o.stop(t + 0.9);
}
function sfxStunBang(vol, pan, far, ring) {
  if (!actx) return;
  const t = actx.currentTime, bus = sfxBus(pan, far, vol * 0.8);
  sfxBurst(t, 0.3, 'highpass', 1400, 0.6, vol * 1.5, bus);
  sfxBurst(t, 0.5, 'lowpass', 1200, 0.7, vol * 0.9, bus);
  if (ring > 0.05) sfxTone(3150, 1 + ring * 2.5, 0.05 * ring, 'sine', 3050, 0.12);
}
function sfxSmokeHiss(vol, pan) {
  if (!actx) return;
  sfxBurst(actx.currentTime, 2.4, 'bandpass', 3200, 0.8, vol * 0.35, out(pan), 0.15);
}
function sfxRay() {
  if (!actx) return;
  sfxTone(1700, 0.17, 0.11, 'sawtooth', 240);
  sfxTone(850, 0.24, 0.09, 'square', 110, 0.01);
  sfxBurst(actx.currentTime, 0.14, 'lowpass', 1400, 0.8, 0.5, sfxOut());
}
// reload foley: each weapon family has its own sequence of mechanical cues (fraction of reload time, sound)
const RELOAD_CUES = {
  default: [[0.08, 'release'], [0.2, 'out'], [0.56, 'in'], [0.66, 'seat'], [0.84, 'rack']],
  pistol:  [[0.1, 'release'], [0.24, 'out'], [0.58, 'in'], [0.68, 'seat'], [0.86, 'slide']],
  shotgun: [[0.12, 'shell'], [0.3, 'shell'], [0.48, 'shell'], [0.66, 'shell'], [0.86, 'pump']],
  sniper:  [[0.06, 'bolt'], [0.26, 'out'], [0.56, 'in'], [0.66, 'seat'], [0.84, 'bolt']],
  lmg:     [[0.06, 'release'], [0.18, 'lid'], [0.36, 'out'], [0.6, 'in'], [0.74, 'lid'], [0.88, 'rack']],
  magnum:  [[0.08, 'lid'], [0.26, 'out'], [0.5, 'shell'], [0.62, 'shell'], [0.8, 'lid']],
  raygun:  [[0.15, 'zapOut'], [0.62, 'in'], [0.8, 'zapIn']],
  rocket:  [[0.25, 'out'], [0.62, 'in'], [0.78, 'seat']],
};
function sfxMech(kind) {
  if (!actx) return;
  const t = actx.currentTime, d = sfxOut();
  const click = (dt, f, v, q = 6) => sfxBurst(t + dt, 0.035, 'bandpass', f, q, v, d);
  const ping = (dt, f, v) => sfxTone(f, 0.06, v, 'sine', f * 0.97, dt);
  const scrape = (dt, dur, f, v) => sfxBurst(t + dt, dur, 'bandpass', f, 1.6, v, d, 0.02);
  switch (kind) {
    case 'release': click(0, 3200, 0.6); ping(0.004, 2400, 0.025); break;
    case 'out': scrape(0, 0.16, 1400, 0.28); click(0.15, 900, 0.4, 3); break;
    case 'in': scrape(0, 0.11, 1700, 0.25); sfxBurst(t + 0.1, 0.07, 'lowpass', 450, 1, 0.9, d); click(0.1, 2600, 0.55); break;
    case 'seat': click(0, 3600, 0.7, 8); click(0.03, 2000, 0.35); break;
    case 'rack': scrape(0, 0.09, 2200, 0.3); click(0.08, 3000, 0.75); scrape(0.14, 0.08, 1800, 0.28); click(0.22, 3400, 0.9); ping(0.225, 2900, 0.04); break;
    case 'slide': click(0, 2800, 0.55); scrape(0.02, 0.06, 1500, 0.3); click(0.08, 3600, 0.9); ping(0.085, 3100, 0.04); break;
    case 'bolt': click(0, 2600, 0.6); scrape(0.03, 0.12, 1300, 0.32); click(0.15, 2200, 0.65); scrape(0.19, 0.1, 1500, 0.3); click(0.29, 3200, 0.8); break;
    case 'shell': scrape(0, 0.06, 1900, 0.35); click(0.05, 1200, 0.55, 3); break;
    case 'pump': scrape(0, 0.09, 900, 0.55); click(0.08, 1500, 0.9, 3); scrape(0.14, 0.08, 1100, 0.5); click(0.21, 1800, 0.9, 3); break;
    case 'lid': click(0, 1700, 0.65, 4); sfxBurst(t + 0.01, 0.05, 'lowpass', 700, 1, 0.45, d); break;
    case 'zapOut': sfxTone(900, 0.25, 0.07, 'sawtooth', 200); break;
    case 'zapIn': sfxTone(200, 0.3, 0.07, 'sawtooth', 1400); sfxTone(1400, 0.1, 0.05, 'sine', 1800, 0.3); break;
  }
}
function sfxRocketLaunch() {
  if (!actx) return;
  const t = actx.currentTime;
  sfxBurst(t, 0.5, 'lowpass', 900, 0.8, 1.1, sfxOut(), 0.02);
  sfxBurst(t, 0.9, 'bandpass', 2200, 0.6, 0.35, sfxOut(), 0.05);
  sfxTone(160, 0.35, 0.2, 'sine', 60);
}
// ============================================================ music: a song in the menus, a seamless loop during the match
const canOpusMp4 = !!document.createElement('audio').canPlayType('audio/mp4; codecs="opus"');
const SONGS = { classic: 'Classica.m4a', zombie: 'Zombie.m4a' };
const music = { want: null, song: null, songKey: null, songVol: 0, loopSrc: null, loopGain: null, loopKey: null, buffers: {}, duck: 1 };
function songEl(key) {
  const a = new Audio((canOpusMp4 ? 'Music/' : 'Music/compat/') + SONGS[key]);
  a.loop = true; a.preload = 'auto'; a.volume = 0;
  return a;
}
function songTarget() { return muted ? 0 : clamp(settings.volMaster * settings.volMusic * 0.6, 0, 1); }
function updateSongVolume() { if (music.song) music.song.volume = songTarget() * music.songVol; }
// songs use <audio> (works from file://); volume fades run on a timer so they also work in the background
setInterval(() => {
  const target = music.want === 'menu' ? 1 : 0;
  music.songVol = clamp(music.songVol + (target > music.songVol ? 0.05 : -0.06), 0, 1);
  if (music.song) {
    updateSongVolume();
    if (music.songVol === 0 && !music.song.paused && target === 0) music.song.pause();
  }
}, 50);
function playSong(key) {
  if (music.songKey !== key || !music.song) {
    if (music.song) { const old = music.song; let v = old.volume; const f = setInterval(() => { v -= 0.05; if (v <= 0) { old.pause(); clearInterval(f); } else old.volume = v; }, 50); }
    music.song = songEl(key); music.songKey = key; music.songVol = 0;
  }
  if (music.song.paused) music.song.play().catch(() => { music.blocked = true; });
}
// each loop lives in its own script (Music/loop-<mode>.js), fetched the first time it is needed instead of at page load
const loopData = {};
function loopScript(key) {
  return loopData[key] ||= new Promise((res, rej) => {
    const el = document.createElement('script'); el.src = `Music/loop-${key}.js`;
    el.onload = () => res(window.SPARIAPS_LOOPS?.[key]); el.onerror = () => { delete loopData[key]; rej(); };
    document.head.appendChild(el);
  });
}
function loopBuffer(key) {
  if (music.buffers[key]) return music.buffers[key];
  if (!actx) return null;
  return music.buffers[key] = loopScript(key).then(b64 => {
    const bin = atob(b64), bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return actx.decodeAudioData(bytes.buffer);
  }).catch(() => { delete music.buffers[key]; return null; });
}
function stopLoop(fade = 0.8) {
  if (!music.loopSrc) { music.loopKey = null; return; }
  const src = music.loopSrc, g = music.loopGain, t = actx.currentTime;
  g.gain.cancelScheduledValues(t); g.gain.setValueAtTime(g.gain.value, t); g.gain.linearRampToValueAtTime(0, t + fade);
  src.stop(t + fade + 0.05);
  music.loopSrc = music.loopGain = music.loopKey = null;
}
async function startLoop(key) {
  if (!actx) return;
  if (music.loopKey === key) return setLoopDuck(1);
  stopLoop();
  music.loopKey = key;
  const p = loopBuffer(key);
  if (!p) return;
  const buf = await p;
  if (!buf) return;
  if (music.loopKey !== key || music.want !== 'game' && music.want !== 'pause') return;
  const src = actx.createBufferSource(); src.buffer = buf; src.loop = true;
  const g = actx.createGain(); g.gain.value = 0;
  src.connect(g).connect(buses.music);
  src.start();
  g.gain.linearRampToValueAtTime(music.duck, actx.currentTime + 1.2);
  music.loopSrc = src; music.loopGain = g;
}
function setLoopDuck(v) {
  music.duck = v;
  if (music.loopGain) music.loopGain.gain.setTargetAtTime(v, actx.currentTime, 0.25);
}
// scene: 'menu' (song of the selected mode), 'game' (loop), 'pause' (loop, quieter)
function setMusic(scene) {
  music.want = scene;
  // while you are in the menu, fetch the loop of the selected mode so it is ready when the match starts
  if (scene === 'menu') { if (actx) stopLoop(); playSong(mode); const m = mode; setTimeout(() => { if (music.want === 'menu' && mode === m) loopScript(m).catch(() => {}); }, 1500); }
  else if (scene === 'game') { music.duck = 1; startLoop(mode); }
  else if (scene === 'pause') setLoopDuck(0.35);
}
// browsers only allow sound after the first click/keypress
function unlockMusic() {
  initAudio();
  if (music.want === 'menu') playSong(mode);
  removeEventListener('pointerdown', unlockMusic); removeEventListener('keydown', unlockMusic);
}
addEventListener('pointerdown', unlockMusic); addEventListener('keydown', unlockMusic);

// menu feedback: soft tick on hover, click on press (confirm buttons get a brighter two-note chime)
function sfxUiHover() { if (actx) withCat('ui', () => sfxTone(2100, 0.035, 0.025, 'sine', 2300)); }
function sfxUiClick(strong) {
  if (!actx) return;
  withCat('ui', () => {
    if (strong) { sfxTone(660, 0.09, 0.07, 'triangle', 660); sfxTone(990, 0.14, 0.07, 'triangle', 990, 0.06); }
    else { sfxTone(1200, 0.05, 0.06, 'triangle', 900); sfxBurst(actx.currentTime, 0.02, 'highpass', 3000, 0.7, 0.12, sfxOut()); }
  });
}
function sfxBossHorn() {
  if (!actx) return;
  const t = actx.currentTime, bus = sfxBus(0, 0.2, 1);
  for (const [f, v] of [[55, 0.5], [82.4, 0.35], [110, 0.2]]) {
    const o = actx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(f * 0.94, t); o.frequency.linearRampToValueAtTime(f, t + 0.6);
    const lp = actx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.setValueAtTime(300, t); lp.frequency.linearRampToValueAtTime(900, t + 1.2); lp.frequency.linearRampToValueAtTime(250, t + 2.6);
    const g = actx.createGain(); g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(v, t + 0.4); g.gain.setValueAtTime(v, t + 1.8); g.gain.exponentialRampToValueAtTime(0.001, t + 2.8);
    o.connect(lp).connect(g).connect(bus); o.start(t); o.stop(t + 2.9);
  }
  sfxBoom(0.8, 0, 0.4);
}
function sfxBoing() { sfxTone(170, 0.35, 0.22, 'sine', 720); sfxTone(340, 0.25, 0.08, 'triangle', 1300, 0.02); sfxSwoosh(0.4); }
function sfxBounce(vol) { sfxTone(rand(900, 1300), 0.05, 0.07 * vol, 'triangle', 650); }
function sfxBoxOpen() { [523, 659, 784, 1046, 1318].forEach((f, i) => sfxTone(f, 0.3, 0.1, 'triangle', f, i * 0.08)); }
function sfxBoxReveal(tier) {
  const base = { common: 392, uncommon: 440, rare: 523, epic: 587, legendary: 659 }[tier] || 440;
  [1, 1.26, 1.5, 2, 2.52].forEach((m, i) => sfxTone(base * m, 0.4, 0.09, i % 2 ? 'triangle' : 'sine', base * m, i * 0.05));
}

// ============================================================ throwables, projectiles, explosions
const lowGfx = () => settings.quality === 'low';
const projectiles = [], flashes = [];
const projRay = new THREE.Raycaster();
const boomLight = new THREE.PointLight(0xffa050, 0, 24, 2);
scene.add(boomLight);
let boomT = 0;
const PROJ = {
  frag:   { fuse: 2.2, bounce: 0.38, grav: 20, r: 0.07 },
  stun:   { fuse: 1.4, bounce: 0.3,  grav: 20, r: 0.07 },
  smoke:  { fuse: 1.3, bounce: 0.25, grav: 20, r: 0.07 },
  tknife: { grav: 5, hits: true, life: 3, r: 0.02 },
  plasma: { grav: 0, hits: true, life: 2.5, r: 0.05 },
  rocket: { grav: 0, hits: true, life: 4, r: 0.08 },
  erocket: { grav: 0, hits: true, enemy: true, life: 5, r: 0.1 },
  acid: { grav: 9, hits: true, enemy: true, life: 5, r: 0.12 },
};
const TH_MATS = {
  olive: new THREE.MeshStandardMaterial({ color: 0x4d5a3a, roughness: 0.55, metalness: 0.3 }),
  steel: new THREE.MeshStandardMaterial({ color: 0x9aa2ab, roughness: 0.3, metalness: 0.9 }),
  smoke: new THREE.MeshStandardMaterial({ color: 0x6b7280, roughness: 0.5, metalness: 0.4 }),
  band: new THREE.MeshStandardMaterial({ color: 0xeeeeee, roughness: 0.5 }),
  plasmaCore: new THREE.MeshBasicMaterial({ color: new THREE.Color(0.6, 3, 0.9), toneMapped: false }),
  plasmaGlow: new THREE.SpriteMaterial({ map: glowTex, color: new THREE.Color(0.4, 2.2, 0.6), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }),
};
const TH_GEO = {
  frag: new THREE.SphereGeometry(0.06, 16, 12), fuse: new THREE.CylinderGeometry(0.018, 0.018, 0.05, 10), lever: rbox(0.012, 0.07, 0.02, 0.004),
  can: new THREE.CylinderGeometry(0.045, 0.045, 0.14, 16), bandG: new THREE.CylinderGeometry(0.047, 0.047, 0.025, 16),
  blade: rbox(0.03, 0.005, 0.15, 0.002), handle: rbox(0.024, 0.014, 0.08, 0.005), core: new THREE.SphereGeometry(0.06, 12, 10),
};
const PROJ_BUILD = {
  frag() { const g = new THREE.Group(); g.add(new THREE.Mesh(TH_GEO.frag, TH_MATS.olive)); const f = new THREE.Mesh(TH_GEO.fuse, TH_MATS.steel); f.position.y = 0.07; g.add(f); const l = new THREE.Mesh(TH_GEO.lever, TH_MATS.steel); l.position.set(0.03, 0.03, 0); g.add(l); return g; },
  stun() { const g = new THREE.Group(); g.add(new THREE.Mesh(TH_GEO.can, TH_MATS.steel)); const b = new THREE.Mesh(TH_GEO.bandG, gunMats.accent); g.add(b); return g; },
  smoke() { const g = new THREE.Group(); g.add(new THREE.Mesh(TH_GEO.can, TH_MATS.smoke)); const b = new THREE.Mesh(TH_GEO.bandG, TH_MATS.band); b.position.y = 0.03; g.add(b); return g; },
  tknife() { const g = new THREE.Group(); const b = new THREE.Mesh(TH_GEO.blade, gunMats.blade); b.position.z = 0.06; const h = new THREE.Mesh(TH_GEO.handle, gunMats.polymer); h.position.z = -0.05; g.add(b, h); return g; },
  rocket() {
    const g = new THREE.Group();
    const b = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.34, 14).rotateX(Math.PI / 2), TH_MATS.olive);
    const c = new THREE.Mesh(new THREE.ConeGeometry(0.045, 0.12, 14).rotateX(Math.PI / 2), gunMats.shell); c.position.z = 0.23;
    const f = new THREE.Sprite(new THREE.SpriteMaterial({ map: flashTex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }));
    f.position.z = -0.22; f.scale.setScalar(0.5);
    g.add(b, c, f); return g;
  },
  acid() { const g = PROJ_BUILD.plasma(); g.scale.setScalar(1.5); return g; },
  erocket() { const g = PROJ_BUILD.rocket(); g.scale.setScalar(1.5); g.children[2].material.color.set(0xff4060); return g; },
  plasma() { const g = new THREE.Group(); g.add(new THREE.Mesh(TH_GEO.core, TH_MATS.plasmaCore)); const s = new THREE.Sprite(TH_MATS.plasmaGlow); s.scale.setScalar(0.7); g.add(s); return g; },
};
function launchProjectile(kind, pos, vel) {
  const mesh = PROJ_BUILD[kind]();
  mesh.traverse(o => { if (o.isMesh) o.castShadow = kind !== 'plasma'; });
  mesh.position.copy(pos); scene.add(mesh);
  projectiles.push({ kind, mesh, pos: pos.clone(), vel, t: 0, rest: false, spin: rand(8, 14), stuck: false, stuckT: 0 });
}
function removeProjectile(i) { scene.remove(projectiles[i].mesh); projectiles.splice(i, 1); }
function aimPoint(maxD = 120) {
  camera.updateMatrixWorld();
  const origin = camera.getWorldPosition(new V3()), dir = new V3(0, 0, -1).applyQuaternion(camera.quaternion);
  projRay.set(origin, dir); projRay.far = maxD;
  const h = projRay.intersectObjects(worldMeshes.concat(...enemies.filter(b => !b.dead).map(b => b.parts)), false)[0];
  return h ? h.point : origin.addScaledVector(dir, maxD);
}
function throwItem(kind) {
  if (weapon.meleeT > 0 || weapon.switchT > 0 || throwCD > 0) return;
  const el = document.querySelector(`.eq[data-e="${kind}"]`);
  if (equip[kind] <= 0) { sfxTone(260, 0.07, 0.08, 'square', 200); el?.animate([{ transform: 'translateX(-4px)' }, { transform: 'translateX(4px)' }, { transform: 'none' }], { duration: 180 }); return; }
  equip[kind]--; throwCD = kind === 'tknife' ? 0.35 : 0.8;
  weapon.throwT = THROW_TIME; weapon.reloading = false;
  camera.updateMatrixWorld();
  const fwd = new V3(0, 0, -1).applyQuaternion(camera.quaternion), right = new V3(1, 0, 0).applyQuaternion(camera.quaternion);
  const start = camera.position.clone().addScaledVector(fwd, 0.45).addScaledVector(right, 0.14).add(new V3(0, -0.08, 0));
  if (!worldClear(camera.position, start)) start.copy(camera.position);
  let vel;
  if (kind === 'tknife') vel = aimPoint().sub(start).normalize().multiplyScalar(32);
  else vel = fwd.multiplyScalar(kind === 'smoke' ? 15 : 17).add(new V3(0, 3.2, 0)).addScaledVector(player.vel, 0.5);
  launchProjectile(kind, start, vel);
  withCat('weapons', () => { sfxSwoosh(0.35); if (kind !== 'tknife') sfxTone(2300, 0.03, 0.08, 'square', 1800); });
  el?.animate([{ transform: 'translateY(-4px)' }, { transform: 'none' }], { duration: 250 });
}
function spawnFlash(p, color, size, life) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: flashTex, color, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }));
  s.position.copy(p); s.userData = { life, max: life, size };
  scene.add(s); flashes.push(s);
}
function lightBurst(p, color, intensity) {
  boomLight.color.set(color); boomLight.position.copy(p).setY(p.y + 0.8);
  boomLight.intensity = intensity * lightK(); boomT = 0.5;
}
// blast damage with falloff; walls shield enemies (and you)
const blastFx = { fire: [], rings: [], debris: [], scorch: [] };
const shockGeo = new THREE.RingGeometry(0.72, 1, 48).rotateX(-Math.PI / 2);
const debrisGeo = [rbox(0.12, 0.08, 0.1, 0.02), rbox(0.08, 0.06, 0.14, 0.015), new THREE.TetrahedronGeometry(0.08)];
const debrisMats = [mats.concrete, mats.trim, new THREE.MeshStandardMaterial({ color: 0x1a1512, emissive: 0xff5a10, emissiveIntensity: 3 })];
const scorchMat = new THREE.MeshBasicMaterial({ map: holeTex, transparent: true, depthWrite: false, opacity: 0.85, polygonOffset: true, polygonOffsetFactor: -3 });
function spawnBlast(p, radius, color, big = true) {
  const low = lowGfx(), ground = groundAt(p.x, p.z, p.y + 0.5, 0.3), nearGround = p.y - ground < 1.2;
  // layered fireball: bright core puffs that swell, rise and cool from yellow to deep red
  for (let i = 0, n = low ? 5 : big ? 12 : 7; i < n; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: fireTex, color: new THREE.Color(color).lerp(new THREE.Color(0xfff2c0), 0.4), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false }));
    sp.position.copy(p).add(new V3(rand(-1, 1), rand(-0.3, 1), rand(-1, 1)).multiplyScalar(radius * 0.18));
    const life = rand(0.45, 0.8);
    sp.userData = { v: new V3(rand(-1, 1), rand(0.4, 1.6), rand(-1, 1)).multiplyScalar(radius * 0.55), life, max: life, s0: radius * rand(0.35, 0.6), base: color };
    sp.material.rotation = rand(0, 6.28);
    scene.add(sp); blastFx.fire.push(sp);
  }
  // shockwave on the ground + a ring of kicked-up dust
  if (nearGround) {
    const r = new THREE.Mesh(shockGeo, new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(1.6), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, side: THREE.DoubleSide }));
    r.position.set(p.x, ground + 0.06, p.z); r.userData = { life: 0.45, max: 0.45, size: radius * 1.5 };
    scene.add(r); blastFx.rings.push(r);
    for (let i = 0; i < (low ? 4 : 10); i++) {
      const a = i / 10 * 6.28 + rand(-0.2, 0.2), q = p.clone().setY(ground + 0.3).add(new V3(Math.cos(a), 0, Math.sin(a)).multiplyScalar(radius * rand(0.35, 0.6)));
      spawnSmoke(q, mode === 'zombie' ? 0x3a3530 : 0x9a9082, radius * 0.7, rand(1.4, 2.2), 0.3, 0.45);
    }
    // scorch mark that fades out slowly
    const sc = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), scorchMat.clone());
    sc.scale.setScalar(radius * rand(0.7, 0.9)); sc.rotation.y = rand(0, 6.28); sc.position.set(p.x, ground + 0.015, p.z);
    sc.userData = { life: 25 }; scene.add(sc); blastFx.scorch.push(sc);
    if (blastFx.scorch.length > 14) scene.remove(blastFx.scorch.shift());
  }
  // debris chunks and glowing embers that bounce and settle
  for (let i = 0, n = low ? 5 : big ? 16 : 6; i < n; i++) {
    const hot = i % 4 === 0, m = new THREE.Mesh(debrisGeo[i % 3], hot ? debrisMats[2] : debrisMats[i % 2]);
    m.position.copy(p).add(new V3(0, 0.2, 0)); m.scale.setScalar(rand(0.6, 1.4) * (big ? 1 : 0.6)); m.castShadow = !low;
    m.userData = { v: new V3(rand(-1, 1), rand(0.6, 1.4), rand(-1, 1)).normalize().multiplyScalar(rand(4, 11) * (big ? 1 : 0.6)), spin: new V3(rand(-12, 12), rand(-12, 12), rand(-12, 12)), life: rand(2.2, 3.4), ground };
    scene.add(m); blastFx.debris.push(m);
  }
  // a dark column of smoke that lingers and rises
  for (let i = 0; i < (low ? 3 : big ? 9 : 4); i++) {
    spawnSmoke(p.clone().add(new V3(rand(-0.6, 0.6), rand(0, 1.4), rand(-0.6, 0.6)).multiplyScalar(radius * 0.25)), i % 3 ? 0x2f2b28 : 0x55504a, radius * rand(0.8, 1.2), rand(2.6, 4.2), rand(0.8, 1.6), 0.6);
  }
}
function updateBlastFx(dt) {
  for (let i = blastFx.fire.length - 1; i >= 0; i--) {
    const s = blastFx.fire[i], u = s.userData;
    u.life -= dt; const t = 1 - u.life / u.max;
    s.position.addScaledVector(u.v, dt); u.v.multiplyScalar(Math.exp(-dt * 4)); u.v.y += dt * 1.5;
    s.scale.setScalar(u.s0 * (0.7 + smooth(Math.min(1, t * 1.6)) * 1.3));
    s.material.color.set(u.base).lerp(new THREE.Color(0xfff2c0), Math.max(0, 0.5 - t)).multiplyScalar(1 - t * 0.6);
    s.material.opacity = Math.pow(1 - t, 1.4); s.material.rotation += dt * 0.8;
    if (u.life <= 0) { scene.remove(s); s.material.dispose(); blastFx.fire.splice(i, 1); }
  }
  for (let i = blastFx.rings.length - 1; i >= 0; i--) {
    const r = blastFx.rings[i], u = r.userData;
    u.life -= dt; const t = 1 - u.life / u.max;
    r.scale.setScalar(0.3 + smooth(t) * u.size); r.material.opacity = (1 - t) * 0.9;
    if (u.life <= 0) { scene.remove(r); r.material.dispose(); blastFx.rings.splice(i, 1); }
  }
  for (let i = blastFx.debris.length - 1; i >= 0; i--) {
    const m = blastFx.debris[i], u = m.userData;
    u.life -= dt; u.v.y -= 20 * dt;
    m.position.addScaledVector(u.v, dt);
    m.rotation.x += u.spin.x * dt; m.rotation.y += u.spin.y * dt; m.rotation.z += u.spin.z * dt;
    if (m.position.y < u.ground + 0.04) { m.position.y = u.ground + 0.04; u.v.y *= -0.35; u.v.x *= 0.55; u.v.z *= 0.55; u.spin.multiplyScalar(0.5); }
    if (u.life < 0.5) m.scale.multiplyScalar(Math.exp(-dt * 8));
    if (u.life <= 0) { scene.remove(m); blastFx.debris.splice(i, 1); }
  }
  for (const sc of blastFx.scorch) { sc.userData.life -= dt; sc.material.opacity = 0.85 * clamp(sc.userData.life / 6, 0, 1); }
}
function clearBlastFx() {
  for (const k of ['fire', 'rings', 'debris', 'scorch']) { blastFx[k].forEach(o => scene.remove(o)); blastFx[k].length = 0; }
}
function explode(p, o) {
  const color = o.color ?? 0xffa040;
  spawnFlash(p, 0xfff0d0, o.radius * 1.1, 0.16);
  spawnBlast(p, o.radius, color, o.radius >= 4);
  spawnParticles(p, color, lowGfx() ? 14 : 30, new V3(0, 1, 0), 10);
  lightBurst(p, color, 110);
  const d = playerEye().distanceTo(p);
  sfxBoom(clamp(1.25 - d / 60, 0.2, 1.1) * (o.vol ?? 1), panOf(p), clamp(d / 50, 0, 1));
  player.shake = Math.max(player.shake, clamp(1.2 - d / (o.radius * 4), 0, 1));
  const rk = clamp(1.3 - d / (o.radius * 5), 0, 1);
  if (rk > 0.05) rumble(rk, rk * 0.8, 250 + rk * 300);
  const from = p.clone().setY(p.y + 0.3);
  let hit = false, kill = false;
  for (const b of o.noEnemies ? [] : enemies) {
    if (b.dead || b === o.skip) continue;
    const c = b.pos.clone().setY(b.pos.y + 1), dist = c.distanceTo(p);
    if (dist > o.radius || !worldClear(from, c)) continue;
    const dmg = o.dmg * Math.pow(1 - dist / o.radius, 0.6) * (pw('quad') ? 3 : 1), prev = b.hp;
    const killed = b.damage(dmg, false, o.key);
    showDamageNumber(c, Math.min(prev, dmg), false, killed);
    hit = true; kill ||= killed;
  }
  if (hit) showHitmarker(kill);
  if (o.self) {
    const body = player.pos.clone().setY(player.pos.y + 0.9), pd = body.distanceTo(p);
    if (pd < o.radius && worldClear(from, body)) damagePlayer(o.self * (1 - pd / o.radius), p, true);
  }
}
// spitter acid: a direct hit burns, landing next to you only splashes
function acidSplash(p, direct) {
  spawnParticles(p, 0x8dff4a, 16, new V3(0, 1, 0), 4);
  spawnSmoke(p, 0x4a7a30, 1.3);
  const d = playerEye().distanceTo(p);
  if (actx) withCat('enemies', () => sfxBurst(actx.currentTime, 0.25, 'bandpass', 1800, 0.8, clamp(0.5 - d / 50, 0.05, 0.4), sfxOut()));
  const body = player.pos.clone().setY(player.pos.y + 0.9), pd = body.distanceTo(p);
  if (direct) damagePlayer(13, p);
  else if (pd < 1.8 && worldClear(p, body)) damagePlayer(6 * (1 - pd / 1.8 * 0.5), p);
}
function enemyBlast(p) {
  const boss = enemies.find(b => b.boss && !b.dead);
  explode(p, { radius: 4, dmg: 0, noEnemies: true, key: 'rocket', color: 0xff5040 });
  const body = player.pos.clone().setY(player.pos.y + 0.9), pd = body.distanceTo(p);
  if (pd < 4 && worldClear(p, body)) damagePlayer((22 + 6 * (boss?.boss || 1)) * (1 - pd / 4 * 0.7), p);
}
function stunBurst(p) {
  spawnFlash(p, 0xffffff, 10, 0.3);
  spawnParticles(p, 0xfff6d0, lowGfx() ? 12 : 26, new V3(0, 1, 0), 7);
  lightBurst(p, 0xffffff, 140);
  const from = p.clone().setY(p.y + 0.3), eye = playerEye(), d = eye.distanceTo(p);
  for (const b of enemies) {
    if (b.dead) continue;
    const c = b.pos.clone().setY(b.pos.y + 1.5), dist = c.distanceTo(p);
    if (dist < 12 && worldClear(from, c)) { b.stunT = Math.max(b.stunT, lerp(5, 2.2, dist / 12) * (b.boss ? 0.3 : 1)); b.path.length = 0; }
  }
  let ring = 0;
  if (d < 14 && worldClear(from, eye)) {
    const facing = new V3(0, 0, -1).applyQuaternion(camera.quaternion).dot(p.clone().sub(eye).normalize());
    ring = (1 - d / 14) * (facing > 0 ? 0.45 + facing * 0.55 : 0.25);
    blind = Math.max(blind, ring * 3.2);
  }
  sfxStunBang(clamp(1.25 - d / 50, 0.2, 1.1), panOf(p), clamp(d / 45, 0, 1), ring);
}
function spawnCloud(p) {
  const c = { pos: p.clone().setY(Math.max(p.y, 0) + 1.2), r: 0, t: 0, life: 15, sprites: [] };
  const col = mode === 'zombie' ? 0x6a6f78 : 0xd2d6dc;
  for (let i = 0, n = lowGfx() ? 14 : 30; i < n; i++) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: cloudTex, color: col, transparent: true, depthWrite: false, opacity: 0 }));
    const a = rand(0, 6.28), rr = Math.sqrt(Math.random()) * 3.2;
    s.userData = { off: new V3(Math.cos(a) * rr, rand(-0.9, 1.8), Math.sin(a) * rr), size: rand(3.4, 5), spin: rand(-0.3, 0.3) };
    scene.add(s); c.sprites.push(s);
  }
  clouds.push(c);
  const d = playerEye().distanceTo(p);
  sfxSmokeHiss(clamp(1.1 - d / 40, 0.1, 1), panOf(p));
}
function onImpact(pr, h, dir) {
  const enemy = h.object.userData.enemy;
  if (pr.kind === 'tknife') {
    if (enemy && !enemy.dead) {
      const part = h.object.userData.part, head = part === 'head';
      const dmg = (head ? 400 : part === 'limb' ? 120 : 170) * (pw('quad') ? 3 : 1), prev = enemy.hp;
      const killed = enemy.damage(dmg, head, 'tknife');
      showDamageNumber(h.point, Math.min(prev, dmg), head, killed); showHitmarker(killed);
      spawnParticles(h.point, enemy.sparkColor, 10, dir.clone().negate(), 3);
      sfxTone(160, 0.1, 0.3, 'square', 70);
      return true;
    }
    if (enemy) return true;
    // stick into the wall for a few seconds
    const n = h.face.normal.clone().transformDirection(h.object.matrixWorld);
    pr.pos.copy(h.point).addScaledVector(dir, 0.04); pr.stuck = true; pr.stuckT = 8;
    pr.mesh.position.copy(pr.pos); pr.mesh.lookAt(pr.pos.clone().add(dir));
    spawnParticles(h.point.clone().addScaledVector(n, 0.03), 0xffe0a0, 6, n, 3);
    sfxTone(2600, 0.05, 0.12, 'square', 1700);
    return false;
  }
  if (pr.kind === 'erocket') { enemyBlast(h.point.clone().addScaledVector(dir, -0.3)); return true; }
  if (pr.kind === 'acid') { acidSplash(h.point.clone().addScaledVector(dir, -0.1), false); return true; }
  if (pr.kind === 'rocket') {
    const n = enemy ? dir.clone().negate() : h.face.normal.clone().transformDirection(h.object.matrixWorld);
    explode(h.point.clone().addScaledVector(n, 0.2), { radius: 6, dmg: 400 * dmgMul('rocket'), key: 'rocket', self: 55, vol: 1.2 });
    shotsHit += enemy ? 1 : 0;
    return true;
  }
  // plasma bolt: direct hit + green splash
  if (enemy && !enemy.dead) {
    const part = h.object.userData.part, w = WEAPONS.raygun, dmg = w.dmg[part] * (pw('quad') ? 3 : 1) * dmgMul('raygun'), prev = enemy.hp;
    const killed = enemy.damage(dmg, part === 'head', 'raygun');
    showDamageNumber(h.point, Math.min(prev, dmg), part === 'head', killed); showHitmarker(killed);
    shotsHit++;
  }
  explode(h.point, { radius: WEAPONS.raygun.splash, dmg: WEAPONS.raygun.splashDmg * dmgMul('raygun'), key: 'raygun', color: 0x6bff8a, smoke: 0x3a6a40, vol: 0.45, skip: enemy, self: 12 });
  return true;
}
function detonate(pr) {
  if (pr.kind === 'frag') explode(pr.pos, { radius: 6.5, dmg: 260, key: 'frag', self: 60 });
  else if (pr.kind === 'stun') stunBurst(pr.pos);
  else if (pr.kind === 'smoke') spawnCloud(pr.pos);
}
function updateThrowables(dt) {
  throwCD -= dt;
  blind = Math.max(0, blind - dt * 0.6);
  boomT -= dt; boomLight.intensity = boomT > 0 ? boomLight.intensity * Math.exp(-dt * 9) * rand(0.85, 1.1) : 0;
  updateBlastFx(dt);
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const pr = projectiles[i], def = PROJ[pr.kind];
    pr.t += dt;
    if (pr.stuck) { pr.stuckT -= dt; if (pr.stuckT <= 0) removeProjectile(i); continue; }
    if (def.fuse && pr.t >= def.fuse) { detonate(pr); removeProjectile(i); continue; }
    if (def.life && pr.t > def.life) { removeProjectile(i); continue; }
    if (!pr.rest) {
      pr.vel.y -= def.grav * dt;
      const step = pr.vel.clone().multiplyScalar(dt), len = step.length(), dir = step.clone().divideScalar(len || 1);
      projRay.set(pr.pos, dir); projRay.far = len + def.r;
      const h = len > 1e-5 && projRay.intersectObjects(def.hits && !def.enemy ? worldMeshes.concat(...enemies.filter(b => !b.dead).map(b => b.parts)) : worldMeshes, false)[0];
      // boss rockets also blow up when they reach you
      if (def.enemy && pr.pos.distanceTo(player.pos.clone().setY(player.pos.y + 0.9)) < 1) { if (pr.kind === 'acid') acidSplash(pr.pos, true); else enemyBlast(pr.pos); removeProjectile(i); continue; }
      if (h) {
        if (def.hits) { if (onImpact(pr, h, dir)) removeProjectile(i); continue; }
        const n = h.face.normal.clone().transformDirection(h.object.matrixWorld);
        pr.pos.copy(h.point).addScaledVector(n, def.r);
        const vn = pr.vel.dot(n);
        pr.vel.addScaledVector(n, -(1 + def.bounce) * vn).multiplyScalar(0.72);
        if (Math.abs(vn) > 2) sfxBounce(clamp(1 - playerEye().distanceTo(pr.pos) / 30, 0.1, 1));
        if (n.y > 0.7 && pr.vel.length() < 1.3) { pr.rest = true; pr.vel.set(0, 0, 0); }
      } else pr.pos.add(step);
      if (pr.pos.y < -3 || Math.abs(pr.pos.x) > 45 || Math.abs(pr.pos.z) > 45) { removeProjectile(i); continue; }
    }
    pr.mesh.position.copy(pr.pos);
    if (pr.kind === 'tknife') { pr.mesh.lookAt(pr.pos.clone().add(pr.vel)); pr.mesh.rotateX(-pr.t * 28); }
    else if (pr.kind === 'rocket' || pr.kind === 'erocket') {
      pr.mesh.lookAt(pr.pos.clone().add(pr.vel)); pr.mesh.children[2].scale.setScalar(rand(0.4, 0.65));
      if (Math.random() < (lowGfx() ? 0.35 : 0.8)) spawnSmoke(pr.pos.clone().addScaledVector(pr.vel, -0.012), 0xb8b2aa, 0.7);
    }
    else if (pr.kind === 'plasma' || pr.kind === 'acid') { pr.mesh.children[1].scale.setScalar(0.6 + Math.sin(pr.t * 40) * 0.12); if (Math.random() < 0.5) spawnParticles(pr.pos, 0x6bff8a, 1, null, 0.6); }
    else if (!pr.rest) { pr.mesh.rotation.x += dt * pr.spin; pr.mesh.rotation.z += dt * pr.spin * 0.6; }
  }
  for (let i = flashes.length - 1; i >= 0; i--) {
    const s = flashes[i], u = s.userData;
    u.life -= dt;
    const t = 1 - u.life / u.max;
    s.scale.setScalar(u.size * (0.5 + t)); s.material.opacity = 1 - t;
    if (u.life <= 0) { scene.remove(s); s.material.dispose(); flashes.splice(i, 1); }
  }
  for (let i = clouds.length - 1; i >= 0; i--) {
    const c = clouds[i];
    c.t += dt;
    const grow = smooth(clamp(c.t / 1.8, 0, 1)), fade = clamp((c.life - c.t) / 2.5, 0, 1);
    c.r = 4 * grow * Math.min(1, fade / 0.4);
    for (const s of c.sprites) {
      const u = s.userData;
      s.position.copy(c.pos).addScaledVector(u.off, 0.35 + 0.65 * grow); s.position.y += c.t * 0.04;
      s.scale.setScalar(u.size * (0.4 + 0.6 * grow));
      s.material.opacity = 0.9 * grow * fade; s.material.rotation += dt * u.spin;
    }
    if (c.t >= c.life) { c.sprites.forEach(s => { scene.remove(s); s.material.dispose(); }); clouds.splice(i, 1); }
  }
}
function clearThrowables() {
  while (projectiles.length) removeProjectile(0);
  flashes.forEach(s => { scene.remove(s); s.material.dispose(); }); flashes.length = 0;
  clouds.forEach(c => c.sprites.forEach(s => { scene.remove(s); s.material.dispose(); })); clouds.length = 0;
  boomLight.intensity = 0; blind = 0; throwCD = 0;
}

// ============================================================ weapons in the world: floor drops + mystery box
const worldGunProto = {};
for (const [k, w] of Object.entries(WEAPONS)) {
  const g = w.group.clone(true), junk = [];
  const armMats = [gunMats.glove, gunMats.sleeve, gunMats.gloveDark, gunMats.watch, gunMats.skin, gunMats.knuckle, gunMats.strap, gunMats.patch];
  g.traverse(o => { if (o.isSprite || armMats.includes(o.material)) junk.push(o); else { o.visible = true; if (o.isMesh) o.castShadow = true; } });
  junk.forEach(o => o.parent.remove(o));
  g.position.set(0, 0, 0); g.rotation.set(0, 0, 0);
  worldGunProto[k] = g;
}
const makeWorldGun = k => worldGunProto[k].clone(true);
const rarityRingMats = {};
const rarityRing = r => rarityRingMats[r.name] ||= new THREE.MeshBasicMaterial({ color: new THREE.Color(r.color).multiplyScalar(2.2), toneMapped: false });
const drops = [];
function spawnDrop(key, mag, pos) {
  const g = new THREE.Group(), m = makeWorldGun(key), r = rarityOf(key);
  m.rotation.set(0, 0, Math.PI / 2); m.position.y = 0.08; m.scale.setScalar(1.35);
  const ring = new THREE.Mesh(PU.ring, rarityRing(r)); ring.rotation.x = Math.PI / 2; ring.position.y = 0.03; ring.scale.setScalar(1.3);
  g.add(m, ring);
  g.position.copy(pos); g.rotation.y = rand(0, 6.28);
  scene.add(g);
  drops.push({ key, mag, pos: pos.clone(), group: g, ring, life: 60 });
  if (drops.length > 8) removeDrop(drops[0]);
}
function removeDrop(d) { scene.remove(d.group); drops.splice(drops.indexOf(d), 1); }
function dropPoint() {
  const fwd = new V3(-Math.sin(player.yaw), 0, -Math.cos(player.yaw));
  const p = player.pos.clone().addScaledVector(fwd, 1.1);
  if (!worldClear(player.pos.clone().setY(player.pos.y + 0.5), p.clone().setY(player.pos.y + 0.5))) p.copy(player.pos);
  p.y = groundAt(p.x, p.z, player.pos.y + 0.2, 0.2);
  return p;
}
function updateDrops(dt) {
  for (let i = drops.length - 1; i >= 0; i--) {
    const d = drops[i];
    d.life -= dt;
    if (d.life <= 0) { removeDrop(d); continue; }
    d.group.visible = d.life > 5 || Math.sin(d.life * 18) > 0;
    d.ring.scale.setScalar(1.3 + Math.sin(now * 3 + i) * 0.06);
  }
}
function renderSlots() {
  slots.forEach((k, i) => {
    const el = $('slot' + i);
    el.dataset.w = k || ''; el.classList.toggle('none', !k);
    el.innerHTML = (k ? ICONS[k] : '<svg viewBox="0 0 24 24"></svg>') + `<span class="k">${i + 1}</span>`;
  });
}
function giveWeapon(key, mag) {
  let i = slots.indexOf(null);
  if (i < 0) {
    i = Math.max(0, slots.indexOf(weapon.switchTo || weapon.current));
    spawnDrop(slots[i], weapon.mags[slots[i]], dropPoint());
  }
  slots[i] = key; weapon.mags[key] = mag ?? magOf(key);
  renderSlots();
  switchWeapon(key);
  sfxPickup(true);
}
function dropCurrentWeapon() {
  const i = slots.indexOf(weapon.switchTo || weapon.current);
  if (i < 0 || weapon.meleeT > 0) return;
  if (!slots[1 - i]) { toast('NON PUOI GETTARE L’ULTIMA ARMA', 'pu', 'box', '#ff8a7a'); return; }
  const key = slots[i];
  spawnDrop(key, weapon.mags[key], dropPoint());
  slots[i] = null; renderSlots();
  switchWeapon(slots[1 - i]);
  sfxSwoosh(0.3);
}
function pickupDrop(d) {
  if (slots.includes(d.key)) {
    weapon.mags[d.key] = magOf(d.key);
    toast(`MUNIZIONI ${WEAPONS[d.key].name}`, 'pu', d.key, rarityOf(d.key).css); sfxPickup(false);
  } else giveWeapon(d.key, d.mag);
  removeDrop(d);
}

// ---------------------------------------------------------------- mystery box
const BOX_COST = 950;
const box = (() => {
  const [qc, qg] = canvas(256);
  qg.font = '700 210px Rajdhani, Inter, sans-serif'; qg.textAlign = 'center'; qg.textBaseline = 'middle';
  qg.shadowColor = '#6cc4ff'; qg.shadowBlur = 28; qg.fillStyle = '#eaf7ff'; qg.fillText('?', 128, 138); qg.fillText('?', 128, 138);
  const qTex = new THREE.CanvasTexture(qc); qTex.colorSpace = THREE.SRGBColorSpace;
  const wood = new THREE.MeshStandardMaterial({ ...crateTex(), color: 0x6a4a34, bumpScale: 1.4, roughness: 0.6 });
  const gold = new THREE.MeshStandardMaterial({ color: 0xd4a640, metalness: 0.9, roughness: 0.3 });
  const qMat = new THREE.MeshBasicMaterial({ map: qTex, transparent: true, depthWrite: false, color: new THREE.Color(0.8, 1.6, 2.2), toneMapped: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 });
  const iron = new THREE.MeshStandardMaterial({ color: 0x1e2127, roughness: 0.35, metalness: 0.85 });
  const g = new THREE.Group();
  const body = new THREE.Mesh(rbox(1.7, 0.62, 0.85, 0.05), wood); body.position.y = 0.31; body.castShadow = body.receiveShadow = true; g.add(body);
  for (const y of [0.06, 0.55]) { const t = new THREE.Mesh(rbox(1.74, 0.05, 0.89, 0.02), gold); t.position.y = y; g.add(t); }
  for (const x of [-0.84, 0.84]) { const t = new THREE.Mesh(rbox(0.07, 0.58, 0.9, 0.025), gold); t.position.set(x, 0.3, 0); g.add(t); }
  const latch = new THREE.Mesh(rbox(0.16, 0.13, 0.04, 0.015), iron); latch.position.set(0, 0.52, 0.445); g.add(latch);
  const keyhole = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.01, 12).rotateX(Math.PI / 2), gold); keyhole.position.set(0, 0.51, 0.467); g.add(keyhole);
  const qGeo = new THREE.PlaneGeometry(0.42, 0.42);
  for (const [x, z, ry] of [[-0.4, 0.431, 0], [0.4, 0.431, 0], [-0.4, -0.431, Math.PI], [0.4, -0.431, Math.PI], [0.881, 0, Math.PI / 2], [-0.881, 0, -Math.PI / 2]]) {
    const q = new THREE.Mesh(qGeo, qMat); q.position.set(x, 0.31, z); q.rotation.y = ry; g.add(q);
  }
  const lid = new THREE.Group(); lid.position.set(0, 0.62, -0.425); g.add(lid);
  const lidM = new THREE.Mesh(rbox(1.7, 0.14, 0.85, 0.05), wood); lidM.position.set(0, 0.07, 0.425); lidM.castShadow = true; lid.add(lidM);
  const lidT = new THREE.Mesh(rbox(1.74, 0.045, 0.89, 0.018), gold); lidT.position.set(0, 0.055, 0.425); lid.add(lidT);
  for (const [cx, cz] of [[-0.78, 0.06], [0.78, 0.06], [-0.78, 0.79], [0.78, 0.79]]) {
    const cap = new THREE.Mesh(rbox(0.16, 0.03, 0.16, 0.012), gold); cap.position.set(cx, 0.15, cz); lid.add(cap);
  }
  for (const x of [-0.5, 0.5]) { const h = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.18, 12).rotateZ(Math.PI / 2), iron); h.position.set(x, 0.0, -0.01); lid.add(h); }
  const qTop = new THREE.Mesh(qGeo, qMat); qTop.rotation.x = -Math.PI / 2; qTop.position.set(0, 0.152, 0.425); lid.add(qTop);
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.75, 16, 32, 1, true).translate(0, 8, 0), beamMat(0x7fc8ff, 0.32));
  const light = new THREE.PointLight(0x9fd0ff, 0, 9, 2); light.position.y = 1.3;
  const display = new THREE.Group(); display.position.y = 0.5; g.add(display, beam, light);
  const models = {};
  for (const k of Object.keys(WEAPONS)) { const m = makeWorldGun(k); m.rotation.y = Math.PI / 2; m.scale.setScalar(1.25); m.visible = false; display.add(m); models[k] = m; }
  scene.add(g);
  return { group: g, body, lid, beam, light, display, models, collider: new THREE.Box3(), spot: -1, state: 'idle', t: 0, swapT: 0, shown: null, choice: null };
})();
function showBoxModel(k) { for (const [key, m] of Object.entries(box.models)) m.visible = key === k; box.shown = k; }
function placeBox(first) {
  let idx = box.spot;
  for (let tries = 0; tries < 30; tries++) {
    const BOX_SPOTS = MAP.boxSpots, c = Math.floor(Math.random() * BOX_SPOTS.length);
    if (c === box.spot) continue;
    idx = c;
    if (first || Math.hypot(BOX_SPOTS[c][0] - player.pos.x, BOX_SPOTS[c][1] - player.pos.z) > 12) break;
  }
  const [x, z] = MAP.boxSpots[idx % MAP.boxSpots.length];
  box.spot = idx;
  box.group.position.set(x, 0, z); box.group.rotation.y = Math.atan2(-x, -z);
  box.group.visible = true; box.group.updateMatrixWorld(true);
  box.collider.setFromObject(box.body);
  if (!colliders.includes(box.collider)) colliders.push(box.collider);
  if (!worldMeshes.includes(box.body)) worldMeshes.push(box.body);
  box.state = 'idle'; box.t = 0; box.lid.rotation.x = 0; showBoxModel(null);
  box.beam.material.uniforms.color.value.set(0x7fc8ff); box.light.color.set(0x9fd0ff);
}
function hideBox() {
  box.group.visible = false;
  if (colliders.includes(box.collider)) colliders.splice(colliders.indexOf(box.collider), 1);
  if (worldMeshes.includes(box.body)) worldMeshes.splice(worldMeshes.indexOf(box.body), 1);
}
function rollBoxWeapon() {
  const pool = BOX_POOL.filter(e => !slots.includes(e[0]));
  let r = Math.random() * pool.reduce((s, e) => s + e[2], 0);
  for (const e of pool) { r -= e[2]; if (r <= 0) return e[0]; }
  return pool[0][0];
}
function openBox() {
  box.state = 'rolling'; box.t = 0; box.swapT = 0;
  box.choice = rollBoxWeapon();
  sfxBoxOpen();
}
function takeBoxWeapon() {
  giveWeapon(box.choice);
  const r = rarityOf(box.choice);
  toast(`${WEAPONS[box.choice].name} · ${r.name}`, 'pu', box.choice, r.css);
  showBoxModel(null);
  box.state = 'closing'; box.t = 0;
}
function updateBox(dt) {
  box.t += dt;
  const pulse = 0.8 + Math.sin(now * 3) * 0.2;
  if (box.state === 'idle') {
    box.light.intensity = 2.5 * pulse * lightK();
  } else if (box.state === 'rolling') {
    box.lid.rotation.x = -smooth(clamp(box.t / 0.4, 0, 1)) * 1.9;
    box.display.position.y = 0.45 + smooth(clamp(box.t / 2.6, 0, 1)) * 0.85;
    box.display.rotation.y = 0;
    box.swapT -= dt;
    if (box.swapT <= 0) {
      const keys = Object.keys(box.models).filter(k => k !== box.shown);
      showBoxModel(keys[Math.floor(Math.random() * keys.length)]);
      box.swapT = lerp(0.06, 0.34, Math.pow(box.t / 3.2, 2));
      sfxTone(rand(900, 1500), 0.035, 0.05, 'square', rand(900, 1500));
    }
    box.light.intensity = (3 + Math.random() * 2) * lightK();
    if (box.t >= 3.2) {
      box.state = 'offer'; box.t = 0;
      showBoxModel(box.choice);
      const r = rarityOf(box.choice);
      box.beam.material.uniforms.color.value.set(r.color); box.light.color.set(r.color);
      spawnParticles(box.group.position.clone().setY(1.4), r.color, 24, new V3(0, 1, 0), 3);
      sfxBoxReveal(BOX_POOL.find(e => e[0] === box.choice)[1]);
    }
  } else if (box.state === 'offer') {
    box.display.position.y = 1.3 + Math.sin(box.t * 2.5) * 0.05;
    box.display.rotation.y = Math.sin(box.t * 0.9) * 0.5;
    box.light.intensity = 3.5 * pulse * lightK();
    if (box.t > 9) { box.state = 'closing'; box.t = 0; toast('L’ARMA È TORNATA NELLA CASSA', 'pu', 'box', '#9fd0ff'); }
  } else if (box.state === 'closing') {
    box.display.position.y = Math.max(0.3, box.display.position.y - dt * 1.6);
    box.lid.rotation.x = -1.9 * (1 - smooth(clamp(box.t / 0.8, 0, 1)));
    if (box.t > 1.1) {
      // single use: the box vanishes and reappears somewhere else
      const p = box.group.position.clone().setY(0.8);
      spawnParticles(p, 0x9fd0ff, 30, new V3(0, 1, 0), 5);
      for (let i = 0; i < 4; i++) spawnSmoke(p.clone().add(new V3(rand(-0.8, 0.8), rand(0, 0.6), rand(-0.8, 0.8))), 0xaac8e0, 2);
      sfxSwoosh(0.5); sfxTone(700, 0.5, 0.1, 'triangle', 180);
      hideBox(); box.state = 'away'; box.t = 0;
    }
  } else if (box.state === 'away' && box.t > 3) {
    placeBox(false);
    spawnParticles(box.group.position.clone().setY(1), 0x9fd0ff, 30, new V3(0, 1, 0), 4);
    toast('LA CASSA MISTERIOSA SI È SPOSTATA', 'pu', 'box', '#9fd0ff');
    sfxPowerSpawn(0.8);
  }
  box.beam.visible = box.state !== 'closing' && box.state !== 'away';
  box.beam.rotation.y += dt * 0.5;
  if (box.state === 'away') box.light.intensity = 0;
}

// ---------------------------------------------------------------- minimap (player-centred, rotates with the view)
const MM = { cv: $('minimap'), R: 90, range: 32, base: null, ver: -1 };
MM.ctx = MM.cv.getContext('2d');
function minimapBase() {
  // static layout drawn once at 5 px per metre
  const c = document.createElement('canvas'); c.width = c.height = 400;
  const g = c.getContext('2d');
  g.fillStyle = 'rgba(255,255,255,.05)'; g.fillRect(0, 0, 400, 400);
  if (MAP.key === 'arena') { g.strokeStyle = 'rgba(255,196,120,.25)'; g.lineWidth = 2; g.beginPath(); g.arc(200, 200, 46, 0, Math.PI * 2); g.stroke(); }
  if (MAP.roads) { g.fillStyle = 'rgba(0,0,0,.28)'; for (const [x0, z0, x1, z1] of MAP.roads) g.fillRect((x0 + 40) * 5, (z0 + 40) * 5, (x1 - x0) * 5, (z1 - z0) * 5); }
  g.fillStyle = 'rgba(210,220,235,.42)';
  const skip = new Set([box.collider, ...arena.solids.map(s => s.box)]);
  for (const b of colliders) {
    if (skip.has(b) || b.max.y < 0.5) continue;
    g.fillRect((b.min.x + 40) * 5, (b.min.z + 40) * 5, (b.max.x - b.min.x) * 5, (b.max.z - b.min.z) * 5);
  }
  return c;
}
function drawMinimap() {
  const { ctx, R, range } = MM;
  if (MM.ver !== mapVersion || !MM.base) { MM.base = minimapBase(); MM.ver = mapVersion; }
  const S = R / range, cy = Math.cos(player.yaw), sy = Math.sin(player.yaw);
  ctx.clearRect(0, 0, 2 * R, 2 * R);
  ctx.save();
  ctx.beginPath(); ctx.arc(R, R, R - 1, 0, Math.PI * 2); ctx.clip();
  ctx.fillStyle = 'rgba(8,12,20,.35)'; ctx.fillRect(0, 0, 2 * R, 2 * R);
  // world -> map: forward is always up
  ctx.save();
  ctx.translate(R, R); ctx.scale(S, S); ctx.transform(cy, sy, -sy, cy, 0, 0); ctx.translate(-player.pos.x, -player.pos.z);
  ctx.drawImage(MM.base, -40, -40, 80, 80);
  if (arena.on) {
    ctx.strokeStyle = 'rgba(58,255,224,.7)'; ctx.lineWidth = 0.35;
    for (const s of arena.solids) { const b = s.box; ctx.strokeRect(b.min.x, b.min.z, b.max.x - b.min.x, b.max.z - b.min.z); }
    ctx.fillStyle = 'rgba(58,255,224,.8)';
    for (const p of arena.pads) { ctx.beginPath(); ctx.arc(p.pos.x, p.pos.z, 0.8, 0, Math.PI * 2); ctx.fill(); }
  }
  if (box.group.visible) {
    ctx.fillStyle = '#ffd45a'; const bp = box.group.position;
    ctx.fillRect(bp.x - 1, bp.z - 1, 2, 2);
  }
  for (const h of MAP.houses || []) { ctx.fillStyle = h.open ? '#8dffb0' : '#ff6a5a'; for (const [x, z] of h.doors) ctx.fillRect(x - 0.7, z - 0.7, 1.4, 1.4); }
  if (MAP.bench) { ctx.fillStyle = '#ff9d5c'; ctx.beginPath(); ctx.arc(MAP.bench.x, MAP.bench.z, 1.1, 0, Math.PI * 2); ctx.fill(); }
  if (MAP.perks) { ctx.fillStyle = '#c98bff'; ctx.globalAlpha = waveBreak > 0 ? 1 : 0.45; ctx.beginPath(); ctx.arc(MAP.perks.x, MAP.perks.z, 1.1, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1; }
  ctx.restore();
  // enemies: clamp far ones to the rim so you always know where they come from
  for (const b of enemies) {
    if (b.dead) continue;
    const dx = b.pos.x - player.pos.x, dz = b.pos.z - player.pos.z;
    let sx = (dx * cy - dz * sy) * S, sz = (dx * sy + dz * cy) * S;
    const d = Math.hypot(sx, sz), edge = d > R - 6;
    if (edge) { sx *= (R - 6) / d; sz *= (R - 6) / d; }
    ctx.fillStyle = b.boss ? '#ffd45a' : b.climber ? '#b98cff' : mode === 'zombie' ? '#ff6a3d' : '#ff4d4d';
    ctx.globalAlpha = edge ? 0.55 : 1;
    ctx.beginPath(); ctx.arc(R + sx, R + sz, (edge ? 2.5 : 3.6) * (b.boss ? 1.9 : 1), 0, Math.PI * 2); ctx.fill();
    if (!edge && b.pos.y - player.pos.y > 1.5) { ctx.fillRect(R + sx - 1, R + sz - 8, 2, 3); } // above you
  }
  ctx.globalAlpha = 1;
  ctx.restore();
  // you
  ctx.fillStyle = '#fff'; ctx.shadowColor = 'rgba(0,0,0,.6)'; ctx.shadowBlur = 4;
  ctx.beginPath(); ctx.moveTo(R, R - 7); ctx.lineTo(R + 5, R + 5); ctx.lineTo(R, R + 2.5); ctx.lineTo(R - 5, R + 5); ctx.closePath(); ctx.fill();
  ctx.shadowBlur = 0;
  ctx.strokeStyle = 'rgba(255,255,255,.12)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(R, R, R * 0.5, 0, Math.PI * 2); ctx.stroke();
}

// ---------------------------------------------------------------- interaction prompt (E)
function interactTarget() {
  if (box.group.visible && (box.state === 'idle' || box.state === 'offer')
    && Math.hypot(player.pos.x - box.group.position.x, player.pos.z - box.group.position.z) < 2.4 && player.pos.y < 1.5) return { type: 'box' };
  let best = null, bd = 1.8;
  for (const d of drops) {
    const dd = Math.hypot(player.pos.x - d.pos.x, player.pos.z - d.pos.z);
    if (dd < bd && Math.abs(player.pos.y - d.pos.y) < 1.2) { best = d; bd = dd; }
  }
  if (best) return { type: 'drop', drop: best };
  if (player.pos.y < 1.5) for (const h of MAP.houses || []) if (!h.open && h.doors.some(([x, z]) => Math.hypot(player.pos.x - x, player.pos.z - z) < 2.1)) return { type: 'house', house: h };
  for (const type of ['bench', 'perks']) if (MAP[type] && Math.hypot(player.pos.x - MAP[type].x, player.pos.z - MAP[type].z) < 2.6 && player.pos.y < 1.5) return { type };
  return null;
}
function interact() {
  const t = interactTarget();
  if (!t) return;
  if (t.type === 'drop') return pickupDrop(t.drop);
  if (t.type === 'bench') return openShop('bench');
  if (t.type === 'house') {
    const h = t.house;
    if (cash < h.cost) { sfxTone(220, 0.15, 0.12, 'square', 160); toast('CREDITI INSUFFICIENTI', 'pu', 'coin', '#ff8a7a'); return; }
    addCash(-h.cost); setHouse(h, true);
    for (let i = 0; i < 9; i++) sfxTone(95 + (i % 2) * 30, 0.07, 0.1, 'sawtooth', 70, i * 0.09);
    sfxTone(520, 0.25, 0.1, 'sine', 780, 0.85);
    toast(`${h.name} · EDIFICIO APERTO`, 'pu', 'coin', '#8dffb0'); return;
  }
  if (t.type === 'perks') {
    if (waveBreak > 0) return openShop('perks');
    sfxTone(220, 0.15, 0.12, 'square', 160); toast('APERTO SOLO TRA UN’ONDATA E L’ALTRA', 'pu', 'coin', '#c98bff'); return;
  }
  if (box.state === 'offer') return takeBoxWeapon();
  if (cash < BOX_COST) { sfxTone(220, 0.15, 0.12, 'square', 160); toast('CREDITI INSUFFICIENTI', 'pu', 'coin', '#ff8a7a'); return; }
  addCash(-BOX_COST); openBox();
}
let promptKey = '';
function updateInteract() {
  const t = interactTarget(), el = $('prompt');
  let html = '';
  if (t?.type === 'box' && box.state === 'idle') html = `<kbd>${keyLabel('E', 'X')}</kbd><span>Cassa misteriosa · arma casuale</span><span class="price${cash < BOX_COST ? ' no' : ''}">${BOX_COST}</span>`;
  else if (t?.type === 'box') { const r = rarityOf(box.choice); html = `<kbd>${keyLabel('E', 'X')}</kbd><span>Prendi <b>${WEAPONS[box.choice].name}</b></span><span class="rar" style="color:${r.css}">${r.name}</span>`; }
  else if (t?.type === 'house') html = `<kbd>${keyLabel('E', 'X')}</kbd><span>Apri <b>${t.house.name}</b> · un posto dove ripararsi</span><span class="price${cash < t.house.cost ? ' no' : ''}">${t.house.cost}</span>`;
  else if (t?.type === 'bench') html = `<kbd>${keyLabel('E', 'X')}</kbd><span>Banco armi · potenzia danno, caricatore e ricarica</span>`;
  else if (t?.type === 'perks') html = waveBreak > 0 ? `<kbd>${keyLabel('E', 'X')}</kbd><span>Distributore · compra un perk</span>` : `<span>Distributore di perk · apre tra un’ondata e l’altra</span>`;
  else if (t) { const r = rarityOf(t.drop.key); html = `<kbd>${keyLabel('E', 'X')}</kbd><span>Raccogli <b>${WEAPONS[t.drop.key].name}</b></span><span class="rar" style="color:${r.css}">${r.name}</span>`; }
  if (html !== promptKey) { promptKey = html; el.innerHTML = html; el.classList.toggle('on', !!html); }
}
function addCash(n) {
  cash = Math.max(0, cash + n);
  if (n > 0) earned += n; else spent -= n;
  const el = $('cash');
  el.textContent = cash;
  if (n > 0) { el.classList.add('flash'); setTimeout(() => el.classList.remove('flash'), 300); }
}
function resetArsenal() {
  clearThrowables();
  while (drops.length) removeDrop(drops[0]);
  Object.assign(equip, EQUIP_START);
  slots = [primary, 'pistol']; renderSlots();
  upg = {}; perks = {}; revives = 1; renderPerks();
  cash = 0; addCash(500); earned = spent = bossKills = 0;
  placeBox(true);
  promptKey = ''; $('prompt').classList.remove('on');
}
placeBox(true);
