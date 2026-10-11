// Spariaps — Controller e ciclo principale.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// ============================================================ controller (Gamepad API, standard mapping)
// buttons: 0 A · 1 B · 2 X · 3 Y · 4 LB · 5 RB · 6 LT · 7 RT · 8 View · 9 Menu · 10 L3 · 11 R3 · 12-15 d-pad ↑↓←→
const PAD_LABELS = {
  xbox: { A: 'A', B: 'B', X: 'X', Y: 'Y', LB: 'LB', RB: 'RB', LT: 'LT', RT: 'RT', L3: 'L3', R3: 'R3', start: 'MENU', back: 'VIEW', up: '▲', down: '▼', left: '◀', right: '▶', ls: 'L', rs: 'R' },
  ps: { A: '✕', B: '○', X: '□', Y: '△', LB: 'L1', RB: 'R1', LT: 'L2', RT: 'R2', L3: 'L3', R3: 'R3', start: 'OPTIONS', back: 'CREATE', up: '▲', down: '▼', left: '◀', right: '▶', ls: 'L', rs: 'R' },
};
let padIndex = null, padStyle = 'xbox';
const PL = () => PAD_LABELS[padStyle];
// prompts are written with the default key and button: show whatever they are bound to now
const LABEL_ACT = { E: 'interact', R: 'reload', INVIO: 'skip', W: 'fwd', A: 'left', S: 'back', D: 'right', Shift: 'sprint', Spazio: 'jump', C: 'crouch' };
const padBtn = btn => { const i = PAD_NAMES.indexOf(btn); return PL()[i < 0 ? btn : PAD_NAMES[padOf(i)]]; };
function keyLabel(kb, btn) {
  if (touchMode) return TOUCH_LABELS[kb] || kb;
  if (padMode() && activePad()) return padBtn(btn);
  const a = LABEL_ACT[kb];
  return a && settings.binds[a] ? keyName(bindOf(a)) : kb;
}
function activePad() {
  const list = navigator.getGamepads ? navigator.getGamepads() : [];
  let gp = padIndex !== null ? list[padIndex] : null;
  if (!gp || !gp.connected) {
    gp = [...list].find(g => g && g.connected && g.mapping === 'standard') || [...list].find(g => g && g.connected) || null;
    padIndex = gp ? gp.index : null;
  }
  if (gp) padStyle = /054c|playstation|dualsense|dualshock|wireless controller/i.test(gp.id) && !/xbox|xinput/i.test(gp.id) ? 'ps' : 'xbox';
  return gp;
}
const padName = gp => gp.id.replace(/\s*\(.*$/, '').replace(/^[0-9a-f]{4}-[0-9a-f]{4}-/i, '').trim() || 'Controller';
function rumble(strong, weak, ms) {
  if (!padMode() || state !== 'playing') return;
  const act = activePad()?.vibrationActuator;
  try { act?.playEffect?.('dual-rumble', { duration: ms, strongMagnitude: clamp(strong, 0, 1), weakMagnitude: clamp(weak, 0, 1) })?.catch?.(() => {}); } catch {}
}
let noteT = 0;
function padNote(text) {
  const el = $('padNote');
  el.innerHTML = ICONS.gamepad + '<span>' + text + '</span>';
  el.classList.add('on');
  clearTimeout(noteT); noteT = setTimeout(() => el.classList.remove('on'), 3200);
}
// refresh every on-screen key hint for the current input device
function applyInputMode() {
  const gp = activePad(), on = padMode() && !!gp;
  const eqKeys = { frag: ['G', 'LB'], stun: ['Z', 'up'], smoke: ['X', 'down'], tknife: ['T', 'left'] };
  document.querySelectorAll('.eq[data-e]').forEach(el => { const k = eqKeys[el.dataset.e]; if (k) el.querySelector('kbd').textContent = on ? PL()[k[1]] : k[0]; });
  document.querySelectorAll('.padB').forEach(el => el.textContent = PL().B);
  promptKey = '';
  $('padStatus').textContent = gp ? `Collegato: ${padName(gp)}` : 'Nessun controller rilevato: collegalo e premi un tasto qualsiasi';
  $('padStatus').style.color = gp ? 'var(--armor2)' : '';
  document.querySelectorAll('#inputSeg button').forEach(b => b.classList.toggle('sel', b.dataset.v === settings.input));
  renderBinds();
  if (!on) { clearPadFocus(); pad.mx = pad.my = 0; pad.jump = pad.sprint = false; }
}
function setInput(v, why) {
  if (settings.input === v) return applyInputMode();
  settings.input = v; saveSettings();
  if (v === 'pad') {
    // switch the legend to the controller tab and drop the mouse lock (the pad needs no cursor)
    document.querySelector('.ctabs button[data-t="3"]')?.click();
    if (state === 'playing' && document.pointerLockElement && activePad()) document.exitPointerLock();
  } else {
    document.querySelector('.ctabs button[data-t="0"]')?.click();
    if (state === 'playing' && !document.pointerLockElement) pause();
  }
  firing = aiming = false;
  applyInputMode();
  if (why) padNote(why);
}
function renderPadLegend() {
  const L = PL(), k = (...b) => b.map(x => `<kbd>${padBtn(x)}</kbd>`).join('');
  $('padLegend').innerHTML = [
    ['Muoviti / Guarda', k('ls', 'rs')], ['Spara / Mira', k('RT', 'LT')], ['Salta (×2 in arena)', k('A')], ['Corri', k('L3')],
    ['Accucciati · scivola (mentre corri)', k('B')], ['Ricarica · usa cassa / raccogli', k('X')], ['Cambia arma', k('Y')],
    ['Coltellata', k('RB', 'R3')], ['Sporgiti a sinistra / destra (mentre miri)', k('L3', 'R3')], ['Granata a frammentazione', k('LB')],
    ['Stordente · Fumogeno', k('up', 'down')], ['Coltello da lancio · Getta arma', k('left', 'right')],
    ['Avvia subito l’ondata', k('back')], ['Pausa', k('start')],
  ].map(([n, v]) => `<div class="ctrl"><span>${n}</span><span>${v}</span></div>`).join('') +
    '<p class="cnote">Nei menu: croce direzionale o stick sinistro per spostarti, stick destro per scorrere, ' + L.A + ' per confermare, ' + L.B + ' per tornare indietro. Collegando un controller il gioco passa da solo a questa modalità.</p>';
}
addEventListener('gamepadconnected', e => {
  padIndex = e.gamepad.index; activePad();
  setInput('pad', `Controller rilevato · modalità controller attiva`);
});
addEventListener('gamepaddisconnected', () => {
  padIndex = null;
  if (activePad()) return applyInputMode();
  if (padMode()) {
    if (state === 'playing') pause();
    setInput('kbm', 'Controller scollegato · torno a mouse e tastiera');
  } else applyInputMode();
});
document.querySelectorAll('#inputSeg button').forEach(b => b.addEventListener('click', () => setInput(b.dataset.v)));
document.querySelectorAll('#invSeg button').forEach(b => b.addEventListener('click', () => { settings.invertY = b.dataset.v === 'on'; saveSettings(); syncOptionUI(); }));
document.querySelectorAll('#assistSeg button').forEach(b => b.addEventListener('click', () => { settings.aimAssist = b.dataset.v === 'on'; saveSettings(); syncOptionUI(); }));
document.querySelectorAll('#fpsSeg button').forEach(b => b.addEventListener('click', () => { settings.fps = b.dataset.v === 'on'; saveSettings(); syncOptionUI(); }));

// ---------------------------------------------------------------- menu navigation with the pad
let padFocus = null, padLayer = null;
function uiLayer() {
  for (const id of ['quitDlg', 'settings', 'locker', 'shop', 'classMenu', 'mapMenu']) if (!$(id).classList.contains('hidden')) return $(id);
  return state !== 'playing' && !menu.classList.contains('hidden') ? menu : null;
}
function focusables(layer) {
  return [...layer.querySelectorAll('button, input[type=range]')].filter(el => !el.disabled && el.offsetParent !== null && el.getClientRects().length);
}
function clearPadFocus() { padFocus?.classList.remove('pfocus'); padFocus = null; }
function setPadFocus(el, sound = true) {
  if (el === padFocus) return;
  clearPadFocus();
  if (!el) return;
  padFocus = el; el.classList.add('pfocus');
  el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  if (sound) sfxUiHover();
}
function defaultFocus(layer) {
  if (layer.id === 'quitDlg') return $('quitNo');
  if (layer.id === 'classMenu') return layer.querySelector('.cls.sel') || $('startBtn');
  if (layer.id === 'mapMenu') return layer.querySelector('.mapc.sel') || $('mapNext');
  if (layer.id === 'shop') return layer.querySelector('.upg:not(:disabled), .perkc:not(:disabled)') || $('shopClose');
  if (layer.id === 'settings') return $('settingsClose');
  return $('play');
}
function padNav(dx, dy) {
  const layer = uiLayer(); if (!layer) return;
  const items = focusables(layer);
  if (!padFocus || !items.includes(padFocus)) return setPadFocus(defaultFocus(layer));
  if (padFocus.type === 'range' && dx) {
    // sliders: left/right change the value
    const el = padFocus, step = +el.step || 1;
    el.value = clamp(+el.value + dx * step, +el.min, +el.max);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    return sfxUiHover();
  }
  const r = padFocus.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
  const col = padFocus.closest('.set-col');
  let best = null, bs = Infinity;
  for (const el of items) {
    if (el === padFocus) continue;
    const q = el.getBoundingClientRect(), qx = q.left + q.width / 2, qy = q.top + q.height / 2;
    const cAlong = (qx - cx) * dx + (qy - cy) * dy;
    if (cAlong <= 6) continue;
    // edge gap along the direction + center offset across it; up/down prefer staying in the same settings column
    const gap = Math.max(0, dx > 0 ? q.left - r.right : dx < 0 ? r.left - q.right : dy > 0 ? q.top - r.bottom : r.top - q.bottom);
    const across = dx ? Math.abs(qy - cy) : Math.abs(qx - cx);
    const sc = gap + across * (dx ? 2 : 0.5) + (dy && col && !col.contains(el) ? 5000 : 0);
    if (sc < bs) { bs = sc; best = el; }
  }
  if (best) setPadFocus(best);
}
function padBack(layer) {
  if (layer.id === 'quitDlg') return $('quitNo').click();
  if (layer.id === 'settings') return $('settingsClose').click();
  if (layer.id === 'locker') return $('lockClose').click();
  if (layer.id === 'classMenu') return $('classBack').click();
  if (layer.id === 'mapMenu') return $('mapBack').click();
  if (layer.id === 'shop') return closeShop();
  if (menuType === 'pause') return $('play').click();
}
addEventListener('mousemove', () => { if (state !== 'playing' && padFocus) clearPadFocus(); });

// ---------------------------------------------------------------- per-frame polling
const padPrev = [];
let navHeld = '', navT = 0;
const dz = (x, y, d) => {
  // radial dead zone, rescaled so the stick still reaches 1
  const m = Math.hypot(x, y);
  if (m < d) return [0, 0];
  const k = Math.min(1, (m - d) / (1 - d)) / m;
  return [x * k, y * k];
};
function assistFriction() {
  if (!settings.aimAssist) return 1;
  const eye = camera.position, fwd = new V3(0, 0, -1).applyQuaternion(camera.quaternion);
  let f = 1;
  for (const b of enemies) {
    if (b.dead) continue;
    const t = new V3(b.pos.x, b.pos.y + 1.2, b.pos.z).sub(eye), d = t.length();
    if (d < 1 || d > 70) continue;
    // angular window scales with distance so it matches the body width on screen
    const ang = Math.acos(clamp(t.dot(fwd) / d, -1, 1)), win = Math.atan(0.9 / d) + 0.02;
    if (ang < win) f = Math.min(f, weapon.adsT > 0.5 ? 0.4 : 0.6);
  }
  return f;
}
function pollPad(dt) {
  const gp = activePad();
  if (!gp) return;
  const b = i => !!gp.buttons[i] && (gp.buttons[i].pressed || gp.buttons[i].value > 0.4);
  const cur = gp.buttons.map((_, i) => b(i));
  const down = i => cur[i] && !padPrev[i], up = i => !cur[i] && padPrev[i];
  const ax = gp.axes;
  // any input from the pad while the mouse is selected switches back to the controller
  if (!padMode() && (cur.some((v, i) => v && !padPrev[i]) || ax.some(v => Math.abs(v) > 0.6))) setInput('pad', 'Controller rilevato · modalità controller attiva');
  if (!padMode()) { cur.forEach((v, i) => padPrev[i] = v); return; }
  // settings waiting for a new button: the first one pressed is taken and does nothing else
  if (bindWait?.dev === 'pad') {
    const p = cur.findIndex((v, i) => v && !padPrev[i] && i < 16);
    if (p >= 0) { const id = bindWait.id; setPadBind(ACT[id].btn, p); bindsChanged(); setPadFocus($('bindList').querySelector(`button[data-id="${id}"][data-dev="pad"]`), false); }
    cur.forEach((v, i) => padPrev[i] = v); return;
  }

  if (state === 'playing' && uiLayer() === null) {
    const [mx, my] = dz(ax[0] || 0, ax[1] || 0, 0.16);
    pad.mx = mx; pad.my = -my;
    let [rx, ry] = dz(ax[2] || 0, ax[3] || 0, 0.12);
    const m = Math.hypot(rx, ry);
    if (m > 0) { const c = Math.pow(m, 1.7) / m; rx *= c; ry *= c; }  // response curve: fine aim near the center
    const ads = weapon.adsT > 0.5 ? (W().scope ? 0.3 : 0.6) : 1, rate = 3.3 * settings.padSens * ads * (m > 0 ? assistFriction() : 1);
    const dyaw = rx * rate * dt, dpitch = ry * rate * 0.7 * dt * (settings.invertY ? -1 : 1);
    player.yaw -= dyaw;
    player.pitch = clamp(player.pitch - dpitch, -1.5, 1.5);
    swayX += dyaw * 0.068; swayY += dpitch * 0.068;

    pad.jump = cur[padOf(0)];
    if (down(padOf(0))) gameKey('Space');
    if (down(padOf(1))) gameKey('KeyC');
    if (down(padOf(2))) { if (interactTarget()) interact(); else startReload(); }
    if (down(padOf(3))) switchWeapon(otherSlot());
    if (down(padOf(4))) throwItem('frag');
    if (down(padOf(5))) startMelee();
    // Rainbow Six Siege on console: L3/R3 lean while aiming, otherwise sprint / melee
    if (down(padOf(10))) { if (isAiming()) toggleLean(-1); else pad.sprint = !pad.sprint; }
    if (down(padOf(11))) { if (isAiming()) toggleLean(1); else startMelee(); }
    if (pad.my < 0.2) pad.sprint = false;
    if (down(padOf(12))) throwItem('stun');
    if (down(padOf(13))) throwItem('smoke');
    if (down(padOf(14))) throwItem('tknife');
    if (down(padOf(15))) dropCurrentWeapon();
    if (down(padOf(8))) gameKey('Enter');
    if (down(padOf(7))) { firing = true; triggerQueued = true; triggerT = now; }
    if (up(padOf(7))) firing = false;
    if (settings.adsHold) { if (down(padOf(6))) aiming = true; if (up(padOf(6))) aiming = false; }
    else if (down(padOf(6))) aiming = !aiming;
    if (down(padOf(9))) pauseGame();
  } else {
    pad.mx = pad.my = 0; pad.jump = false;
    const layer = uiLayer();
    if (layer) {
      let fresh = false;
      if (!padFocus || !layer.contains(padFocus) || padLayer !== layer) {
        padLayer = layer;
        if (padFocus || cur.some(Boolean)) { fresh = !padFocus; setPadFocus(defaultFocus(layer), false); }
      }
      const [sx, sy] = dz(ax[0] || 0, ax[1] || 0, 0.5);
      const dir = cur[12] || sy < -0.5 ? 'u' : cur[13] || sy > 0.5 ? 'd' : cur[14] || sx < -0.5 ? 'l' : cur[15] || sx > 0.5 ? 'r' : '';
      if (dir !== navHeld) { navHeld = dir; navT = 0.38; if (dir) padNav(...{ u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0] }[dir]); }
      else if (dir && (navT -= dt) <= 0) { navT = 0.11; padNav(...{ u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0] }[dir]); }
      const [, scy] = dz(ax[2] || 0, ax[3] || 0, 0.2);
      if (scy) { const sc = layer.id === 'settings' || layer.id === 'locker' || layer.id === 'classMenu' || layer.id === 'mapMenu' || layer.id === 'shop' ? layer : layer === menu ? (menu.scrollHeight > menu.clientHeight ? menu : menu.querySelector('.controls-card')) : null; sc?.scrollBy(0, scy * Math.abs(scy) * 1400 * dt); }
      if (down(0) && !fresh && padFocus && layer.contains(padFocus)) padFocus.click();
      if (down(1)) padBack(layer);
      if (down(9) && layer === menu) $('play').click();
      // bumpers: jump between settings columns
      if ((down(4) || down(5)) && layer.id === 'settings') {
        const cols = [...layer.querySelectorAll('.set-col')], i = cols.indexOf(padFocus?.closest('.set-col'));
        const next = cols[i < 0 ? 0 : (i + (down(5) ? 1 : cols.length - 1)) % cols.length];
        setPadFocus(focusables(next)[0]);
      }
      // bumpers flip the legend tabs on the main menu
      if ((down(4) || down(5)) && layer === menu) {
        const tabs = [...document.querySelectorAll('.ctabs button')], i = tabs.findIndex(t => t.classList.contains('sel'));
        tabs[(i + (down(5) ? 1 : tabs.length - 1)) % tabs.length].click();
      }
    }
  }
  cur.forEach((v, i) => padPrev[i] = v);
}
activePad();
applyInputMode();

// ============================================================ main loop
const clock = new THREE.Clock();
let menuT = 0;
holder.visible = false;
applyAtmosphere(mode);
showMainMenu();
// start the audio right away when the browser allows it (the launcher enables autoplay);
// otherwise the context stays suspended and unlockMusic resumes it on the first click/keypress
initAudio();
let padPlay = false;
// optional frame counter: averaged over half a second so the number stays readable
const fpsMeter = { t: performance.now(), n: 0 };
$('fps').classList.toggle('on', !!settings.fps);
renderer.setAnimationLoop(() => {
  const dt = Math.min(clock.getDelta(), 0.05);
  if (settings.fps) {
    const t = performance.now(); fpsMeter.n++;
    if (t - fpsMeter.t >= 500) { $('fps').textContent = Math.round(fpsMeter.n * 1000 / (t - fpsMeter.t)) + ' FPS'; fpsMeter.t = t; fpsMeter.n = 0; }
  }
  pollPad(dt);
  const pp = state === 'playing' && padMode() && !document.pointerLockElement;
  if (pp !== padPlay) { padPlay = pp; document.body.classList.toggle('padplay', pp); }
  updateTouchUi();
  if (state === 'playing') {
    now += dt;
    updatePlayer(dt);
    withCat('weapons', () => updateWeapon(dt));
    withCat('enemies', () => updateEnemies(dt));
    if (state === 'playing') { updateWaves(dt); updatePickups(dt); updateThrowables(dt); updateArena(dt); updateBox(dt); updateDrops(dt); updateHouses(dt); updateTutorial(dt); if ((chalT -= dt) <= 0) { chalT = 1; checkChallenges(); } updateInteract(); drawMinimap(); }
    updateFx(dt);
    updateDamageNumbers(dt);
    if (state === 'playing') updateHUD(dt);
  } else if (state === 'menu') {
    menuT += dt * 0.08;
    camera.position.set(Math.sin(menuT) * MAP.orbit[0], MAP.orbit[1], Math.cos(menuT) * MAP.orbit[0]);
    camera.lookAt(0, 2, 0);
  }
  updateAmbient(dt);
  sky.position.copy(camera.position);
  gunPass.enabled = state !== 'menu';
  composer.render();
});
