// Spariaps — Ondate, HUD, menu e flusso di gioco.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ waves
let wave = 0, toSpawn = 0, spawnT = 0, waveBreak = 0, waveTotal = 1, bossWave = false;
const aliveEnemies = () => enemies.filter(b => !b.dead).length;
const WORD = () => mode === 'zombie' ? { wave: 'ORDA', enemy: 'zombie' } : { wave: 'ONDATA', enemy: 'bot' };
function startWave() {
  wave++;
  if (diffKey === 'progressive') D = diffFor(wave);
  $('diffInfo').textContent = diffKey === 'progressive' ? ` · livello ${D.level < 0.2 ? 'facile' : D.level < 0.45 ? 'normale' : D.level < 0.75 ? 'difficile' : D.level <= 1 ? 'incubo' : 'incubo+'}` : '';
  // every 5th wave is a boss fight: the boss alone, stronger each time
  bossWave = wave % 5 === 0;
  toSpawn = waveTotal = bossWave ? 1 : Math.max(2, Math.round((mode === 'zombie' ? 6 + wave * 3 : 2 + wave * 2) * D.count));
  spawnT = bossWave ? 2.5 : 0.5;
  if (bossWave) showBanner(`BOSS · ${WORD().wave} ${wave}`, `${mode === 'zombie' ? 'L’ABOMINIO' : 'IL COLOSSO'} LIVELLO ${wave / 5} STA ARRIVANDO`);
  else showBanner(`${WORD().wave} ${wave}`, `${toSpawn} ${WORD().enemy.toUpperCase()} IN ARRIVO` + (diffKey === 'progressive' && wave > 1 ? ' · LA DIFFICOLTÀ AUMENTA' : ''));
  if (mode === 'zombie') withCat('enemies', () => sfxGroan(0.9, 0));
}
const WAVE_BREAK = 60;
function bossDefeated(b) {
  const bonus = Math.round(1000 * b.boss * D.score);
  addCash(bonus);
  const p = b.pos.clone().setY(1.5);
  spawnFlash(p, 0xffc070, 12, 0.5); lightBurst(p, 0xffa050, 160); spawnBlast(p, 6, 0xffa040, true);
  spawnParticles(p, b.sparkColor, 60, new V3(0, 1, 0), 10);
  for (let i = 0; i < 8; i++) spawnSmoke(p.clone().add(new V3(rand(-2, 2), rand(-0.5, 2), rand(-2, 2))), 0x3a3634, 3.5);
  sfxBoom(1.2, panOf(p), 0);
  // loot: health, armour and throwables around the body
  [['health', 1.6, 0], ['armor', -1.6, 0], ['equip', 0, 1.6], ['equip', 0, -1.6]].forEach(([t, ox, oz]) => pickups.push(new Pickup(t, b.pos.x + ox, b.pos.z + oz, true)));
  toast(`BOSS SCONFITTO · +${bonus} CREDITI`, 'pu', 'coin', '#ffd45a');
  bossKills++;
  if (revives < MAX_REVIVES) { revives++; renderPerks(); setTimeout(() => toast('+1 SECONDA VITA', 'hp'), 900); }
}
function updateWaves(dt) {
  if (waveBreak > 0) {
    const before = Math.ceil(waveBreak);
    waveBreak -= dt;
    if (wave > 0 && Math.ceil(waveBreak) !== before && before <= 5) sfxTone(before === 1 ? 1320 : 880, 0.09, 0.08, 'triangle', before === 1 ? 1320 : 880);
    if (waveBreak <= 0) startWave();
    return;
  }
  const maxAlive = mode === 'zombie' ? Math.min(18, Math.round((5 + wave * 2) * D.count)) : Math.min(9, 2 + wave);
  if (toSpawn > 0 && aliveEnemies() < maxAlive) {
    spawnT -= dt;
    if (spawnT <= 0) { spawnEnemy(); toSpawn--; spawnT = mode === 'zombie' ? rand(0.25, 0.7) : rand(0.4, 1.2); }
  }
  if (toSpawn === 0 && aliveEnemies() === 0) {
    waveBreak = WAVE_BREAK; bossWave = false;
    const bonus = Math.round(wave * 250 * D.score);
    score += bonus; addCash(bonus);
    showBanner(`${WORD().wave} SUPERATA`, `+${bonus} PUNTI · PROSSIMA TRA ${WAVE_BREAK} SECONDI · ${keyLabel('INVIO', 'back')} PER INIZIARE SUBITO`);
  }
}

// ============================================================ HUD
let bannerTimer = null;
function showBanner(big, small) {
  const b = $('banner');
  b.querySelector('.big').textContent = big;
  b.querySelector('.small').textContent = small;
  b.classList.add('show');
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => b.classList.remove('show'), 2600);
}
function addKillfeed(name, head, weaponKey) {
  const el = document.createElement('div');
  el.className = 'kf glass';
  el.innerHTML = `<b>TU</b>${ICONS[weaponKey]}<span>${name}</span>${head ? '<span class="hs">HEADSHOT</span>' : ''}`;
  const kf = $('killfeed');
  kf.prepend(el);
  while (kf.children.length > 5) kf.lastChild.remove();
  setTimeout(() => el.remove(), 4500);
}
const slotEls = [...document.querySelectorAll('.slot')];
const eqEls = [...document.querySelectorAll('.eq')];
const hud$ = { hpval: $('hpval'), hpfill: $('hpfill'), hplag: $('hplag'), hpbox: $('hpbox'), regen: $('regen'), stance: $('stance'),
  armorval: $('armorval'), armorfill: $('armorfill'), wname: $('wname'), wicon: $('wicon'),
  ammo: $('ammo'), reloadhint: $('reloadhint'), pips: $('pips'), wave: $('wave'), waveProg: $('waveProg'), botsLeft: $('botsLeft'),
  score: $('score'), kills: $('kills'), wavebox: document.querySelector('.wavebox'), breakInfo: $('breakInfo'), xhair: $('xhair'), ring: $('reloadRing'), ringFg: document.querySelector('#reloadRing .fg') };
let hudWeapon = null, hudMag = -1, hudLagHp = 100;
function updateHUD(dt) {
  const hp = Math.max(0, Math.ceil(player.hp)), ar = Math.ceil(player.armor);
  hudLagHp = Math.max(hp, hudLagHp - 40 * dt);
  hud$.hpval.textContent = hp;
  hud$.hpfill.style.width = hp + '%';
  hud$.hplag.style.width = hudLagHp + '%';
  hud$.hpbox.classList.toggle('low', hp < 35);
  hud$.hpbox.classList.toggle('noarmor', ar <= 0);
  hud$.regen.classList.toggle('on', hp < 100 && now - player.lastHit > D.regenDelay * (perks.regen ? 0.5 : 1));
  hud$.stance.classList.toggle('on', player.crouch);
  hud$.armorval.textContent = ar;
  hud$.armorfill.style.width = ar + '%';

  const w = W(), mag = weapon.mags[weapon.current];
  if (hudWeapon !== weapon.current) {
    hudWeapon = weapon.current; hudMag = -1;
    hud$.wname.textContent = w.name;
    hud$.wicon.innerHTML = ICONS[weapon.current];
    hud$.pips.innerHTML = '<span class="pip"></span>'.repeat(magOf(weapon.current));
    hud$.pips.classList.toggle('dense', magOf(weapon.current) > 40);
  }
  if (hudMag !== mag) {
    hudMag = mag;
    [...hud$.pips.children].forEach((p, i) => p.classList.toggle('used', i >= mag));
  }
  const low = mag <= Math.ceil(magOf(weapon.current) / 6);
  hud$.ammo.textContent = pw('ammo') ? '∞' : mag;
  hud$.ammo.classList.toggle('empty', low && !pw('ammo'));
  hud$.reloadhint.classList.toggle('on', low && !weapon.reloading && !pw('ammo'));
  for (const el of slotEls) el.classList.toggle('active', el.dataset.w === (weapon.meleeT > 0 ? 'knife' : weapon.current));

  hud$.ring.classList.toggle('on', weapon.reloading);
  if (weapon.reloading) hud$.ringFg.style.strokeDashoffset = 125.66 * (weapon.reloadT / reloadOf());

  const boss = enemies.find(b => b.boss && !b.dead);
  $('bossbar').classList.toggle('on', !!boss);
  if (boss) {
    boss.barLag = Math.max(boss.hp, (boss.barLag ?? boss.maxHp) - boss.maxHp * 0.25 * dt);
    $('bossName').textContent = boss.name + (boss.phase > 1 ? ` · FASE ${boss.phase}` : ''); $('bossHp').textContent = Math.ceil(boss.hp);
    $('bossFill').style.width = (boss.hp / boss.maxHp * 100) + '%'; $('bossLag').style.width = (boss.barLag / boss.maxHp * 100) + '%';
  }
  hud$.wave.textContent = wave;
  const brk = wave > 0 && waveBreak > 0;
  hud$.wavebox.classList.toggle('break', brk);
  if (brk) hud$.breakInfo.innerHTML = `prossima tra <b>${Math.ceil(waveBreak)}s</b>${waveBreak > 3 ? ` · ${keyLabel('INVIO', 'back')} per iniziare` : ''}`;
  const left = aliveEnemies() + toSpawn;
  hud$.botsLeft.textContent = left;
  hud$.waveProg.style.width = (waveBreak > 0 ? 100 : 100 * (1 - left / waveTotal)) + '%';
  hud$.score.textContent = score;
  hud$.kills.textContent = kills;
  $('cash').textContent = cash;
  for (const el of eqEls) { const n = equip[el.dataset.e]; el.querySelector('b').textContent = n; el.classList.toggle('empty', n <= 0); }
  $('blind').style.opacity = Math.min(1, blind);
  hud$.xhair.style.setProperty('--g', (5 + (currentSpread() + (w.pellets ? w.pelletSpread : 0)) * 420).toFixed(1) + 'px');
  hud$.xhair.style.opacity = (1 - weapon.adsT) * (1 - player.sprintT * 0.8);

  hurt = Math.max(0, hurt - dt * 1.6);
  const lowPulse = hp < 35 ? (35 - hp) / 35 * (0.55 + 0.25 * Math.sin(now * 7)) : 0;
  const h = Math.max(hurt, lowPulse);
  gradePass.uniforms.hurt.value = h;
  gradePass.uniforms.aberr.value = 0.0015 + h * 0.012;
}

// ============================================================ menus + game flow
const menu = $('menu'), hud = $('hud');
const SUBTITLES = {
  classic: 'Arena: ondate di bot armati, piattaforme sospese, trampolini e doppio salto. Muoviti veloce, prendi quota e non restare mai fermo.',
  zombie: 'È calata la notte e l’arena è infestata. Le orde crescono a ogni ondata, e gli arrampicatori dagli occhi viola scalano casse e muri: nessun posto è davvero sicuro.',
};
function stat(v, l, hi) { return `<div class="stat glass"><div class="v${hi ? ' hi' : ''}">${v}</div><div class="l">${l}</div></div>`; }
function refreshPickers() {
  document.querySelectorAll('#modeSeg button').forEach(b => b.classList.toggle('sel', b.dataset.v === mode));
  document.querySelectorAll('#diffSeg button').forEach(b => b.classList.toggle('sel', b.dataset.v === diffKey));
  $('diffDesc').textContent = D.desc;
  $('best').textContent = getBest();
  if (menuType === 'main') {
    $('subtitle').textContent = SUBTITLES[mode];
    $('mtag').textContent = mode === 'zombie' ? 'MODALITÀ ZOMBIE' : 'MODALITÀ CLASSICA';
  }
}
document.querySelectorAll('#modeSeg button').forEach(b => b.addEventListener('click', () => {
  mode = b.dataset.v; store.set('spariaps-mode', mode);
  applyAtmosphere(mode); refreshPickers();
  if (music.want === 'menu') playSong(mode);
}));
document.querySelectorAll('#diffSeg button').forEach(b => b.addEventListener('click', () => {
  diffKey = b.dataset.v; D = diffFor(1); store.set('spariaps-diff', diffKey);
  refreshPickers();
}));
function showMenu(type, { title, sub, stats = '' } = {}) {
  menuType = type;
  $('mtitle').textContent = title;
  $('subtitle').textContent = sub;
  $('stats').innerHTML = stats;
  $('pickers').classList.toggle('hidden', type !== 'main');
  $('playLabel').textContent = type === 'pause' ? 'RIPRENDI' : type === 'dead' ? 'RIGIOCA' : 'GIOCA';
  $('restartBtn').classList.toggle('hidden', type !== 'pause');
  $('classSwapBtn').classList.toggle('hidden', type !== 'pause');
  $('classSwapBtn').disabled = classSwaps >= MAX_SWAPS;
  $('swapLeft').textContent = `${MAX_SWAPS - classSwaps}/${MAX_SWAPS}`;
  $('mainMenuBtn').classList.toggle('hidden', type === 'main');
  $('bestBox').classList.toggle('hidden', type === 'pause');
  $('mtag').textContent = `${mode === 'zombie' ? 'ZOMBIE' : 'CLASSICA'} · ${D.name}`;
  renderChallenges(); renderLevel();
  $('lockerBtn').classList.toggle('hidden', type !== 'main');
  $('lockHint').textContent = '';
  refreshPickers();
  menu.classList.remove('hidden');
  const wrap = menu.querySelector('.menu-wrap');
  wrap.style.animation = 'none'; void wrap.offsetWidth; wrap.style.animation = '';
}
function showMainMenu() { showMenu('main', { title: 'SPARIAPS', sub: SUBTITLES[mode] }); setMusic('menu'); }
function clearWorld() {
  enemies.forEach(b => b.remove()); enemies = [];
  [...particles, ...tracers, ...decals, ...smokes].forEach(m => scene.remove(m));
  particles.length = tracers.length = decals.length = smokes.length = 0;
  dmgNums.forEach(d => d.el.remove()); dmgNums.length = 0;
  clearThrowables(); clearBlastFx(); clearHazards();
  while (drops.length) removeDrop(drops[0]);
  $('prompt').classList.remove('on'); promptKey = '';
}
function resetGame() {
  bankMatch();
  primary = CLASSES[classKey].weapon;
  setArena(mode === 'classic');
  D = diffFor(1);
  clearWorld();
  for (const h of MAP.houses || []) if (h.open) setHouse(h, false);
  resetPickups();
  Object.assign(player, { hp: 100, armor: CLASSES[classKey].armor, yaw: 0, pitch: 0, onGround: true, lastHit: -99, crouch: false, crouchT: 0, landOff: 0, shake: 0, roll: 0, sprintT: 0, slideT: 0, slideCD: 0, vaultCD: 0 });
  player.pos.set(...MAP.start); player.vel.set(0, 0, 0);
  Object.assign(weapon, {
    current: primary, last: 'pistol', mags: { [primary]: WEAPONS[primary].magSize, pistol: 12 }, reloading: false, reloadT: 0, cooldown: 0,
    bloom: 0, kick: 0, recoilOff: 0, spray: 0, sprayT: 0, adsT: 0, switchT: 0, switchTo: null, meleeT: 0, slideKick: 0, throwT: 0, burstLeft: 0, spin: 0,
  });
  aiming = firing = false;
  player.lean = player.leanT = 0; player.leanV.set(0, 0, 0);
  resetArsenal();
  wave = 0; toSpawn = 0; waveBreak = 2; bossWave = false; classSwaps = 0; waveTotal = 1; score = 0; kills = 0; headshots = 0; shotsFired = 0; shotsHit = 0; now = 0; hurt = 0; banked = false; chalT = 1;
  hudWeapon = null; hudLagHp = 100;
  $('killfeed').innerHTML = ''; $('toasts').innerHTML = ''; $('diffInfo').textContent = '';
  $('scope').classList.remove('on');
  $('waveLabel').textContent = WORD().wave;
  $('enemyWord').textContent = WORD().enemy;
  applyAtmosphere(mode);
  startTutorial();
}
function beginPlay() {
  state = 'playing';
  $('classMenu').classList.add('hidden'); $('settings').classList.add('hidden'); $('shop').classList.add('hidden');
  menu.classList.add('hidden'); hud.classList.add('on');
  holder.visible = true;
  setMusic('game');
}
let lockFails = 0;
function enterGame() {
  if (touchMode) { document.documentElement.requestFullscreen?.().catch(() => {}); return beginPlay(); }
  // controller: no pointer lock needed (falls back to mouse lock when no pad is actually connected)
  if (padMode() && activePad()) { if (document.pointerLockElement) document.exitPointerLock(); return beginPlay(); }
  let p;
  try { p = renderer.domElement.requestPointerLock(); } catch { p = null; }
  if (p && p.catch) p.catch(() => {
    // Chrome refuses a re-lock right after Esc; ask for another click, then fall back to unlocked play
    if (menu.classList.contains('hidden') || ++lockFails >= 2) { lockFails = 0; beginPlay(); }
    else $('lockHint').textContent = 'Clicca di nuovo per entrare in partita';
  });
  else if (!('pointerLockElement' in document)) beginPlay();
}
// ---------------------------------------------------------------- level display and the locker
function renderLevel() {
  const l = levelOf();
  $('lvlBox').innerHTML = `<b>LIV ${l.lvl}</b><div class="lbar"><u style="width:${Math.round(l.cur / l.need * 100)}%"></u></div><span>${l.lvl < MAX_LEVEL ? `${l.cur} / ${l.need} XP` : 'LIVELLO MASSIMO'}</span>`;
}
function renderLocker() {
  const lvl = levelOf().lvl;
  $('lockTag').textContent = `LIVELLO ${lvl}`;
  $('lockBody').innerHTML = Object.entries(LOOKS).map(([k, g]) => `<div class="lk-h">${g.name}</div><div class="lk-row">` + g.items.map(i => {
    const bg = i.pal ? `linear-gradient(135deg, ${i.pal[0]} 0 25%, ${i.pal[1]} 25% 50%, ${i.pal[2]} 50% 75%, ${i.pal[3]} 75%)` : i.metal ? `linear-gradient(135deg, ${i.metal} 0 60%, ${i.poly} 60%)` : i.base;
    const open = lvl >= i.lvl, sel = loadout[k] === i.id;
    return `<button class="sw${sel ? ' sel' : ''}" data-k="${k}" data-id="${i.id}"${open ? '' : ' disabled'}><i style="background:${bg}"></i><b>${i.name}</b><small>${sel ? 'IN USO' : open ? 'Sbloccata' : `Livello ${i.lvl}`}</small></button>`;
  }).join('') + '</div>').join('');
}
$('lockBody').addEventListener('click', e => {
  const b = e.target.closest('.sw');
  if (!b || b.disabled) return;
  loadout[b.dataset.k] = b.dataset.id; store.set('spariaps-loadout', JSON.stringify(loadout));
  applyLoadout(); renderLocker();
  if (padFocus) setPadFocus($('lockBody').querySelector(`.sw[data-k="${b.dataset.k}"][data-id="${b.dataset.id}"]`), false);
});
$('lockerBtn').addEventListener('click', () => { renderLocker(); $('locker').classList.remove('hidden'); });
$('lockClose').addEventListener('click', () => $('locker').classList.add('hidden'));
// ---------------------------------------------------------------- first-match tutorial: a few hints, each ticked off by doing what it says
const K = (kb, btn) => `<kbd>${keyLabel(kb, btn)}</kbd>`;
const TUT = [
  { h: () => touchMode ? `Muoviti con il pollice sinistro e guardati intorno trascinando a destra` : padMode() && activePad() ? `Muoviti con lo stick sinistro e guardati intorno con il destro` : `Muoviti con ${K('W')}${K('A')}${K('S')}${K('D')} e guardati intorno con il mouse`, ok: () => tut.moved > 4 },
  { h: () => `Spara con ${K('Clic SX', 'RT')} · mira con ${K('Clic DX', 'LT')}`, ok: () => shotsFired > 0 },
  { h: () => `Ricarica con ${K('R', 'X')} prima di restare a secco`, ok: () => weapon.reloading },
  { h: () => `Corri con ${K('Shift', 'L3')} · salta con ${K('Spazio', 'A')}`, ok: () => tut.ran && tut.jumped },
  { h: () => `Ogni uccisione dà <b>crediti</b>. Spendili alla <b>cassa misteriosa</b> (quadrato giallo sulla minimappa) con ${K('E', 'X')}` },
  { h: () => `Il <b>banco armi</b> (arancione) potenzia le tue armi · il <b>distributore di perk</b> (viola) apre tra un’ondata e l’altra` },
  { h: () => `Gli <b>edifici</b> con il quadratino rosso si aprono con i crediti: dentro puoi ripararti, ma i nemici ti seguono`, when: () => MAP.houses?.length },
  { h: () => `I <b>cuori</b> sopra la vita sono le seconde vite: se cadi ti rialzi. Ogni 5 ondate arriva un boss. Buona fortuna!` },
];
const tut = { i: -1, t: 0, okT: 0, moved: 0, ran: false, jumped: false, px: 0, pz: 0, html: '' };
function startTutorial() {
  const on = store.get('spariaps-tut', '0') !== '1';
  Object.assign(tut, { i: on ? 0 : -1, t: 0, okT: 0, moved: 0, ran: false, jumped: false, px: player.pos.x, pz: player.pos.z, html: '' });
  $('tut').classList.remove('on', 'ok');
  if (on) waveBreak = 12;   // a quiet moment to try the controls before the first wave
}
function updateTutorial(dt) {
  if (tut.i < 0) return;
  const el = $('tut');
  while (tut.i < TUT.length && TUT[tut.i].when && !TUT[tut.i].when()) tut.i++;
  if (tut.i >= TUT.length) { tut.i = -1; el.classList.remove('on', 'ok'); store.set('spariaps-tut', '1'); return; }
  const s = TUT[tut.i];
  tut.moved += Math.hypot(player.pos.x - tut.px, player.pos.z - tut.pz); tut.px = player.pos.x; tut.pz = player.pos.z;
  if (player.sprintT > 0.6) tut.ran = true;
  if (!player.onGround) tut.jumped = true;
  tut.t += dt;
  const html = s.h();
  if (html !== tut.html) { tut.html = html; el.querySelector('.st').textContent = `TUTORIAL ${tut.i + 1}/${TUT.length}`; el.querySelector('.tx').innerHTML = html; el.classList.add('on'); }
  // actions get a green tick as soon as you do them; plain hints stay long enough to be read
  if (!tut.okT && (s.ok ? s.ok() || tut.t > 25 : tut.t > 7)) { tut.okT = s.ok ? 0.9 : 0.01; if (s.ok && tut.t <= 25) { el.classList.add('ok'); sfxTone(880, 0.1, 0.07, 'sine', 1320); } }
  if (tut.okT && (tut.okT -= dt) <= 0) { tut.i++; tut.t = 0; tut.okT = 0; tut.moved = 0; tut.ran = tut.jumped = false; tut.html = ''; el.classList.remove('on', 'ok'); }
}
$('tutBtn').addEventListener('click', () => { store.set('spariaps-tut', '0'); $('tutBtn').querySelector('span').textContent = 'ATTIVO ALLA PROSSIMA PARTITA ✓'; });
function startNewGame() { initAudio(); resetGame(); enterGame(); }
function pause() {
  state = 'paused'; firing = aiming = false;
  setMusic('pause');
  $('scope').classList.remove('on');
  showMenu('pause', { title: 'PAUSA', sub: 'Prenditi un respiro. Puoi riprendere, ricominciare da capo o tornare al menu.',
    stats: stat(wave, WORD().wave) + stat(kills, 'Uccisioni') + stat(score, 'Punti') });
}
function goMainMenu() {
  if (document.pointerLockElement) document.exitPointerLock();
  checkChallenges(); bankMatch();
  clearWorld();
  pickups.forEach(p => scene.remove(p.group)); pickups = [];
  state = 'menu'; hud.classList.remove('on'); holder.visible = false;
  gradePass.uniforms.hurt.value = 0;
  applyAtmosphere(mode);
  showMainMenu();
}
function gameOver() {
  state = 'dead'; firing = aiming = false;
  setMusic('menu');
  if (document.pointerLockElement) document.exitPointerLock();
  hud.classList.remove('on');
  gradePass.uniforms.hurt.value = 0.4;
  const best = getBest(), record = score > best;
  if (record) store.set(bestKey(), String(score));
  const acc = shotsFired ? Math.round(shotsHit / shotsFired * 100) : 0;
  checkChallenges(true); bankMatch();
  showMenu('dead', {
    title: 'SEI MORTO',
    sub: (record ? 'Nuovo record personale! ' : '') + `Modalità ${mode === 'zombie' ? 'Zombie' : 'Classica'} · ${D.name.toLowerCase()}.`
      + (lastGain ? ` +${lastGain.xp} XP.` + (lastGain.to > lastGain.from ? ` Sei salito al livello ${lastGain.to}!` + (lastGain.unlocked.length ? ` Sbloccato: ${lastGain.unlocked.join(', ').toLowerCase()}.` : '') : '') : ''),
    stats: stat(wave, WORD().wave) + stat(kills, 'Uccisioni') + stat(score, 'Punti', record) + stat(acc + '%', 'Precisione') + stat(headshots, 'Headshot')
      + stat(clockStr(now), 'Tempo') + stat(bossKills, 'Boss') + stat(earned, 'Crediti presi') + stat(spent, 'Crediti spesi')
      + `<div class="career glass"><div class="h">CARRIERA</div><b>${career.games}</b> partite · <b>${career.kills}</b> uccisioni · <b>${career.headshots}</b> headshot · <b>${career.bosses}</b> boss · miglior ${WORD().wave.toLowerCase()} <b>${career.bestWave}</b> · tempo di gioco <b>${clockStr(career.time)}</b></div>`,
  });
}

// ---------------------------------------------------------------- in-match shops (the world freezes while one is open)
let shopKind = null, shopT = 0;
$('shopCoin').innerHTML = ICONS.coin;
function openShop(kind) {
  shopKind = kind; state = 'shop'; shopT = performance.now();
  firing = aiming = false;
  for (const k in keys) keys[k] = false;
  if (document.pointerLockElement) document.exitPointerLock();
  setMusic('pause');
  $('scope').classList.remove('on');
  $('shopTag').textContent = `${WORD().wave} ${wave}`;
  $('shopTitle').textContent = kind === 'perks' ? 'DISTRIBUTORE DI PERK' : 'BANCO ARMI';
  $('shopSub').textContent = kind === 'perks'
    ? 'Abilità permanenti per tutta la partita, una per tipo. Il distributore apre solo tra un’ondata e l’altra: il conto alla rovescia è fermo finché resti qui.'
    : 'Spendi i crediti per potenziare le armi che hai con te. I potenziamenti restano su quell’arma per tutta la partita, anche se la lasci a terra e la riprendi.';
  renderShop();
  $('shop').classList.remove('hidden');
}
function closeShop() {
  if (state !== 'shop') return;
  $('shop').classList.add('hidden');
  enterGame();
}
function renderShop() {
  $('shopCash').textContent = cash;
  if (shopKind === 'perks') {
    $('shopGrid').innerHTML = Object.entries(PERKS).map(([k, pk]) => `
      <button class="perkc glass${perkOwned(k) ? ' own' : ''}" data-k="${k}" style="--c:${pk.css}" ${perkOwned(k) || cash < pk.cost ? 'disabled' : ''}>
        <span class="pt">${pk.tag}</span>
        <span class="pi"><b>${pk.name}${k === 'revive' ? ` · ${revives}/${MAX_REVIVES}` : ''}</b><small>${pk.desc}</small></span>
        <span class="uc">${perkOwned(k) ? (k === 'revive' ? 'AL MASSIMO' : 'ATTIVO') : pk.cost}</span>
      </button>`).join('');
    $('shopGrid').querySelectorAll('.perkc').forEach(b => b.addEventListener('click', () => buyPerk(b.dataset.k)));
    return;
  }
  $('shopGrid').innerHTML = slots.filter(Boolean).map(k => `
    <div class="shop-col glass">
      <div class="sw"><div class="ic">${ICONS[k] || ''}</div><div><div class="cn">${WEAPONS[k].name}</div><div class="wn">${k === weapon.current ? 'IN MANO' : 'DI RISERVA'}</div></div></div>
      ${Object.entries(UPGRADES).map(([t, u]) => {
        const l = upgLv(k, t), max = l >= UPG_COST.length, cost = UPG_COST[l];
        return `<button class="upg${max ? ' max' : ''}" data-k="${k}" data-t="${t}" ${max || cash < cost ? 'disabled' : ''}>
          <span class="un">${u.name}<small>${l ? u.text(l) : 'di serie'}${max ? '' : ' → ' + u.text(l + 1)}</small></span>
          <span class="lv">${UPG_COST.map((_, i) => `<i class="${i < l ? 'on' : ''}"></i>`).join('')}</span>
          <span class="uc">${max ? 'MAX' : cost}</span>
        </button>`;
      }).join('')}
    </div>`).join('');
  $('shopGrid').querySelectorAll('.upg').forEach(b => b.addEventListener('click', () => buyUpgrade(b.dataset.k, b.dataset.t)));
}
function buyUpgrade(k, t) {
  const l = upgLv(k, t), cost = UPG_COST[l];
  if (cost === undefined || cash < cost) return;
  addCash(-cost);
  (upg[k] ||= {})[t] = l + 1;
  if (t === 'mag') weapon.mags[k] = magOf(k);   // the bigger magazine comes full
  hudWeapon = null;
  withCat('ui', () => { sfxTone(520, 0.1, 0.1, 'triangle', 780); sfxTone(1040, 0.18, 0.08, 'triangle', 1560, 0.08); });
  renderShop();
}
const perkOwned = k => k === 'revive' ? revives >= MAX_REVIVES : !!perks[k];
function buyPerk(k) {
  const pk = PERKS[k];
  if (!pk || perkOwned(k) || cash < pk.cost) return;
  addCash(-pk.cost);
  if (k === 'revive') revives++; else perks[k] = true;
  withCat('ui', () => [1, 1.25, 1.5, 2].forEach((m, i) => sfxTone(392 * m, 0.22, 0.09, 'triangle', 392 * m, i * 0.07)));
  renderPerks(); renderShop();
}
// owned perks, shown as small tags next to the health box
function renderPerks() {
  $('perks').innerHTML = `<span class="life" style="--c:${PERKS.revive.css}" title="Seconda vita">♥</span>`.repeat(revives)
    + Object.keys(PERKS).filter(k => perks[k]).map(k => `<span style="--c:${PERKS[k].css}" title="${PERKS[k].name}">${PERKS[k].tag}</span>`).join('');
}
$('shopClose').addEventListener('click', closeShop);
addEventListener('keydown', e => {
  if (state === 'shop' && !e.repeat && (e.code === 'Escape' || e.code === 'KeyE') && performance.now() - shopT > 250) closeShop();
});

// ---------------------------------------------------------------- map selection (shown before the class menu)
const MAP_ORDER = ['city', 'arena'], thumbs = {};
function useMap(key) { setMap(key); applyAtmosphere(mode); placeBox(true); }
// preview picture: one frame of the real map from above, in the lighting of the selected mode
function mapThumb(key) {
  const id = key + '-' + mode;
  if (thumbs[id]) return thumbs[id];
  const src = renderer.domElement;
  if (!src.width || !src.height) return '';
  const cam = new THREE.PerspectiveCamera(48, src.width / src.height, 1, 400), [x, y, z, tx, ty, tz] = MAPS[key].shot;
  cam.position.set(x, y, z); cam.lookAt(tx, ty, tz);
  const prev = MAP.key;
  setMap(key); applyAtmosphere(mode);
  box.group.visible = false; sky.position.copy(cam.position);
  renderer.setRenderTarget(null); renderer.render(scene, cam);
  const c = document.createElement('canvas'); c.width = 640; c.height = 360;
  const sw = Math.min(src.width, src.height * 16 / 9), sh = sw * 9 / 16;
  c.getContext('2d').drawImage(src, (src.width - sw) / 2, (src.height - sh) / 2, sw, sh, 0, 0, 640, 360);
  useMap(prev);
  return thumbs[id] = c.toDataURL('image/jpeg', 0.86);
}
function renderMaps() {
  const pics = Object.fromEntries(MAP_ORDER.map(k => [k, mapThumb(k)]));
  $('maps').innerHTML = MAP_ORDER.map(k => `
    <button class="mapc glass${k === MAP.key ? ' sel' : ''}" data-k="${k}">
      <img src="${pics[k]}" alt="">
      <div class="mi"><div class="mtg">${MAPS[k].tag}</div><div class="mn">${MAPS[k].name}</div><div class="md">${MAPS[k].desc}</div></div>
    </button>`).join('');
  $('maps').querySelectorAll('.mapc').forEach(b => b.addEventListener('click', () => {
    if (b.dataset.k !== MAP.key) { useMap(b.dataset.k); store.set('spariaps-map', MAP.key); }
    renderMaps();
  }));
}
function showMapMenu() {
  if (state === 'dead') goMainMenu();   // clear the finished match so the previews and the orbit show clean maps
  renderMaps();
  $('mapTag').textContent = `${mode === 'zombie' ? 'ZOMBIE' : 'CLASSICA'} · ${diffFor(1).name}`;
  menu.classList.add('hidden');
  $('mapMenu').classList.remove('hidden');
}
$('mapNext').addEventListener('click', () => { $('mapMenu').classList.add('hidden'); showClassMenu(); });
$('mapBack').addEventListener('click', () => { $('mapMenu').classList.add('hidden'); showMainMenu(); });

// ---------------------------------------------------------------- class selection
const STAT_NAMES = ['DANNO', 'CADENZA', 'PRECISIONE', 'MOBILITÀ'];
function renderClasses() {
  $('classes').innerHTML = Object.entries(CLASSES).map(([k, c]) => `
    <button class="cls glass${k === classKey ? ' sel' : ''}" data-k="${k}">
      <div class="ic">${ICONS[c.weapon]}</div>
      <div><div class="cn">${c.name}</div><div class="wn">${WEAPONS[c.weapon].name}</div></div>
      <div class="cd">${c.desc}</div>
      <div class="bars">${c.stats.map((v, i) => `<div class="bar">${STAT_NAMES[i]}<div class="tr"><i style="width:${v * 20}%"></i></div></div>`).join('')}</div>
      <div class="perk">${c.perk}</div>
    </button>`).join('');
  $('classes').querySelectorAll('.cls').forEach(b => b.addEventListener('click', () => {
    classKey = b.dataset.k; store.set('spariaps-class', classKey); renderClasses();
  }));
}
// class menu doubles as the mid-game class swap (from the pause menu, max twice per match)
const MAX_SWAPS = 2;
let classSwaps = 0, classMode = 'new', swapFrom = null;
function showClassMenu(swap = false) {
  classMode = swap ? 'swap' : 'new';
  swapFrom = classKey;
  $('ctag').textContent = swap ? `CAMBIO CLASSE · ${MAX_SWAPS - classSwaps} DISPONIBILI` : `${mode === 'zombie' ? 'ZOMBIE' : 'CLASSICA'} · ${diffFor(1).name}`;
  $('classSub').textContent = swap ? 'La nuova arma principale sostituisce quella della classe attuale; se lo scudo della nuova classe è più alto, lo ricevi subito.' : 'Ogni classe ha un’arma principale diversa. Pistola e coltello sono sempre con te.';
  $('startBtn').firstChild.textContent = swap ? 'CONFERMA' : 'INIZIA';
  renderClasses();
  menu.classList.add('hidden');
  $('classMenu').classList.remove('hidden');
}
function applyClassSwap() {
  const oldW = CLASSES[swapFrom].weapon, c = CLASSES[classKey], neu = c.weapon;
  primary = neu;
  if (!slots.includes(neu)) {
    let i = slots.indexOf(oldW);
    if (i < 0) i = slots.indexOf(null);
    if (i < 0) { i = 0; spawnDrop(slots[0], weapon.mags[slots[0]], dropPoint()); }
    const wasCurrent = weapon.current === slots[i];
    slots[i] = neu;
    if (wasCurrent || !slots.includes(weapon.current)) { weapon.current = neu; weapon.switchTo = null; weapon.switchT = 0; weapon.reloading = false; }
    renderSlots();
  }
  weapon.mags[neu] = magOf(neu);
  player.armor = Math.max(player.armor, c.armor);
  classSwaps++;
  toast(`CLASSE: ${c.name}`, 'pu', neu, '#ffb36b');
}
$('startBtn').addEventListener('click', () => {
  $('classMenu').classList.add('hidden');
  if (classMode === 'new') return startNewGame();
  if (classKey !== swapFrom) applyClassSwap();
  enterGame();
});
$('classBack').addEventListener('click', () => {
  if (classMode === 'swap') { classKey = swapFrom; store.set('spariaps-class', classKey); }
  $('classMenu').classList.add('hidden');
  (classMode === 'new' ? $('mapMenu') : menu).classList.remove('hidden');
});
$('classSwapBtn').addEventListener('click', () => { if (classSwaps < MAX_SWAPS) showClassMenu(true); });

// ---------------------------------------------------------------- settings
const SLIDERS = [['sLights', 'vLights', 'lights'], ['sBright', 'vBright', 'bright'], ['sSens', 'vSens', 'sens'], ['sPadSens', 'vPadSens', 'padSens'],
  ...['Master', 'Music', 'Weapons', 'Enemies', 'Fx', 'Ui'].map(k => ['sVol' + k, 'vVol' + k, 'vol' + k])];
function syncSettingsUI() {
  for (const [sid, vid, k] of SLIDERS) {
    const el = $(sid);
    el.value = Math.round(settings[k] * 100);
    $(vid).textContent = el.value + '%';
    el.style.setProperty('--p', ((el.value - el.min) / (el.max - el.min) * 100) + '%');
  }
}
for (const [sid, , k] of SLIDERS) $(sid).addEventListener('input', e => {
  settings[k] = e.target.value / 100;
  syncSettingsUI(); saveSettings();
  if (k.startsWith('vol')) applyVolumes(); else if (!k.endsWith('ens')) applyAtmosphere(mode);
});
function syncOptionUI() {
  document.querySelectorAll('#adsSeg button').forEach(b => b.classList.toggle('sel', (b.dataset.v === 'hold') === !!settings.adsHold));
  document.querySelectorAll('#qSeg button').forEach(b => b.classList.toggle('sel', b.dataset.v === settings.quality));
  document.querySelectorAll('#autoSeg button').forEach(b => b.classList.toggle('sel', (b.dataset.v === 'on') === !!settings.autoAds));
  $('qHint').textContent = (QUALITY[settings.quality] || QUALITY.high).hint;
  document.querySelectorAll('#invSeg button').forEach(b => b.classList.toggle('sel', (b.dataset.v === 'on') === !!settings.invertY));
  document.querySelectorAll('#assistSeg button').forEach(b => b.classList.toggle('sel', (b.dataset.v === 'on') === !!settings.aimAssist));
  document.querySelectorAll('#fpsSeg button').forEach(b => b.classList.toggle('sel', (b.dataset.v === 'on') === !!settings.fps));
  $('fps').classList.toggle('on', !!settings.fps);
  document.querySelectorAll('#inputSeg button').forEach(b => b.classList.toggle('sel', b.dataset.v === settings.input));
}
document.querySelectorAll('#adsSeg button').forEach(b => b.addEventListener('click', () => {
  settings.adsHold = b.dataset.v === 'hold'; aiming = false; saveSettings(); syncOptionUI();
}));
document.querySelectorAll('#autoSeg button').forEach(b => b.addEventListener('click', () => {
  settings.autoAds = b.dataset.v === 'on'; saveSettings(); syncOptionUI();
}));
document.querySelectorAll('#qSeg button').forEach(b => b.addEventListener('click', () => {
  settings.quality = b.dataset.v; saveSettings(); syncOptionUI(); applyQuality();
  pickups.forEach(p => { if (p.light) p.light.visible = settings.quality !== 'low'; });
}));
$('settingsBtn').addEventListener('click', () => { syncSettingsUI(); syncOptionUI(); applyInputMode(); $('settings').classList.remove('hidden'); });
$('settingsClose').addEventListener('click', () => $('settings').classList.add('hidden'));
// fullscreen toggle (webkit prefix for Safari)
const fsElement = () => document.fullscreenElement || document.webkitFullscreenElement;
function syncFullscreenUI() {
  const on = !!fsElement();
  $('fsBtn').classList.toggle('active', on);
  $('fsBtn').querySelector('span').textContent = on ? 'DISATTIVA' : 'ATTIVA';
}
$('fsBtn').addEventListener('click', () => {
  const el = document.documentElement;
  try {
    const p = fsElement()
      ? (document.exitFullscreen || document.webkitExitFullscreen).call(document)
      : (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
    // Chrome: with the keyboard locked, Esc no longer leaves fullscreen (hold Esc to exit)
    if (p && p.then) p.then(() => { if (fsElement()) navigator.keyboard?.lock?.(['Escape']).catch(() => {}); }, () => toast('SCHERMO INTERO NON DISPONIBILE', 'ar'));
  } catch { toast('SCHERMO INTERO NON DISPONIBILE', 'ar'); }
});
addEventListener('fullscreenchange', syncFullscreenUI);
addEventListener('webkitfullscreenchange', syncFullscreenUI);
addEventListener('resize', syncFullscreenUI);
syncFullscreenUI();
$('settingsReset').addEventListener('click', () => {
  Object.assign(settings, SETTINGS_DEFAULT, { input: settings.input, binds: settings.binds, padBinds: settings.padBinds }); syncSettingsUI(); syncOptionUI(); applyAtmosphere(mode); applyQuality(); applyVolumes(); saveSettings();
  pickups.forEach(p => { if (p.light) p.light.visible = true; });
});
document.querySelectorAll('.ctabs button').forEach(b => b.addEventListener('click', () => {
  document.querySelectorAll('.ctabs button').forEach(x => x.classList.toggle('sel', x === b));
  document.querySelectorAll('.csec').forEach(sec => sec.hidden = sec.dataset.t !== b.dataset.t);
}));
// menu legend for the arena bonuses
$('bonusLegend').innerHTML = [
  ...Object.entries(POWERUPS).map(([k, d]) => [k, d.name, d.css, { jump: 'Salti di quasi 4 m', haste: '+40% movimento e cadenza', ammo: 'Niente ricarica', quad: 'Triplo danno', god: 'Nessun danno subito' }[k] + ` · ${d.dur}s`]),
  ['box', 'CASSA MISTERIOSA', '#9fd0ff', `Arma casuale per ${BOX_COST} crediti, poi si sposta`],
  ['pad', 'TRAMPOLINO', '#7cfff0', 'Solo in modalità classica: ti lancia sulle piattaforme'],
].map(([k, n, c, t]) => `<div class="ctrl bonus" style="--c:${c}">${ICONS[k]}<b>${n}</b><span>${t}</span></div>`).join('');

const UI_SEL = 'button, .cls';
let uiHoverEl = null;
document.addEventListener('pointerover', e => {
  const el = e.target.closest?.(UI_SEL);
  if (el === uiHoverEl) return;
  uiHoverEl = el;
  if (el && state !== 'playing' && !el.disabled) sfxUiHover();
});
document.addEventListener('click', e => {
  const el = e.target.closest?.(UI_SEL);
  if (!el || el.disabled) return;
  initAudio();
  sfxUiClick(el.classList.contains('pbtn'));
}, true);
// quit the whole game: confirm, then close the window (works in the launcher's app window); otherwise show a goodbye screen
$('quitBtn').addEventListener('click', () => $('quitDlg').classList.remove('hidden'));
$('quitNo').addEventListener('click', () => $('quitDlg').classList.add('hidden'));
$('quitYes').addEventListener('click', () => {
  saveSettings();
  music.want = null; if (music.song) music.song.pause(); if (actx) { stopLoop(0.1); setTimeout(() => actx.suspend(), 150); }
  if (document.pointerLockElement) document.exitPointerLock();
  if (fsElement()) (document.exitFullscreen || document.webkitExitFullscreen)?.call(document);
  window.close();
  setTimeout(() => { $('quitDlg').classList.add('hidden'); $('bye').classList.add('on'); renderer.setAnimationLoop(null); }, 300);
});
addEventListener('keydown', e => {
  if (e.code !== 'Escape') return;
  if (!$('quitDlg').classList.contains('hidden')) $('quitDlg').classList.add('hidden');
  else if (!$('settings').classList.contains('hidden')) $('settings').classList.add('hidden');
  else if (!$('locker').classList.contains('hidden')) $('locker').classList.add('hidden');
});
$('play').addEventListener('click', () => {
  initAudio();
  if (menuType === 'pause') enterGame();
  else showMapMenu();
});
$('restartBtn').addEventListener('click', startNewGame);
$('mainMenuBtn').addEventListener('click', goMainMenu);
document.addEventListener('pointerlockchange', () => {
  if (document.pointerLockElement === renderer.domElement) { lockFails = 0; beginPlay(); }
  else if (state === 'playing' && !(padMode() && activePad())) pause();
});
