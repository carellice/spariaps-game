// Spariaps — Utilità, impostazioni di gioco, renderer e texture procedurali.
// I file in js/ sono script classici caricati in ordine da index.html e condividono lo stesso ambito globale
// (non moduli: così il gioco parte anche aprendo index.html direttamente da file).
'use strict';
// three.js and its addons ship with the game (vendor/three.bundle.js), so it also starts offline and from file://
const { THREE, EffectComposer, RenderPass, UnrealBloomPass, OutputPass, ShaderPass, RoomEnvironment, RoundedBoxGeometry, mergeGeometries } = window.SPARIAPS_LIB;

// ============================================================ utils
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = t => t * t * (3 - 2 * t);
const $ = id => document.getElementById(id);
const V3 = THREE.Vector3;
const rbox = (w, h, d, r, seg = 3) => new RoundedBoxGeometry(w, h, d, seg, Math.min(r, w / 2 - 1e-3, h / 2 - 1e-3, d / 2 - 1e-3));
const store = {
  get(k, def) { try { const v = localStorage.getItem(k); return v === null ? def : v; } catch { return def; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
};

const ICONS = {
  gamepad: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7h10a5 5 0 0 1 4.9 6l-.8 4a2.4 2.4 0 0 1-4.2 1L15 16H9l-1.9 2a2.4 2.4 0 0 1-4.2-1l-.8-4A5 5 0 0 1 7 7z"/><path d="M8 10v4M6 12h4"/><circle cx="15.5" cy="11" r=".6" fill="currentColor"/><circle cx="17.5" cy="13" r=".6" fill="currentColor"/></svg>',
  rifle: '<svg viewBox="0 0 64 22" fill="currentColor"><path d="M1 8h6l2-2h22l2-2h9v2h9V4h2v4h9v3H48l-3 2h-9l-3 8h-6l2-8H16l-2 5H5l1-5H1z"/></svg>',
  pistol: '<svg viewBox="0 0 34 22" fill="currentColor"><path d="M2 3h28v3h2v3H14l-3 11H4l3-11H2z"/></svg>',
  knife: '<svg viewBox="0 0 52 16" fill="currentColor"><path d="M1 6h13v4H1zM14 3h4v10h-4zM18 5h22l11 3-11 3H18z"/></svg>',
  cross: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6v7h7v6h-7v7H9v-7H2V9h7z"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l8 3v6c0 5-3.4 9.3-8 11-4.6-1.7-8-6-8-11V5z"/></svg>',
  shotgun: '<svg viewBox="0 0 66 18" fill="currentColor"><path d="M1 7h8l2-2h41v2h13v3H52v2H34l-2 1H19l-3 5H9l2-5H1z"/></svg>',
  sniper: '<svg viewBox="0 0 74 22" fill="currentColor"><path d="M1 12h8l2-2h14V7h3V4h16v3h3v3h26v3H49l-2 2H35l-3 7h-6l2-7H14l-2 4H4l1-4H1z"/></svg>',
  lmg: '<svg viewBox="0 0 66 26" fill="currentColor"><path d="M1 9h7l2-2h24V3h12v4h19v3H47v3h-4a7 7 0 0 1-14 0H16l-2 5H6l1-5H1z"/></svg>',
  smg: '<svg viewBox="0 0 46 24" fill="currentColor"><path d="M1 6h4l1-2h22l1 2h16v3H30v3h-4l-2 10h-5l2-10h-6l-2 4H5l1-4H1z"/></svg>',
  jump: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l7-7 7 7M5 19l7-7 7 7"/></svg>',
  haste: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.5 1L4 14h6.5L9 23l11-14h-6.8z"/></svg>',
  quad: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a9 9 0 0 0-9 9c0 3 1.5 5.2 3.5 6.5V21h3v-2h1v2h3v-2h1v2h3v-3.5c2-1.3 3.5-3.5 3.5-6.5a9 9 0 0 0-9-9zm-3.5 8a2 2 0 1 1 0 4 2 2 0 0 1 0-4zm7 0a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"/></svg>',
  ammo: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"><path d="M12 12c-2-2.7-3.7-4-5.5-4a4 4 0 0 0 0 8c1.8 0 3.5-1.3 5.5-4zm0 0c2 2.7 3.7 4 5.5 4a4 4 0 0 0 0-8c-1.8 0-3.5 1.3-5.5 4z"/></svg>',
  god: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1.5l3.1 6.6 7.2.9-5.3 5 1.4 7.1L12 17.6l-6.4 3.5L7 14l-5.3-5 7.2-.9z"/></svg>',
  coin: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15.9V19h-2v-1.1c-1.6-.3-2.8-1.3-3-2.9h2c.2.7.9 1.2 2 1.2 1.3 0 1.8-.6 1.8-1.2 0-.7-.4-1.1-2-1.5-2-.5-3.4-1.2-3.4-3 0-1.4 1.1-2.4 2.6-2.8V6.6h2v1.1c1.5.3 2.4 1.4 2.5 2.7h-2c-.1-.7-.6-1.1-1.6-1.1-1 0-1.6.5-1.6 1.1 0 .6.5.9 2 1.3 2 .5 3.4 1.3 3.4 3.2 0 1.5-1.1 2.6-2.7 3z"/></svg>',
  frag: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 2h5v2h-1v1.1A7 7 0 1 1 7.6 7L6.3 5.7l1.4-1.4L9 5.6a7 7 0 0 1 3-.5V4h-2zm2 6a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm-2 2h4v1.5h-4zm0 3h4v1.5h-4z"/></svg>',
  stun: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6v2h-1v2h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h2V4H9zm-.5 8v2h7v-2zm0 4v2h7v-2z"/><path d="M2 9l3 1-3 1zm20 0l-3 1 3 1zM3 4l3 3-1 1zm18 0l-3 3 1 1z"/></svg>',
  smoke: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 11h4v2h1a1 1 0 0 1 1 1v8H8v-8a1 1 0 0 1 1-1h1z"/><circle cx="9" cy="6" r="3"/><circle cx="14.5" cy="4.5" r="2.5"/><circle cx="16" cy="9" r="2"/><circle cx="6" cy="9.5" r="1.8"/></svg>',
  tknife: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M21.5 2.5L10 11l3 3 8.5-11.5zM9.3 12.2l2.5 2.5-1.4 1.4-.7-.7-4.9 4.9a1.5 1.5 0 0 1-2.1-2.1l4.9-4.9-.7-.7z"/></svg>',
  magnum: '<svg viewBox="0 0 44 24" fill="currentColor"><path d="M1 5h26v-2h3v2h13v4H28v1h-3v2h-4l-4 3h-3l-3 8H5l3-9H4l-1-3H1z"/></svg>',
  raygun: '<svg viewBox="0 0 44 26" fill="currentColor"><path d="M4 7h16l3-3h4l3 2h5l3-2h4v12h-4l-3-2h-5l-3 2h-4l-3-2h-2l-3 10H8l3-10H4z"/><path d="M26 7h2v8h-2zM31 7h2v8h-2z" fill-opacity=".45"/></svg>',
  uzi: '<svg viewBox="0 0 36 24" fill="currentColor"><path d="M2 4h26v3h6v3H22v2h-4l-1 10h-5l1-10H8l-1 3H3z"/></svg>',
  burst: '<svg viewBox="0 0 64 22" fill="currentColor"><path d="M1 9h8l2-3h24l2-2h8v2h8V4h2v5h8v3H50l-3 2h-9l-3 7h-6l2-7H17l-3 5H6l1-5H1z"/></svg>',
  dmr: '<svg viewBox="0 0 72 22" fill="currentColor"><path d="M1 11h8l2-2h12V6h4V3h14v3h3v3h28v3H46l-2 2H33l-3 7h-6l2-7H14l-2 4H4l1-4H1z"/></svg>',
  minigun: '<svg viewBox="0 0 66 26" fill="currentColor"><path d="M1 8h10V4h14v4h6V6h33v3H33v2h31v3H33v2h31v3H33v-2h-4l-3 7h-8l2-7H11l-2 3H3z"/></svg>',
  rocket: '<svg viewBox="0 0 70 22" fill="currentColor"><path d="M1 6h4l2 2h44l2-3h8l8 6-8 6h-8l-2-3H38l-2 7h-6l1-7H20l-2 5h-6l2-5H7l-2 2H1z"/></svg>',
  pad: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M7 9l5-5 5 5M7 14l5-5 5 5"/><ellipse cx="12" cy="19" rx="9" ry="2.6"/></svg>',
  box: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 8h18v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zm-1-4h20v3H2zm8.2 7.4c0-1.1.9-1.9 2-1.9s1.9.8 1.9 1.8c0 1.4-1.7 1.5-1.7 2.9h-1c0-1.9 1.6-2 1.6-2.9 0-.5-.4-.8-.8-.8-.5 0-.9.4-.9.9zm1.3 4.3h1.2v1.2h-1.2z"/></svg>',
};
document.querySelectorAll('[data-icon]').forEach(el => { el.outerHTML = ICONS[el.dataset.icon]; });

// ============================================================ game settings: modes + difficulty
const DIFFS = {
  easy:      { name: 'FACILE',    dmg: 0.6,  acc: 0.7,  hp: 0.8,  count: 0.8,  speed: 0.9,  regen: 16, regenDelay: 4,   score: 0.75, climb: 0.08, desc: 'Nemici lenti e poco precisi, rigenerazione rapida.' },
  normal:    { name: 'NORMALE',   dmg: 1,    acc: 1,    hp: 1,    count: 1,    speed: 1,    regen: 12, regenDelay: 5,   score: 1,    climb: 0.16, desc: 'L’esperienza bilanciata.' },
  hard:      { name: 'DIFFICILE', dmg: 1.35, acc: 1.2,  hp: 1.25, count: 1.2,  speed: 1.1,  regen: 8,  regenDelay: 6,   score: 1.5,  climb: 0.26, desc: 'Più nemici, più resistenti e più letali. Punti ×1.5' },
  nightmare: { name: 'INCUBO',    dmg: 1.75, acc: 1.4,  hp: 1.6,  count: 1.45, speed: 1.2,  regen: 4,  regenDelay: 8,   score: 2.2,  climb: 0.38, desc: 'Solo per veterani. Quasi nessuna rigenerazione. Punti ×2.2' },
};
DIFFS.progressive = { ...DIFFS.easy, name: 'PROGRESSIVA', desc: 'Parte facile e si fa più dura a ogni ondata superata, fino a Incubo e oltre. I punti crescono con lei.' };
// progressive: interpolate from Facile (wave 1) to Incubo (wave 11), then keep climbing a bit
function diffFor(w) {
  if (diffKey !== 'progressive') return DIFFS[diffKey];
  const t = clamp((w - 1) / 10, 0, 1.4), e = DIFFS.easy, n = DIFFS.nightmare, o = { ...DIFFS.progressive, level: t };
  for (const k of ['dmg', 'acc', 'hp', 'count', 'speed', 'regen', 'regenDelay', 'score', 'climb']) o[k] = lerp(e[k], n[k], t);
  o.regen = Math.max(3, o.regen); o.regenDelay = Math.min(9, o.regenDelay);
  return o;
}
let mode = store.get('spariaps-mode', 'classic');
let diffKey = store.get('spariaps-diff', 'normal');
if (!DIFFS[diffKey]) diffKey = 'normal';
if (mode !== 'zombie') mode = 'classic';
let D = diffFor(1);

const SETTINGS_DEFAULT = { lights: 1, bright: 1, sens: 1, adsHold: true, autoAds: false, quality: 'high',
  input: 'kbm', padSens: 1, invertY: false, aimAssist: true, fps: false, binds: {}, padBinds: {},
  volMaster: 1, volMusic: 0.7, volWeapons: 1, volEnemies: 1, volFx: 1, volUi: 0.8 };
const settings = { ...SETTINGS_DEFAULT };
try { Object.assign(settings, JSON.parse(store.get('spariaps-settings', '{}'))); } catch {}
settings.binds = { ...settings.binds }; settings.padBinds = { ...settings.padBinds };
const saveSettings = () => store.set('spariaps-settings', JSON.stringify(settings));
const lightK = () => Math.max(0.35, settings.lights);

// ============================================================ renderer / scenes / post-processing
const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.95;
document.body.prepend(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color();
scene.fog = new THREE.Fog(0xffffff, 45, 175);

const camera = new THREE.PerspectiveCamera(75, innerWidth / innerHeight, 0.05, 400);
camera.rotation.order = 'YXZ';
scene.add(camera);

const pmrem = new THREE.PMREMGenerator(renderer);
const envTex = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environment = envTex;

const hemi = new THREE.HemisphereLight(0xe2ecff, 0x5a4a3a, 0.5);
scene.add(hemi);
const SUN_DIR = new V3(30, 55, 20).normalize();
const sun = new THREE.DirectionalLight(0xfff0dd, 2.4);
sun.position.copy(SUN_DIR).multiplyScalar(80);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -48, right: 48, top: 48, bottom: -48, near: 1, far: 200 });
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.03;
scene.add(sun);

const muzzleLight = new THREE.PointLight(0xffb060, 0, 14, 2);
muzzleLight.position.set(0.2, -0.1, -1);
camera.add(muzzleLight);
// weapon torch, only switched on at night (zombie mode)
const torch = new THREE.SpotLight(0xfff1d6, 0, 40, 0.42, 0.55, 1.4);
torch.position.set(0.25, -0.2, 0);
torch.target.position.set(0.1, -0.35, -6);
camera.add(torch, torch.target);

const skyMat = new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false, fog: false,
  uniforms: { top: { value: new THREE.Color() }, mid: { value: new THREE.Color() }, bottom: { value: new THREE.Color() }, sunDir: { value: SUN_DIR }, glow: { value: 1 }, sunCol: { value: new THREE.Color(1, 0.92, 0.75) } },
  vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: `uniform vec3 top, mid, bottom, sunDir, sunCol; uniform float glow; varying vec3 vDir;
    void main(){
      vec3 d = normalize(vDir); float h = d.y;
      vec3 c = h > 0.0 ? mix(mid, top, pow(h, 0.5)) : mix(mid, bottom, min(1.0, -h * 5.0));
      float s = max(dot(d, sunDir), 0.0);
      c += sunCol * (pow(s, 900.0) * 12.0 + pow(s, 14.0) * 0.4) * glow;
      gl_FragColor = vec4(c, 1.0);
    }`,
});
const sky = new THREE.Mesh(new THREE.SphereGeometry(300, 32, 16), skyMat);
sky.renderOrder = -1;
scene.add(sky);

const gunScene = new THREE.Scene();
gunScene.environment = envTex;
const gunCam = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.01, 10);
gunScene.add(new THREE.HemisphereLight(0xffffff, 0x445066, 0.8));
const gunLight = new THREE.DirectionalLight(0xfff2e0, 2.2);
gunLight.position.set(1, 2, 1.2);
gunScene.add(gunLight);
const gunRim = new THREE.DirectionalLight(0x9ecbff, 1.2);
gunRim.position.set(-2, 0.5, -1);
gunScene.add(gunRim);
const gunMuzzleLight = new THREE.PointLight(0xffa040, 0, 3, 2);
gunScene.add(gunMuzzleLight);

const GradeShader = {
  uniforms: { tDiffuse: { value: null }, hurt: { value: 0 }, aberr: { value: 0.0015 }, tint: { value: new THREE.Vector3(1, 1, 1) } },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: `uniform sampler2D tDiffuse; uniform float hurt, aberr; uniform vec3 tint; varying vec2 vUv;
    void main(){
      vec2 d = vUv - 0.5; float r = dot(d, d);
      vec2 off = d * aberr * (0.4 + r * 4.0);
      vec3 c = vec3(texture2D(tDiffuse, vUv + off).r, texture2D(tDiffuse, vUv).g, texture2D(tDiffuse, vUv - off).b);
      float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
      c = mix(vec3(l), c, 1.12) * tint;
      c = (c - 0.5) * 1.05 + 0.5;
      c *= 1.0 - r * 0.75;
      c = mix(c, c * vec3(1.35, 0.45, 0.4) + vec3(0.12, 0.0, 0.0), hurt * smoothstep(0.04, 0.32, r));
      gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
    }`,
};

const rt = new THREE.WebGLRenderTarget(innerWidth, innerHeight, { type: THREE.HalfFloatType, samples: 4 });
const composer = new EffectComposer(renderer, rt);
composer.setPixelRatio(renderer.getPixelRatio());
composer.setSize(innerWidth, innerHeight);
composer.addPass(new RenderPass(scene, camera));
const gunPass = new RenderPass(gunScene, gunCam);
gunPass.clear = false;
gunPass.clearDepth = true;
composer.addPass(gunPass);
const bloomPass = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.5, 0.55, 1.0);
composer.addPass(bloomPass);
composer.addPass(new OutputPass());
const gradePass = new ShaderPass(GradeShader);
composer.addPass(gradePass);

// graphics presets: resolution scale, shadows, bloom and MSAA
const QUALITY = {
  low:    { name: 'BASSA', pr: 0.75, shadows: false, shadowSize: 512,  soft: false, bloom: false, samples: 0, hint: 'Niente ombre né bagliore, risoluzione ridotta: per PC poco potenti' },
  medium: { name: 'MEDIA', pr: 1,    shadows: true,  shadowSize: 1024, soft: false, bloom: true,  samples: 2, hint: 'Ombre semplici e risoluzione standard: un buon equilibrio' },
  high:   { name: 'ALTA',  pr: 1.5,  shadows: true,  shadowSize: 2048, soft: true,  bloom: true,  samples: 4, hint: 'Ombre morbide, bagliore e antialiasing: la resa migliore' },
};
function applyQuality() {
  const Q = QUALITY[settings.quality] || QUALITY.high;
  const pr = settings.quality === 'low' ? Math.min(devicePixelRatio, 1) * Q.pr : Math.min(devicePixelRatio, Q.pr);
  renderer.setPixelRatio(pr); composer.setPixelRatio(pr);
  const type = Q.soft ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  if (renderer.shadowMap.enabled !== Q.shadows || renderer.shadowMap.type !== type) {
    renderer.shadowMap.enabled = Q.shadows; renderer.shadowMap.type = type;
    for (const sc of [scene, gunScene]) sc.traverse(o => { if (o.material) [].concat(o.material).forEach(m => m.needsUpdate = true); });
  }
  if (sun.shadow.mapSize.x !== Q.shadowSize) {
    sun.shadow.mapSize.set(Q.shadowSize, Q.shadowSize);
    if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
  }
  bloomPass.enabled = Q.bloom;
  for (const t of [composer.renderTarget1, composer.renderTarget2]) if (t.samples !== Q.samples) { t.samples = Q.samples; t.dispose(); }
  composer.setSize(innerWidth, innerHeight);
}
applyQuality();

addEventListener('resize', () => {
  renderer.setSize(innerWidth, innerHeight);
  composer.setSize(innerWidth, innerHeight);
  camera.aspect = gunCam.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix(); gunCam.updateProjectionMatrix();
});

// ============================================================ procedural textures
function canvas(s) { const c = document.createElement('canvas'); c.width = c.height = s; return [c, c.getContext('2d')]; }
function finishTex(c, color = true) {
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  if (color) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = renderer.capabilities.getMaxAnisotropy();
  return t;
}
function surface({ base, seam, cells, blotch = 0.1, dirt = 0, size = 512 }) {
  const [c, g] = canvas(size), [bc, bg] = canvas(size);
  g.fillStyle = base; g.fillRect(0, 0, size, size);
  bg.fillStyle = '#b0b0b0'; bg.fillRect(0, 0, size, size);
  for (let i = 0; i < 70; i++) {
    const x = Math.random() * size, y = Math.random() * size, r = rand(30, 110), dark = Math.random() < 0.6;
    for (const [ctx, col] of [[g, dark ? `rgba(0,0,0,${blotch})` : `rgba(255,255,255,${blotch * 0.6})`], [bg, dark ? 'rgba(0,0,0,.06)' : 'rgba(255,255,255,.06)']]) {
      const gr = ctx.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = gr; ctx.fillRect(x - r, y - r, r * 2, r * 2);
    }
  }
  for (let i = 0; i < 7000; i++) {
    const x = Math.random() * size, y = Math.random() * size, v = Math.random();
    g.fillStyle = `rgba(${v < .5 ? '0,0,0' : '255,255,255'},${Math.random() * 0.05})`; g.fillRect(x, y, 2, 2);
    bg.fillStyle = `rgba(${v < .5 ? '0,0,0' : '255,255,255'},.18)`; bg.fillRect(x, y, 1.5, 1.5);
  }
  if (dirt) {
    const gr = g.createLinearGradient(0, size * 0.6, 0, size);
    gr.addColorStop(0, 'rgba(30,22,14,0)'); gr.addColorStop(1, `rgba(30,22,14,${dirt})`);
    g.fillStyle = gr; g.fillRect(0, 0, size, size);
  }
  const step = size / cells;
  g.strokeStyle = seam; g.lineWidth = 2; bg.strokeStyle = '#3a3a3a'; bg.lineWidth = 3;
  for (let i = 0; i <= cells; i++) for (const ctx of [g, bg]) {
    ctx.beginPath(); ctx.moveTo(i * step, 0); ctx.lineTo(i * step, size); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, i * step); ctx.lineTo(size, i * step); ctx.stroke();
  }
  return { map: finishTex(c), bumpMap: finishTex(bc, false) };
}
function crateTex() {
  const s = 256, [c, g] = canvas(s), [bc, bg] = canvas(s);
  g.fillStyle = '#8f6f46'; g.fillRect(0, 0, s, s);
  bg.fillStyle = '#909090'; bg.fillRect(0, 0, s, s);
  for (let i = 0; i < 16; i++) {
    const y = i * 16 + rand(0, 6);
    g.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`; g.fillRect(0, y, s, 2);
    bg.fillStyle = '#6a6a6a'; bg.fillRect(0, y, s, 1);
  }
  for (const [ctx, col] of [[g, '#5e4429'], [bg, '#e0e0e0']]) {
    ctx.strokeStyle = col; ctx.lineWidth = 20; ctx.strokeRect(10, 10, s - 20, s - 20);
    ctx.beginPath(); ctx.moveTo(16, 16); ctx.lineTo(s - 16, s - 16); ctx.stroke();
  }
  return { map: finishTex(c), bumpMap: finishTex(bc, false) };
}
function barrelTex(color) {
  const s = 256, [c, g] = canvas(s);
  g.fillStyle = color; g.fillRect(0, 0, s, s);
  for (const y of [0.18, 0.5, 0.82]) { g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(0, y * s - 4, s, 8); g.fillStyle = 'rgba(255,255,255,.14)'; g.fillRect(0, y * s - 6, s, 2); }
  for (let i = 0; i < 2000; i++) { g.fillStyle = `rgba(40,20,10,${Math.random() * 0.16})`; g.fillRect(Math.random() * s, Math.random() * s, 3, 3); }
  return finishTex(c);
}
function radialTex(stops) {
  const s = 128, [c, g] = canvas(s);
  const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  stops.forEach(([o, col]) => gr.addColorStop(o, col));
  g.fillStyle = gr; g.fillRect(0, 0, s, s);
  return new THREE.CanvasTexture(c);
}
const flashTex = radialTex([[0, 'rgba(255,255,240,1)'], [0.25, 'rgba(255,220,120,.9)'], [0.6, 'rgba(255,140,40,.35)'], [1, 'rgba(255,100,0,0)']]);
const holeTex = radialTex([[0, 'rgba(10,10,10,1)'], [0.35, 'rgba(20,20,20,.9)'], [0.6, 'rgba(40,40,40,.4)'], [1, 'rgba(0,0,0,0)']]);
const smokeTex = radialTex([[0, 'rgba(255,255,255,.55)'], [0.5, 'rgba(255,255,255,.2)'], [1, 'rgba(255,255,255,0)']]);
const cloudTex = radialTex([[0, 'rgba(255,255,255,.95)'], [0.45, 'rgba(255,255,255,.6)'], [0.8, 'rgba(255,255,255,.18)'], [1, 'rgba(255,255,255,0)']]);
// explosion textures: a lumpy fireball blob and a billowing smoke puff
function blobbyTex(stops, n, spread) {
  const s = 128, [c, g] = canvas(s);
  for (let i = 0; i < n; i++) {
    const x = s / 2 + rand(-spread, spread), y = s / 2 + rand(-spread, spread), r = rand(18, 40), gr = g.createRadialGradient(x, y, 0, x, y, r);
    stops.forEach(([o, col]) => gr.addColorStop(o, col)); g.fillStyle = gr; g.fillRect(0, 0, s, s);
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
const fireTex = blobbyTex([[0, 'rgba(255,250,220,.55)'], [0.35, 'rgba(255,190,90,.35)'], [0.7, 'rgba(230,80,20,.15)'], [1, 'rgba(120,20,0,0)']], 9, 22);
const puffTex = blobbyTex([[0, 'rgba(255,255,255,.34)'], [0.6, 'rgba(255,255,255,.16)'], [1, 'rgba(255,255,255,0)']], 10, 24);
const glowTex = radialTex([[0, 'rgba(255,255,255,.9)'], [0.35, 'rgba(255,255,255,.35)'], [1, 'rgba(255,255,255,0)']]);

function boxUV(geo, tile, yOffset = 0) {
  const pos = geo.attributes.position, nor = geo.attributes.normal, uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) {
    const nx = Math.abs(nor.getX(i)), ny = Math.abs(nor.getY(i)), nz = Math.abs(nor.getZ(i));
    const x = pos.getX(i), y = pos.getY(i) + yOffset, z = pos.getZ(i);
    if (nx >= ny && nx >= nz) uv.setXY(i, z / tile, y / tile);
    else if (ny >= nz) uv.setXY(i, x / tile, z / tile);
    else uv.setXY(i, x / tile, y / tile);
  }
  uv.needsUpdate = true;
  return geo;
}

// ---------------------------------------------------------------- helpers needed while the maps are being built (defined here so they exist before js/world.js runs)
function beamMat(color, k = 0.55) {
  return new THREE.ShaderMaterial({
    uniforms: { color: { value: new THREE.Color(color) }, k: { value: k } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
    fragmentShader: 'uniform vec3 color; uniform float k; varying vec2 vUv; void main(){ float a = pow(clamp(1.0 - vUv.y, 0.0, 1.0), 1.5) * k * (0.6 + 0.4 * sin(vUv.x * 6.2832 * 3.0)); gl_FragColor = vec4(color * a, a); }',
  });
}
