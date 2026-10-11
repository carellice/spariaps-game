// Spariaps — Nemici: bot, zombie e boss.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ enemies: shared rig + behaviour
const hbGeo = new THREE.PlaneGeometry(1, 0.14);
const hbBaseMat = new THREE.ShaderMaterial({
  transparent: true, depthWrite: false, toneMapped: false,
  extensions: { derivatives: true },
  uniforms: { hp: { value: 1 }, lag: { value: 1 }, col: { value: new THREE.Color(0x34d399) }, flash: { value: 0 } },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: `uniform float hp, lag, flash; uniform vec3 col; varying vec2 vUv;
    float sdr(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
    void main(){
      vec2 size = vec2(1.0, 0.14);
      vec2 p = (vUv - 0.5) * size;
      float d = sdr(p, size * 0.5, 0.07);
      float aa = fwidth(d) * 1.2;
      float outer = 1.0 - smoothstep(-aa, aa, d);
      vec2 ib = size * 0.5 - vec2(0.022);
      float di = sdr(p, ib, 0.048);
      float inner = 1.0 - smoothstep(-aa, aa, di);
      float x = (p.x + ib.x) / (2.0 * ib.x);
      float isFill = step(x, hp) * inner;
      float isLag = step(x, lag) * (1.0 - step(x, hp)) * inner;
      vec3 c = vec3(0.04, 0.05, 0.07);
      c = mix(c, mix(col * 0.8, col * 1.35, vUv.y), isFill);
      c = mix(c, vec3(1.0), isLag * 0.85);
      float tick = 1.0 - smoothstep(0.0, 0.01, abs(fract(x * 4.0 + 0.5) - 0.5));
      c *= 1.0 - tick * 0.55 * inner * step(0.02, x) * step(x, 0.98);
      c += flash * 0.6 * inner;
      gl_FragColor = vec4(c, outer * mix(0.6, 1.0, max(isFill, isLag)));
    }`,
});
let enemies = [];

class Enemy {
  constructor(x, z, maxHp) {
    this.pos = new V3(x, 0, z);
    this.hp = this.maxHp = maxHp; this.lagHp = maxHp;
    this.dead = false; this.deathT = 0;
    this.path = []; this.repathT = 0; this.walk = rand(0, 6); this.hurtT = 0; this.nav = grid; this.stunT = 0;
    this.flinch = 0; this.flinchSide = 0; this.deathTwist = rand(-0.4, 0.4);
    this.phase = 1;
    this.yaw = Math.atan2(player.pos.x - x, player.pos.z - z);
    this.parts = []; this.mats = []; this.flashMats = [];
    this.group = new THREE.Group();
    this.pivot = new THREE.Group(); this.group.add(this.pivot);
    this.hips = new THREE.Group(); this.hips.position.y = 0.88; this.pivot.add(this.hips);
    this.spine = new THREE.Group(); this.spine.position.y = 0.04; this.hips.add(this.spine);
    this.headG = new THREE.Group(); this.spine.add(this.headG);
    this.hbMat = hbBaseMat.clone();
    this.hb = new THREE.Mesh(hbGeo, this.hbMat);
    this.hb.renderOrder = 10;
    scene.add(this.hb);
  }
  mat(params) { const m = new THREE.MeshStandardMaterial({ transparent: true, envMapIntensity: ATMOS[mode].env, ...params }); this.mats.push(m); return m; }
  add(geo, mat, x, y, z, kind, parent) {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z); m.castShadow = true;
    if (kind) { m.userData = { enemy: this, part: kind }; this.parts.push(m); }
    parent.add(m); return m;
  }
  // two jointed legs: hip -> thigh, knee -> shin + foot
  buildLegs(geo, thighMat, shinMat, footMat, kneeMat) {
    this.legs = [-0.13, 0.13].map(lx => {
      const hip = new THREE.Group(); hip.position.set(lx, 0, 0); this.hips.add(hip);
      this.add(geo.thigh, thighMat, 0, -0.21, 0, 'limb', hip);
      const knee = new THREE.Group(); knee.position.y = -0.44; hip.add(knee);
      if (kneeMat) this.add(geo.knee, kneeMat, 0, 0, 0.02, 'limb', knee);
      this.add(geo.shin, shinMat, 0, -0.2, 0, 'limb', knee);
      this.add(geo.foot, footMat, 0, -0.395, 0.05, 'limb', knee);
      return { hip, knee };
    });
  }
  finish() {
    this.group.position.copy(this.pos);
    this.group.rotation.y = this.yaw;
    scene.add(this.group);
  }
  gait(dt, speedNow, g) {
    const amt = clamp(speedNow / g.ref, 0, 1.25);
    this.walk += dt * speedNow * g.rate;
    this.legs.forEach((L, i) => {
      const ph = this.walk + i * Math.PI, k = i === 0 ? (g.limp ?? 1) : 1;
      L.hip.rotation.x = -Math.sin(ph) * g.stride * amt * k;
      L.knee.rotation.x = (0.05 + Math.max(0, -Math.cos(ph)) * g.knee) * amt * k;
    });
    this.hips.position.y = 0.88 + (Math.abs(Math.cos(this.walk)) - 0.6) * g.bob * amt;
    return amt;
  }
  animateDeath(dt) {
    this.deathT += dt;
    const t = this.deathT;
    const buckle = smooth(clamp(t / 0.3, 0, 1)), fall = smooth(clamp((t - 0.12) / 0.55, 0, 1));
    this.legs.forEach((L, i) => { L.knee.rotation.x = buckle * (1.1 + i * 0.3); L.hip.rotation.x = -buckle * (0.4 + i * 0.2); });
    this.hips.position.y = 0.88 - buckle * 0.32;
    this.pivot.rotation.x = -fall * 1.35;
    this.pivot.rotation.z = fall * this.deathTwist;
    this.spine.rotation.x = lerp(this.spine.rotation.x, 0.35, fall);
    this.headG.rotation.x = -fall * 0.35;
    this.onDeathPose?.(fall);
    if (t > 2.2) this.mats.forEach(m => m.opacity = Math.max(0, 3.2 - t));
    return t < 3.2;
  }
  damage(amount, head, weaponKey) {
    if (this.dead) return false;
    this.hp -= amount; this.hurtT = 0.08;
    this.flinch = 1; this.flinchSide = rand(-1, 1);
    this.onHurt?.();
    // bosses change phase at two thirds and one third of their health
    if (this.boss && this.hp > 0) {
      const ph = this.hp > this.maxHp * 0.66 ? 1 : this.hp > this.maxHp * 0.33 ? 2 : 3;
      if (ph > this.phase) { this.phase = ph; bossPhase(this); }
    }
    if (this.hp > 0) return false;
    this.hp = 0; this.dead = true;
    this.onDeath?.();
    if (this.boss) bossDefeated(this);
    kills++;
    if (head) headshots++;
    const pts = this.points[weaponKey === 'knife' || weaponKey === 'tknife' ? 2 : head ? 1 : 0];
    score += Math.round(pts * D.score); addCash(Math.round(pts * D.score * (perks.loot ? 1.3 : 1)));
    addKillfeed(this.name, head, weaponKey);
    spawnParticles(this.pos.clone().setY(1.2), this.sparkColor, 20, null, 5);
    spawnSmoke(this.pos.clone().setY(1.2), 0x555555, 1.4);
    this.hb.visible = false;
    if (Math.random() < this.dropChance) pickups.push(new Pickup('health', this.pos.x, this.pos.z, true));
    else if (Math.random() < 0.16) pickups.push(new Pickup('equip', this.pos.x, this.pos.z, true));
    return true;
  }
  remove() {
    scene.remove(this.group); scene.remove(this.hb);
    this.hbMat.dispose(); this.mats.forEach(m => m.dispose());
  }
  steerTo(tx, tz, dt) {
    this.repathT -= dt;
    if (walkLine(this.pos.x, this.pos.z, tx, tz, this.nav)) {
      this.path.length = 0;
    } else {
      if (this.repathT <= 0 || !this.path.length) { this.repathT = rand(0.5, 0.9); this.path = findPath(this.pos.x, this.pos.z, tx, tz, this.nav); }
      while (this.path.length && Math.hypot(this.path[0][0] - this.pos.x, this.path[0][1] - this.pos.z) < 0.5) this.path.shift();
      if (this.path.length) { tx = this.path[0][0]; tz = this.path[0][1]; }
    }
    const d = new V3(tx - this.pos.x, 0, tz - this.pos.z);
    return d.lengthSq() > 0.01 ? d.normalize() : d.set(0, 0, 0);
  }
  turnTo(yaw, dt, rate = 10) {
    let d = yaw - this.yaw;
    d = Math.atan2(Math.sin(d), Math.cos(d));
    this.yaw += d * Math.min(1, dt * rate);
  }
  moveAndCollide(move, speed, dt, radius, direct = false) {
    if (direct) {
      // climber going straight for you: scale any face in the way, then walk over the top
      const nx = this.pos.x + move.x * speed * dt, nz = this.pos.z + move.z * speed * dt;
      const ahead = groundAt(nx, nz, 99, radius);
      if (ahead > this.pos.y + 0.25) { this.climbing = true; this.pos.y = Math.min(ahead, this.pos.y + dt * 2.8); }
      else {
        this.climbing = false; this.pos.x = nx; this.pos.z = nz;
        const g = groundAt(this.pos.x, this.pos.z, 99, radius);
        this.pos.y = g > this.pos.y ? Math.min(g, this.pos.y + dt * 3.5) : Math.max(g, this.pos.y - dt * 7);
      }
      for (const o of enemies) {
        if (o === this || o.dead || Math.abs(o.pos.y - this.pos.y) > 1) continue;
        const dx = this.pos.x - o.pos.x, dz = this.pos.z - o.pos.z, d = Math.hypot(dx, dz);
        if (d < 0.8 && d > 1e-4) { this.pos.x += dx / d * (0.8 - d) * 0.5; this.pos.z += dz / d * (0.8 - d) * 0.5; }
      }
      this.pos.x = clamp(this.pos.x, -40 + radius, 40 - radius); this.pos.z = clamp(this.pos.z, -40 + radius, 40 - radius);
      return;
    }
    this.climbing = false;
    this.pos.addScaledVector(move, speed * dt);
    for (const o of enemies) {
      if (o === this || o.dead) continue;
      const dx = this.pos.x - o.pos.x, dz = this.pos.z - o.pos.z, d = Math.hypot(dx, dz);
      if (d < 0.85 && d > 1e-4) { this.pos.x += dx / d * (0.85 - d) * 0.5; this.pos.z += dz / d * (0.85 - d) * 0.5; }
    }
    if (this.nav === climbGrid) {
      // climb onto low obstacles, drop back down when stepping off
      collideCircle(this.pos, radius, 1.0, 1.9);
      const target = groundAt(this.pos.x, this.pos.z, 0.95, radius);
      this.pos.y = target > this.pos.y ? Math.min(target, this.pos.y + dt * 3.5) : Math.max(target, this.pos.y - dt * 7);
    } else collideCircle(this.pos, radius, 0, 1.9);
  }
  // flashbanged: stagger in place, no attacks
  stunnedUpdate(dt) {
    this.stunT -= dt;
    this.gait(dt, 0, { stride: 0.4, knee: 0.5, rate: 2, bob: 0.04, ref: 3 });
    const w = Math.min(1, this.stunT);
    this.spine.rotation.set(0.25 * w + Math.sin(now * 3.1) * 0.08, Math.sin(now * 2.3) * 0.3 * w, Math.sin(now * 4.2) * 0.16 * w);
    this.headG.rotation.set(0.3 * w, Math.sin(now * 5) * 0.4 * w, Math.sin(now * 3.7) * 0.25 * w);
    this.yaw += Math.sin(now * 1.7) * dt * 0.8;
    if (Math.random() < dt * 3) spawnParticles(this.pos.clone().setY(this.pos.y + this.barY - 0.2), 0xfff3a0, 2, new V3(0, 1, 0), 1.2);
    this.commonUpdate(dt, playerEye().distanceTo(this.pos));
    return true;
  }
  commonUpdate(dt, dist) {
    this.hurtT -= dt;
    this.flinch *= Math.exp(-dt * 8);
    const h = this.hurtT > 0 ? 0.8 : 0;
    this.flashMats.forEach(m => m.emissive.setScalar(h));
    this.group.position.copy(this.pos);
    this.group.rotation.y = this.yaw;
    // health bar
    if (this.lagHp < this.hp) this.lagHp = this.hp;
    this.lagHp = Math.max(this.hp, this.lagHp - this.maxHp * 0.7 * dt);
    const f = this.hp / this.maxHp, u = this.hbMat.uniforms;
    u.hp.value = f; u.lag.value = this.lagHp / this.maxHp;
    u.col.value.setHSL(f * 0.36, 0.85, 0.52);
    u.flash.value = Math.max(0, this.hurtT) * 10;
    const s = clamp(dist / 14, 1, 2.4) * 0.85;
    this.hb.scale.setScalar(s);
    this.hb.position.set(this.pos.x, this.pos.y + this.barY + (this.hips.position.y - 0.88) + (s - 0.85) * 0.1, this.pos.z);
    this.hb.quaternion.copy(camera.quaternion);
  }
}

// ---------------------------------------------------------------- bot (classic mode)
const BOT_NAMES = ['Alfa', 'Bravo', 'Charlie', 'Delta', 'Echo', 'Foxtrot', 'Golf', 'Hotel', 'India', 'Juliet', 'Kilo', 'Lima', 'Mike', 'November', 'Oscar', 'Papa', 'Romeo', 'Sierra', 'Tango', 'Victor'];
const botFlashMat = new THREE.SpriteMaterial({ map: flashTex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, toneMapped: false });
const BG = {
  thigh: new THREE.CapsuleGeometry(0.085, 0.26, 4, 12),
  shin: new THREE.CapsuleGeometry(0.095, 0.24, 4, 12),
  knee: new THREE.SphereGeometry(0.1, 16, 10),
  foot: rbox(0.18, 0.09, 0.3, 0.04),
  pelvis: rbox(0.42, 0.2, 0.26, 0.08),
  torso: rbox(0.5, 0.58, 0.32, 0.13),
  chest: rbox(0.54, 0.36, 0.14, 0.06),
  core: new THREE.CircleGeometry(0.06, 24),
  pack: rbox(0.38, 0.44, 0.18, 0.07),
  shoulder: new THREE.SphereGeometry(0.14, 20, 14),
  neck: new THREE.CylinderGeometry(0.06, 0.07, 0.12, 16),
  head: new THREE.SphereGeometry(0.19, 28, 18),
  visor: new THREE.CylinderGeometry(0.196, 0.196, 0.075, 28, 1, true, -0.95, 1.9),
  crest: rbox(0.06, 0.08, 0.3, 0.028),
  gun: rbox(0.09, 0.13, 0.55, 0.035),
  barrel: new THREE.CylinderGeometry(0.022, 0.022, 0.2, 12).rotateX(Math.PI / 2),
  antenna: new THREE.CylinderGeometry(0.01, 0.01, 0.4, 6),
  tip: new THREE.SphereGeometry(0.028, 10, 8),
};
// armoured combat android: baked worn paint (panel lines, rivets, scratches, hazard stripes, unit number)
function botArmorTex(base, accent, n) {
  return zTex(base, g => {
    for (let i = 0; i < 3000; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,255,255'},${Math.random() * 0.05})`; g.fillRect(rand(0, 256), rand(0, 256), 2, 2); }
    for (let i = 0; i < 8; i++) {
      const v = rand(12, 244) | 0, hz = Math.random() < 0.5;
      g.fillStyle = 'rgba(0,0,0,.5)'; hz ? g.fillRect(0, v, 256, 2) : g.fillRect(v, 0, 2, 256);
      g.fillStyle = 'rgba(255,255,255,.12)'; hz ? g.fillRect(0, v + 2, 256, 1) : g.fillRect(v + 2, 0, 1, 256);
    }
    for (let i = 0; i < 50; i++) {
      const x = rand(0, 256), y = rand(0, 256);
      g.fillStyle = 'rgba(0,0,0,.45)'; g.beginPath(); g.arc(x, y, 2.4, 0, 7); g.fill();
      g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.arc(x - 0.6, y - 0.6, 1, 0, 7); g.fill();
    }
    if (accent) {
      g.save(); g.beginPath(); g.rect(0, 190, 256, 30); g.clip();
      g.fillStyle = '#111'; g.fillRect(0, 190, 256, 30);
      g.fillStyle = accent;
      for (let x = -40; x < 300; x += 26) { g.beginPath(); g.moveTo(x, 190); g.lineTo(x + 13, 190); g.lineTo(x + 43, 220); g.lineTo(x + 30, 220); g.fill(); }
      g.restore();
    }
    g.font = '700 36px Rajdhani, Inter, sans-serif'; g.fillStyle = 'rgba(255,255,255,.6)'; g.fillText(n, 22, 62);
    g.lineCap = 'round';
    for (let i = 0; i < 80; i++) {
      const x = rand(0, 256), y = rand(0, 256), a = rand(0, 6.28), l = rand(3, 16);
      g.strokeStyle = `rgba(230,230,230,${rand(0.15, 0.4)})`; g.lineWidth = rand(0.5, 1.4);
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke();
    }
    for (let i = 0; i < 18; i++) {
      const x = rand(0, 256), y = rand(0, 256), r = rand(10, 40), gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, 'rgba(20,14,10,.3)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, 2 * r, 2 * r);
    }
  });
}
const BOTTEX = {
  armor: [['#b4412f', '#f2c230', 'B-07'], ['#a3362c', '#e8e8e8', 'B-21'], ['#bf5230', '#f2c230', 'B-34'], ['#96383a', '#e8e8e8', 'B-58']].map(a => botArmorTex(...a)),
  boss: botArmorTex('#3b3f4a', '#ff2a55', 'MK'),
  dark: botArmorTex('#2a2e36', null, ''),
};
const vents3 = mergeGeometries([0, -0.034, -0.068].map(y => rbox(0.12, 0.016, 0.02, 0.006).translate(0, y, 0)));
Object.assign(BG, {
  shin: rbox(0.17, 0.42, 0.19, 0.05),
  foot: rbox(0.2, 0.1, 0.34, 0.04),
  thighPlate: rbox(0.17, 0.26, 0.08, 0.035),
  piston: new THREE.CylinderGeometry(0.018, 0.018, 0.34, 8),
  hipPlate: rbox(0.08, 0.2, 0.24, 0.03),
  abs: rbox(0.34, 0.085, 0.22, 0.035),
  upper: rbox(0.5, 0.34, 0.3, 0.12),
  chestPlate: rbox(0.56, 0.32, 0.16, 0.07),
  collar: new THREE.TorusGeometry(0.12, 0.035, 8, 20),
  coreRing: new THREE.TorusGeometry(0.07, 0.014, 8, 24),
  vents: vents3,
  led: rbox(0.1, 0.018, 0.01, 0.005),
  pauldron: new THREE.SphereGeometry(0.17, 20, 12, 0, Math.PI * 2, 0, Math.PI * 0.55).scale(1.05, 0.9, 1.1),
  pauldronRim: new THREE.TorusGeometry(0.165, 0.02, 6, 24),
  helmet: rbox(0.3, 0.31, 0.33, 0.12),
  visorBar: rbox(0.25, 0.045, 0.03, 0.012),
  visorStem: rbox(0.045, 0.09, 0.03, 0.012),
  jawGuard: rbox(0.22, 0.09, 0.12, 0.03),
  earVent: new THREE.CylinderGeometry(0.05, 0.05, 0.04, 16).rotateZ(Math.PI / 2),
  fin: rbox(0.02, 0.12, 0.16, 0.008),
  packVent: rbox(0.26, 0.028, 0.02, 0.01),
  foreArmor: rbox(0.13, 0.11, 0.22, 0.035),
  hand: rbox(0.09, 0.09, 0.1, 0.03),
  receiver: rbox(0.09, 0.13, 0.4, 0.03),
  shroud: rbox(0.08, 0.08, 0.26, 0.02),
  barrel2: new THREE.CylinderGeometry(0.02, 0.024, 0.2, 12).rotateX(Math.PI / 2),
  mag: rbox(0.06, 0.17, 0.08, 0.02),
  scope: new THREE.CylinderGeometry(0.035, 0.035, 0.16, 14).rotateX(Math.PI / 2),
  lens: new THREE.CircleGeometry(0.03, 14),
  stock: rbox(0.07, 0.12, 0.18, 0.03),
});
const RIG_MUZZLE = new V3(0.22, 0.01, 1.03);
let botCounter = 0;

class Bot extends Enemy {
  constructor(x, z, wave, boss = 0, kind) {
    // snipers show up from wave 3, never more than two at a time
    if (boss) kind = null;
    else if (kind === undefined) kind = wave >= 3 && Math.random() < Math.min(0.22, wave * 0.03) && enemies.filter(e => e.kind === 'sniper' && !e.dead).length < 2 ? 'sniper' : null;
    super(x, z, Math.round((boss ? 1200 + 850 * (boss - 1) : kind === 'sniper' ? 70 : 100) * D.hp));
    this.kind = kind; this.aimT = 0;
    this.name = boss ? `COLOSSO Mk.${boss}` : (kind === 'sniper' ? 'Cecchino-' : 'Bot-') + BOT_NAMES[botCounter++ % BOT_NAMES.length];
    this.points = boss ? [1500 * boss, 1500 * boss, 1500 * boss] : kind === 'sniper' ? [150, 220, 260] : [100, 150, 200];
    this.boss = boss; this.dmgMul = boss ? 0.9 + boss * 0.2 : 1; this.rocketT = 3; this.barrageT = 4;
    this.sparkColor = 0xffaa33;
    this.dropChance = 0.18;
    this.barY = 2.3;
    this.accuracy = Math.min(0.85, (0.3 + wave * 0.04) * D.acc);
    this.reaction = Math.max(0.18, (0.85 - wave * 0.05) / D.acc);
    this.fireRate = Math.max(0.5, 1 - wave * 0.04) / D.acc;
    this.speed = Math.min(5, (3.2 + wave * 0.12) * D.speed);
    this.losT = Math.random() * 0.2; this.hasLOS = false;
    this.seenT = 0; this.fireCD = rand(0.6, 1.4); this.strafeDir = 1; this.strafeT = 0;
    this.flashT = 0; this.kick = 0;

    const armorMap = boss ? BOTTEX.boss : BOTTEX.armor[Math.floor(Math.random() * BOTTEX.armor.length)];
    const armor = this.mat({ map: armorMap, bumpMap: armorMap, bumpScale: 0.9, roughness: 0.36, metalness: boss ? 0.8 : 0.5 });
    const dark = this.mat({ map: BOTTEX.dark, bumpMap: BOTTEX.dark, bumpScale: 0.9, roughness: 0.42, metalness: 0.75 });
    const glow = this.mat({ color: 0x111111, emissive: boss ? 0xff1e5a : kind === 'sniper' ? 0x3aa8ff : 0xff4a10, emissiveIntensity: 4 * lightK(), side: THREE.DoubleSide });
    const chrome = this.mat({ color: 0xb8bec6, roughness: 0.2, metalness: 0.95 });
    this.glowMat = glow;
    this.flashMats = [armor, dark];
    const S = this.spine, H = this.headG;
    // legs: armoured shins and thigh plates, chrome knee pistons
    this.buildLegs(BG, dark, armor, dark, armor);
    this.legs.forEach(L => {
      this.add(BG.thighPlate, armor, 0, -0.2, 0.075, 'limb', L.hip);
      this.add(BG.piston, chrome, 0, -0.2, -0.105, null, L.knee);
    });
    this.add(BG.pelvis, dark, 0, 0.02, 0, 'body', S);
    for (const s of [-1, 1]) this.add(BG.hipPlate, armor, 0.24 * s, -0.03, 0, 'body', S).rotation.z = 0.18 * s;
    // segmented abdomen, armoured chest with vents and a glowing core
    [0.12, 0.2, 0.28].forEach((y, i) => this.add(BG.abs, dark, 0, y, 0, 'body', S).scale.set(1 - i * 0.04, 1, 1));
    this.add(BG.upper, dark, 0, 0.5, 0, 'body', S);
    this.add(BG.chestPlate, armor, 0, 0.5, 0.1, 'body', S);
    for (const s of [-1, 1]) {
      this.add(BG.vents, dark, 0.16 * s, 0.47, 0.182, null, S);
      this.add(BG.led, glow, 0.16 * s, 0.61, 0.182, null, S);
    }
    this.add(BG.core, glow, 0, 0.52, 0.184, null, S);
    this.add(BG.coreRing, chrome, 0, 0.52, 0.182, null, S);
    this.add(BG.collar, dark, 0, 0.68, 0, null, S).rotation.x = Math.PI / 2;
    // power pack
    this.add(BG.pack, dark, 0, 0.45, -0.22, 'body', S);
    for (const y of [0.52, 0.46, 0.4]) this.add(BG.packVent, glow, 0, y, -0.312, null, S);
    this.add(BG.antenna, dark, -0.12, 0.8, -0.26, null, S);
    this.add(BG.tip, glow, -0.12, 1.01, -0.26, null, S);
    for (const s of [-1, 1]) {
      this.add(BG.pauldron, armor, 0.34 * s, 0.6, 0, 'body', S).rotation.z = -0.3 * s;
      this.add(BG.pauldronRim, dark, 0.34 * s, 0.6, 0, null, S).rotation.set(Math.PI / 2, 0.3 * s, 0);
    }
    this.add(BG.neck, dark, 0, 0.72, 0, 'body', S);
    // helmet with a T-shaped visor
    H.position.set(0, 0.88, 0);
    this.add(BG.helmet, armor, 0, 0.02, 0, 'head', H);
    this.add(BG.jawGuard, dark, 0, -0.1, 0.075, 'head', H);
    this.add(BG.visorBar, glow, 0, 0.04, 0.162, null, H);
    this.add(BG.visorStem, glow, 0, -0.02, 0.162, null, H);
    for (const s of [-1, 1]) {
      this.add(BG.earVent, dark, 0.155 * s, 0, 0, null, H);
      this.add(BG.fin, dark, 0.1 * s, 0.18, -0.03, null, H).rotation.z = -0.25 * s;
    }
    // weapon rig (arms + rifle) pivots at the shoulders so it can aim and recoil
    this.rig = new THREE.Group(); this.rig.position.set(0, 0.4, 0); S.add(this.rig);
    for (const [a, b] of [[new V3(0.32, 0.1, 0.04), new V3(0.24, -0.02, 0.42)], [new V3(-0.32, 0.1, 0.04), new V3(0.12, -0.04, 0.62)]]) {
      const m = limb(this.rig, a, b, 0.065, dark);
      m.castShadow = true; m.userData = { enemy: this, part: 'limb' }; this.parts.push(m);
      const fa = this.add(BG.foreArmor, armor, 0, 0, 0, 'limb', this.rig);
      fa.position.copy(a).lerp(b, 0.62); fa.quaternion.copy(m.quaternion);
      this.add(BG.hand, dark, b.x, b.y - 0.02, b.z, null, this.rig);
    }
    this.add(BG.receiver, dark, 0.22, -0.02, 0.5, null, this.rig);
    this.add(BG.shroud, armor, 0.22, 0.005, 0.78, null, this.rig);
    this.add(BG.barrel2, chrome, 0.22, 0.01, 0.95, null, this.rig);
    this.add(BG.mag, dark, 0.22, -0.15, 0.5, null, this.rig).rotation.x = 0.2;
    this.add(BG.scope, dark, 0.22, 0.1, 0.48, null, this.rig);
    this.add(BG.lens, glow, 0.22, 0.1, 0.561, null, this.rig);
    this.add(BG.stock, dark, 0.22, -0.04, 0.23, null, this.rig);
    if (kind === 'sniper') {
      // pale armour, a long barrel with a big scope, and the laser that gives the shot away
      armor.color.set(0xa9c4ff);
      this.add(BG.barrel2, chrome, 0.22, 0.01, 1.2, null, this.rig);
      this.add(BG.scope, dark, 0.22, 0.12, 0.62, null, this.rig).scale.setScalar(1.5);
      this.laser = new THREE.Mesh(new THREE.CylinderGeometry(0.014, 0.014, 1, 6, 1, true).rotateX(Math.PI / 2),
        new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.08, 0.05).multiplyScalar(2.5), transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
      this.laser.visible = false; this.laser.frustumCulled = false; scene.add(this.laser);
      this.speed *= 0.85;
    }
    this.flash = new THREE.Sprite(botFlashMat);
    this.flash.position.copy(RIG_MUZZLE); this.flash.scale.setScalar(0.7); this.flash.visible = false;
    this.rig.add(this.flash);
    this.finish();
    spawnParticles(this.pos.clone().setY(1), 0xff6a3d, 14, null, 3);
    spawnSmoke(this.pos.clone().setY(0.6), 0x888888, 1.6);
  }
  onHurt() { this.seenT = Math.max(this.seenT, this.reaction * 0.5); }
  onDeathPose(fall) { this.rig.rotation.x = fall * 0.9; this.flash.visible = false; if (this.laser) this.laser.visible = false; }
  remove() { super.remove(); if (this.laser) { scene.remove(this.laser); this.laser.material.dispose(); } }
  onPhase() { this.glowMat.emissive.set(this.phase === 2 ? 0xffa020 : 0xffffff); }
  // sniper: one heavy round after the laser has been on you; moving (or breaking the line) is how you dodge it
  fireSniper(dist) {
    this.group.updateMatrixWorld();
    const muzzle = this.rig.localToWorld(RIG_MUZZLE.clone().setZ(1.3));
    const target = playerEye().add(new V3(0, -0.3, 0));
    const pSpeed = Math.hypot(player.vel.x, player.vel.z);
    const p = clamp((pSpeed > 6 ? 0.25 : pSpeed > 1 ? 0.55 : 0.92) - (player.onGround ? 0 : 0.12) + (D.acc - 1) * 0.15, 0.1, 0.95);
    let end = target;
    if (Math.random() < p) damagePlayer(38, this.pos);
    else {
      const dir = target.clone().add(new V3(rand(-0.9, 0.9), rand(-0.5, 0.7), rand(-0.9, 0.9))).sub(muzzle).normalize();
      losRay.set(muzzle, dir); losRay.far = 120;
      const h = losRay.intersectObjects(worldMeshes, false)[0];
      end = h ? h.point : muzzle.clone().addScaledVector(dir, 120);
      if (h) addDecal(h.point, h.face.normal.clone().transformDirection(h.object.matrixWorld));
    }
    spawnTracer(muzzle, end, 0xff4030);
    this.flashT = 0.08; this.kick = 1.6;
    sfxShot(SND.sniper, clamp(1.2 - dist / 80, 0.3, 0.9), panOf(this.pos), clamp(dist / 60, 0, 1));
  }

  fire(dist) {
    this.group.updateMatrixWorld();
    const muzzle = this.rig.localToWorld(RIG_MUZZLE.clone());
    const target = playerEye().add(new V3(0, -0.3, 0));
    const pSpeed = Math.hypot(player.vel.x, player.vel.z);
    const p = clamp(this.accuracy - dist * 0.007 - (pSpeed > 6 ? 0.14 : pSpeed > 1 ? 0.07 : 0) - (player.onGround ? 0 : 0.1) - player.crouchT * 0.07, 0.05, 0.9);
    let end;
    if (Math.random() < p) {
      end = target;
      damagePlayer(rand(6, 10) * this.dmgMul, this.pos);
    } else {
      const miss = target.clone().add(new V3(rand(-1.2, 1.2), rand(-0.8, 0.9), rand(-1.2, 1.2)));
      const dir = miss.sub(muzzle).normalize();
      losRay.set(muzzle, dir); losRay.far = 80;
      const h = losRay.intersectObjects(worldMeshes, false)[0];
      end = h ? h.point : muzzle.clone().addScaledVector(dir, 80);
      if (h) addDecal(h.point, h.face.normal.clone().transformDirection(h.object.matrixWorld));
    }
    spawnTracer(muzzle, end, 0xff7a40);
    this.flashT = 0.06; this.kick = 1;
    sfxShot(SND.bot, clamp(1.1 - dist / 60, 0.15, 0.75), panOf(this.pos), clamp(dist / 45, 0, 1));
  }

  update(dt) {
    if (this.dead) return this.animateDeath(dt);
    if (this.stunT > 0) { this.flashT = 0; this.flash.visible = false; this.hasLOS = false; this.seenT = 0; if (this.laser) { this.laser.visible = false; this.aimT = 0; } return this.stunnedUpdate(dt); }
    const eye = this.pos.clone().setY(1.75), pEye = playerEye();
    const toP = pEye.clone().sub(eye), dist = toP.length();
    this.losT -= dt;
    if (this.losT <= 0) { this.losT = 0.15; this.hasLOS = dist < 70 && lineOfSight(eye, pEye); }
    this.seenT = this.hasLOS ? this.seenT + dt : 0;

    let move, speed = this.speed, faceYaw;
    if (this.hasLOS) {
      faceYaw = Math.atan2(toP.x, toP.z);
      this.strafeT -= dt;
      if (this.strafeT <= 0) { this.strafeT = rand(0.7, 1.8); this.strafeDir = Math.random() < 0.5 ? -1 : 1; }
      if (this.kind === 'sniper') {
        // keeps its distance: closes in only when far away, backs off (strafing) when you rush it
        const flat = new V3(toP.x, 0, toP.z).normalize();
        if (dist > 46) move = this.steerTo(player.pos.x, player.pos.z, dt);
        else if (dist < 18) {
          move = flat.clone().negate().addScaledVector(new V3(flat.z, 0, -flat.x), this.strafeDir * 0.6).normalize();
          if (blockedAt(this.pos.x + move.x * 0.8, this.pos.z + move.z * 0.8)) move = new V3(flat.z, 0, -flat.x).multiplyScalar(this.strafeDir);
        } else move = new V3();
      } else if (dist > 22) move = this.steerTo(player.pos.x, player.pos.z, dt);
      else {
        const flat = new V3(toP.x, 0, toP.z).normalize();
        move = new V3(flat.z, 0, -flat.x).multiplyScalar(this.strafeDir)
          .addScaledVector(flat, dist > 12 ? 0.6 : dist < 6 ? -0.7 : 0).normalize();
        speed *= 0.55;
        if (blockedAt(this.pos.x + move.x * 0.8, this.pos.z + move.z * 0.8)) { this.strafeDir *= -1; this.strafeT = rand(0.7, 1.5); }
      }
      this.fireCD -= dt;
      if (this.kind === 'sniper') {
        // laser on for 1.5 s (it thickens as the shot gets close), then a long pause
        if (this.seenT > this.reaction) this.aimT += dt;
        if (this.aimT > 1.5) { this.fireSniper(dist); this.aimT = -rand(2.4, 3.6) * this.fireRate; }
        if (this.aimT > 0) {
          this.group.updateMatrixWorld();
          const a = this.rig.localToWorld(RIG_MUZZLE.clone().setZ(1.3)), b = pEye.clone().add(new V3(0, -0.3, 0)), L = this.laser;
          L.visible = true; L.position.copy(a).lerp(b, 0.5); L.lookAt(b);
          const k = this.aimT / 1.5; L.scale.set(1 + k * 1.6, 1 + k * 1.6, a.distanceTo(b));
          L.material.opacity = (0.35 + 0.5 * k) * (k > 0.75 ? 0.6 + 0.4 * Math.sin(now * 50) : 1);
        } else this.laser.visible = false;
      } else if (this.seenT > this.reaction && this.fireCD <= 0) {
        this.fire(dist);
        this.fireCD = rand(0.4, 0.9) * this.fireRate * (this.boss ? 0.8 / (1 + 0.3 * (this.phase - 1)) : 1);
      }
      // boss: rocket volleys you have to dodge
      if (this.boss && this.seenT > this.reaction && (this.rocketT -= dt) <= 0) {
        this.rocketT = Math.max(2, 4.6 - this.boss * 0.4);
        this.group.updateMatrixWorld();
        const m = this.rig.localToWorld(RIG_MUZZLE.clone());
        // one rocket per phase, fanned out
        const aim = playerEye().add(new V3(0, -0.5, 0)).sub(m).normalize();
        for (let i = 0; i < this.phase; i++) launchProjectile('erocket', m, aim.clone().applyAxisAngle(_yAxis, (i - (this.phase - 1) / 2) * 0.14).multiplyScalar(19 + this.boss));
        sfxRocketLaunch();
      }
    } else {
      move = this.steerTo(player.pos.x, player.pos.z, dt);
      this.fireCD = Math.max(this.fireCD, 0.3);
      if (this.laser) { this.laser.visible = false; this.aimT = Math.min(this.aimT, 0); }
    }
    // boss, from phase 2: mortar barrage on your position (even behind cover) — get out of the red circles
    if (this.boss && this.phase >= 2 && (this.barrageT -= dt) <= 0) {
      this.barrageT = this.phase === 3 ? 5 : 7.5;
      const n = 3 + this.phase;
      for (let i = 0; i < n; i++) {
        const a = rand(0, 6.28), r = i ? rand(2.5, 7) : 0;
        const hp = new V3(clamp(player.pos.x + Math.cos(a) * r, -38, 38), groundAt(player.pos.x, player.pos.z, player.pos.y, 0.4), clamp(player.pos.z + Math.sin(a) * r, -38, 38));
        addHazard(hp, 3.2, 1.2 + i * 0.16, () => enemyBlast(hp.clone().setY(hp.y + 0.4)));
      }
      withCat('enemies', () => { sfxTone(90, 0.5, 0.3, 'sawtooth', 40); sfxTone(1400, 0.9, 0.05, 'sine', 500, 0.2); });
    }
    if (this.boss && this.phase === 3) speed *= 1.15;
    if (faceYaw === undefined && move.lengthSq() > 0) faceYaw = Math.atan2(move.x, move.z);
    if (faceYaw !== undefined) this.turnTo(faceYaw, dt);
    this.moveAndCollide(move, speed, dt, this.boss ? 0.6 : 0.42);

    // animation
    const amt = this.gait(dt, move.lengthSq() > 0 ? speed : 0, { stride: 0.55, knee: 0.85, rate: 2.5, bob: 0.05, ref: 3.2 });
    this.kick *= Math.exp(-dt * 14);
    const aimPitch = this.hasLOS ? Math.asin(clamp(toP.y / dist, -0.6, 0.6)) : 0;
    this.spine.rotation.set(0.06 * amt - this.flinch * 0.35 + Math.sin(now * 2 + this.walk) * 0.012, Math.sin(this.walk) * 0.1 * amt, this.flinchSide * this.flinch * 0.2);
    this.headG.rotation.x = -aimPitch * 0.5;
    // scanning head while searching, pulsing core and visor (with the odd glitch)
    this.headG.rotation.y = this.hasLOS ? 0 : Math.sin(now * 1.3 + this.walk) * 0.45;
    this.glowMat.emissiveIntensity = (3.6 + Math.sin(now * 7 + this.walk) * 0.7) * lightK() * (Math.random() < 0.012 ? 0.15 : 1);
    this.rig.rotation.x = -aimPitch * 0.9 - this.kick * 0.22;
    this.rig.position.z = -this.kick * 0.07;
    this.flashT -= dt; this.flash.visible = this.flashT > 0;
    this.commonUpdate(dt, dist);
    return true;
  }
}

// ---------------------------------------------------------------- zombie (zombie mode)
const ZG = {
  thigh: new THREE.CapsuleGeometry(0.075, 0.27, 4, 10),
  shin: new THREE.CapsuleGeometry(0.068, 0.27, 4, 10),
  foot: rbox(0.15, 0.08, 0.27, 0.035),
  pelvis: rbox(0.38, 0.18, 0.24, 0.07),
  torso: rbox(0.44, 0.52, 0.26, 0.1),
  rib: rbox(0.2, 0.14, 0.05, 0.02),
  neck: new THREE.CylinderGeometry(0.055, 0.065, 0.14, 12),
  head: new THREE.SphereGeometry(0.165, 24, 16),
  jaw: rbox(0.2, 0.08, 0.17, 0.035),
  eye: new THREE.SphereGeometry(0.026, 10, 8),
  upper: new THREE.CapsuleGeometry(0.058, 0.2, 4, 10),
  fore: new THREE.CapsuleGeometry(0.05, 0.19, 4, 10),
  hand: new THREE.SphereGeometry(0.06, 12, 8),
};
const SHIRTS = [0x5b4a3a, 0x3d4a5c, 0x6a3b3b, 0x4a5a3a, 0x5c5c62];
// ---------------------------------------------------------------- zombie look: baked rotting skin, torn bloody clothes, gore details
function zTex(base, draw) { const [c, g] = canvas(256); g.fillStyle = base; g.fillRect(0, 0, 256, 256); draw(g); return finishTex(c); }
function splat(g, x, y, r, col) {
  g.fillStyle = col;
  g.beginPath(); g.arc(x, y, r, 0, 7); g.fill();
  for (let i = 0; i < 9; i++) { const a = rand(0, 6.28), d = rand(r * 0.8, r * 2.4); g.beginPath(); g.arc(x + Math.cos(a) * d, y + Math.sin(a) * d, rand(r * 0.1, r * 0.35), 0, 7); g.fill(); }
  for (let i = 0; i < 3; i++) g.fillRect(x + rand(-r, r), y, rand(1.5, 3), rand(r, r * 4)); // drips
}
function skinTex(base) {
  return zTex(base, g => {
    for (let i = 0; i < 70; i++) {
      const x = rand(0, 256), y = rand(0, 256), r = rand(8, 40), gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, Math.random() < 0.5 ? 'rgba(30,18,38,.4)' : Math.random() < 0.5 ? 'rgba(120,130,40,.25)' : 'rgba(255,240,220,.12)');
      gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, 2 * r, 2 * r);
    }
    g.lineCap = 'round';
    for (let i = 0; i < 34; i++) { // dark veins
      let x = rand(0, 256), y = rand(0, 256), a = rand(0, 6.28);
      g.strokeStyle = `rgba(${rand(40, 70) | 0},16,${rand(50, 85) | 0},${rand(0.3, 0.6)})`; g.lineWidth = rand(0.6, 1.8);
      g.beginPath(); g.moveTo(x, y);
      for (let k = 0; k < 12; k++) { a += rand(-0.6, 0.6); x += Math.cos(a) * 6; y += Math.sin(a) * 6; g.lineTo(x, y); }
      g.stroke();
    }
    for (let i = 0; i < 12; i++) { // rotting sores
      const x = rand(0, 256), y = rand(0, 256), r = rand(4, 13);
      g.fillStyle = 'rgba(40,22,12,.75)'; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill();
      g.strokeStyle = 'rgba(160,130,60,.35)'; g.lineWidth = 2; g.stroke();
    }
    for (let i = 0; i < 9; i++) splat(g, rand(0, 256), rand(0, 256), rand(3, 9), 'rgba(95,6,6,.82)');
    for (let i = 0; i < 5000; i++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.09})`; g.fillRect(rand(0, 256), rand(0, 256), 1.5, 1.5); }
  });
}
function clothTex(base) {
  return zTex(base, g => {
    for (let x = 0; x < 256; x += 2) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.09})`; g.fillRect(x, 0, 1, 256); }
    const gr = g.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(30,20,10,.6)');
    g.fillStyle = gr; g.fillRect(0, 0, 256, 256);
    for (let i = 0; i < 40; i++) { g.fillStyle = `rgba(60,45,30,${rand(0.1, 0.3)})`; g.beginPath(); g.arc(rand(0, 256), rand(0, 256), rand(3, 14), 0, 7); g.fill(); }
    // soaked-in blood: large irregular stains that run downwards, a little fine spatter
    for (let i = 0; i < 3; i++) {
      const x = rand(30, 226), y = rand(20, 150), r = rand(30, 60);
      for (let k = 0; k < 14; k++) {
        const bx = x + rand(-r, r) * 0.7, by = y + rand(-r, r) * 0.5, br = rand(r * 0.25, r * 0.6), gr = g.createRadialGradient(bx, by, 0, bx, by, br);
        gr.addColorStop(0, 'rgba(78,4,4,.75)'); gr.addColorStop(0.7, 'rgba(60,4,4,.45)'); gr.addColorStop(1, 'rgba(40,5,5,0)');
        g.fillStyle = gr; g.fillRect(bx - br, by - br, 2 * br, 2 * br);
      }
      g.fillStyle = 'rgba(70,4,4,.7)';
      for (let k = 0; k < 6; k++) { const dx = x + rand(-r, r) * 0.6; g.fillRect(dx, y, rand(2, 5), rand(r * 0.8, r * 2.4)); }
    }
    g.fillStyle = 'rgba(90,6,6,.8)';
    for (let i = 0; i < 40; i++) { g.beginPath(); g.arc(rand(0, 256), rand(0, 200), rand(0.6, 2.2), 0, 7); g.fill(); }
    for (let i = 0; i < 8; i++) { // tears
      const x = rand(0, 256), y = rand(0, 256);
      g.fillStyle = 'rgba(12,8,6,.95)'; g.beginPath(); g.moveTo(x, y);
      for (let k = 0; k < 7; k++) g.lineTo(x + rand(-16, 16), y + rand(-12, 12));
      g.fill();
    }
  });
}
const ZTEX = {
  skin: ['#6c775d', '#5f6951', '#77796a'].map(skinTex),
  climber: skinTex('#5f6674'),
  boss: skinTex('#6e3830'),
  shirts: SHIRTS.map(c => clothTex('#' + new THREE.Color(c).multiplyScalar(1.05).getHexString())),
  pants: clothTex('#3a3f4e'),
};
function teethGeo(n, w, h) {
  const sh = new THREE.Shape(); sh.moveTo(-w / 2, 0);
  for (let i = 0; i < n; i++) { const x0 = -w / 2 + i * w / n; sh.lineTo(x0 + w / n / 2, -h * (0.65 + (i % 3) * 0.17)); sh.lineTo(x0 + w / n, 0); }
  sh.lineTo(w / 2, 0.012); sh.lineTo(-w / 2, 0.012);
  return new THREE.ExtrudeGeometry(sh, { depth: 0.012, bevelEnabled: false }).translate(0, 0, -0.006);
}
const mergeAt = (geo, pts) => mergeGeometries(pts.map(([x, y, z, rx = 0, ry = 0, rz = 0]) => geo.clone().rotateX(rx).rotateY(ry).rotateZ(rz).translate(x, y, z)));
Object.assign(ZG, {
  skull: new THREE.SphereGeometry(0.165, 28, 20),
  skullCap: new THREE.SphereGeometry(0.169, 16, 10, 0, 1.5, 0, 1.15),
  brow: rbox(0.25, 0.05, 0.09, 0.022),
  sockets: mergeAt(new THREE.SphereGeometry(0.046, 14, 10).scale(1, 0.85, 0.55), [[-0.062, 0, 0], [0.062, 0, 0]]),
  pupils: mergeAt(new THREE.SphereGeometry(0.016, 10, 8), [[-0.062, 0, 0], [0.062, 0, 0]]),
  nose: new THREE.ConeGeometry(0.024, 0.045, 3).rotateX(Math.PI),
  mouth: new THREE.SphereGeometry(0.06, 14, 10).scale(1.15, 0.62, 0.5),
  teethUp: teethGeo(7, 0.1, 0.028),
  teethLow: teethGeo(6, 0.09, 0.024).rotateZ(Math.PI),
  jaw2: rbox(0.15, 0.045, 0.13, 0.02),
  hair: mergeAt(new THREE.ConeGeometry(0.018, 0.14, 5), [[-0.07, 0.12, -0.06, -0.6, 0, 0.5], [0.02, 0.15, -0.08, -0.9, 0, -0.2], [0.09, 0.1, -0.09, -1.1, 0, -0.6], [-0.1, 0.05, -0.1, -1.3, 0, 0.9], [0.05, 0.06, -0.14, -1.5, 0, -0.3], [-0.03, 0.02, -0.15, -1.7, 0, 0.2]]),
  claws: mergeAt(new THREE.ConeGeometry(0.011, 0.09, 6).rotateX(Math.PI), [[-0.036, -0.07, 0.02, 0.25], [-0.012, -0.08, 0.03, 0.2], [0.012, -0.08, 0.03, 0.2], [0.036, -0.07, 0.02, 0.25], [0.05, -0.02, 0.03, 0.6, 0, 0.7]]),
  ribs: mergeAt(new THREE.CapsuleGeometry(0.012, 0.13, 3, 6).rotateZ(Math.PI / 2), [[0, 0.045, 0, 0, 0, -0.12], [0, 0, 0, 0, 0, -0.08], [0, -0.045, 0, 0, 0, -0.04]]),
  wound: new THREE.CircleGeometry(0.105, 20).scale(0.85, 1, 1),
  hem: mergeAt(new THREE.BoxGeometry(0.04, 0.1, 0.012), [[-0.15, -0.02, 0, 0, 0, 0.2], [0.02, -0.035, 0, 0, 0, -0.12], [0.16, -0.015, 0, 0, 0, 0.25]]),
  bone: new THREE.CapsuleGeometry(0.026, 0.2, 4, 8),
  fleshRing: new THREE.TorusGeometry(0.048, 0.022, 6, 14),
  handZ: new THREE.SphereGeometry(0.06, 12, 8).scale(1, 0.8, 1.25),
});

class Zombie extends Enemy {
  constructor(x, z, wave, boss = 0, kind) {
    // special breeds join in as the waves go on: spitters (ranged), bombers (explode) and armoured ones
    if (boss) kind = null;
    else if (kind === undefined) {
      kind = null;
      let r = Math.random();
      for (const [k, from, p] of [['spitter', 2, Math.min(0.18, 0.05 + wave * 0.015)], ['bomber', 3, Math.min(0.16, 0.03 + wave * 0.015)], ['armored', 4, Math.min(0.18, wave * 0.02)]]) {
        if (wave < from) continue;
        if (r < p) { kind = k; break; }
        r -= p;
      }
    }
    // climbers scale walls and crates: more of them on harder difficulties and later waves
    const climber = !!boss || (!kind && Math.random() < Math.min(0.7, (D.climb ?? 0.16) + wave * 0.012));
    const runner = !kind && !climber && Math.random() < Math.min(0.45, 0.06 + wave * 0.05);
    const baseHp = kind === 'armored' ? 190 : kind === 'bomber' ? 60 : kind === 'spitter' ? 85 : climber ? 110 : runner ? 70 : 100;
    super(x, z, Math.round((boss ? 1800 + 1100 * (boss - 1) : baseHp * (1 + (wave - 1) * 0.06)) * D.hp));
    this.kind = kind; this.fuseT = 0; this.spitCD = rand(1, 2.5); this.spitT = 0; this.losT = 0; this.hasLOS = false;
    this.slamT = 0; this.slamCD = 3; this.volleyCD = 3;
    this.runner = runner; this.climber = climber; this.climbing = false;
    this.boss = boss; this.reach = boss ? 2.3 : 1.3; this.chargeT = 5; this.charging = 0;
    this.name = boss ? `ABOMINIO Lv.${boss}` : kind ? { bomber: 'Zombie esplosivo', armored: 'Zombie corazzato', spitter: 'Zombie sputatore' }[kind] : climber ? 'Zombie arrampicatore' : runner ? 'Zombie corridore' : 'Zombie';
    this.points = boss ? [1200 * boss, 1200 * boss, 1200 * boss] : kind === 'armored' ? [110, 150, 200] : kind ? [80, 110, 150] : [60, 90, 120];
    this.sparkColor = 0xb8ff5a;
    this.dropChance = 0.1;
    this.barY = 2.05;
    this.speed = (runner ? Math.min(6.2, 5 + wave * 0.06) : climber ? Math.min(4, 2.7 + wave * 0.09) : Math.min(3.6, 2.1 + wave * 0.1)) * D.speed;
    this.hitDmg = boss ? 26 + 8 * boss : kind === 'armored' ? 20 : runner ? 9 : 14;
    if (boss) this.speed = Math.min(4.2, 2.9 + boss * 0.2) * D.speed;
    if (kind) this.speed = (kind === 'bomber' ? Math.min(5, 3.6 + wave * 0.08) : kind === 'armored' ? Math.min(2.6, 1.7 + wave * 0.06) : Math.min(3.4, 2.4 + wave * 0.08)) * D.speed;
    this.attackT = 0; this.attackCD = 0; this.hitDone = false;
    this.groanT = rand(1, 6);
    this.limp = runner ? 1 : rand(0.55, 1);
    this.nav = climbGrid;
    this.headTilt = rand(-0.3, 0.3);

    const skinMap = boss ? ZTEX.boss : climber ? ZTEX.climber : ZTEX.skin[Math.floor(Math.random() * ZTEX.skin.length)];
    const skin = this.mat({ map: skinMap, bumpMap: skinMap, bumpScale: 1.5, roughness: 0.86, metalness: 0 });
    const skinDark = this.mat({ color: 0x2a2620, roughness: 0.9 });
    const shirt = this.mat({ map: ZTEX.shirts[Math.floor(Math.random() * SHIRTS.length)], roughness: 0.95 });
    const pants = this.mat({ map: ZTEX.pants, roughness: 0.95 });
    const eyes = this.mat({ color: 0x111111, emissive: boss ? 0xff1e2a : kind === 'bomber' ? 0xff7a1a : kind === 'spitter' ? 0x7dff3a : kind === 'armored' ? 0x6cd4ff : climber ? 0x9a6bff : runner ? 0xff3010 : 0xffd040, emissiveIntensity: 5 * lightK() });
    const hole = this.mat({ color: 0x0c0505, roughness: 1 });
    const gore = this.mat({ color: 0x4a0707, roughness: 0.22, metalness: 0.1 });
    const bone = this.mat({ color: 0x9c9072, roughness: 0.75 });
    const nail = this.mat({ color: 0x2a2218, roughness: 0.4 });
    this.eyesMat = eyes;
    this.flashMats = [skin, shirt, pants];
    const S = this.spine, H = this.headG;
    this.buildLegs(ZG, pants, pants, skinDark, null);
    this.add(ZG.pelvis, pants, 0, 0.02, 0, 'body', S);
    this.add(ZG.torso, shirt, 0, 0.33, 0, 'body', S);
    if (Math.random() < 0.7) this.add(ZG.hem, shirt, rand(-0.04, 0.04), 0.09, 0.128, null, S); // torn rags
    // open chest wound with ribs showing
    if (Math.random() < 0.65 || boss) {
      const wx = rand(-0.1, 0.1), wy = rand(0.3, 0.42);
      this.add(ZG.wound, gore, wx, wy, 0.132, null, S);
      this.add(ZG.ribs, bone, wx, wy, 0.136, null, S);
    }
    this.add(ZG.neck, skin, 0, 0.65, 0.02, 'body', S);
    // head: sunken glowing eyes, heavy brow, hanging jaw full of teeth
    H.position.set(0, 0.8, 0.04);
    this.add(ZG.skull, skin, 0, 0.02, 0, 'head', H).scale.set(0.92, 1.12, 1.02);
    this.add(ZG.brow, skin, 0, 0.078, 0.113, 'head', H).rotation.x = -0.15;
    this.add(ZG.sockets, hole, 0, 0.032, 0.13, null, H);
    this.add(ZG.pupils, eyes, 0, 0.03, 0.146, null, H);
    this.add(ZG.nose, hole, 0, -0.012, 0.158, null, H).scale.set(1, 1, 0.5);
    this.add(ZG.mouth, hole, 0, -0.078, 0.128, null, H);
    this.add(ZG.teethUp, bone, 0, -0.058, 0.152, null, H);
    if (Math.random() < 0.45) this.add(ZG.skullCap, bone, 0, 0.02, 0, null, H).rotation.set(rand(-0.3, 0.3), rand(0, 6.28), 0);
    if (Math.random() < 0.6) this.add(ZG.hair, skinDark, 0, 0.02, 0, null, H);
    this.jaw = new THREE.Group(); this.jaw.position.set(0, -0.07, 0.02); H.add(this.jaw);
    this.add(ZG.jaw2, skin, 0, -0.035, 0.06, 'head', this.jaw);
    this.add(ZG.teethLow, bone, 0, -0.012, 0.118, null, this.jaw);
    this.tw = new V3(); this.twK = 0; this.twitchT = rand(0.5, 3);
    this.arms = [-1, 1].map(s => {
      const sh = new THREE.Group(); sh.position.set(0.27 * s, 0.56, 0); S.add(sh);
      if (climber) sh.scale.set(1, 1.22, 1); // long clawing arms
      this.add(ZG.upper, shirt, 0, -0.16, 0, 'limb', sh);
      const el = new THREE.Group(); el.position.y = -0.32; sh.add(el);
      if (Math.random() < 0.3) {
        // flesh torn off the forearm: bare bone
        this.add(ZG.bone, bone, 0, -0.15, 0, 'limb', el);
        this.add(ZG.fleshRing, gore, 0, -0.05, 0, null, el).rotation.x = Math.PI / 2;
        this.add(ZG.fleshRing, gore, 0, -0.25, 0, null, el).rotation.x = Math.PI / 2;
      } else this.add(ZG.fore, skin, 0, -0.15, 0, 'limb', el);
      this.add(ZG.handZ, skin, 0, -0.3, 0.01, 'limb', el);
      this.add(ZG.claws, nail, 0, -0.3, 0.01, null, el);
      return { sh, el, s };
    });
    if (boss) this.spine.scale.set(1.3, 1.05, 1.3); // hulking torso
    if (kind === 'bomber') {
      // bloated body covered in glowing pustules
      this.spine.scale.set(1.35, 1.08, 1.5);
      this.pusMat = this.mat({ color: 0x331000, emissive: 0xff7a1a, emissiveIntensity: 3 });
      for (const [px, py, pz, r] of [[0.1, 0.5, 0.15, 0.1], [-0.13, 0.36, 0.16, 0.08], [0.02, 0.24, 0.17, 0.07], [0.17, 0.3, 0.05, 0.07], [-0.1, 0.56, -0.14, 0.09], [0.12, 0.34, -0.15, 0.08], [-0.2, 0.5, 0.02, 0.07]])
        this.add(new THREE.SphereGeometry(r, 10, 8), this.pusMat, px, py, pz, 'body', S);
    } else if (kind === 'armored') {
      // riot gear: vest, shoulder pads and a helmet with a visor
      const plate = this.mat({ color: 0x1c2330, roughness: 0.4, metalness: 0.7 }), visor = this.mat({ color: 0x0a0f16, roughness: 0.1, metalness: 0.9 });
      this.add(rbox(0.5, 0.5, 0.34, 0.08), plate, 0, 0.42, 0, 'body', S);
      for (const sd of [-1, 1]) this.add(rbox(0.2, 0.12, 0.26, 0.05), plate, 0.3 * sd, 0.63, 0, 'body', S);
      this.add(new THREE.SphereGeometry(0.2, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.6), plate, 0, 0.02, 0, 'head', H);
      this.add(rbox(0.3, 0.12, 0.05, 0.02), visor, 0, 0.0, 0.165, 'head', H);
    } else if (kind === 'spitter') {
      // sickly green skin and a glowing acid sac under the jaw
      skin.color.set(0xa8d890);
      this.sacMat = this.mat({ color: 0x0a2a08, emissive: 0x7dff3a, emissiveIntensity: 2.5 });
      this.add(new THREE.SphereGeometry(0.11, 12, 10), this.sacMat, 0, 0.72, 0.11, 'body', S);
      this.add(new THREE.SphereGeometry(0.07, 10, 8), this.sacMat, 0.1, 0.5, 0.15, null, S);
      this.add(new THREE.SphereGeometry(0.06, 10, 8), this.sacMat, -0.12, 0.42, 0.15, null, S);
    }
    this.finish();
    spawnParticles(this.pos.clone().setY(0.3), 0x6a5a40, 16, new V3(0, 1, 0), 3, false);
    spawnSmoke(this.pos.clone().setY(0.4), 0x4a4038, 1.8);
  }
  onDeath() {
    const d = playerEye().distanceTo(this.pos); if (d < 30) sfxGroan(clamp(1.1 - d / 30, 0.15, 0.9), panOf(this.pos), 'death');
    if (this.kind === 'bomber') this.blow();
  }
  // armour shrugs off bullets (explosions and blades go through)
  damage(amount, head, weaponKey) {
    if (this.kind === 'armored' && !this.dead && !['frag', 'rocket', 'raygun', 'knife', 'tknife'].includes(weaponKey)) {
      amount *= head ? 0.6 : 0.35;
      if (Math.random() < 0.5) sfxTone(rand(1800, 2400), 0.04, 0.05, 'square', 900);
    }
    return super.damage(amount, head, weaponKey);
  }
  // bomber: blast that hurts you and every zombie around (chain reactions welcome)
  blow() {
    if (this.blown) return;
    this.blown = true;
    const p = this.pos.clone().setY(this.pos.y + 1);
    explode(p, { radius: 4.5, dmg: 150, key: 'frag', color: 0xff8a2a, skip: this });
    const body = player.pos.clone().setY(player.pos.y + 0.9), pd = body.distanceTo(p);
    if (pd < 4.5 && worldClear(p, body)) damagePlayer(38 * (1 - pd / 4.5 * 0.7), p);
  }
  onPhase() { this.eyesMat.emissive.set(this.phase === 2 ? 0xff7a1a : 0xffffff); this.speed *= 1.12; }
  // boss slam: a shockwave along the ground — be in the air when it lands
  slam() {
    const p = this.pos.clone().setY(this.pos.y + 0.12), R = 8.5;
    addWave(p, R, 0.45);
    spawnParticles(p, 0x8a7a60, 40, new V3(0, 1, 0), 8, false);
    for (let i = 0; i < 8; i++) spawnSmoke(p.clone().add(new V3(Math.cos(i * 0.785) * 2.5, 0.3, Math.sin(i * 0.785) * 2.5)), 0x5a5048, 2.4);
    const d = Math.hypot(player.pos.x - this.pos.x, player.pos.z - this.pos.z);
    sfxBoom(clamp(1.2 - d / 40, 0.3, 1.1), panOf(this.pos), clamp(d / 40, 0, 1));
    player.shake = Math.max(player.shake, clamp(1.2 - d / 16, 0, 1));
    if (d < R && player.onGround && Math.abs(player.pos.y - this.pos.y) < 1.2) {
      damagePlayer(22 + 6 * this.boss, this.pos);
      player.vel.add(new V3(player.pos.x - this.pos.x, 0, player.pos.z - this.pos.z).normalize().multiplyScalar(7)).setY(6); player.onGround = false;
    }
  }
  spit(spread = 0) {
    const k = this.group.scale.y;
    const m = this.pos.clone().setY(this.pos.y + 1.55 * k).add(new V3(Math.sin(this.yaw), 0, Math.cos(this.yaw)).multiplyScalar(0.3 * k));
    const d = playerEye().add(new V3(0, -0.4, 0)).sub(m), T = Math.max(0.25, Math.hypot(d.x, d.z) / 17);
    // lobbed with a little lead: keep moving and it lands behind you
    launchProjectile('acid', m, new V3((d.x + player.vel.x * T * 0.6) / T, d.y / T + 4.5 * T, (d.z + player.vel.z * T * 0.6) / T).applyAxisAngle(_yAxis, spread));
    const dist = playerEye().distanceTo(m);
    sfxSwoosh(clamp(0.5 - dist / 60, 0.08, 0.4)); sfxGroan(clamp(0.8 - dist / 40, 0.1, 0.6), panOf(this.pos), 'attack');
  }
  onDeathPose(fall) { this.arms.forEach(a => { a.sh.rotation.x = lerp(a.sh.rotation.x, -2.6, fall); a.el.rotation.x = -0.2; }); }

  update(dt) {
    if (this.dead) return this.animateDeath(dt);
    if (this.stunT > 0) { this.attackT = 0; return this.stunnedUpdate(dt); }
    const dx = player.pos.x - this.pos.x, dz = player.pos.z - this.pos.z;
    const dh = Math.hypot(dx, dz), dist = playerEye().distanceTo(this.pos.clone().setY(this.pos.y + 1.6));
    // swipes reach your legs on a low crate; anything higher needs a climber
    const dy = player.pos.y - this.pos.y, reachable = dy > -1.1 && dy < (this.boss ? 2.6 : 1.65);
    const direct = this.climber && (player.pos.y > 1.3 || this.pos.y > 1.3) && dh < 16;
    this.attackCD -= dt;
    let move = new V3(), speed = this.speed, hold = false;
    if (this.kind === 'bomber') {
      // lights its fuse next to you, then goes off (no kill reward for letting it)
      this.attackCD = 9;
      if (this.fuseT <= 0 && dh < 2 && Math.abs(dy) < 2.2) { this.fuseT = 0.55; sfxTone(900, 0.5, 0.12, 'square', 2400); }
      if (this.fuseT > 0 && (this.fuseT -= dt) <= 0) { this.blow(); this.hp = 0; this.dead = true; this.hb.visible = false; return this.animateDeath(dt); }
      this.pusMat.emissiveIntensity = (2.6 + Math.sin(now * (this.fuseT > 0 ? 40 : 5) + this.walk) * 1.6) * lightK() * (this.fuseT > 0 ? 2 : 1);
    } else if (this.kind === 'spitter') {
      // stops at range with a clear view and lobs acid; still claws if you walk up to it
      if ((this.losT -= dt) <= 0) { this.losT = 0.25; this.hasLOS = dh < 26 && lineOfSight(this.pos.clone().setY(this.pos.y + 1.55), playerEye()); }
      this.spitCD -= dt;
      if (this.hasLOS && dh > 6 && dh < 24) {
        hold = true;
        if (this.spitCD <= 0 && this.attackT <= 0 && this.spitT <= 0) { this.spitCD = rand(2.2, 3.4); this.spitT = 0.45; }
      }
      if (this.spitT > 0 && (this.spitT -= dt) <= 0) this.spit();
      this.sacMat.emissiveIntensity = (2.2 + Math.sin(now * 4 + this.walk) * 0.8 + (this.spitT > 0 ? 4 : 0)) * lightK();
    }
    if (this.attackT > 0) {
      this.attackT += dt;
      const p = this.attackT / 0.7;
      if (!this.hitDone && p > 0.55) {
        this.hitDone = true;
        if (dh < this.reach + 0.45 && reachable) {
          damagePlayer(this.hitDmg, this.pos);
          if (this.boss) { player.vel.add(new V3(dx, 0, dz).normalize().multiplyScalar(9)).setY(5); player.onGround = false; player.shake = 1; }
          sfxBite(0.9);
        } else sfxSwoosh(0.25);
      }
      if (p >= 1) { this.attackT = 0; this.attackCD = rand(0.35, 0.8); }
      if (dh > 0.9) move.set(dx, 0, dz).normalize().multiplyScalar(0.35);
    } else if (dh < this.reach && reachable && this.attackCD <= 0) {
      this.attackT = 0.0001; this.hitDone = false;
      sfxGroan(0.75, panOf(this.pos), 'attack');
    } else if (!hold && (dh > this.reach * 0.73 || (direct && !reachable && dh > 0.05))) {
      move = direct ? new V3(dx, 0, dz).normalize() : this.steerTo(player.pos.x, player.pos.z, dt);
    }
    // boss: roars and charges when you keep your distance
    if (this.boss) {
      this.charging = Math.max(0, this.charging - dt);
      if ((this.chargeT -= dt) <= 0 && dh > 5 && dh < 22) {
        this.chargeT = Math.max(4, 8 - this.boss * 0.6); this.charging = 1.8;
        sfxGroan(1, panOf(this.pos), 'attack'); player.shake = Math.max(player.shake, 0.4);
      }
      if (this.charging > 0) speed *= 2.3;
      if (this.phase >= 2) {
        // ground slam: rears up for a moment, then the shockwave
        if (this.slamT > 0) { move.set(0, 0, 0); if ((this.slamT -= dt) <= 0) this.slam(); }
        else if ((this.slamCD -= dt) <= 0 && dh < 9 && this.attackT <= 0) {
          this.slamCD = this.phase === 3 ? 5 : 7.5; this.slamT = 0.9; this.charging = 0;
          sfxGroan(1, panOf(this.pos), 'attack');
        }
        // acid volley when you keep away
        if ((this.volleyCD -= dt) <= 0 && dh > 10 && dh < 32 && this.slamT <= 0) {
          this.volleyCD = this.phase === 3 ? 4.5 : 6.5;
          for (let i = -1; i <= 1; i++) this.spit(i * 0.2);
        }
      }
    }
    this.turnTo(dh < 5 || this.attackT > 0 || hold ? Math.atan2(dx, dz) : move.lengthSq() > 0 ? Math.atan2(move.x, move.z) : this.yaw, dt, this.runner ? 9 : 5);
    this.moveAndCollide(move, speed, dt, this.boss ? 0.6 : 0.38, direct);

    this.groanT -= dt;
    if (this.groanT <= 0) { this.groanT = rand(3, 8); if (dh < 28) sfxGroan(clamp(1.1 - dh / 28, 0.1, 0.8), panOf(this.pos)); }

    // animation: shambling or sprinting gait, arms reaching, overhead swipe when attacking
    const moving = move.length() * speed;
    const amt = this.gait(dt, this.climbing ? 2.2 : moving, this.runner
      ? { stride: 0.75, knee: 1.2, rate: 2.0, bob: 0.09, ref: 5 }
      : { stride: 0.42, knee: 0.55, rate: 2.9, bob: 0.06, ref: 2.2, limp: this.limp });
    const lean = this.runner ? 0.42 : 0.26;
    this.spine.rotation.set(lean - this.flinch * 0.45 + Math.sin(now * 1.3 + this.walk) * 0.02, Math.sin(this.walk) * 0.12 * amt,
      Math.sin(this.walk) * (this.runner ? 0.06 : 0.16) * amt + this.flinchSide * this.flinch * 0.3);
    if (this.spitT > 0) this.spine.rotation.x -= 0.55 * Math.sin(this.spitT / 0.45 * Math.PI);   // rears back before spitting
    this.headG.rotation.set(-lean * 0.6 + Math.sin(now * 2.1 + this.walk) * 0.05, 0, this.headTilt + Math.sin(now * 0.9) * 0.08);
    // sudden neck jerks, chattering jaw, flickering eyes
    if ((this.twitchT -= dt) <= 0) { this.twitchT = rand(0.7, 3.2); this.tw.set(rand(-0.35, 0.35), rand(-0.55, 0.55), rand(-0.45, 0.45)); this.twK = 1; }
    this.twK = Math.max(0, this.twK - dt * 4.5);
    const tk = this.twK * this.twK;
    this.headG.rotation.x += this.tw.x * tk; this.headG.rotation.y += this.tw.y * tk; this.headG.rotation.z += this.tw.z * tk;
    const open = this.attackT > 0 || this.spitT > 0 ? 0.6 : 0.16 + Math.max(0, Math.sin(now * 11 + this.walk * 2)) * 0.14;
    this.jaw.rotation.x = lerp(this.jaw.rotation.x, open, Math.min(1, dt * 14));
    this.eyesMat.emissiveIntensity = (4.2 + Math.sin(now * 9 + this.walk) * 1.2 + (Math.random() < 0.03 ? -3 : 0)) * lightK();
    let swing = null;
    if (this.attackT > 0) {
      const p = this.attackT / 0.7;
      swing = p < 0.45 ? lerp(-1.4, -2.5, smooth(p / 0.45)) : lerp(-2.5, -0.35, smooth(clamp((p - 0.45) / 0.25, 0, 1)));
      this.spine.rotation.x += Math.sin(Math.min(1, p) * Math.PI) * 0.3;
    }
    this.arms.forEach((a, i) => {
      const ph = this.walk + i * Math.PI;
      if (this.slamT > 0) { a.sh.rotation.x = -3 + (0.9 - this.slamT) * 0.4; a.el.rotation.x = -0.1; }
      else if (swing !== null) { a.sh.rotation.x = swing + i * 0.15; a.el.rotation.x = -0.15; }
      else if (this.climbing) { a.sh.rotation.x = -2.75 + Math.sin(now * 9 + i * Math.PI) * 0.45; a.el.rotation.x = -0.5 - Math.max(0, Math.sin(now * 9 + i * Math.PI)) * 0.6; }
      else if (this.runner) { a.sh.rotation.x = -0.5 + Math.sin(ph) * 0.9 * amt; a.el.rotation.x = -1.1; }
      else { a.sh.rotation.x = -1.35 + Math.sin(now * 1.7 + i * 1.3) * 0.12 + Math.sin(ph) * 0.1 * amt; a.el.rotation.x = -0.25; }
      a.sh.rotation.z = a.s * (0.08 + Math.sin(now * 1.3 + i) * 0.04);
    });
    this.commonUpdate(dt, dist);
    return true;
  }
}

function spawnEnemy() {
  let spot = null;
  const lvl = bossWave ? wave / 5 : 0;
  const pe = playerEye(), minD = lvl ? 26 : mode === 'zombie' ? 16 : 22;
  for (let t = 0; t < 80; t++) {
    const i = 1 + Math.floor(Math.random() * (G - 2)), j = 1 + Math.floor(Math.random() * (G - 2));
    if (grid[i + j * G]) continue;
    const x = i - HALF + 0.5, z = j - HALF + 0.5;
    if (Math.hypot(x - player.pos.x, z - player.pos.z) < minD) continue;
    if (enemies.some(b => !b.dead && Math.hypot(b.pos.x - x, b.pos.z - z) < 2)) continue;
    spot = [x, z];
    if (!lineOfSight(new V3(x, 1.6, z), pe)) break;
  }
  spot ||= MAP.fallback;
  const e = mode === 'zombie' ? new Zombie(spot[0], spot[1], wave, lvl) : new Bot(spot[0], spot[1], wave, lvl);
  if (lvl) {
    // twice the size, its own health bar at the top of the screen
    e.group.scale.setScalar(mode === 'zombie' ? 2 : 1.9); e.barY *= 2; e.hb.visible = false;
    e.dropChance = 0; e.reaction = 0.4;
    const p = e.pos.clone().setY(1);
    for (let i = 0; i < 6; i++) spawnSmoke(p.clone().add(new V3(rand(-1.5, 1.5), rand(0, 2), rand(-1.5, 1.5))), 0x444048, 3);
    spawnParticles(p, mode === 'zombie' ? 0xff3030 : 0xff1e5a, 40, new V3(0, 1, 0), 7);
    withCat('enemies', sfxBossHorn);
  }
  enemies.push(e);
}

// ---------------------------------------------------------------- boss phases: warnings on the ground, shockwaves, reinforcements
const hazards = [], spawnQueue = [];
const hazRing = new THREE.RingGeometry(0.9, 1, 56).rotateX(-Math.PI / 2), hazDisc = new THREE.CircleGeometry(1, 40).rotateX(-Math.PI / 2);
const hazMat = (o, glow = true) => new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.12, 0.06).multiplyScalar(glow ? 1.6 : 0.8), transparent: true, opacity: o, blending: glow ? THREE.AdditiveBlending : THREE.NormalBlending, depthWrite: false, toneMapped: !glow, side: THREE.DoubleSide });
// red circle that fills up, then calls onFire
function addHazard(pos, radius, delay, onFire) {
  const g = new THREE.Group(); g.position.copy(pos).setY(pos.y + 0.06);
  const ring = new THREE.Mesh(hazRing, hazMat(0.9)), disc = new THREE.Mesh(hazDisc, hazMat(0.22, false));
  ring.scale.setScalar(radius); disc.scale.setScalar(0.01); g.add(ring, disc); scene.add(g);
  hazards.push({ g, ring, disc, radius, t: delay, max: delay, onFire });
}
// expanding shockwave ring (visual only)
function addWave(pos, radius, dur) {
  const g = new THREE.Group(); g.position.copy(pos);
  const ring = new THREE.Mesh(hazRing, hazMat(0.9)); ring.material.color.setRGB(1.6, 1.4, 1); g.add(ring); scene.add(g);
  hazards.push({ g, ring, radius, t: dur, max: dur, wave: true });
}
function updateHazards(dt) {
  for (let i = hazards.length - 1; i >= 0; i--) {
    const h = hazards[i], k = 1 - (h.t -= dt) / h.max;
    if (h.wave) { h.ring.scale.setScalar(Math.max(0.01, h.radius * k)); h.ring.material.opacity = 0.9 * (1 - k); }
    else { h.disc.scale.setScalar(Math.max(0.01, h.radius * k)); h.ring.material.opacity = 0.6 + 0.4 * Math.sin(now * 22); }
    if (h.t > 0) continue;
    h.onFire?.();
    scene.remove(h.g); h.g.children.forEach(m => m.material.dispose()); hazards.splice(i, 1);
  }
}
function clearHazards() { hazards.forEach(h => { scene.remove(h.g); h.g.children.forEach(m => m.material.dispose()); }); hazards.length = 0; spawnQueue.length = 0; }
function bossPhase(b) {
  const z = b instanceof Zombie;
  showBanner(`${b.name} · FASE ${b.phase}`, b.phase === 2
    ? (z ? 'COLPO A TERRA E ACIDO · SALTA PER SCHIVARE L’ONDA' : 'BOMBARDAMENTO · ESCI DAI CERCHI ROSSI')
    : (z ? 'FURIA · ARRIVA L’ORDA' : 'FURIA · ARRIVANO I RINFORZI'));
  withCat('enemies', sfxBossHorn);
  player.shake = Math.max(player.shake, 0.8);
  const p = b.pos.clone().setY(b.pos.y + 1.5);
  spawnParticles(p, b.sparkColor, 50, new V3(0, 1, 0), 9); spawnFlash(p, 0xffc070, 8, 0.3);
  addWave(b.pos.clone().setY(b.pos.y + 0.12), 7, 0.5);
  b.stunT = Math.max(b.stunT, 1.1);   // staggers for a moment: a window to reload or back off
  b.onPhase?.();
  // reinforcements: a couple at phase 2, a pack at phase 3
  spawnQueue.push({ b, n: b.phase === 2 ? 2 : 3 + Math.min(2, b.boss) });
}
function updateEnemies(dt) {
  updateHazards(dt);
  for (const q of spawnQueue.splice(0)) {
    for (let i = 0, t = 0; i < q.n && t < 60; t++) {
      const a = rand(0, 6.28), r = rand(3, 8), x = q.b.pos.x + Math.cos(a) * r, z = q.b.pos.z + Math.sin(a) * r;
      if (Math.abs(x) > 38 || Math.abs(z) > 38 || blockedAt(x, z)) continue;
      enemies.push(q.b instanceof Zombie ? new Zombie(x, z, wave, 0) : new Bot(x, z, wave, 0));
      waveTotal++; i++;
    }
  }
  enemies = enemies.filter(b => {
    const keep = b.update(dt);
    if (!keep) b.remove();
    return keep;
  });
}
