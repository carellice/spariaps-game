# Spariaps — Modelli delle armi (con mani e braccia), sparo, rinculo, ricarica, coltellata.
# Le armi in mano vivono in un mondo 3D a parte (SubViewport) disegnato sopra la scena: non entrano mai nei muri.
extends Node

const SWITCH_TIME := 0.4
const MELEE_TIME := 0.5
const THROW_TIME := 0.45
const KNIFE_DMG := 200.0

const W := {
	"rifle": { "name": "FUCILE", "auto": true, "rate": 0.1, "magSize": 30, "reload": 1.6, "dmg": { "head": 100, "body": 34, "limb": 24 }, "hip": 0.018, "ads": 0.0015, "move": 0.03, "bloom": 0.006,
		"recoil": 0.018, "climb": 0.006, "fov": 50, "vol": 1.0, "snd": "rifle", "speed": 1.0, "shake": 0.12, "hipPos": Vector3(0.2, -0.2, -0.72), "adsPos": Vector3(0, -0.105, -0.5) },
	"pistol": { "name": "PISTOLA", "cues": "pistol", "auto": false, "rate": 0.14, "magSize": 12, "reload": 1.2, "dmg": { "head": 100, "body": 45, "limb": 32 }, "hip": 0.012, "ads": 0.001, "move": 0.02, "bloom": 0.012,
		"recoil": 0.032, "climb": 0.009, "fov": 60, "vol": 0.8, "snd": "pistol", "speed": 1.05, "shake": 0.1, "kickRot": 0.18, "kickBack": 0.04, "hipPos": Vector3(0.13, -0.14, -0.4), "adsPos": Vector3(0, -0.0675, -0.36), "hipYaw": 0.1 },
	"shotgun": { "name": "FUCILE A POMPA", "cues": "shotgun", "auto": false, "rate": 0.85, "magSize": 6, "reload": 2.3, "pellets": 8, "pelletSpread": 0.05, "dmg": { "head": 30, "body": 19, "limb": 13 }, "hip": 0.01, "ads": 0.004, "move": 0.02, "bloom": 0.0,
		"recoil": 0.06, "climb": 0.02, "fov": 62, "vol": 1.1, "snd": "shotgun", "speed": 1.0, "shake": 0.5, "kickRot": 0.16, "kickBack": 0.08, "hipPos": Vector3(0.2, -0.2, -0.66), "adsPos": Vector3(0, -0.05, -0.52) },
	"sniper": { "name": "FUCILE DI PRECISIONE", "cues": "sniper", "auto": false, "rate": 1.25, "magSize": 5, "reload": 2.6, "scope": true, "adsSpeed": 5, "dmg": { "head": 300, "body": 120, "limb": 75 }, "hip": 0.07, "ads": 0.0002, "move": 0.05, "bloom": 0.0,
		"recoil": 0.05, "climb": 0.03, "fov": 16, "vol": 1.15, "snd": "sniper", "speed": 0.92, "shake": 0.35, "kickRot": 0.12, "kickBack": 0.07, "hipPos": Vector3(0.2, -0.2, -0.7), "adsPos": Vector3(0, -0.1, -0.45) },
	"lmg": { "name": "MITRAGLIATRICE LEGGERA", "cues": "lmg", "auto": true, "rate": 0.075, "magSize": 80, "reload": 3.4, "adsSpeed": 5, "dmg": { "head": 75, "body": 28, "limb": 20 }, "hip": 0.03, "ads": 0.004, "move": 0.035, "bloom": 0.004,
		"recoil": 0.014, "climb": 0.005, "fov": 55, "vol": 1.0, "snd": "lmg", "speed": 0.86, "shake": 0.15, "hipPos": Vector3(0.21, -0.22, -0.72), "adsPos": Vector3(0, -0.175, -0.55) },
	"smg": { "name": "MITRAGLIETTA", "auto": true, "rate": 0.062, "magSize": 35, "reload": 1.35, "adsSpeed": 9, "dmg": { "head": 65, "body": 22, "limb": 16 }, "hip": 0.016, "ads": 0.006, "move": 0.012, "bloom": 0.004,
		"recoil": 0.011, "climb": 0.004, "fov": 62, "vol": 0.85, "snd": "smg", "speed": 1.12, "shake": 0.08, "hipPos": Vector3(0.17, -0.17, -0.55), "adsPos": Vector3(0, -0.08, -0.42) },
	"magnum": { "name": "REVOLVER MAGNUM", "cues": "magnum", "auto": false, "rate": 0.42, "magSize": 6, "reload": 2.1, "dmg": { "head": 240, "body": 95, "limb": 65 }, "hip": 0.014, "ads": 0.0008, "move": 0.02, "bloom": 0.02,
		"recoil": 0.075, "climb": 0.028, "fov": 55, "vol": 1.1, "snd": "magnum", "speed": 1.02, "shake": 0.32, "kickRot": 0.34, "kickBack": 0.06, "hipPos": Vector3(0.13, -0.15, -0.42), "adsPos": Vector3(0, -0.0765, -0.38), "hipYaw": 0.1 },
	"uzi": { "name": "MICRO SMG", "auto": true, "rate": 0.055, "magSize": 32, "reload": 1.3, "adsSpeed": 10, "dmg": { "head": 55, "body": 18, "limb": 13 }, "hip": 0.02, "ads": 0.008, "move": 0.012, "bloom": 0.005,
		"recoil": 0.01, "climb": 0.004, "fov": 64, "vol": 0.8, "snd": "uzi", "speed": 1.12, "shake": 0.07, "hipPos": Vector3(0.15, -0.15, -0.46), "adsPos": Vector3(0, -0.07, -0.38), "hipYaw": 0.1 },
	"burst": { "name": "FUCILE A RAFFICA", "auto": false, "burst": 3, "burstDelay": 0.32, "rate": 0.065, "magSize": 30, "reload": 1.7, "dmg": { "head": 115, "body": 40, "limb": 28 }, "hip": 0.016, "ads": 0.0012, "move": 0.028, "bloom": 0.004,
		"recoil": 0.016, "climb": 0.005, "fov": 50, "vol": 1.0, "snd": "burst", "speed": 1.0, "shake": 0.12, "hipPos": Vector3(0.2, -0.2, -0.72), "adsPos": Vector3(0, -0.105, -0.5) },
	"dmr": { "name": "FUCILE TATTICO", "auto": false, "rate": 0.24, "magSize": 15, "reload": 2.0, "adsSpeed": 6, "dmg": { "head": 190, "body": 72, "limb": 50 }, "hip": 0.03, "ads": 0.0004, "move": 0.04, "bloom": 0.01,
		"recoil": 0.04, "climb": 0.016, "fov": 34, "vol": 1.1, "snd": "dmr", "speed": 0.96, "shake": 0.22, "kickRot": 0.1, "kickBack": 0.06, "hipPos": Vector3(0.2, -0.2, -0.72), "adsPos": Vector3(0, -0.09, -0.42) },
	"minigun": { "name": "MINIGUN", "cues": "lmg", "auto": true, "spinup": true, "rate": 0.036, "magSize": 200, "reload": 4.6, "adsSpeed": 4, "dmg": { "head": 55, "body": 22, "limb": 16 }, "hip": 0.035, "ads": 0.02, "move": 0.03, "bloom": 0.003,
		"recoil": 0.007, "climb": 0.0025, "fov": 62, "vol": 0.85, "snd": "minigun", "speed": 0.76, "shake": 0.14, "kickBack": 0.02, "hipPos": Vector3(0.2, -0.22, -0.62), "adsPos": Vector3(0.06, -0.19, -0.56) },
	"rocket": { "name": "LANCIARAZZI", "cues": "rocket", "auto": false, "rate": 0.9, "magSize": 3, "reload": 2.8, "projectile": "rocket", "projSpeed": 34, "adsSpeed": 5, "dmg": { "head": 0, "body": 0, "limb": 0 }, "hip": 0.01, "ads": 0.002, "move": 0.02, "bloom": 0.0,
		"recoil": 0.09, "climb": 0.04, "fov": 55, "vol": 1.0, "snd": "", "speed": 0.88, "shake": 0.6, "kickRot": 0.2, "kickBack": 0.12, "hipPos": Vector3(0.2, -0.13, -0.5), "adsPos": Vector3(0.075, -0.085, -0.42) },
	"raygun": { "name": "PISTOLA A RAGGI", "cues": "raygun", "auto": false, "rate": 0.26, "magSize": 20, "reload": 2.5, "projectile": "plasma", "projSpeed": 48, "splash": 2.8, "splashDmg": 130, "dmg": { "head": 320, "body": 210, "limb": 160 }, "hip": 0.008, "ads": 0.002, "move": 0.01, "bloom": 0.004,
		"recoil": 0.03, "climb": 0.012, "fov": 58, "vol": 0.9, "snd": "", "speed": 1.03, "shake": 0.22, "kickRot": 0.22, "kickBack": 0.05, "hipPos": Vector3(0.15, -0.16, -0.54), "adsPos": Vector3(0, -0.09, -0.44), "hipYaw": 0.1 },
}

# reload foley: each weapon family has its own sequence of mechanical cues (fraction of reload time, sound)
const RELOAD_CUES := {
	"default": [[0.08, "release"], [0.2, "out"], [0.56, "in"], [0.66, "seat"], [0.84, "rack"]],
	"pistol": [[0.1, "release"], [0.24, "out"], [0.58, "in"], [0.68, "seat"], [0.86, "slide"]],
	"shotgun": [[0.12, "shell"], [0.3, "shell"], [0.48, "shell"], [0.66, "shell"], [0.86, "pump"]],
	"sniper": [[0.06, "bolt"], [0.26, "out"], [0.56, "in"], [0.66, "seat"], [0.84, "bolt"]],
	"lmg": [[0.06, "release"], [0.18, "lid"], [0.36, "out"], [0.6, "in"], [0.74, "lid"], [0.88, "rack"]],
	"magnum": [[0.08, "lid"], [0.26, "out"], [0.5, "shell"], [0.62, "shell"], [0.8, "lid"]],
	"raygun": [[0.15, "zapOut"], [0.62, "in"], [0.8, "zapIn"]],
	"rocket": [[0.25, "out"], [0.62, "in"], [0.78, "seat"]],
}

# recoil patterns: v(n) scales the climb of shot n of a burst, h(n) is the sideways pull (positive = right)
static func _sway(n: float, amp: float, period: float, from := 0.0) -> float:
	return 0.0 if n < from else sin((n - from) / period * TAU) * amp

static func recoil_v(k: String, n: int) -> float:
	match k:
		"rifle": return 1.35 if n < 4 else 0.8
		"smg": return 1.1 if n < 2 else 0.7
		"uzi": return 0.75
		"lmg": return 1.7 if n < 6 else 0.45
		"minigun": return maxf(0.25, 1.2 - n * 0.05)
		"burst": return [0.8, 1.1, 1.5][mini(n, 2)]
		"dmr": return 1.15
		"pistol": return 1.0 + mini(n, 4) * 0.12
		"magnum": return 1.3
		"shotgun", "sniper": return 1.2
		"raygun": return 0.8
	return 1.0

static func recoil_h(k: String, n: int) -> float:
	match k:
		"rifle": return 0.0 if n < 4 else _sway(n - 4, 0.0075, 12)
		"smg": return _sway(n, 0.003, 5)
		"lmg": return _sway(n, 0.0045, 18, 6)
		"minigun": return _sway(n, 0.0035, 30)
		"burst": return [0.001, 0.0035, 0.006][mini(n, 2)]
		"dmr": return (-1.0 if n % 2 else 1.0) * 0.0045
		"magnum": return 0.004
		"sniper": return -0.003
		"raygun": return _sway(n, 0.002, 4)
	return 0.0

const JIT := { "rifle": 0.0008, "smg": 0.0042, "uzi": 0.0065, "lmg": 0.0018, "minigun": 0.003, "burst": 0.0006, "dmr": 0.001, "pistol": 0.003, "magnum": 0.004, "shotgun": 0.009, "sniper": 0.004, "rocket": 0.006, "raygun": 0.001 }

# ============================================================ state
var current := "rifle"
var last := "pistol"
var mags := {}
var reloading := false
var reload_t := 0.0
var cooldown := 0.0
var bloom := 0.0
var kick := 0.0
var recoil_off := 0.0
var flash_t := 0.0
var ads_t := 0.0
var slide_kick := 0.0
var spray := 0
var spray_t := 0.0
var switch_t := 0.0
var switch_to := ""
var melee_t := 0.0
var melee_hit := false
var throw_t := 0.0
var throw_cd := 0.0
var burst_left := 0
var spin := 0.0
var cue_i := 0

var models := {}            # key -> model dictionary (group, flash, mag, ...)
var holder: Node3D
var knife: Node3D
var throw_arm: Node3D
var gun_cam: Camera3D
var gun_muzzle_light: OmniLight3D
var gun_light: DirectionalLight3D
var M := {}                 # weapon + hand materials

func _ready() -> void:
	G.weapons = self

func cur() -> Dictionary:
	return W[current]

func mag_of(k: String) -> int:
	return roundi(W[k].magSize * (1.0 + 0.25 * G.upg_lv(k, "mag")))

func dmg_mul(k: String) -> float:
	return 1.0 + 0.2 * G.upg_lv(k, "dmg")

func reload_of(k := "") -> float:
	if k == "":
		k = current
	return W[k].reload * (1.0 - 0.15 * G.upg_lv(k, "rel")) * (0.65 if G.perks.has("reload") else 1.0)

func other_slot() -> String:
	var i := G.slots.find(switch_to if switch_to != "" else current)
	if i < 0:
		for s in G.slots:
			if s:
				return s
		return ""
	var o: Variant = G.slots[1 - i]
	return o if o else ""

# ============================================================ materials
func _materials() -> void:
	M = {
		"metal": Gfx.mat(0x2b2f36, 0.32, 0.8), "metalLight": Gfx.mat(0x70767f, 0.28, 0.85), "tan": Gfx.mat(0x9a8566, 0.55, 0.05),
		"polymer": Gfx.mat(0x1f2226, 0.5, 0.15), "accent": Gfx.mat(0xff6b3d, 0.4, 0.3), "sleeve": Gfx.mat(0x4b5240, 0.92),
		"glove": Gfx.mat(0x5b4b3b, 0.72), "blade": Gfx.mat(0xe8edf2, 0.22, 0.75), "sight": Gfx.glow(0xff3020, 6.0),
		"wood": Gfx.mat(0x7a5234, 0.55, 0.05), "olive": Gfx.mat(0x4a5540, 0.6, 0.1), "shell": Gfx.mat(0xb3261e, 0.4, 0.3),
		"lens": Gfx.mat(0x0a1a2a, 0.08, 1.0), "dot": Gfx.glow(0xffffff, 0.8), "redDot": Gfx.glow(0xff3020, 2.6),
		"glass": Gfx.transparent(0xbfe4ff, 0.12, 0.05), "dotF": Gfx.glow(0x7dff7d, 1.6), "chrome": Gfx.mat(0xc8ced6, 0.18, 1.0),
		"rayRed": Gfx.mat(0xb8322a, 0.3, 0.6), "rayGlow": Gfx.glow(0x4dff6a, 1.4), "skin": Gfx.mat(0xc48a68, 0.58),
		"knuckle": Gfx.mat(0x26282c, 0.45, 0.1), "strap": Gfx.mat(0x2a2d27, 0.85), "gloveDark": Gfx.mat(0x131417, 0.55, 0.2),
		"watch": Gfx.glow(0x3aff9a, 0.9), "patch": Gfx.mat(0xffffff, 0.9),
	}
	M.accent.emission_enabled = true; M.accent.emission = G.col(0xff4a1a); M.accent.emission_energy_multiplier = 0.4
	M.lens.emission_enabled = true; M.lens.emission = G.col(0x12345a); M.lens.emission_energy_multiplier = 0.7
	# Italian flag patch
	var im := Gfx._img(48, 32, Color.html("#2b2a24"))
	var cols := ["#1f8a4c", "#f2efe6", "#c9302c"]
	for i in 3:
		Gfx._rect(im, 3 + i * 14, 3, 14, 26, Color.html(cols[i]))
	M.patch.albedo_texture = Gfx.tex(im)
	apply_loadout()
	for k in M:
		var mt: StandardMaterial3D = M[k]
		if mt.emission_enabled and mt.albedo_color.v < 0.1:
			continue
		mt.rim_enabled = true
		mt.rim = 0.22
		mt.rim_tint = 0.65
		if mt.metallic >= 0.5:
			mt.roughness_texture = Gfx.noise_tex()
			mt.roughness = minf(1.0, mt.roughness * 1.7)
			mt.clearcoat_enabled = k in ["metal", "chrome", "metalLight"]
			mt.clearcoat = 0.35
			mt.clearcoat_roughness = 0.35

func apply_loadout() -> void:
	var c: Dictionary = G.look_of("camo")
	var g: Dictionary = G.look_of("glove")
	var f: Dictionary = G.look_of("finish")
	M.sleeve.albedo_texture = Gfx.blotch_tex(c.base, c.pal, 128, 0.05, "camo")
	M.sleeve.albedo_color = Color.WHITE
	M.glove.albedo_color = Color.html(g.base)
	M.metal.albedo_color = Color.html(f.metal)
	M.metal.roughness = 0.2 if f.id == "oro" else 0.32
	M.polymer.albedo_color = Color.html(f.poly)

# ============================================================ model helpers
func part(g: Node3D, mesh: Mesh, m: Material, x: float, y: float, z: float, rx := 0.0, ry := 0.0, rz := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.rotation = Vector3(rx, ry, rz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	return mi

# three.js-style ring (around the Z axis)
func ring_part(g: Node3D, r: float, tube: float, m: Material, x: float, y: float, z: float, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := part(g, Gfx.torus(r, tube, 24), m, x, y, z)
	mi.basis = Basis.from_euler(rot) * Basis(Vector3.RIGHT, PI / 2)
	return mi

func disc_part(g: Node3D, r: float, m: Material, x: float, y: float, z: float) -> MeshInstance3D:
	return part(g, Gfx.cyl(r, r, 0.001, 20), m, x, y, z, PI / 2)

func flash_sprite(g: Node3D, z: float, y: float, size: float, color := Color(1, 1, 1)) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Gfx.flash_tex()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.modulate = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0)
	s.pixel_size = size / 128.0
	s.position = Vector3(0, y, z)
	s.visible = false
	s.set_meta("size", size)
	g.add_child(s)
	return s

# capsule stretched between two points, merged into a batch
func _caps(batch: Gfx.Batch, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var L := d.length()
	if L < 1e-4:
		return
	batch.add(Gfx.capsule(r, maxf(L, 2.0 * r + 0.001), 8), m, Transform3D(Basis(Quaternion(Vector3.UP, d / L)), (a + b) * 0.5), false)

# gloved hands: each finger is a bent 3-point chain of capsules; fingerless gloves leave the fingertips bare
const HAND := {
	"grip": { "palm": [0.055, 0.088, 0.085, 0.018, 0.0, 0.012], "pad": [0.014, 0.07, 0.05, 0.044, -0.004, -0.008], "back": [1.0, 0.0, 0.35], "fingers": [
		[[[0.036, 0.006, -0.018], [0.014, 0.004, -0.047], [-0.029, 0.002, -0.036]], 0.0115],
		[[[0.036, -0.02, -0.017], [0.015, -0.022, -0.046], [-0.027, -0.024, -0.034]], 0.0115],
		[[[0.035, -0.045, -0.015], [0.016, -0.047, -0.042], [-0.023, -0.049, -0.031]], 0.0105],
		[[[0.031, 0.036, -0.018], [0.021, 0.04, -0.049], [0.004, 0.042, -0.07]], 0.0115],
		[[[0.03, 0.044, 0.03], [0.004, 0.055, 0.016], [-0.028, 0.051, -0.01]], 0.013]] },
	"support": { "palm": [0.07, 0.028, 0.1, 0.0, -0.018, 0.0], "pad": [0.03, 0.012, 0.075, 0.018, -0.036, 0.0], "back": [0.3, -1.0, 0.0], "fingers": [
		[[[0.03, -0.024, -0.035], [0.053, -0.002, -0.035], [0.05, 0.031, -0.037]], 0.0115],
		[[[0.03, -0.024, -0.012], [0.053, -0.002, -0.012], [0.05, 0.031, -0.014]], 0.0115],
		[[[0.03, -0.024, 0.012], [0.053, -0.002, 0.012], [0.05, 0.031, 0.01]], 0.0115],
		[[[0.029, -0.024, 0.034], [0.05, -0.004, 0.035], [0.047, 0.026, 0.035]], 0.0105],
		[[[-0.03, -0.016, 0.03], [-0.047, 0.002, 0.004], [-0.048, 0.023, -0.03]], 0.013]] },
	"cup": { "palm": [0.028, 0.072, 0.08, -0.012, 0.0, 0.0], "pad": [0.012, 0.055, 0.045, -0.03, 0.0, 0.002], "back": [-1.0, 0.0, 0.3], "fingers": [
		[[[-0.02, 0.0, -0.026], [0.0, -0.001, -0.05], [0.034, -0.004, -0.045]], 0.0115],
		[[[-0.02, -0.024, -0.024], [0.0, -0.025, -0.048], [0.034, -0.028, -0.042]], 0.0115],
		[[[-0.019, -0.046, -0.022], [0.0, -0.047, -0.044], [0.03, -0.05, -0.038]], 0.0105],
		[[[-0.012, 0.03, -0.02], [-0.009, 0.033, -0.05], [-0.004, 0.034, -0.075]], 0.013]] },
}

func hand(parent: Node3D, pos: Vector3, kind: String, rot_x := 0.0, flip := false) -> Node3D:
	var h: Dictionary = HAND[kind]
	var g := Node3D.new()
	g.position = pos
	g.rotation.x = rot_x
	if flip:
		g.scale.x = -1
	parent.add_child(g)
	var p: Array = h.palm
	var k: Array = h.pad
	var batch := Gfx.Batch.new()
	batch.at(Gfx.box(p[0], p[1], p[2]), M.glove, Vector3(p[3], p[4], p[5]), Vector3.ZERO, false)
	batch.at(Gfx.box(k[0], k[1], k[2]), M.knuckle, Vector3(k[3], k[4], k[5]), Vector3.ZERO, false)
	var bn := Vector3(h.back[0], h.back[1], h.back[2]).normalized()
	var knuckles: Array = []
	for fi in h.fingers.size():
		var fd: Array = h.fingers[fi]
		var pts: Array = fd[0].map(func(q): return Vector3(q[0], q[1], q[2]))
		var r: float = fd[1] * 1.12
		var cut: Vector3 = pts[1].lerp(pts[2], 0.5)
		_caps(batch, pts[0], pts[1], r, M.glove)
		_caps(batch, pts[1], cut, r * 0.98, M.glove)
		_caps(batch, cut.lerp(pts[1], 0.12), pts[2], r * 0.9, M.skin)
		if fi < h.fingers.size() - 1:
			knuckles.append(pts[0] + bn * fd[1] * 0.55)
	_caps(batch, knuckles[0], knuckles[knuckles.size() - 1], 0.0085, M.knuckle)
	batch.commit(g)
	return g

# forearm from the wrist (a) back to the elbow (b): tapered camo sleeve, glove cuff, flag patch or a watch
func forearm(g: Node3D, a: Vector3, b: Vector3, r: float, watch := false) -> void:
	var d := (b - a)
	var L := d.length() + 0.1
	var dir := d.normalized()
	var basis := Basis(Quaternion(Vector3.UP, dir))
	var batch := Gfx.Batch.new()
	batch.add(Gfx.cyl(r * 1.3, r * 0.9, L, 14), M.sleeve, Transform3D(basis, a + dir * (L * 0.5)), false)
	batch.add(Gfx.cyl(r * 0.97, r * 0.9, 0.06, 14), M.glove, Transform3D(basis, a + dir * 0.012), false)
	batch.add(Gfx.cyl(r * 1.02, r * 1.02, 0.02, 14), M.strap, Transform3D(basis, a + dir * 0.024), false)
	var up := (Vector3.UP - dir * dir.y).normalized()
	if watch:
		batch.add(Gfx.cyl(r * 1.0, r * 1.0, 0.016, 14), M.gloveDark, Transform3D(basis, a + dir * 0.09 * L), false)
		batch.add(Gfx.box(0.026, 0.006, 0.022), M.watch, Transform3D(basis, a + dir * 0.09 * L + up * r * 1.02), false)
	else:
		batch.add(Gfx.box(0.04, 0.003, 0.03), M.patch, Transform3D(basis, a + dir * 0.34 * L + up * r * 1.15), false)
	batch.commit(g)

func add_arms(md: Dictionary, right: Vector3, left: Variant = null, left_kind := "support") -> void:
	var g: Node3D = md.group
	hand(g, right, "grip", -0.28)
	forearm(g, right + Vector3(0.025, -0.03, 0.045), right + Vector3(0.16, -0.36, 0.34), 0.04)
	if left is Vector3:
		# the off hand lives in its own group so it can leave the weapon (reload)
		var L := Node3D.new()
		g.add_child(L)
		if left_kind == "grip":
			hand(L, left, "grip", -0.1, true)
		elif left_kind == "top":
			hand(L, left, "support", 0, false).rotation.z = PI
		else:
			hand(L, left, "support")
		forearm(L, left + Vector3(-0.02, -0.045, 0.03), left + Vector3(-0.1, -0.28, 0.5), 0.04, true)
		md.leftArm = L; md.leftPos = left

# off hand for handguns (pistol, revolver, ray gun)
func support_handgun(md: Dictionary, lg: Vector3) -> void:
	var L := Node3D.new()
	md.group.add_child(L)
	hand(L, lg, "cup", -0.25)
	forearm(L, lg + Vector3(-0.02, -0.03, 0.03), lg + Vector3(-0.2, -0.33, 0.36), 0.042, true)
	md.leftArm = L; md.leftPos = lg

# reflex sight: thin ring on two side posts, faint glass and a small red dot
func ring_sight(g: Node3D, y: float, z: float, r: float, base: float) -> void:
	var t := r * 0.22
	ring_part(g, r, t, M.metal, 0, y, z)
	for s in [-1, 1]:
		var h := y - base
		part(g, Gfx.box(t * 1.6, h, 0.022), M.metal, s * (r + t * 0.3), base + h / 2.0, z)
	disc_part(g, r, M.glass, 0, y, z - 0.004)
	part(g, Gfx.sphere(0.0018, 6, 4), M.redDot, 0, y, z - 0.01)

# real handgun sights: a front post (tritium dot) seen through the notch between two rear posts (white dots)
func iron_sights(g: Node3D, base_y: float, front_z: float, rear_z: float, h: float) -> void:
	var y := base_y + h / 2.0
	var dot_y := base_y + h - 0.0035
	part(g, Gfx.box(0.0045, h, 0.012), M.metal, 0, y, front_z)
	part(g, Gfx.sphere(0.0017, 6, 4), M.dotF, 0, dot_y, front_z + 0.0062)
	for s in [-1, 1]:
		part(g, Gfx.box(0.008, h, 0.012), M.metal, s * 0.0088, y, rear_z)
		part(g, Gfx.sphere(0.0015, 6, 4), M.dot, s * 0.0088, dot_y, rear_z + 0.0062)
	part(g, Gfx.box(0.03, 0.005, 0.012), M.metal, 0, base_y + 0.0025, rear_z)

func cylz(r1: float, r2: float, h: float, seg := 14) -> CylinderMesh:
	return Gfx.cyl(r1, r2, h, seg)

# ============================================================ weapon models (arms = false builds the bare gun for the world)
func build(k: String, arms := true) -> Dictionary:
	var g := Node3D.new()
	var md := { "group": g, "key": k }
	var X := PI / 2
	match k:
		"rifle":
			part(g, Gfx.box(0.075, 0.1, 0.42), M.metal, 0, 0, 0)
			part(g, Gfx.box(0.086, 0.086, 0.28), M.polymer, 0, 0.005, -0.33)
			part(g, Gfx.box(0.088, 0.012, 0.2), M.accent, 0, -0.022, -0.33)
			part(g, Gfx.box(0.034, 0.014, 0.36), M.metalLight, 0, 0.057, -0.12)
			part(g, cylz(0.014, 0.014, 0.3), M.metalLight, 0, 0.02, -0.58, X)
			part(g, cylz(0.025, 0.022, 0.09), M.metal, 0, 0.02, -0.76, X)
			md.mag = part(g, Gfx.box(0.05, 0.19, 0.085), M.polymer, 0, -0.12, -0.06, 0.25)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.1, 0.13, -0.3)
			part(g, Gfx.box(0.06, 0.1, 0.26), M.tan, 0, -0.01, 0.34)
			part(g, Gfx.box(0.066, 0.13, 0.03), M.polymer, 0, -0.03, 0.47)
			part(g, Gfx.box(0.05, 0.016, 0.09), M.metal, 0, 0.068, -0.02)
			for i in 14:
				part(g, Gfx.box(0.04, 0.008, 0.009), M.metal, 0, 0.072, -0.29 + i * 0.024)
			ring_sight(g, 0.105, -0.04, 0.03, 0.068)
			if arms: add_arms(md, Vector3(0.01, -0.09, 0.12), Vector3(-0.01, -0.035, -0.34))
			md.flash = flash_sprite(g, -0.84, 0.02, 0.32)
		"pistol":
			var slide := Node3D.new(); slide.position = Vector3(0, 0.03, -0.02); g.add_child(slide)
			part(slide, Gfx.box(0.046, 0.048, 0.2), M.metalLight, 0, 0, 0)
			for i in 4:
				part(slide, Gfx.box(0.048, 0.03, 0.004), M.metal, 0, 0, 0.05 + i * 0.011)
			iron_sights(slide, 0.024, -0.085, 0.088, 0.014)
			part(g, Gfx.box(0.042, 0.032, 0.18), M.polymer, 0, -0.005, -0.015)
			part(g, Gfx.box(0.047, 0.008, 0.11), M.accent, 0, 0.013, -0.04)
			part(g, Gfx.box(0.04, 0.125, 0.058), M.polymer, 0, -0.07, 0.06, -0.25)
			md.mag = part(g, Gfx.box(0.034, 0.03, 0.05), M.metal, 0, -0.13, 0.077, -0.25)
			part(g, cylz(0.009, 0.009, 0.03, 10), M.metal, 0, 0.03, -0.13, X)
			if arms:
				add_arms(md, Vector3(0, -0.08, 0.07))
				support_handgun(md, Vector3(-0.025, -0.07, 0.05))
			md.flash = flash_sprite(g, -0.17, 0.03, 0.22)
			md.slide = slide; md.slideBase = slide.position.z
		"shotgun":
			part(g, Gfx.box(0.07, 0.09, 0.32), M.metal, 0, 0, 0)
			part(g, Gfx.box(0.073, 0.008, 0.16), M.accent, 0, -0.025, -0.02)
			part(g, cylz(0.019, 0.019, 0.56), M.metalLight, 0, 0.025, -0.44, X)
			part(g, cylz(0.016, 0.016, 0.44), M.metal, 0, -0.018, -0.38, X)
			part(g, Gfx.sphere(0.006, 6, 4), M.sight, 0, 0.048, -0.7)
			part(g, Gfx.box(0.05, 0.12, 0.06), M.polymer, 0, -0.09, 0.12, -0.3)
			part(g, Gfx.box(0.062, 0.11, 0.3), M.wood, 0, -0.035, 0.31, 0.1)
			part(g, Gfx.box(0.066, 0.13, 0.03), M.polymer, 0, -0.06, 0.46, 0.1)
			md.mag = part(g, cylz(0.012, 0.012, 0.06, 10), M.shell, 0, -0.06, -0.06, X)
			# the pump carries the left hand with it
			var pump := Node3D.new(); pump.position = Vector3(0, -0.02, -0.34); g.add_child(pump)
			part(pump, Gfx.box(0.074, 0.058, 0.18), M.wood, 0, 0, 0)
			for i in 4:
				part(pump, Gfx.box(0.076, 0.006, 0.01), M.polymer, 0, 0, -0.06 + i * 0.04)
			if arms:
				hand(pump, Vector3(-0.01, -0.012, 0), "support")
				forearm(pump, Vector3(-0.03, -0.05, 0.03), Vector3(-0.11, -0.3, 0.52), 0.04, true)
				add_arms(md, Vector3(0.01, -0.09, 0.12))
			md.flash = flash_sprite(g, -0.76, 0.025, 0.42)
			md.pump = pump; md.pumpBase = pump.position.z
		"sniper":
			part(g, Gfx.box(0.07, 0.09, 0.38), M.metal, 0, 0, 0)
			part(g, cylz(0.014, 0.017, 0.72), M.metal, 0, 0.02, -0.55, X)
			part(g, Gfx.box(0.05, 0.05, 0.08), M.metal, 0, 0.02, -0.94)
			part(g, Gfx.box(0.064, 0.13, 0.4), M.olive, 0, -0.03, 0.36)
			part(g, Gfx.box(0.05, 0.05, 0.18), M.olive, 0, 0.045, 0.34)
			part(g, Gfx.box(0.074, 0.1, 0.3), M.olive, 0, -0.01, -0.3)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.1, 0.13, -0.3)
			md.mag = part(g, Gfx.box(0.05, 0.08, 0.09), M.metal, 0, -0.075, -0.03)
			part(g, cylz(0.028, 0.028, 0.3, 20), M.metal, 0, 0.1, -0.03, X)
			part(g, cylz(0.042, 0.028, 0.09, 20), M.metal, 0, 0.1, -0.22, X)
			part(g, cylz(0.034, 0.034, 0.06, 20), M.metal, 0, 0.1, 0.15, X)
			disc_part(g, 0.038, M.lens, 0, 0.1, -0.266)
			for z in [-0.1, 0.06]:
				part(g, Gfx.box(0.03, 0.05, 0.03), M.metal, 0, 0.065, z)
			part(g, Gfx.box(0.012, 0.03, 0.02), M.accent, 0.03, 0.1, -0.02)
			var bolt := Node3D.new(); bolt.position = Vector3(0.04, 0.02, 0.08); g.add_child(bolt)
			part(bolt, cylz(0.007, 0.007, 0.06, 8), M.metalLight, 0.025, 0, 0, 0, 0, X)
			part(bolt, Gfx.sphere(0.014, 10, 6), M.metalLight, 0.055, 0, 0)
			if arms: add_arms(md, Vector3(0.01, -0.09, 0.12), Vector3(-0.01, -0.06, -0.3))
			md.flash = flash_sprite(g, -1.0, 0.02, 0.45)
			md.bolt = bolt
		"lmg":
			part(g, Gfx.box(0.09, 0.12, 0.46), M.metal, 0, 0, 0)
			part(g, Gfx.box(0.095, 0.03, 0.22), M.polymer, 0, 0.068, -0.02)
			part(g, Gfx.box(0.08, 0.08, 0.34), M.polymer, 0, 0.01, -0.4)
			for i in 5:
				part(g, cylz(0.009, 0.009, 0.084, 8), M.metal, 0, 0.03, -0.3 - i * 0.05, 0, 0, X)
			part(g, cylz(0.016, 0.016, 0.3), M.metalLight, 0, 0.01, -0.7, X)
			part(g, cylz(0.024, 0.028, 0.09), M.metal, 0, 0.01, -0.88, X)
			part(g, Gfx.box(0.022, 0.022, 0.2), M.metal, 0, 0.13, -0.08)
			for z in [-0.16, 0.0]:
				part(g, Gfx.box(0.018, 0.06, 0.02), M.metal, 0, 0.1, z)
			md.mag = part(g, cylz(0.085, 0.085, 0.075, 24), M.polymer, -0.015, -0.12, -0.04, 0, 0, X)
			part(md.mag, cylz(0.05, 0.05, 0.08, 16), M.accent, 0, 0, 0)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.1, 0.14, -0.3)
			part(g, Gfx.box(0.07, 0.12, 0.26), M.polymer, 0, -0.02, 0.36)
			for s in [-1, 1]:
				part(g, cylz(0.007, 0.007, 0.26, 8), M.metal, 0.02 * s, -0.04, -0.62, X)
			ring_sight(g, 0.175, -0.1, 0.026, 0.14)
			if arms: add_arms(md, Vector3(0.01, -0.1, 0.13), Vector3(-0.01, -0.05, -0.4))
			md.flash = flash_sprite(g, -0.95, 0.01, 0.38)
		"smg":
			part(g, Gfx.box(0.062, 0.09, 0.3), M.metal, 0, 0, 0)
			part(g, Gfx.box(0.07, 0.07, 0.13), M.polymer, 0, -0.005, -0.2)
			part(g, Gfx.box(0.072, 0.01, 0.12), M.accent, 0, 0.03, -0.2)
			part(g, cylz(0.02, 0.02, 0.12), M.metal, 0, 0.012, -0.32, X)
			md.mag = part(g, Gfx.box(0.036, 0.2, 0.055), M.metal, 0, -0.14, -0.06, 0.12)
			part(g, Gfx.box(0.045, 0.12, 0.055), M.polymer, 0, -0.09, 0.09, -0.3)
			for s in [-1, 1]:
				part(g, Gfx.box(0.012, 0.012, 0.22), M.metalLight, 0.022 * s, 0, 0.25)
			part(g, Gfx.box(0.06, 0.09, 0.022), M.polymer, 0, -0.015, 0.36)
			part(g, Gfx.box(0.04, 0.012, 0.06), M.metal, 0, 0.051, -0.02)
			for i in 7:
				part(g, Gfx.box(0.04, 0.008, 0.009), M.metal, 0, 0.053, -0.17 + i * 0.023)
			ring_sight(g, 0.08, -0.03, 0.022, 0.053)
			if arms: add_arms(md, Vector3(0.01, -0.08, 0.09), Vector3(-0.01, -0.035, -0.2))
			md.flash = flash_sprite(g, -0.4, 0.012, 0.26)
		"magnum":
			part(g, Gfx.box(0.042, 0.055, 0.14), M.chrome, 0, 0.022, -0.01)
			part(g, cylz(0.015, 0.015, 0.22), M.chrome, 0, 0.036, -0.18, X)
			part(g, Gfx.box(0.026, 0.014, 0.22), M.metal, 0, 0.054, -0.17)
			iron_sights(g, 0.05, -0.262, 0.05, 0.027)
			md.mag = part(g, cylz(0.032, 0.032, 0.058, 12), M.metal, 0, 0.022, -0.03, X)
			part(g, Gfx.box(0.044, 0.008, 0.07), M.accent, 0, -0.004, -0.06)
			part(g, Gfx.box(0.038, 0.13, 0.052), M.wood, 0, -0.062, 0.075, -0.35)
			if arms:
				add_arms(md, Vector3(0, -0.085, 0.085))
				support_handgun(md, Vector3(-0.025, -0.075, 0.065))
			md.flash = flash_sprite(g, -0.31, 0.036, 0.3)
		"raygun":
			part(g, Gfx.box(0.06, 0.08, 0.2), M.rayRed, 0, 0.02, 0)
			part(g, cylz(0.03, 0.05, 0.2, 20), M.rayRed, 0, 0.025, -0.19, X)
			for i in 3:
				ring_part(g, 0.047 - i * 0.005, 0.008, M.rayGlow, 0, 0.025, -0.12 - i * 0.055)
			part(g, cylz(0.02, 0.028, 0.04), M.chrome, 0, 0.025, -0.305, X)
			part(g, Gfx.sphere(0.014, 12, 8), M.rayGlow, 0, 0.025, -0.325)
			part(g, Gfx.box(0.02, 0.03, 0.12), M.chrome, 0, 0.07, -0.02)
			part(g, Gfx.sphere(0.005, 6, 4), M.sight, 0, 0.09, -0.07)
			part(g, Gfx.box(0.04, 0.12, 0.055), M.metal, 0, -0.07, 0.07, -0.3)
			md.mag = part(g, cylz(0.016, 0.016, 0.06), M.chrome, 0, -0.04, -0.06)
			part(md.mag, cylz(0.0165, 0.0165, 0.012), M.rayGlow, 0, 0, 0)
			if arms:
				add_arms(md, Vector3(0, -0.085, 0.085))
				support_handgun(md, Vector3(-0.025, -0.075, 0.065))
			md.flash = flash_sprite(g, -0.36, 0.025, 0.34, Color(0.5, 1.0, 0.55))
		"uzi":
			part(g, Gfx.box(0.052, 0.075, 0.24), M.metal, 0, 0.01, -0.04)
			part(g, Gfx.box(0.054, 0.012, 0.12), M.accent, 0, 0.049, -0.06)
			part(g, cylz(0.012, 0.012, 0.07, 10), M.metalLight, 0, 0.015, -0.19, X)
			md.mag = part(g, Gfx.box(0.032, 0.17, 0.04), M.metal, 0, -0.1, 0.02, -0.1)
			part(g, Gfx.box(0.04, 0.1, 0.05), M.polymer, 0, -0.06, 0.03, -0.1)
			for z in [-0.14, 0.05]:
				part(g, Gfx.box(0.012, 0.022, 0.012), M.metal, 0, 0.058, z)
			part(g, Gfx.sphere(0.003, 6, 4), M.sight, 0, 0.07, -0.14)
			for s in [-1, 1]:
				part(g, Gfx.box(0.008, 0.008, 0.16), M.metalLight, 0.02 * s, 0.0, 0.16)
			if arms: add_arms(md, Vector3(0, -0.07, 0.04), Vector3(-0.01, -0.03, -0.12))
			md.flash = flash_sprite(g, -0.24, 0.015, 0.22)
		"burst":
			part(g, Gfx.box(0.072, 0.1, 0.44), M.olive, 0, 0, 0)
			part(g, Gfx.box(0.08, 0.08, 0.3), M.metal, 0, 0.005, -0.36)
			for i in 3:
				part(g, Gfx.box(0.082, 0.01, 0.03), M.accent, 0, -0.02, -0.28 - i * 0.06)
			part(g, cylz(0.014, 0.014, 0.28), M.metalLight, 0, 0.02, -0.6, X)
			part(g, Gfx.box(0.05, 0.05, 0.06), M.metal, 0, 0.02, -0.76)
			md.mag = part(g, Gfx.box(0.05, 0.17, 0.08), M.metal, 0, -0.11, -0.06, 0.12)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.1, 0.13, -0.3)
			part(g, Gfx.box(0.06, 0.12, 0.2), M.olive, 0, -0.02, 0.33)
			part(g, Gfx.box(0.034, 0.014, 0.34), M.metal, 0, 0.057, -0.12)
			part(g, Gfx.box(0.04, 0.016, 0.08), M.metal, 0, 0.068, -0.03)
			ring_sight(g, 0.105, -0.04, 0.03, 0.068)
			if arms: add_arms(md, Vector3(0.01, -0.09, 0.12), Vector3(-0.01, -0.035, -0.34))
			md.flash = flash_sprite(g, -0.82, 0.02, 0.3)
		"dmr":
			part(g, Gfx.box(0.07, 0.095, 0.4), M.tan, 0, 0, 0)
			part(g, Gfx.box(0.076, 0.085, 0.32), M.polymer, 0, 0.005, -0.34)
			part(g, cylz(0.014, 0.016, 0.42), M.metal, 0, 0.02, -0.68, X)
			part(g, cylz(0.022, 0.02, 0.07), M.metal, 0, 0.02, -0.9, X)
			md.mag = part(g, Gfx.box(0.05, 0.12, 0.08), M.metal, 0, -0.09, -0.05, 0.1)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.1, 0.13, -0.3)
			part(g, Gfx.box(0.062, 0.12, 0.3), M.tan, 0, -0.02, 0.35)
			# low-power optic: open tube with clear glass, so aiming looks through it at a red dot
			var tube := Gfx.cyl(0.022, 0.022, 0.2, 20, true)
			var tm: StandardMaterial3D = M.metal.duplicate(); tm.cull_mode = BaseMaterial3D.CULL_DISABLED
			part(g, tube, tm, 0, 0.09, -0.04, X)
			part(g, Gfx.cyl(0.026, 0.022, 0.05, 20, true), tm, 0, 0.09, -0.165, X)
			for zr in [[0.06, 0.022], [-0.19, 0.026]]:
				ring_part(g, zr[1], 0.003, M.metal, 0, 0.09, zr[0])
			disc_part(g, 0.025, M.glass, 0, 0.09, -0.185)
			part(g, Gfx.sphere(0.0012, 6, 4), M.redDot, 0, 0.09, -0.18)
			for z in [-0.08, 0.02]:
				part(g, Gfx.box(0.024, 0.04, 0.02), M.metal, 0, 0.058, z)
			if arms: add_arms(md, Vector3(0.01, -0.09, 0.12), Vector3(-0.01, -0.04, -0.34))
			md.flash = flash_sprite(g, -0.95, 0.02, 0.36)
		"minigun":
			part(g, Gfx.box(0.13, 0.13, 0.3), M.metal, 0, 0, 0.02)
			part(g, Gfx.box(0.135, 0.02, 0.2), M.accent, 0, 0.06, 0.02)
			var sp := Node3D.new(); sp.position = Vector3(0, 0, -0.14); g.add_child(sp)
			for i in 6:
				var a := i / 6.0 * TAU
				part(sp, cylz(0.012, 0.012, 0.56, 8), M.metalLight, cos(a) * 0.035, sin(a) * 0.035, -0.28, X)
			for z in [-0.1, -0.5]:
				part(sp, cylz(0.056, 0.056, 0.03, 16), M.metal, 0, 0, z, X)
			md.mag = part(g, Gfx.box(0.1, 0.12, 0.14), M.olive, -0.1, -0.09, 0.05)
			part(g, Gfx.box(0.03, 0.03, 0.2), M.metal, 0, 0.11, -0.04)
			part(g, Gfx.box(0.03, 0.05, 0.03), M.metal, 0, 0.085, 0.05)
			part(g, Gfx.box(0.05, 0.13, 0.06), M.polymer, 0, -0.12, 0.14, -0.2)
			if arms: add_arms(md, Vector3(0.01, -0.12, 0.14), Vector3(-0.02, 0.13, -0.04), "top")
			md.flash = flash_sprite(g, -0.76, 0, 0.4)
			md.spin = sp
		"rocket":
			part(g, cylz(0.068, 0.068, 0.95, 24), M.olive, 0, 0, -0.15, X)
			part(g, cylz(0.08, 0.072, 0.1, 24), M.metal, 0, 0, -0.6, X)
			part(g, Gfx.cyl(0.09, 0.07, 0.12, 24, true), M.metal, 0, 0, 0.36, X)
			for z in [-0.35, 0.05]:
				part(g, cylz(0.071, 0.071, 0.03, 24), M.accent, 0, 0, z, X)
			md.mag = part(g, Gfx.cyl(0.0, 0.05, 0.16, 16), M.shell, 0, 0, -0.72, -X)
			part(g, Gfx.box(0.04, 0.12, 0.05), M.polymer, 0, -0.11, 0.08, -0.25)
			part(g, Gfx.box(0.04, 0.1, 0.05), M.polymer, 0, -0.1, -0.2, -0.1)
			part(g, Gfx.box(0.03, 0.06, 0.12), M.metal, -0.075, 0.05, -0.08)
			part(g, Gfx.sphere(0.004, 6, 4), M.sight, -0.075, 0.085, -0.13)
			if arms: add_arms(md, Vector3(0, -0.13, 0.1), Vector3(-0.01, -0.1, -0.2), "grip")
			md.flash = flash_sprite(g, -0.8, 0, 0.45)
	# trigger + guard on every gun
	var TRIG := { "rifle": [-0.05, 0.075], "burst": [-0.05, 0.075], "dmr": [-0.048, 0.075], "sniper": [-0.045, 0.075], "smg": [-0.045, 0.035], "lmg": [-0.06, 0.085],
		"shotgun": [-0.045, 0.065], "uzi": [-0.028, -0.035], "pistol": [-0.021, -0.01], "minigun": [-0.065, 0.085], "rocket": [-0.068, 0.025], "raygun": [-0.02, 0.015], "magnum": [-0.012, 0.02] }
	if TRIG.has(k):
		var t: Array = TRIG[k]
		ring_part(g, 0.03, 0.0055, M.metal, 0, t[0], t[1], Vector3(0, PI / 2, 0))
		part(g, Gfx.box(0.007, 0.032, 0.009), M.metalLight, 0, t[0] - 0.012, t[1] - 0.004, 0.35)
	if md.has("mag"):
		md.magBase = md.mag.position
	return md

func build_knife() -> Node3D:
	var g := Node3D.new()
	part(g, Gfx.box(0.005, 0.034, 0.26), M.blade, 0.004, 0.004, -0.13)
	part(g, Gfx.box(0.005, 0.02, 0.06), M.blade, 0.004, 0.012, -0.28, 0.4)
	part(g, Gfx.box(0.07, 0.014, 0.014), M.metal, 0, 0, 0.005)
	part(g, Gfx.capsule(0.017, 0.124, 10), M.polymer, 0, 0, 0.07, PI / 2)
	hand(g, Vector3(0, -0.005, 0.07), "grip", PI / 2 - 0.1)
	forearm(g, Vector3(0.01, -0.02, 0.11), Vector3(0.12, -0.2, 0.45), 0.045)
	g.visible = false
	return g

# bare gun for the floor and the mystery box
func world_gun(k: String) -> Node3D:
	var md := build(k, false)
	var g: Node3D = md.group
	if md.has("flash"):
		md.flash.queue_free()
	return g

# ============================================================ gun viewport (its own little world, drawn over the scene)
func setup(gun_world_root: Node3D, cam: Camera3D) -> void:
	_materials()
	gun_cam = cam
	holder = Node3D.new()
	gun_world_root.add_child(holder)
	for k in W:
		var md := build(k)
		md.group.visible = false
		holder.add_child(md.group)
		models[k] = md
	knife = build_knife()
	gun_world_root.add_child(knife)
	throw_arm = Node3D.new()
	hand(throw_arm, Vector3.ZERO, "grip", -0.5, true)
	forearm(throw_arm, Vector3(-0.02, -0.04, 0.03), Vector3(-0.1, -0.3, 0.42), 0.04, true)
	throw_arm.visible = false
	gun_world_root.add_child(throw_arm)
	gun_muzzle_light = OmniLight3D.new()
	gun_muzzle_light.light_color = G.col(0xffa040)
	gun_muzzle_light.omni_range = 3
	gun_muzzle_light.light_energy = 0
	gun_world_root.add_child(gun_muzzle_light)

func reset(prim: String) -> void:
	current = prim; last = "pistol"
	mags = { prim: W[prim].magSize, "pistol": 12 }
	reloading = false; reload_t = 0; cooldown = 0; bloom = 0; kick = 0; recoil_off = 0; spray = 0; spray_t = 0
	ads_t = 0; switch_t = 0; switch_to = ""; melee_t = 0; slide_kick = 0; throw_t = 0; throw_cd = 0; burst_left = 0; spin = 0
	G.firing = false; G.aiming = false

# ============================================================ actions
func start_reload() -> void:
	if reloading or switch_t > 0 or melee_t > 0 or mags.get(current, 0) == mag_of(current):
		return
	if G.pw("ammo"):
		mags[current] = mag_of(current)
		return
	reloading = true; reload_t = reload_of(); burst_left = 0; cue_i = 0
	G.trigger_queued = false

func switch_weapon(to: String) -> void:
	if to == "" or not W.has(to) or melee_t > 0:
		return
	if to == current and switch_t <= 0:
		return
	switch_to = to; burst_left = 0; spin = 0
	if switch_t <= 0:
		switch_t = SWITCH_TIME
	reloading = false
	G.audio.with_cat("weapons", func(): G.audio.tone(900, 0.05, 0.08, "triangle", 600))

func start_melee() -> void:
	if melee_t > 0:
		return
	melee_t = MELEE_TIME; melee_hit = false
	reloading = false
	G.audio.with_cat("weapons", func(): G.audio.swoosh())

func do_melee_hit() -> void:
	var P: Node = G.player
	var f: Vector3 = P.fwd()
	var target: Variant = null
	var best_d := 2.6
	for b in G.enemies.list:
		if b.dead or absf(P.pos.y - b.pos.y) > 1.4:
			continue
		var to := Vector3(b.pos.x - P.pos.x, 0, b.pos.z - P.pos.z)
		var d := to.length()
		if d < best_d and d > 0 and (to / d).dot(f) > 0.7:
			target = b; best_d = d
	if target != null:
		var hp: float = target.hp
		target.damage(KNIFE_DMG * (3.0 if G.pw("quad") else 1.0), false, "knife")
		G.ui.damage_number(target.pos + Vector3(0, 1.5, 0), minf(hp, KNIFE_DMG), false, target.dead)
		G.fx.particles(target.pos + Vector3(0, 1.2, 0), target.spark_color, 16, -f, 4)
		G.ui.hitmarker(target.dead)
		G.audio.tone(140, 0.12, 0.35, "square", 60)
		G.audio.tone(700, 0.18, 0.2, "triangle", 1600)
		P.vel += f * 3
		P.shake = maxf(P.shake, 0.4)
		return
	var cam: Camera3D = G.camera
	var dir := -cam.global_basis.z
	var h: Dictionary = G.world.ray(cam.global_position, cam.global_position + dir * 2.0)
	if not h.is_empty():
		G.fx.particles(h.position + h.normal * 0.03, 0xffe0a0, 6, h.normal, 3)
		G.audio.tone(2600, 0.06, 0.15, "square", 1800)

# ============================================================ shooting
func current_spread() -> float:
	var w := cur()
	var P: Node = G.player
	var speed := Vector2(P.vel.x, P.vel.z).length()
	return (lerpf(w.hip, w.ads, ads_t) + speed / 8.5 * lerpf(w.move, w.move * 0.33, ads_t) + (0.0 if P.on_ground else 0.06) + bloom) * lerpf(1, 0.65, P.crouch_t)

func muzzle_world() -> Vector3:
	var md: Dictionary = models[current]
	var lp: Vector3 = md.flash.global_position if md.has("flash") else Vector3(0, -0.1, -0.6)
	return G.camera.global_transform * lp

func _dir(spread: float) -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * spread
	return G.camera.global_basis * Vector3(cos(a) * r, sin(a) * r, -1).normalized()

func _cast(origin: Vector3, dir: Vector3, w: Dictionary, agg: Dictionary) -> void:
	var h: Dictionary = G.world.ray(origin, origin + dir * 250.0, true)
	var end := origin + dir * 150.0
	var quad := G.pw("quad")
	if not h.is_empty():
		end = h.position
		var col: Object = h.collider
		if col.has_meta("enemy"):
			var enemy: Object = col.get_meta("enemy")
			if not enemy.dead:
				var p: String = col.get_meta("part")
				var head := p == "head"
				var prev: float = enemy.hp
				var dmg: float = w.dmg[p] * (3.0 if quad else 1.0) * dmg_mul(current)
				var killed: bool = enemy.damage(dmg, head, current)
				var a: Dictionary = agg.get(enemy, { "sum": 0.0, "point": h.position, "head": false, "killed": false })
				a.sum += minf(prev, dmg); a.head = a.head or head; a.killed = a.killed or killed
				agg[enemy] = a
			G.fx.particles(h.position, enemy.spark_color, 3 if w.has("pellets") else 7, -dir, 3)
		else:
			var n: Vector3 = h.normal
			var p2: Vector3 = h.position + n * 0.03
			G.fx.particles(p2, 0xffc680, 1 if w.has("pellets") else 3, n, 3)
			G.fx.particles(p2, 0x9a948a, 2 if w.has("pellets") else 4, n, 2.5, false)
			if not w.has("pellets") or randf() < 0.3:
				G.fx.spawn_smoke(p2, 0xd6cec2, 0.5)
			G.fx.decal(h.position, n)
	G.fx.tracer(muzzle_world(), end, 0xd08cff if quad else 0xffe29a)

func shoot() -> void:
	var w := cur()
	var P: Node = G.player
	if not G.pw("ammo"):
		mags[current] -= 1
	cooldown = w.rate * (0.75 if G.pw("haste") else 1.0) * (0.8 if G.perks.has("rate") else 1.0)
	G.shots_fired += 1
	G.inp.rumble(0.55 if w.has("pellets") or w.has("projectile") else (0.7 if w.get("scope", false) else 0.18), 0.4, 0.12 if w.get("scope", false) or w.has("pellets") else 0.06)
	var origin: Vector3 = G.camera.global_position
	var agg := {}
	var spread := current_spread()
	if w.has("projectile"):
		# energy bolt / rocket: aim where the crosshair points, launch it from the muzzle
		var dir := _dir(spread)
		var h: Dictionary = G.world.ray(origin, origin + dir * 120.0, true)
		var target: Vector3 = h.position if not h.is_empty() else origin + dir * 120.0
		var m := muzzle_world()
		G.items.launch(w.projectile, m, (target - m).normalized() * w.projSpeed)
	else:
		for i in w.get("pellets", 1):
			var sp: float = (w.pelletSpread * lerpf(1, 0.75, ads_t) + spread * 0.5) if w.has("pellets") else spread
			_cast(origin, _dir(sp), w, agg)
	var any_kill := false
	for a in agg.values():
		G.ui.damage_number(a.point, a.sum, a.head, a.killed)
		any_kill = any_kill or a.killed
	if agg.size() > 0:
		G.shots_hit += 1
		G.ui.hitmarker(any_kill)
		G.audio.tone(700 if any_kill else 1500, 0.18 if any_kill else 0.05, 0.25 if any_kill else 0.12, "triangle" if any_kill else "square", 1600 if any_kill else 1500)
	flash_t = 0.05; kick = 1; slide_kick = 1
	bloom = minf(0.05, bloom + w.bloom)
	# every weapon has its own spray: `n` counts the shots of the current burst and resets when you let go for a moment
	var n := spray
	spray += 1
	var steady := lerpf(1, 0.6, ads_t) * lerpf(1, 0.7, P.crouch_t)
	spray_t = w.rate + 0.28
	recoil_off += w.recoil * lerpf(1, 0.5, ads_t) * lerpf(1, 0.7, P.crouch_t)
	P.pitch = clampf(P.pitch + w.climb * recoil_v(current, n) * steady, -1.5, 1.5)
	var jit: float = JIT.get(current, 0.001)
	P.yaw -= (recoil_h(current, n) + G.rnd(-jit, jit)) * steady
	P.shake = maxf(P.shake, w.get("shake", 0.12))
	if w.get("projectile", "") == "plasma":
		G.audio.ray_sfx()
	elif w.has("projectile"):
		G.audio.rocket_launch()
	else:
		G.audio.shot(w.snd, w.vol)
	var md: Dictionary = models[current]
	if w.has("projectile"):
		pass
	elif md.has("pump"):
		G.audio.tone(900, 0.05, 0.12, "square", 500, 0.28); G.audio.tone(650, 0.06, 0.12, "square", 380, 0.46)
	elif md.has("bolt"):
		G.audio.tone(1300, 0.04, 0.1, "square", 700, 0.4); G.audio.tone(900, 0.05, 0.1, "square", 600, 0.7)
	else:
		G.audio.shell(G.rnd(0.3, 0.45))
	if mags[current] == 0:
		start_reload()

# ============================================================ per-frame update: firing logic + the weapon pose
func update(dt: float) -> void:
	var P: Node = G.player
	cooldown -= dt
	throw_cd -= dt
	var lower := 0.0
	if switch_t > 0:
		switch_t -= dt
		if switch_t <= SWITCH_TIME / 2 and switch_to != "" and switch_to != current:
			last = current; current = switch_to
			bloom = 0
		if switch_t <= 0:
			switch_to = ""
		var t := clampf(switch_t / SWITCH_TIME, 0, 1)
		lower = (1 - t) * 2 if t > 0.5 else t * 2
	var melee_p := 0.0
	if melee_t > 0:
		melee_t -= dt
		melee_p = 1 - clampf(melee_t / MELEE_TIME, 0, 1)
		if not melee_hit and melee_p > 0.32:
			melee_hit = true; do_melee_hit()
	if throw_t > 0:
		throw_t -= dt
	var busy := switch_t > 0 or melee_t > 0 or throw_t > 0
	var w := cur()
	var md: Dictionary = models[current]

	if reloading:
		reload_t -= dt
		# mechanical reload sounds, cued along the animation
		var cues: Array = RELOAD_CUES[w.get("cues", "default")]
		var rp := 1 - reload_t / reload_of()
		while cue_i < cues.size() and rp >= cues[cue_i][0]:
			G.audio.mech(cues[cue_i][1]); cue_i += 1
		if reload_t <= 0:
			reloading = false; mags[current] = mag_of(current)
	# simplified aiming: holding fire also aims, and shots wait until the sights are up
	var auto_aim: bool = G.settings.autoAds and G.firing and not G.aiming and not w.has("projectile")
	var need_ads := (0.85 if w.get("scope", false) else 0.3) if auto_aim else 0.0
	# no shot queue: clicks while reloading/switching are dropped, early clicks are buffered only briefly
	if G.trigger_queued and (reloading or busy):
		G.trigger_queued = false
	if G.trigger_queued and G.now - G.trigger_t > 0.18 and not auto_aim:
		G.trigger_queued = false
	# minigun: barrels must spin up before it fires
	if w.get("spinup", false):
		var was := spin
		spin = clampf(spin + (1.8 if (G.firing or G.aiming) and not busy and not reloading else -1.2) * dt, 0, 1)
		if was == 0 and spin > 0:
			G.audio.tone(90, 0.5, 0.06, "sawtooth", 320)
		md.spin.rotation.z += spin * dt * 38
	var wants_fire: bool = (G.firing if w.auto else G.trigger_queued) and (not w.get("spinup", false) or spin > 0.7) and ads_t >= need_ads
	if w.has("burst") and burst_left > 0:
		if not busy and not reloading and cooldown <= 0:
			if mags[current] > 0:
				shoot()
				burst_left -= 1
				if burst_left == 0:
					cooldown = w.burstDelay
			else:
				burst_left = 0
	elif wants_fire and not busy and not reloading and cooldown <= 0 and P.sprint_t < 0.4:
		if mags.get(current, 0) > 0:
			shoot()
			if w.has("burst"):
				burst_left = w.burst - 1
				if burst_left == 0:
					cooldown = w.burstDelay
		else:
			start_reload()
		G.trigger_queued = false
	bloom = maxf(0, bloom - dt * 0.08)
	spray_t -= dt
	if spray_t <= 0:
		spray = 0
	recoil_off *= exp(-dt * 12)
	kick *= exp(-dt * 18)
	slide_kick *= exp(-dt * 28)
	flash_t -= dt
	ads_t = clampf(ads_t + (1.0 if ((G.aiming or auto_aim) and not reloading and not busy and P.sprint_t < 0.5) else -1.0) * dt * w.get("adsSpeed", 7), 0, 1)

	G.camera.fov = lerpf(75, w.fov, ads_t) + P.sprint_t * 5
	gun_cam.fov = lerpf(60, 45, ads_t)
	for k in models:
		models[k].group.visible = k == current

	# pose: hip/ads, bob, sway, strafe tilt, jump lag, sprint, kick, reload, switch, melee
	G.sway *= exp(-dt * 8)
	var speed := Vector2(P.vel.x, P.vel.z).length()
	var bob_amt: float = (speed / 8.0 if P.on_ground else 0.0) * (1 - ads_t * 0.85)
	var bt: float = P.bob
	var sp := G.smooth(P.sprint_t)
	var ads := ads_t
	var hp: Vector3 = w.hipPos.lerp(w.adsPos, ads)
	hp.x += sin(bt) * 0.014 * bob_amt - clampf(G.sway.x, -0.03, 0.03)
	hp.y += absf(cos(bt)) * 0.014 * bob_amt + clampf(G.sway.y, -0.03, 0.03) + sin(G.now * 1.7) * 0.0025 * (1 - ads)
	hp.y += clampf(-P.vel.y * 0.004, -0.04, 0.04) - P.land_off * 0.35
	hp.z += kick * w.get("kickBack", 0.05)
	hp.x -= sp * 0.06; hp.y -= sp * 0.05
	# hip pose: held a little higher and turned toward the crosshair, so its side and both hands are in view
	var hip = (1 - G.smooth(ads)) * w.get("hipYaw", 0.2) / 0.2
	hp.x -= hip * 0.03; hp.y += hip * 0.045
	var rot := Vector3(kick * w.get("kickRot", 0.06) - sp * 0.25 + hip * 0.02, sp * 0.75 + hip * 0.2,
		P.roll * 3 + sp * 0.3 + sin(G.now * 1.1) * 0.004 * (1 - ads) - hip * 0.06)
	# reload: tilt, mag drops out and a new one slides in
	var L: Node3D = md.get("leftArm")
	if reloading:
		var p := 1 - reload_t / reload_of()
		var tilt := sin(minf(1, p * 1.1) * PI)
		rot.x -= tilt * 0.3; rot.z += tilt * 0.5; hp.y -= tilt * 0.06
		if p > 0.74 and p < 0.86:
			hp.y += sin((p - 0.74) / 0.12 * PI) * 0.018
		var off := 0.0
		var vis := true
		if p < 0.12:
			off = 0
		elif p < 0.34:
			off = -G.smooth((p - 0.12) / 0.22) * 0.32
		elif p < 0.5:
			vis = false
		elif p < 0.76:
			off = -(1 - G.smooth((p - 0.5) / 0.26)) * 0.32
		md.mag.visible = vis
		md.mag.position.y = md.magBase.y + off
		# the off hand lets go, pulls the magazine down and out of view, brings the new one up and returns
		if L:
			if not md.has("reloadD"):
				md.reloadD = md.magBase - md.leftPos + Vector3(-0.01, -0.07, 0.03)
			var k := G.smooth(p / 0.12) if p < 0.12 else (1 - G.smooth((p - 0.88) / 0.12) if p > 0.88 else 1.0)
			L.position = md.reloadD * k
			L.position.y += off if vis else -0.4
			L.rotation.z = k * 0.3
	else:
		md.mag.visible = true
		md.mag.position.y = md.magBase.y
		if L:
			L.position = Vector3.ZERO; L.rotation.z = 0
	if md.has("slide"):
		var locked: bool = mags.get("pistol", 1) == 0 and not (reloading and 1 - reload_t / reload_of() > 0.8)
		md.slide.position.z = md.slideBase + (0.035 if locked else slide_kick * 0.045)
	# pump / bolt cycling after each shot
	if (md.has("pump") or md.has("bolt")) and cooldown > 0 and not reloading:
		var p2: float = 1 - cooldown / w.rate
		var cyc := sin(clampf((p2 - 0.18) / 0.6, 0, 1) * PI)
		if md.has("pump"):
			md.pump.position.z = md.pumpBase + cyc * 0.11; rot.x += cyc * 0.06
		if md.has("bolt"):
			md.bolt.rotation.z = cyc * 1.3
			md.bolt.position.z = 0.08 + sin(clampf((p2 - 0.3) / 0.4, 0, 1) * PI) * 0.07
			rot.z += cyc * 0.18
	else:
		if md.has("pump"): md.pump.position.z = md.pumpBase
		if md.has("bolt"):
			md.bolt.rotation.z = 0; md.bolt.position.z = 0.08
	var scoped = w.get("scope", false) and ads_t > 0.85 and switch_t <= 0
	G.ui.scope_on = scoped
	holder.visible = not scoped
	hp.y -= G.smooth(lower) * 0.4
	rot.x -= G.smooth(lower) * 0.6
	rot.z += G.smooth(lower) * 0.5
	var throw_p := sin((1 - throw_t / THROW_TIME) * PI) if throw_t > 0 else 0.0
	hp.y -= throw_p * 0.22; rot.x -= throw_p * 0.35; hp.x += throw_p * 0.08
	# throw: the left arm comes up from below, winds back and swings forward, then drops away
	throw_arm.visible = throw_t > 0
	if throw_arm.visible:
		var t := 1 - throw_t / THROW_TIME
		var up := G.smooth(clampf(t / 0.3, 0, 1))
		var fw := G.smooth(clampf((t - 0.25) / 0.35, 0, 1))
		var out := G.smooth(clampf((t - 0.7) / 0.3, 0, 1))
		throw_arm.position = Vector3(-0.26 + fw * 0.14, -0.52 + up * 0.42 - fw * 0.06 - out * 0.45, -0.4 - fw * 0.34)
		throw_arm.rotation = Vector3(0.9 - fw * 1.5, 0.25 - fw * 0.2, 0.2)
	var melee_dip := sin(melee_p * PI) if melee_p > 0 else 0.0
	hp.y -= melee_dip * 0.3
	hp.x += melee_dip * 0.1
	holder.position = hp
	holder.rotation = rot

	knife.visible = melee_t > 0
	if knife.visible:
		var a := G.smooth(clampf((melee_p - 0.12) / 0.3, 0, 1))
		var o := G.smooth(clampf((melee_p - 0.6) / 0.4, 0, 1))
		knife.position = Vector3(lerpf(0.32, -0.22, a), lerpf(-0.12, -0.2, a) - o * 0.35 - (1 - G.smooth(clampf(melee_p / 0.12, 0, 1))) * 0.3, lerpf(-0.42, -0.55, a))
		knife.rotation = Vector3(lerpf(0.1, -0.3, a), lerpf(0.9, -0.5, a), lerpf(-0.9, 0.3, a))

	var fl: Sprite3D = md.get("flash")
	if fl:
		fl.visible = flash_t > 0
		if fl.visible:
			fl.rotation.z = randf() * TAU
			fl.pixel_size = G.rnd(0.8, 1.2) * float(fl.get_meta("size")) / 128.0
	G.main.muzzle_light.light_energy = 3.0 if flash_t > 0 else 0.0
	gun_muzzle_light.light_energy = 2.0 if flash_t > 0 else 0.0
	if flash_t > 0:
		gun_muzzle_light.position = holder.position + Vector3(0, 0.05, -0.3)
