# Spariaps — Stato condiviso, tabelle di gioco e salvataggi.
# Autoload "G": ogni modulo legge e scrive qui lo stato della partita e trova gli altri moduli.
extends Node

# ============================================================ modules (filled by main.gd)
var main: Node
var world: Node
var audio: Node
var fx: Node
var player: Node
var weapons: Node
var enemies: Node
var items: Node
var game: Node
var ui: Node
var inp: Node
var camera: Camera3D
var scene_root: Node3D

# ============================================================ storage: one config file in the user folder
var _cfg := ConfigFile.new()
const CFG_PATH := "user://spariaps.cfg"
var _dirty := false

func _init() -> void:
	_cfg.load(CFG_PATH)

func sget(k: String, def: Variant = null) -> Variant:
	return _cfg.get_value("store", k, def)

func sset(k: String, v: Variant) -> void:
	_cfg.set_value("store", k, v)
	_dirty = true

func flush() -> void:
	if _dirty:
		_dirty = false
		_cfg.save(CFG_PATH)

func _process(_dt: float) -> void:
	if _dirty and Engine.get_process_frames() % 30 == 0:
		flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()

# ============================================================ utils
func rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)

static func smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

static func col(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)

static func css(s: String) -> Color:
	return Color.html(s)

func light_k() -> float:
	return maxf(0.35, settings.lights)

func clock_str(t: float) -> String:
	var s := int(t)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%d:%02d" % [m, s % 60]

# ============================================================ modes + difficulty
const DIFFS := {
	"easy": { "name": "FACILE", "dmg": 0.6, "acc": 0.7, "hp": 0.8, "count": 0.8, "speed": 0.9, "regen": 16.0, "regenDelay": 4.0, "score": 0.75, "climb": 0.08, "desc": "Nemici lenti e poco precisi, rigenerazione rapida." },
	"normal": { "name": "NORMALE", "dmg": 1.0, "acc": 1.0, "hp": 1.0, "count": 1.0, "speed": 1.0, "regen": 12.0, "regenDelay": 5.0, "score": 1.0, "climb": 0.16, "desc": "L’esperienza bilanciata." },
	"hard": { "name": "DIFFICILE", "dmg": 1.35, "acc": 1.2, "hp": 1.25, "count": 1.2, "speed": 1.1, "regen": 8.0, "regenDelay": 6.0, "score": 1.5, "climb": 0.26, "desc": "Più nemici, più resistenti e più letali. Punti ×1.5" },
	"nightmare": { "name": "INCUBO", "dmg": 1.75, "acc": 1.4, "hp": 1.6, "count": 1.45, "speed": 1.2, "regen": 4.0, "regenDelay": 8.0, "score": 2.2, "climb": 0.38, "desc": "Solo per veterani. Quasi nessuna rigenerazione. Punti ×2.2" },
}
const DIFF_ORDER := ["easy", "normal", "hard", "nightmare", "progressive"]
const PROGRESSIVE_DESC := "Parte facile e si fa più dura a ogni ondata superata, fino a Incubo e oltre. I punti crescono con lei."

var mode := "classic"
var diff_key := "normal"
var D: Dictionary = {}

# progressive: interpolate from Facile (wave 1) to Incubo (wave 11), then keep climbing a bit
func diff_for(w: int) -> Dictionary:
	if diff_key != "progressive":
		return DIFFS[diff_key]
	var t := clampf((w - 1) / 10.0, 0.0, 1.4)
	var e: Dictionary = DIFFS.easy
	var n: Dictionary = DIFFS.nightmare
	var o := e.duplicate()
	o.name = "PROGRESSIVA"; o.desc = PROGRESSIVE_DESC; o.level = t
	for k in ["dmg", "acc", "hp", "count", "speed", "regen", "regenDelay", "score", "climb"]:
		o[k] = lerpf(e[k], n[k], t)
	o.regen = maxf(3.0, o.regen); o.regenDelay = minf(9.0, o.regenDelay)
	return o

# ============================================================ settings
const SETTINGS_DEFAULT := { "lights": 1.0, "bright": 1.0, "sens": 1.0, "adsHold": true, "autoAds": false, "quality": "high",
	"input": "kbm", "padSens": 1.0, "invertY": false, "aimAssist": true, "fps": false, "binds": {}, "padBinds": {},
	"volMaster": 1.0, "volMusic": 0.7, "volWeapons": 1.0, "volEnemies": 1.0, "volFx": 1.0, "volUi": 0.8, "fullscreen": true }
var settings: Dictionary = {}
var muted := false

func save_settings() -> void:
	sset("settings", settings.duplicate(true))

const QUALITY := {
	"low": { "name": "BASSA", "scale": 0.75, "shadows": false, "glow": false, "msaa": 0, "hint": "Niente ombre né bagliore, risoluzione ridotta: per PC poco potenti" },
	"medium": { "name": "MEDIA", "scale": 1.0, "shadows": true, "glow": true, "msaa": 1, "hint": "Ombre semplici e risoluzione standard: un buon equilibrio" },
	"high": { "name": "ALTA", "scale": 1.0, "shadows": true, "glow": true, "msaa": 2, "hint": "Ombre morbide, bagliore e antialiasing: la resa migliore" },
}

# ============================================================ match state shared by every module
var state := "menu"          # menu · playing · paused · dead · shop
var menu_type := "main"
var now := 0.0
var score := 0
var kills := 0
var headshots := 0
var shots_fired := 0
var shots_hit := 0
var hurt := 0.0
var cash := 0
var blind := 0.0
var earned := 0
var spent := 0
var boss_kills := 0
var wave := 0
var to_spawn := 0
var wave_break := 0.0
var wave_total := 1
var spawn_t := 0.0
var boss_wave := false
var class_swaps := 0
var firing := false
var aiming := false
var trigger_queued := false
var trigger_t := 0.0
var sway := Vector2.ZERO

func is_playing() -> bool:
	return state == "playing"

# ============================================================ perks, second lives, power-ups
const PERKS := {
	"tank": { "name": "PELLE DURA", "tag": "PD", "css": "#ff6b5c", "cost": 2500, "desc": "Subisci il 30% di danni in meno." },
	"reload": { "name": "MANI SVELTE", "tag": "MS", "css": "#7dff8a", "cost": 2000, "desc": "Ricarichi tutte le armi il 35% più in fretta." },
	"rate": { "name": "DOPPIO COLPO", "tag": "DC", "css": "#ffb347", "cost": 2000, "desc": "Cadenza di fuoco +25% con ogni arma." },
	"speed": { "name": "GAMBE D’ACCIAIO", "tag": "GA", "css": "#ffe45c", "cost": 1500, "desc": "Ti muovi il 12% più veloce." },
	"regen": { "name": "SANGUE FREDDO", "tag": "SF", "css": "#6cd4ff", "cost": 2000, "desc": "La vita inizia a rigenerarsi in metà tempo e al doppio della velocità." },
	"loot": { "name": "SCIACALLO", "tag": "SC", "css": "#c98bff", "cost": 1500, "desc": "Guadagni il 30% di crediti in più da ogni uccisione." },
	"revive": { "name": "SECONDA VITA", "tag": "♥", "css": "#ff5c7a", "cost": 3000, "desc": "Una vita di scorta: se cadi ti rialzi subito. Ne puoi tenere due." },
}
const PERK_ORDER := ["tank", "reload", "rate", "speed", "regen", "loot", "revive"]
const MAX_REVIVES := 2
var perks := {}
var revives := 1

func perk_owned(k: String) -> bool:
	return revives >= MAX_REVIVES if k == "revive" else perks.has(k)

const POWERUPS := {
	"jump": { "name": "SUPER SALTO", "color": 0x7dff4a, "css": "#9dff75", "dur": 15.0, "respawn": 35.0, "first": 0.0, "hint": "Salti di quasi 4 m" },
	"haste": { "name": "VELOCITÀ", "color": 0xffd23a, "css": "#ffdc5e", "dur": 12.0, "respawn": 40.0, "first": 8.0, "hint": "+40% movimento e cadenza" },
	"ammo": { "name": "MUNIZIONI INFINITE", "color": 0xff8a2a, "css": "#ffa35c", "dur": 15.0, "respawn": 45.0, "first": 15.0, "hint": "Niente ricarica" },
	"quad": { "name": "DANNO x3", "color": 0xb04dff, "css": "#c98bff", "dur": 12.0, "respawn": 60.0, "first": 30.0, "hint": "Triplo danno" },
	"god": { "name": "INVULNERABILE", "color": 0x3affe6, "css": "#7cfff0", "dur": 8.0, "respawn": 80.0, "first": 50.0, "hint": "Nessun danno subito" },
}
var powers := { "jump": 0.0, "haste": 0.0, "quad": 0.0, "ammo": 0.0, "god": 0.0 }

func pw(k: String) -> bool:
	return powers[k] > 0.0

# ============================================================ weapons data (models and behaviour live in weapons.gd)
const RARITY := {
	"common": { "name": "COMUNE", "color": 0xc9d1db },
	"uncommon": { "name": "NON COMUNE", "color": 0x6bff8f },
	"rare": { "name": "RARA", "color": 0x5cb3ff },
	"epic": { "name": "EPICA", "color": 0xc77dff },
	"legendary": { "name": "LEGGENDARIA", "color": 0xffc94d },
}
const BOX_POOL := [
	["pistol", "common", 11], ["uzi", "common", 11],
	["smg", "uncommon", 14], ["shotgun", "uncommon", 13],
	["rifle", "rare", 12], ["magnum", "rare", 10], ["burst", "rare", 10], ["dmr", "rare", 9],
	["lmg", "epic", 8], ["sniper", "epic", 8], ["minigun", "epic", 7],
	["raygun", "legendary", 4], ["rocket", "legendary", 4],
]
const BOX_COST := 950

func rarity_key(k: String) -> String:
	for e in BOX_POOL:
		if e[0] == k:
			return e[1]
	return "common"

func rarity_of(k: String) -> Dictionary:
	return RARITY[rarity_key(k)]

const CLASSES := {
	"assault": { "name": "ASSALTATORE", "weapon": "rifle", "desc": "Fucile d’assalto automatico e versatile, efficace a ogni distanza.", "armor": 0, "stats": [3, 3, 3, 3], "perk": "Equilibrato in tutto" },
	"breacher": { "name": "INCURSORE", "weapon": "shotgun", "desc": "Fucile a pompa devastante a corto raggio. Perfetto contro le orde.", "armor": 25, "stats": [5, 1, 1, 3], "perk": "+25 scudo iniziale" },
	"sniper": { "name": "CECCHINO", "weapon": "sniper", "desc": "Fucile di precisione con mirino ottico: alla testa è sempre letale.", "armor": 0, "stats": [5, 1, 5, 2], "perk": "Mirino ottico ad alto ingrandimento" },
	"gunner": { "name": "MITRAGLIERE", "weapon": "lmg", "desc": "Mitragliatrice leggera da 80 colpi. Lenta da ricaricare, inarrestabile.", "armor": 50, "stats": [3, 4, 2, 1], "perk": "+50 scudo iniziale" },
	"scout": { "name": "ESPLORATORE", "weapon": "smg", "desc": "Mitraglietta a cadenza altissima e ricarica rapida. Il più veloce.", "armor": 0, "stats": [2, 5, 3, 5], "perk": "Movimento +12%" },
}
const CLASS_ORDER := ["assault", "breacher", "sniper", "gunner", "scout"]
const MAX_SWAPS := 2
var class_key := "assault"
var primary := "rifle"

const UPGRADES := {
	"dmg": { "name": "DANNO", "step": 20, "fmt": "+%d%% danno" },
	"mag": { "name": "CARICATORE", "step": 25, "fmt": "+%d%% colpi" },
	"rel": { "name": "RICARICA", "step": 15, "fmt": "−%d%% tempo" },
}
const UPG_COST := [600, 1100, 1800]
var upg := {}

func upg_lv(k: String, t: String) -> int:
	return upg.get(k, {}).get(t, 0)

const EQUIP_NAMES := { "frag": "GRANATA", "stun": "STORDENTE", "smoke": "FUMOGENO", "tknife": "COLTELLI DA LANCIO" }
const EQUIP_MAX := { "frag": 3, "stun": 3, "smoke": 2, "tknife": 5 }
const EQUIP_ORDER := ["frag", "stun", "smoke", "tknife"]
var equip := { "frag": 0, "stun": 0, "smoke": 0, "tknife": 0 }

func random_equip() -> String:
	var r := randf() * 10.0
	for e in [["frag", 3], ["stun", 2], ["smoke", 2], ["tknife", 3]]:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return "frag"

var slots: Array = ["rifle", "pistol"]

# ============================================================ unlockable looks
const LOOKS := {
	"camo": { "name": "MIMETICA", "items": [
		{ "id": "bosco", "name": "BOSCO", "lvl": 1, "base": "#4b5240", "pal": ["#5a6246", "#3b4331", "#7a7453", "#2c2f25"] },
		{ "id": "deserto", "name": "DESERTO", "lvl": 3, "base": "#b9a37a", "pal": ["#cdb98f", "#9c8660", "#e0d3ae", "#7d6a4a"] },
		{ "id": "urbano", "name": "URBANO", "lvl": 6, "base": "#7b8088", "pal": ["#9aa0a8", "#5a5f66", "#c3c7cc", "#34373c"] },
		{ "id": "artico", "name": "ARTICO", "lvl": 10, "base": "#d4d9dd", "pal": ["#eef1f3", "#aeb6bd", "#ffffff", "#7f8890"] },
		{ "id": "notte", "name": "NOTTE", "lvl": 14, "base": "#1c2028", "pal": ["#262b36", "#11141a", "#343b4a", "#0a0c10"] },
		{ "id": "tigre", "name": "TIGRE", "lvl": 20, "base": "#c9772a", "pal": ["#e08f3c", "#1a1410", "#f0b060", "#0f0b08"] },
	] },
	"glove": { "name": "GUANTI", "items": [
		{ "id": "cuoio", "name": "CUOIO", "lvl": 1, "base": "#5b4b3b" },
		{ "id": "nero", "name": "NERI", "lvl": 2, "base": "#1d1e21" },
		{ "id": "sabbia", "name": "SABBIA", "lvl": 5, "base": "#b39b76" },
		{ "id": "rosso", "name": "ROSSI", "lvl": 9, "base": "#8d2a22" },
		{ "id": "bianco", "name": "BIANCHI", "lvl": 13, "base": "#d8d6cf" },
		{ "id": "viola", "name": "VIOLA", "lvl": 18, "base": "#5a2f8a" },
	] },
	"finish": { "name": "FINITURA ARMI", "items": [
		{ "id": "standard", "name": "STANDARD", "lvl": 1, "metal": "#2b2f36", "poly": "#202328" },
		{ "id": "sabbia", "name": "SABBIA", "lvl": 4, "metal": "#8c7a5c", "poly": "#a8946e" },
		{ "id": "oliva", "name": "OLIVA", "lvl": 8, "metal": "#4a5540", "poly": "#39422f" },
		{ "id": "artico", "name": "ARTICO", "lvl": 12, "metal": "#c3c8ce", "poly": "#dfe2e5" },
		{ "id": "rosso", "name": "CREMISI", "lvl": 16, "metal": "#7a1f1c", "poly": "#241416" },
		{ "id": "oro", "name": "ORO", "lvl": 25, "metal": "#c9a227", "poly": "#17171a" },
	] },
}
const LOOK_ORDER := ["camo", "glove", "finish"]
var loadout := { "camo": "bosco", "glove": "cuoio", "finish": "standard" }

func look_of(k: String) -> Dictionary:
	for i in LOOKS[k].items:
		if i.id == loadout[k]:
			return i
	return LOOKS[k].items[0]

# ============================================================ career, levels and challenges
var career := { "games": 0, "kills": 0, "headshots": 0, "bosses": 0, "time": 0.0, "bestWave": 0, "nightmareWave": 0, "xp": 0 }
const MAX_LEVEL := 30
var last_gain: Dictionary = {}
var banked := true
var chal := {}

func level_of(xp: int = -1) -> Dictionary:
	if xp < 0:
		xp = int(career.xp)
	var lvl := 1
	var need := 2000
	while lvl < MAX_LEVEL and xp >= need:
		xp -= need; lvl += 1; need += 1000
	return { "lvl": lvl, "cur": xp if lvl < MAX_LEVEL else need, "need": need }

func add_xp(n: float) -> Dictionary:
	var from: int = level_of().lvl
	career.xp = int(career.xp) + maxi(0, roundi(n))
	var to: int = level_of().lvl
	var unlocked: Array = []
	if to > from:
		for k in LOOK_ORDER:
			for i in LOOKS[k].items:
				if i.lvl > from and i.lvl <= to:
					unlocked.append("%s %s" % [LOOKS[k].name, i.name])
	return { "xp": roundi(n), "from": from, "to": to, "unlocked": unlocked }

const CHALLENGES := [
	{ "id": "kills100", "name": "PRIME ARMI", "desc": "100 uccisioni in carriera", "goal": 100 },
	{ "id": "kills1000", "name": "VETERANO", "desc": "1000 uccisioni in carriera", "goal": 1000 },
	{ "id": "heads100", "name": "TIRATORE SCELTO", "desc": "100 headshot in carriera", "goal": 100 },
	{ "id": "games25", "name": "DI CASA", "desc": "Gioca 25 partite", "goal": 25 },
	{ "id": "boss1", "name": "AMMAZZAGIGANTI", "desc": "Sconfiggi un boss", "goal": 1 },
	{ "id": "boss10", "name": "CACCIATORE DI BOSS", "desc": "Sconfiggi 10 boss in carriera", "goal": 10 },
	{ "id": "wave10", "name": "RESISTENZA", "desc": "Raggiungi l’ondata 10", "goal": 10 },
	{ "id": "night20", "name": "INCUBO A OCCHI APERTI", "desc": "Raggiungi l’ondata 20 a difficoltà Incubo", "goal": 20 },
	{ "id": "acc50", "name": "OCCHIO DI FALCO", "desc": "Chiudi una partita da almeno 150 colpi con il 50% di precisione", "goal": 50, "unit": "%", "end": true },
	{ "id": "time15", "name": "MARATONETA", "desc": "Sopravvivi 15 minuti in una partita", "goal": 15, "unit": " min" },
	{ "id": "houses4", "name": "PADRONE DI CASA", "desc": "Apri i 4 edifici del Quartiere in una partita", "goal": 4 },
	{ "id": "perks6", "name": "TUTTO COMPRESO", "desc": "Compra 6 perk in una partita", "goal": 6 },
	{ "id": "spend15k", "name": "SPENDACCIONE", "desc": "Spendi 15000 crediti in una partita", "goal": 15000 },
]

func best_key() -> String:
	var mk: String = world.MAP.key if world and world.MAP else "city"
	return "best-%s-%s%s" % [mode, diff_key, "" if mk == "arena" else "-" + mk]

func get_best() -> int:
	return int(sget(best_key(), 0))

# ============================================================ controls: remappable keys and pad buttons
# Gameplay code asks for logical actions; bindings translate the physical key or button.
const ACTIONS := [
	["fwd", "Avanti", KEY_W, -1], ["back", "Indietro", KEY_S, -1], ["left", "Sinistra", KEY_A, -1], ["right", "Destra", KEY_D, -1],
	["fire", "Spara", 0, 7], ["aim", "Mira", 0, 6],
	["jump", "Salta", KEY_SPACE, 0], ["sprint", "Corri", KEY_SHIFT, 10], ["crouch", "Accucciati · scivola", KEY_C, 1],
	["reload", "Ricarica (controller: anche usa)", KEY_R, 2], ["interact", "Usa · raccogli", KEY_E, -1], ["swap", "Cambia arma", KEY_Q, 3],
	["melee", "Coltellata", KEY_V, 5], ["melee2", "Coltellata (stick destro)", 0, 11],
	["frag", "Granata", KEY_G, 4], ["stun", "Stordente", KEY_Z, 12], ["smoke", "Fumogeno", KEY_X, 13], ["tknife", "Coltello da lancio", KEY_T, 14],
	["drop", "Getta arma", KEY_B, 15], ["skip", "Avvia subito l’ondata", KEY_ENTER, 8], ["pause", "Pausa", KEY_P, 9],
]
const FIXED_KEYS := [KEY_ESCAPE, KEY_1, KEY_2, KEY_M, KEY_F]
const PAD_NAMES := ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "back", "start", "L3", "R3", "up", "down", "left", "right"]
const PAD_LABELS := {
	"xbox": { "A": "A", "B": "B", "X": "X", "Y": "Y", "LB": "LB", "RB": "RB", "LT": "LT", "RT": "RT", "L3": "L3", "R3": "R3", "start": "MENU", "back": "VIEW", "up": "▲", "down": "▼", "left": "◀", "right": "▶", "ls": "L", "rs": "R" },
	"ps": { "A": "✕", "B": "○", "X": "□", "Y": "△", "LB": "L1", "RB": "R1", "LT": "L2", "RT": "R2", "L3": "L3", "R3": "R3", "start": "OPTIONS", "back": "CREATE", "up": "▲", "down": "▼", "left": "◀", "right": "▶", "ls": "L", "rs": "R" },
}

func action_def(id: String) -> Array:
	for a in ACTIONS:
		if a[0] == id:
			return a
	return []

func bind_of(id: String) -> int:
	var b: Dictionary = settings.binds
	return int(b[id]) if b.has(id) else int(action_def(id)[2])

func pad_of(i: int) -> int:
	var b: Dictionary = settings.padBinds
	return int(b[str(i)]) if b.has(str(i)) else i

static func key_name(code: int) -> String:
	match code:
		KEY_SPACE: return "Spazio"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_ENTER: return "Invio"
		KEY_KP_ENTER: return "Invio tn"
		KEY_TAB: return "Tab"
		KEY_CAPSLOCK: return "Bloc Maiusc"
		KEY_BACKSPACE: return "Backspace"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
	# show the key as printed on this keyboard's layout (physical codes are US positions)
	if DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code)

# ============================================================ load everything saved
func load_all() -> void:
	settings = SETTINGS_DEFAULT.duplicate(true)
	var s: Variant = sget("settings", {})
	if s is Dictionary:
		for k in s:
			settings[k] = s[k]
	if not (settings.binds is Dictionary): settings.binds = {}
	if not (settings.padBinds is Dictionary): settings.padBinds = {}
	muted = bool(sget("muted", false))
	mode = str(sget("mode", "classic"))
	if mode != "zombie": mode = "classic"
	diff_key = str(sget("diff", "normal"))
	if not DIFFS.has(diff_key) and diff_key != "progressive": diff_key = "normal"
	D = diff_for(1)
	class_key = str(sget("class", "assault"))
	if not CLASSES.has(class_key): class_key = "assault"
	primary = CLASSES[class_key].weapon
	var c: Variant = sget("career", {})
	if c is Dictionary:
		for k in c:
			career[k] = c[k]
	var ch: Variant = sget("challenges", {})
	if ch is Dictionary:
		chal = ch.duplicate()
	var lo: Variant = sget("loadout", {})
	if lo is Dictionary:
		for k in lo:
			loadout[k] = lo[k]
