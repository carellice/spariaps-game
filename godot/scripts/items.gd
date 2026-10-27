# Spariaps — Oggetti: kit e bonus, granate e proiettili, esplosioni, armi a terra e cassa misteriosa.
extends Node

var pickups: Array = []
var projectiles: Array = []
var drops: Array = []
var mats := {}
var pu_mats := {}
var box := {}
var told := {}              # power-up type -> when its "available" toast was last shown

const PROJ := {
	"frag": { "fuse": 2.2, "bounce": 0.38, "grav": 20.0, "r": 0.07 },
	"stun": { "fuse": 1.4, "bounce": 0.3, "grav": 20.0, "r": 0.07 },
	"smoke": { "fuse": 1.3, "bounce": 0.25, "grav": 20.0, "r": 0.07 },
	"tknife": { "grav": 5.0, "hits": true, "life": 3.0, "r": 0.02 },
	"plasma": { "grav": 0.0, "hits": true, "life": 2.5, "r": 0.05 },
	"rocket": { "grav": 0.0, "hits": true, "life": 4.0, "r": 0.08 },
	"erocket": { "grav": 0.0, "hits": true, "enemy": true, "life": 5.0, "r": 0.1 },
	"acid": { "grav": 9.0, "hits": true, "enemy": true, "life": 5.0, "r": 0.12 },
}

func _ready() -> void:
	G.items = self

func setup() -> void:
	mats = {
		"health": Gfx.mat(0xeafff0, 0.3, 0.1), "armor": Gfx.mat(0x1d4f9a, 0.25, 0.6),
		"healthRing": Gfx.glow(0x2dff7a, 2.5), "armorRing": Gfx.glow(0x3aa8ff, 2.5), "equipRing": Gfx.glow(0xffa040, 2.5),
		"healthDisc": Gfx.additive(0x2dff7a, 0.55, Gfx.glow_tex()), "armorDisc": Gfx.additive(0x3aa8ff, 0.55, Gfx.glow_tex()), "equipDisc": Gfx.additive(0xffa040, 0.55, Gfx.glow_tex()),
		"pad": Gfx.mat(0x2a2f38, 0.4, 0.7),
		"olive": Gfx.mat(0x4d5a3a, 0.55, 0.3), "steel": Gfx.mat(0x9aa2ab, 0.3, 0.9), "smoke": Gfx.mat(0x6b7280, 0.5, 0.4), "band": Gfx.mat(0xeeeeee, 0.5),
		"accent": Gfx.glow(0xff6b3d, 0.8), "blade": Gfx.mat(0xe8edf2, 0.22, 0.75), "poly": Gfx.mat(0x1f2226, 0.5, 0.15), "shell": Gfx.mat(0xb3261e, 0.4, 0.3),
		"plasma": Gfx.glow(Color(0.3, 1.0, 0.45), 3.0), "plasmaGlow": Gfx.additive(Color(0.25, 1.2, 0.35), 0.75, Gfx.glow_tex()),
		"flame": Gfx.additive(Color(1, 0.75, 0.45), 1.0, Gfx.flash_tex(), 2.0),
	}
	for k in ["health", "armor"]:
		mats[k].emission_enabled = true
		mats[k].emission = G.col(0x2dff7a if k == "health" else 0x3aa8ff)
		mats[k].emission_energy_multiplier = 1.4
	mats.plasmaGlow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mats.flame.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_build_box()

# ============================================================ pickups: health packs, armour, throwables, arena power-ups
func proj_model(kind: String) -> Node3D:
	var g := Node3D.new()
	var add := func(mesh: Mesh, m: Material, p: Vector3, rot: Vector3) -> MeshInstance3D: return Gfx.mesh_node(mesh, m, p, rot, g)
	match kind:
		"frag":
			add.call(Gfx.sphere(0.06, 12, 8), mats.olive, Vector3.ZERO, Vector3.ZERO)
			add.call(Gfx.cyl(0.018, 0.018, 0.05, 8), mats.steel, Vector3(0, 0.07, 0), Vector3.ZERO)
			add.call(Gfx.box(0.012, 0.07, 0.02), mats.steel, Vector3(0.03, 0.03, 0), Vector3.ZERO)
		"stun":
			add.call(Gfx.cyl(0.045, 0.045, 0.14, 12), mats.steel, Vector3.ZERO, Vector3.ZERO)
			add.call(Gfx.cyl(0.047, 0.047, 0.025, 12), mats.accent, Vector3.ZERO, Vector3.ZERO)
		"smoke":
			add.call(Gfx.cyl(0.045, 0.045, 0.14, 12), mats.smoke, Vector3.ZERO, Vector3.ZERO)
			add.call(Gfx.cyl(0.047, 0.047, 0.025, 12), mats.band, Vector3(0, 0.03, 0), Vector3.ZERO)
		"tknife":
			add.call(Gfx.box(0.03, 0.005, 0.15), mats.blade, Vector3(0, 0, 0.06), Vector3.ZERO)
			add.call(Gfx.box(0.024, 0.014, 0.08), mats.poly, Vector3(0, 0, -0.05), Vector3.ZERO)
		"rocket", "erocket":
			add.call(Gfx.cyl(0.045, 0.045, 0.34, 12), mats.olive, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			add.call(Gfx.cyl(0.0, 0.045, 0.12, 12), mats.shell, Vector3(0, 0, 0.23), Vector3(PI / 2, 0, 0))
			var f: MeshInstance3D = add.call(Gfx.plane(1, 1), mats.flame, Vector3(0, 0, -0.22), Vector3.ZERO)
			f.scale = Vector3.ONE * 0.5
			f.name = "flame"
			if kind == "erocket":
				g.scale = Vector3.ONE * 1.5
		_:
			add.call(Gfx.sphere(0.06, 10, 6), mats.plasma, Vector3.ZERO, Vector3.ZERO)
			var s: MeshInstance3D = add.call(Gfx.plane(0.7, 0.7), mats.plasmaGlow, Vector3.ZERO, Vector3.ZERO)
			s.name = "glow"
			if kind == "acid":
				g.scale = Vector3.ONE * 1.5
	for c in g.get_children():
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

func _power_mats(type: String) -> Dictionary:
	if pu_mats.has(type):
		return pu_mats[type]
	var c := G.col(G.POWERUPS[type].color)
	var body := Gfx.mat(c.lerp(Color.WHITE, 0.35), 0.25, 0.3)
	body.emission_enabled = true; body.emission = c; body.emission_energy_multiplier = 1.6
	pu_mats[type] = { "body": body, "ring": Gfx.glow(c, 2.5), "disc": Gfx.additive(c, 0.7, Gfx.glow_tex()), "beam": Gfx.beam(c, 0.55) }
	return pu_mats[type]

func _power_model(type: String, m: Material) -> Node3D:
	var g := Node3D.new()
	match type:
		"jump":
			for y in [-0.12, 0.1]:
				Gfx.mesh_node(Gfx.cyl(0.0, 0.2, 0.2, 16), m, Vector3(0, y, 0), Vector3.ZERO, g)
			Gfx.mesh_node(Gfx.cyl(0.06, 0.06, 0.22, 12), m, Vector3(0, -0.3, 0), Vector3.ZERO, g)
		"haste":
			Gfx.mesh_node(Gfx.box(0.07, 0.34, 0.08), m, Vector3(0.03, 0.12, 0), Vector3(0, 0, -0.5), g)
			Gfx.mesh_node(Gfx.box(0.07, 0.34, 0.08), m, Vector3(-0.03, -0.12, 0), Vector3(0, 0, -0.5), g)
			Gfx.mesh_node(Gfx.box(0.22, 0.06, 0.08), m, Vector3(0, 0, 0), Vector3.ZERO, g)
		"ammo":
			for i in 3:
				Gfx.mesh_node(Gfx.capsule(0.05, 0.32, 12), m, Vector3((i - 1) * 0.13, 0, 0), Vector3.ZERO, g)
		"quad":
			Gfx.mesh_node(Gfx.sphere(0.26, 6, 3), m, Vector3.ZERO, Vector3.ZERO, g)
			var shell := Gfx.mesh_node(Gfx.sphere(0.4, 6, 3), Gfx.additive(G.POWERUPS.quad.color, 0.35), Vector3.ZERO, Vector3.ZERO, g)
			g.set_meta("spin", shell)
		_:
			for i in 5:
				Gfx.mesh_node(Gfx.box(0.08, 0.3, 0.06), m, Vector3(cos(i * TAU / 5 + PI / 2) * 0.12, sin(i * TAU / 5 + PI / 2) * 0.12, 0), Vector3(0, 0, i * TAU / 5), g)
	return g

func _ring_node(m: Material, parent: Node3D, y: float, s := 1.0) -> MeshInstance3D:
	var r := Gfx.mesh_node(Gfx.torus(0.42, 0.025, 40), m, Vector3(0, y, 0), Vector3.ZERO, parent)
	r.scale = Vector3.ONE * s
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return r

func _disc_node(m: Material, parent: Node3D, y: float, s := 1.0) -> MeshInstance3D:
	var d := Gfx.mesh_node(World.flat_quad(1.5, 1.5), m, Vector3(0, y, 0), Vector3.ZERO, parent)
	d.scale = Vector3.ONE * s
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d

func make_pickup(type: String, x: float, z: float, temp := false) -> Dictionary:
	var Wd: Node = G.world
	var p := { "type": type, "temp": temp, "power": G.POWERUPS.has(type), "active": true, "respawn": 0.0, "life": 20.0 if temp else INF, "phase": randf() * 6.0, "kind": "" }
	var g := Node3D.new()
	var item := Node3D.new()
	g.add_child(item)
	p.group = g; p.item = item
	if p.power:
		# power-ups keep their exact spot (the quad sits on top of the central platform)
		p.pos = Vector3(x, Wd.ground_at(x, z, 10, 0.3), z)
		var m := _power_mats(type)
		var model := _power_model(type, m.body)
		item.add_child(model)
		p.model = model
		p.ring = _ring_node(m.ring, g, 0.1, 1.35)
		Gfx.mesh_node(Gfx.cyl(0.72, 0.8, 0.08, 32), mats.pad, Vector3(0, 0.04, 0), Vector3.ZERO, g)
		p.disc = _disc_node(m.disc, g, 0.09, 1.6)
		p.beam = Gfx.mesh_node(Gfx.cyl(0.5, 0.62, 5, 24, true), m.beam, Vector3(0, 2.5, 0), Vector3.ZERO, g)
		p.beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := OmniLight3D.new()
		l.light_color = G.col(G.POWERUPS[type].color)
		l.omni_range = 7
		l.position.y = 1.1
		l.visible = G.settings.quality != "low"
		g.add_child(l)
		p.light = l
		g.position = p.pos
		G.scene_root.add_child(g)
		if G.POWERUPS[type].first > 0:
			p.active = false; p.respawn = G.POWERUPS[type].first; _shown(p, false)
		return p
	var idx: int = Wd.nearest_free(Wd.cell_idx(x, z), Wd.grid)
	p.pos = Vector3(x, 0, z) if temp else Vector3(idx % World.GN - World.HALF + 0.5, 0, idx / World.GN - World.HALF + 0.5)
	if type == "equip":
		_set_kind(p, G.random_equip())
	elif type == "health":
		Gfx.mesh_node(Gfx.box(0.34, 0.11, 0.11), mats.health, Vector3.ZERO, Vector3.ZERO, item)
		Gfx.mesh_node(Gfx.box(0.11, 0.34, 0.11), mats.health, Vector3.ZERO, Vector3.ZERO, item)
	else:
		Gfx.mesh_node(Gfx.box(0.34, 0.38, 0.07), mats.armor, Vector3.ZERO, Vector3.ZERO, item)
		Gfx.mesh_node(Gfx.box(0.24, 0.24, 0.08), mats.armor, Vector3(0, -0.15, 0), Vector3(0, 0, PI / 4), item)
	p.ring = _ring_node(mats[type + "Ring"], g, 0.06)
	_disc_node(mats[type + "Disc"], g, 0.02)
	g.position = p.pos
	G.scene_root.add_child(g)
	return p

func temp_pickup(type: String, x: float, z: float) -> void:
	pickups.append(make_pickup(type, x, z, true))

# throwable crate: shows the item it contains, rerolled at every respawn
func _set_kind(p: Dictionary, kind: String) -> void:
	p.kind = kind
	for c in p.item.get_children():
		c.queue_free()
	var m := proj_model(kind)
	m.scale = Vector3.ONE * (2.6 if kind == "tknife" else 2.4)
	if kind == "tknife":
		m.rotation = Vector3(PI / 2, 0, 0.5)
	p.item.add_child(m)

func _shown(p: Dictionary, on: bool) -> void:
	if not p.power:
		p.group.visible = on
		return
	# the pad stays on the floor while a power-up is recharging
	p.item.visible = on; p.ring.visible = on; p.beam.visible = on; p.disc.visible = on
	p.light.light_energy = 1.5 * G.light_k() if on else 0.0

func color_of(p: Dictionary) -> int:
	if p.power:
		return G.POWERUPS[p.type].color
	return { "health": 0x2dff7a, "armor": 0x3aa8ff, "equip": 0xffa040 }[p.type]

func _update_pickup(p: Dictionary, dt: float) -> bool:
	var P: Node = G.player
	if not p.active:
		p.respawn -= dt
		if p.respawn <= 0:
			if p.type == "equip":
				_set_kind(p, G.random_equip())
			p.active = true; _shown(p, true)
			G.fx.particles(p.pos + Vector3(0, 0.6, 0), color_of(p), 24 if p.power else 12, Vector3.UP, 3.5 if p.power else 2.0)
			if p.power:
				var def: Dictionary = G.POWERUPS[p.type]
				var d := Vector2(P.pos.x - p.pos.x, P.pos.z - p.pos.z).length()
				if def.first >= 30 and G.now - float(told.get(p.type, -99.0)) > 5:
					told[p.type] = G.now
					G.ui.toast("%s DISPONIBILE" % def.name, def.css)
				G.audio.power_spawn(clampf(1 - d / 45, 0.15, 1))
		return true
	if p.temp:
		p.life -= dt
		if p.life <= 0:
			p.group.queue_free()
			return false
		p.group.visible = p.life > 4 or sin(p.life * 20) > 0
	p.phase += dt
	p.item.position.y = (1.05 if p.power else 0.75) + sin(p.phase * 2.2) * 0.08
	p.item.rotation.y += dt * (2.2 if p.power else 1.6)
	p.ring.scale = Vector3.ONE * (1.35 if p.power else 1.0) * (1 + sin(p.phase * 3) * 0.06)
	var d2 := Vector2(P.pos.x - p.pos.x, P.pos.z - p.pos.z).length()
	if p.power:
		if p.model.has_meta("spin"):
			var sp: Node3D = p.model.get_meta("spin")
			sp.rotation.x += dt * 1.3; sp.rotation.z -= dt * 0.9
		p.beam.rotation.y += dt * 0.8
		p.light.light_energy = (1.2 + sin(p.phase * 4) * 0.3) * G.light_k()
		if d2 < 1.2 and absf(P.pos.y - p.pos.y) < 1.3:
			activate_power(p.type)
			return _consume(p)
		return true
	if d2 < 1.1 and absf(P.pos.y - p.pos.y) < 1.3:
		if p.type == "health" and P.hp < 100:
			var gain := minf(35, 100 - P.hp)
			P.hp += gain
			G.ui.toast("+%d SALUTE" % ceili(gain), "#34d399")
			G.audio.pickup(false)
			return _consume(p)
		if p.type == "equip" and G.equip[p.kind] < G.EQUIP_MAX[p.kind]:
			var k: String = p.kind
			var n := 2 if k == "tknife" else 1
			G.equip[k] = mini(G.EQUIP_MAX[k], G.equip[k] + n)
			G.ui.toast("+%d %s" % [n, G.EQUIP_NAMES[k]], "#ffb36b")
			G.audio.pickup(true)
			return _consume(p)
		if p.type == "armor" and P.armor < 100:
			var gain2 := minf(50, 100 - P.armor)
			P.armor += gain2
			G.ui.toast("+%d SCUDO" % ceili(gain2), "#4aa8ff")
			G.audio.pickup(true)
			return _consume(p)
	return true

func _consume(p: Dictionary) -> bool:
	G.fx.particles(p.pos + Vector3(0, 0.8, 0), color_of(p), 30 if p.power else 16, Vector3.UP, 5.0 if p.power else 3.0)
	if p.temp:
		p.group.queue_free()
		return false
	p.active = false; _shown(p, false)
	p.respawn = G.POWERUPS[p.type].respawn if p.power else { "health": 22.0, "armor": 38.0, "equip": 18.0 }[p.type]
	return true

func reset_pickups() -> void:
	for p in pickups:
		p.group.queue_free()
	pickups.clear()
	var MAP: Dictionary = G.world.MAP
	for type in MAP.pickups:
		for s in MAP.pickups[type]:
			pickups.append(make_pickup(type, s[0], s[1]))
	told.clear()
	for type in G.POWERUPS:
		for s in MAP.power[type]:
			pickups.append(make_pickup(type, s[0], s[1]))
	for k in G.powers:
		G.powers[k] = 0.0
	G.ui.clear_powers()

func clear_pickups() -> void:
	for p in pickups:
		p.group.queue_free()
	pickups.clear()

func atmosphere_changed() -> void:
	for p in pickups:
		if p.power:
			p.light.visible = G.settings.quality != "low"

func activate_power(type: String) -> void:
	var def: Dictionary = G.POWERUPS[type]
	G.powers[type] = def.dur
	G.ui.toast(def.name, def.css)
	G.audio.powerup(type)
	G.hurt = 0
	var Wp: Node = G.weapons
	if type == "ammo":
		for k in Wp.mags:
			Wp.mags[k] = Wp.mag_of(k)
		if Wp.reloading:
			Wp.reloading = false; Wp.mags[Wp.current] = Wp.mag_of(Wp.current)

func update_powers(dt: float) -> void:
	for type in G.POWERUPS:
		if G.powers[type] <= 0:
			continue
		var before: float = G.powers[type]
		G.powers[type] = maxf(0, G.powers[type] - dt)
		var left: float = G.powers[type]
		if left < 3 and ceili(left) != ceili(before):
			G.audio.tone(880, 0.05, 0.08, "triangle", 880)
		if left <= 0:
			G.audio.tone(600, 0.25, 0.12, "triangle", 220)

func update_pickups(dt: float) -> void:
	var keep: Array = []
	for p in pickups:
		if _update_pickup(p, dt):
			keep.append(p)
	pickups = keep
	update_powers(dt)

# ============================================================ throwables, projectiles, explosions
func launch(kind: String, pos: Vector3, vel: Vector3) -> void:
	var mesh := proj_model(kind)
	mesh.position = pos
	G.scene_root.add_child(mesh)
	projectiles.append({ "kind": kind, "mesh": mesh, "pos": pos, "vel": vel, "t": 0.0, "rest": false, "spin": G.rnd(8, 14), "stuck": false, "stuck_t": 0.0 })

func _remove_proj(i: int) -> void:
	projectiles[i].mesh.queue_free()
	projectiles.remove_at(i)

func aim_point(max_d := 120.0) -> Vector3:
	var cam: Camera3D = G.camera
	var o := cam.global_position
	var dir := -cam.global_basis.z
	var h: Dictionary = G.world.ray(o, o + dir * max_d, true)
	return h.position if not h.is_empty() else o + dir * max_d

func throw_item(kind: String) -> void:
	var Wp: Node = G.weapons
	if Wp.melee_t > 0 or Wp.switch_t > 0 or Wp.throw_cd > 0:
		return
	if G.equip[kind] <= 0:
		G.audio.tone(260, 0.07, 0.08, "square", 200)
		G.ui.shake_equip(kind)
		return
	G.equip[kind] -= 1
	Wp.throw_cd = 0.35 if kind == "tknife" else 0.8
	Wp.throw_t = Wp.THROW_TIME; Wp.reloading = false
	var cam: Camera3D = G.camera
	var f := -cam.global_basis.z
	var r := cam.global_basis.x
	var start := cam.global_position + f * 0.45 + r * 0.14 + Vector3(0, -0.08, 0)
	if not G.world.world_clear(cam.global_position, start):
		start = cam.global_position
	var vel: Vector3
	if kind == "tknife":
		vel = (aim_point() - start).normalized() * 32
	else:
		vel = f * (15.0 if kind == "smoke" else 17.0) + Vector3(0, 3.2, 0) + G.player.vel * 0.5
	launch(kind, start, vel)
	var prev_cat: String = G.audio.cat
	G.audio.cat = "weapons"
	G.audio.swoosh(0.35)
	if kind != "tknife":
		G.audio.tone(2300, 0.03, 0.08, "square", 1800)
	G.audio.cat = prev_cat
	G.ui.bump_equip(kind)

# blast damage with falloff; walls shield enemies (and you)
func explode(p: Vector3, o: Dictionary) -> void:
	var color: int = o.get("color", 0xffa040)
	var radius: float = o.radius
	var P: Node = G.player
	G.fx.flash(p, 0xfff0d0, radius * 1.1, 0.16)
	G.fx.blast(p, radius, color, radius >= 4)
	G.fx.particles(p, color, 14 if G.settings.quality == "low" else 30, Vector3.UP, 10)
	G.fx.light_burst(p, color, 110)
	var d: float = P.eye().distance_to(p)
	G.audio.boom(clampf(1.25 - d / 60, 0.2, 1.1) * o.get("vol", 1.0), p, clampf(d / 50, 0, 1))
	P.shake = maxf(P.shake, clampf(1.2 - d / (radius * 4), 0, 1))
	var rk := clampf(1.3 - d / (radius * 5), 0, 1)
	if rk > 0.05:
		G.inp.rumble(rk, rk * 0.8, 0.25 + rk * 0.3)
	var from := p + Vector3(0, 0.3, 0)
	var hit := false
	var kill := false
	if not o.get("noEnemies", false):
		for b in G.enemies.list:
			if b.dead or b == o.get("skip"):
				continue
			var c: Vector3 = b.pos + Vector3(0, 1, 0)
			var dist := c.distance_to(p)
			if dist > radius or not G.world.world_clear(from, c):
				continue
			var dmg: float = o.dmg * pow(1 - dist / radius, 0.6) * (3.0 if G.pw("quad") else 1.0)
			var prev: float = b.hp
			var killed: bool = b.damage(dmg, false, o.key)
			G.ui.damage_number(c, minf(prev, dmg), false, killed)
			hit = true; kill = kill or killed
	if hit:
		G.ui.hitmarker(kill)
	if o.has("self"):
		var body: Vector3 = P.pos + Vector3(0, 0.9, 0)
		var pd := body.distance_to(p)
		if pd < radius and G.world.world_clear(from, body):
			P.damage(o.self * (1 - pd / radius), p, true)

# spitter acid: a direct hit burns, landing next to you only splashes
func acid_splash(p: Vector3, direct: bool) -> void:
	var P: Node = G.player
	G.fx.particles(p, 0x8dff4a, 16, Vector3.UP, 4)
	G.fx.spawn_smoke(p, 0x4a7a30, 1.3)
	var d: float = P.eye().distance_to(p)
	G.audio.with_cat("enemies", func(): G.audio.tone(1800, 0.25, clampf(0.5 - d / 50, 0.05, 0.4) * 0.3, "sawtooth", 600, 0.0, p))
	var body: Vector3 = P.pos + Vector3(0, 0.9, 0)
	var pd := body.distance_to(p)
	if direct:
		P.damage(13, p)
	elif pd < 1.8 and G.world.world_clear(p, body):
		P.damage(6 * (1 - pd / 1.8 * 0.5), p)

func enemy_blast(p: Vector3) -> void:
	var b: Object = G.enemies.boss()
	var P: Node = G.player
	explode(p, { "radius": 4.0, "dmg": 0.0, "noEnemies": true, "key": "rocket", "color": 0xff5040 })
	var body: Vector3 = P.pos + Vector3(0, 0.9, 0)
	var pd := body.distance_to(p)
	if pd < 4 and G.world.world_clear(p, body):
		P.damage((22 + 6 * (b.boss if b else 1)) * (1 - pd / 4 * 0.7), p)

func stun_burst(p: Vector3) -> void:
	var P: Node = G.player
	G.fx.flash(p, 0xffffff, 10, 0.3)
	G.fx.particles(p, 0xfff6d0, 12 if G.settings.quality == "low" else 26, Vector3.UP, 7)
	G.fx.light_burst(p, 0xffffff, 140)
	var from := p + Vector3(0, 0.3, 0)
	var eye: Vector3 = P.eye()
	var d := eye.distance_to(p)
	for b in G.enemies.list:
		if b.dead:
			continue
		var c: Vector3 = b.pos + Vector3(0, 1.5, 0)
		var dist := c.distance_to(p)
		if dist < 12 and G.world.world_clear(from, c):
			b.stun_t = maxf(b.stun_t, lerpf(5, 2.2, dist / 12) * (0.3 if b.boss else 1.0))
			b.path.clear()
	var ring := 0.0
	if d < 14 and G.world.world_clear(from, eye):
		var facing := (-G.camera.global_basis.z).dot((p - eye).normalized())
		ring = (1 - d / 14) * (0.45 + facing * 0.55 if facing > 0 else 0.25)
		G.blind = maxf(G.blind, ring * 3.2)
	G.audio.stun_bang(clampf(1.25 - d / 50, 0.2, 1.1), p, clampf(d / 45, 0, 1), ring)

func spawn_cloud(p: Vector3) -> void:
	var c := { "pos": Vector3(p.x, maxf(p.y, 0) + 1.2, p.z), "r": 0.0, "t": 0.0, "life": 15.0, "sprites": [] }
	var col := Color.html("#6a6f78") if G.mode == "zombie" else Color.html("#d2d6dc")
	for i in (14 if G.settings.quality == "low" else 30):
		var a := randf() * TAU
		var rr := sqrt(randf()) * 3.2
		var s := { "off": Vector3(cos(a) * rr, G.rnd(-0.9, 1.8), sin(a) * rr), "size": G.rnd(3.4, 5), "c": Color(col.r, col.g, col.b, 0), "xf": Transform3D(), "cloud": c }
		G.fx.clouds.add(s)
		c.sprites.append(s)
	G.world.clouds.append(c)
	var d: float = G.player.eye().distance_to(p)
	G.audio.smoke_hiss(clampf(1.1 - d / 40, 0.1, 1), p)

func _impact(pr: Dictionary, h: Dictionary, dir: Vector3) -> bool:
	var col: Object = h.collider
	var enemy: Object = col.get_meta("enemy") if col.has_meta("enemy") else null
	var quad := 3.0 if G.pw("quad") else 1.0
	if pr.kind == "tknife":
		if enemy and not enemy.dead:
			var part: String = col.get_meta("part")
			var head := part == "head"
			var dmg := (400.0 if head else (120.0 if part == "limb" else 170.0)) * quad
			var prev: float = enemy.hp
			var killed: bool = enemy.damage(dmg, head, "tknife")
			G.ui.damage_number(h.position, minf(prev, dmg), head, killed); G.ui.hitmarker(killed)
			G.fx.particles(h.position, enemy.spark_color, 10, -dir, 3)
			G.audio.tone(160, 0.1, 0.3, "square", 70)
			return true
		if enemy:
			return true
		# stick into the wall for a few seconds
		pr.pos = h.position + dir * 0.04; pr.stuck = true; pr.stuck_t = 8.0
		pr.mesh.position = pr.pos
		pr.mesh.look_at(pr.pos + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		G.fx.particles(h.position + h.normal * 0.03, 0xffe0a0, 6, h.normal, 3)
		G.audio.tone(2600, 0.05, 0.12, "square", 1700)
		return false
	if pr.kind == "erocket":
		enemy_blast(h.position - dir * 0.3)
		return true
	if pr.kind == "acid":
		acid_splash(h.position - dir * 0.1, false)
		return true
	var Wp: Node = G.weapons
	if pr.kind == "rocket":
		var n: Vector3 = -dir if enemy else h.normal
		explode(h.position + n * 0.2, { "radius": 6.0, "dmg": 400.0 * Wp.dmg_mul("rocket"), "key": "rocket", "self": 55.0, "vol": 1.2 })
		if enemy:
			G.shots_hit += 1
		return true
	# plasma bolt: direct hit + green splash
	var w: Dictionary = Wp.W.raygun
	if enemy and not enemy.dead:
		var part2: String = col.get_meta("part")
		var dmg2: float = w.dmg[part2] * quad * Wp.dmg_mul("raygun")
		var prev2: float = enemy.hp
		var killed2: bool = enemy.damage(dmg2, part2 == "head", "raygun")
		G.ui.damage_number(h.position, minf(prev2, dmg2), part2 == "head", killed2); G.ui.hitmarker(killed2)
		G.shots_hit += 1
	explode(h.position, { "radius": w.splash, "dmg": w.splashDmg * Wp.dmg_mul("raygun"), "key": "raygun", "color": 0x6bff8a, "vol": 0.45, "skip": enemy, "self": 12.0 })
	return true

func _detonate(pr: Dictionary) -> void:
	match pr.kind:
		"frag": explode(pr.pos, { "radius": 6.5, "dmg": 260.0, "key": "frag", "self": 60.0 })
		"stun": stun_burst(pr.pos)
		"smoke": spawn_cloud(pr.pos)

func update_throwables(dt: float) -> void:
	var P: Node = G.player
	G.blind = maxf(0, G.blind - dt * 0.6)
	var low: bool = G.settings.quality == "low"
	for i in range(projectiles.size() - 1, -1, -1):
		var pr: Dictionary = projectiles[i]
		var def: Dictionary = PROJ[pr.kind]
		pr.t += dt
		if pr.stuck:
			pr.stuck_t -= dt
			if pr.stuck_t <= 0:
				_remove_proj(i)
			continue
		if def.has("fuse") and pr.t >= def.fuse:
			_detonate(pr); _remove_proj(i); continue
		if def.has("life") and pr.t > def.life:
			_remove_proj(i); continue
		if not pr.rest:
			pr.vel.y -= def.grav * dt
			var step: Vector3 = pr.vel * dt
			var ln := step.length()
			var dir := step / ln if ln > 1e-6 else Vector3.ZERO
			# boss rockets and acid also go off when they reach you
			if def.get("enemy", false) and pr.pos.distance_to(P.pos + Vector3(0, 0.9, 0)) < 1:
				if pr.kind == "acid":
					acid_splash(pr.pos, true)
				else:
					enemy_blast(pr.pos)
				_remove_proj(i); continue
			var h: Dictionary = G.world.ray(pr.pos, pr.pos + dir * (ln + def.r), def.get("hits", false) and not def.get("enemy", false)) if ln > 1e-5 else {}
			if not h.is_empty():
				if def.get("hits", false):
					if _impact(pr, h, dir):
						_remove_proj(i)
					continue
				var n: Vector3 = h.normal
				pr.pos = h.position + n * def.r
				var vn: float = pr.vel.dot(n)
				pr.vel = (pr.vel - n * (1 + def.bounce) * vn) * 0.72
				if absf(vn) > 2:
					G.audio.bounce(clampf(1 - P.eye().distance_to(pr.pos) / 30, 0.1, 1), pr.pos)
				if n.y > 0.7 and pr.vel.length() < 1.3:
					pr.rest = true; pr.vel = Vector3.ZERO
			else:
				pr.pos += step
			if pr.pos.y < -3 or absf(pr.pos.x) > 45 or absf(pr.pos.z) > 45:
				_remove_proj(i); continue
		var mesh: Node3D = pr.mesh
		mesh.position = pr.pos
		if pr.kind == "tknife":
			if pr.vel.length_squared() > 0.01:
				mesh.look_at(pr.pos + pr.vel, Vector3.UP if absf(pr.vel.normalized().y) < 0.99 else Vector3.RIGHT)
			mesh.rotate_object_local(Vector3.RIGHT, -pr.t * 28)
		elif pr.kind == "rocket" or pr.kind == "erocket":
			if pr.vel.length_squared() > 0.01:
				mesh.look_at(pr.pos + pr.vel, Vector3.UP if absf(pr.vel.normalized().y) < 0.99 else Vector3.RIGHT)
				mesh.rotate_object_local(Vector3.UP, PI)
			var fl: Node3D = mesh.get_node_or_null("flame")
			if fl:
				fl.scale = Vector3.ONE * G.rnd(0.4, 0.65)
			if randf() < (0.35 if low else 0.8):
				G.fx.spawn_smoke(pr.pos - pr.vel * 0.012, 0xb8b2aa, 0.7)
		elif pr.kind == "plasma" or pr.kind == "acid":
			var gl: Node3D = mesh.get_node_or_null("glow")
			if gl:
				gl.scale = Vector3.ONE * (0.6 + sin(pr.t * 40) * 0.12) / 0.6
			if randf() < 0.5:
				G.fx.particles(pr.pos, 0x6bff8a, 1, null, 0.6)
		elif not pr.rest:
			mesh.rotation.x += dt * pr.spin; mesh.rotation.z += dt * pr.spin * 0.6
	# smoke grenade clouds: grow, linger, fade
	var keep: Array = []
	for c in G.world.clouds:
		c.t += dt
		var grow := G.smooth(clampf(c.t / 1.8, 0, 1))
		var fade := clampf((c.life - c.t) / 2.5, 0, 1)
		c.r = 4 * grow * minf(1, fade / 0.4)
		for s in c.sprites:
			var base: Color = s.c
			s.c = Color(base.r, base.g, base.b, 0.9 * grow * fade)
			s.xf = Transform3D(Basis().scaled(Vector3.ONE * s.size * (0.4 + 0.6 * grow)), c.pos + s.off * (0.35 + 0.65 * grow) + Vector3(0, c.t * 0.04, 0))
		if c.t < c.life:
			keep.append(c)
	G.world.clouds = keep
	var live: Array = []
	for s in G.fx.clouds.items:
		if s.cloud.t < s.cloud.life:
			live.append(s)
	G.fx.clouds.items = live
	G.fx.clouds.flush()

func clear_throwables() -> void:
	while projectiles.size() > 0:
		_remove_proj(0)
	G.world.clouds.clear()
	G.fx.clouds.clear()
	G.blind = 0.0

# ============================================================ weapons in the world: floor drops + mystery box
func _rarity_ring(k: String) -> StandardMaterial3D:
	var key := "rar-" + G.rarity_key(k)
	if not mats.has(key):
		mats[key] = Gfx.glow(G.rarity_of(k).color, 2.2)
	return mats[key]

func spawn_drop(key: String, mag: int, pos: Vector3) -> void:
	var g := Node3D.new()
	var m: Node3D = G.weapons.world_gun(key)
	m.rotation = Vector3(0, 0, PI / 2)
	m.position.y = 0.08
	m.scale = Vector3.ONE * 1.35
	g.add_child(m)
	var ring := _ring_node(_rarity_ring(key), g, 0.03, 1.3)
	g.position = pos
	g.rotation.y = randf() * TAU
	G.scene_root.add_child(g)
	drops.append({ "key": key, "mag": mag, "pos": pos, "group": g, "ring": ring, "life": 60.0 })
	if drops.size() > 8:
		remove_drop(drops[0])

func remove_drop(d: Dictionary) -> void:
	d.group.queue_free()
	drops.erase(d)

func drop_point() -> Vector3:
	var P: Node = G.player
	var p: Vector3 = P.pos + P.fwd() * 1.1
	if not G.world.world_clear(P.pos + Vector3(0, 0.5, 0), Vector3(p.x, P.pos.y + 0.5, p.z)):
		p = P.pos
	p.y = G.world.ground_at(p.x, p.z, P.pos.y + 0.2, 0.2)
	return p

func update_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.life -= dt
		if d.life <= 0:
			remove_drop(d); continue
		d.group.visible = d.life > 5 or sin(d.life * 18) > 0
		d.ring.scale = Vector3.ONE * (1.3 + sin(G.now * 3 + i) * 0.06)

func give_weapon(key: String, mag := -1) -> void:
	var Wp: Node = G.weapons
	var i := G.slots.find(null)
	if i < 0:
		i = maxi(0, G.slots.find(Wp.switch_to if Wp.switch_to != "" else Wp.current))
		spawn_drop(G.slots[i], Wp.mags.get(G.slots[i], 0), drop_point())
	G.slots[i] = key
	Wp.mags[key] = mag if mag >= 0 else Wp.mag_of(key)
	Wp.switch_weapon(key)
	G.audio.pickup(true)

func drop_current_weapon() -> void:
	var Wp: Node = G.weapons
	var i := G.slots.find(Wp.switch_to if Wp.switch_to != "" else Wp.current)
	if i < 0 or Wp.melee_t > 0:
		return
	if G.slots[1 - i] == null:
		G.ui.toast("NON PUOI GETTARE L’ULTIMA ARMA", "#ff8a7a")
		return
	var key: String = G.slots[i]
	spawn_drop(key, Wp.mags.get(key, 0), drop_point())
	G.slots[i] = null
	Wp.switch_weapon(G.slots[1 - i])
	G.audio.swoosh(0.3)

func pickup_drop(d: Dictionary) -> void:
	var Wp: Node = G.weapons
	if G.slots.has(d.key):
		Wp.mags[d.key] = Wp.mag_of(d.key)
		G.ui.toast("MUNIZIONI %s" % Wp.W[d.key].name, "#" + G.col(G.rarity_of(d.key).color).to_html(false))
		G.audio.pickup(false)
	else:
		give_weapon(d.key, d.mag)
	remove_drop(d)

# ---------------------------------------------------------------- mystery box
func _build_box() -> void:
	var g := Node3D.new()
	var wood := Gfx.mat(0x6a4a34, 0.6, 0.0, { "albedo_texture": Gfx.crate_tex() })
	var gold := Gfx.mat(0xd4a640, 0.3, 0.9)
	var iron := Gfx.mat(0x1e2127, 0.35, 0.85)
	var body := Gfx.mesh_node(Gfx.box(1.7, 0.62, 0.85), wood, Vector3(0, 0.31, 0), Vector3.ZERO, g)
	for y in [0.06, 0.55]:
		Gfx.mesh_node(Gfx.box(1.74, 0.05, 0.89), gold, Vector3(0, y, 0), Vector3.ZERO, g)
	for x in [-0.84, 0.84]:
		Gfx.mesh_node(Gfx.box(0.07, 0.58, 0.9), gold, Vector3(x, 0.3, 0), Vector3.ZERO, g)
	Gfx.mesh_node(Gfx.box(0.16, 0.13, 0.04), iron, Vector3(0, 0.52, 0.445), Vector3.ZERO, g)
	for q in [[-0.4, 0.44, 0.0], [0.4, 0.44, 0.0], [-0.4, -0.44, PI], [0.4, -0.44, PI], [0.89, 0.0, PI / 2], [-0.89, 0.0, -PI / 2]]:
		var l := Label3D.new()
		l.text = "?"
		l.font = G.world.font
		l.font_size = 96
		l.pixel_size = 0.004
		l.modulate = Color(1.0, 1.9, 2.6)
		l.outline_modulate = Color(0.2, 0.6, 1.0, 0.6)
		l.position = Vector3(q[0], 0.31, q[1]) if absf(q[0]) < 0.8 else Vector3(q[0], 0.31, q[1])
		l.rotation.y = q[2]
		l.double_sided = false
		g.add_child(l)
	var lid := Node3D.new(); lid.position = Vector3(0, 0.62, -0.425); g.add_child(lid)
	Gfx.mesh_node(Gfx.box(1.7, 0.14, 0.85), wood, Vector3(0, 0.07, 0.425), Vector3.ZERO, lid)
	Gfx.mesh_node(Gfx.box(1.74, 0.045, 0.89), gold, Vector3(0, 0.055, 0.425), Vector3.ZERO, lid)
	var top := Label3D.new()
	top.text = "?"; top.font = G.world.font; top.font_size = 96; top.pixel_size = 0.004; top.modulate = Color(1.0, 1.9, 2.6)
	top.position = Vector3(0, 0.153, 0.425); top.rotation.x = -PI / 2
	lid.add_child(top)
	var beam := Gfx.mesh_node(Gfx.cyl(0.55, 0.75, 16, 24, true), Gfx.beam(0x7fc8ff, 0.32), Vector3(0, 8, 0), Vector3.ZERO, g)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = G.col(0x9fd0ff); light.omni_range = 9; light.position.y = 1.3
	g.add_child(light)
	var display := Node3D.new(); display.position.y = 0.5; g.add_child(display)
	var models := {}
	for k in G.weapons.W:
		var m: Node3D = G.weapons.world_gun(k)
		m.rotation.y = PI / 2
		m.scale = Vector3.ONE * 1.25
		m.visible = false
		display.add_child(m)
		models[k] = m
	g.visible = false
	G.scene_root.add_child(g)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.7, 0.62, 0.85)
	shape.shape = bs
	var sb := StaticBody3D.new()
	sb.collision_layer = 0
	sb.add_child(shape)
	shape.position.y = 0.31
	g.add_child(sb)
	box = { "group": g, "body": sb, "lid": lid, "beam": beam, "light": light, "display": display, "models": models, "collider": AABB(),
		"spot": -1, "state": "idle", "t": 0.0, "swap_t": 0.0, "shown": "", "choice": "" }

func _show_box_model(k: String) -> void:
	for key in box.models:
		box.models[key].visible = key == k
	box.shown = k

func place_box(first: bool) -> void:
	var MAP: Dictionary = G.world.MAP
	var P: Node = G.player
	var spots: Array = MAP.boxSpots
	var idx: int = box.spot
	for tries in 30:
		var c := randi() % spots.size()
		if c == box.spot:
			continue
		idx = c
		if first or Vector2(spots[c][0] - P.pos.x, spots[c][1] - P.pos.z).length() > 12:
			break
	idx = idx % spots.size()
	var x: float = spots[idx][0]
	var z: float = spots[idx][1]
	box.spot = idx
	var g: Node3D = box.group
	g.position = Vector3(x, 0, z)
	g.rotation.y = atan2(-x, -z)
	g.visible = true
	_hide_collider()
	var bb := g.transform * AABB(Vector3(-0.85, 0, -0.425), Vector3(1.7, 0.62, 0.85))
	box.collider = bb
	G.world.colliders.append(bb)
	box.body.collision_layer = 1
	box.state = "idle"; box.t = 0.0; box.lid.rotation.x = 0; _show_box_model("")
	(box.beam.material_override as ShaderMaterial).set_shader_parameter("color", G.col(0x7fc8ff))
	box.light.light_color = G.col(0x9fd0ff)

func _hide_collider() -> void:
	G.world.colliders.erase(box.collider)
	box.body.collision_layer = 0

func hide_box() -> void:
	box.group.visible = false
	_hide_collider()

func _roll_box_weapon() -> String:
	var pool: Array = G.BOX_POOL.filter(func(e): return not G.slots.has(e[0]))
	var total := 0.0
	for e in pool:
		total += e[2]
	var r := randf() * total
	for e in pool:
		r -= e[2]
		if r <= 0:
			return e[0]
	return pool[0][0]

func open_box() -> void:
	box.state = "rolling"; box.t = 0.0; box.swap_t = 0.0
	box.choice = _roll_box_weapon()
	G.audio.box_open()

func take_box_weapon() -> void:
	give_weapon(box.choice)
	var r: Dictionary = G.rarity_of(box.choice)
	G.ui.toast("%s · %s" % [G.weapons.W[box.choice].name, r.name], "#" + G.col(r.color).to_html(false))
	_show_box_model("")
	box.state = "closing"; box.t = 0.0

func update_box(dt: float) -> void:
	box.t += dt
	var pulse := 0.8 + sin(G.now * 3) * 0.2
	var g: Node3D = box.group
	match box.state:
		"idle":
			box.light.light_energy = 1.2 * pulse * G.light_k()
		"rolling":
			box.lid.rotation.x = -G.smooth(clampf(box.t / 0.4, 0, 1)) * 1.9
			box.display.position.y = 0.45 + G.smooth(clampf(box.t / 2.6, 0, 1)) * 0.85
			box.display.rotation.y = 0
			box.swap_t -= dt
			if box.swap_t <= 0:
				var keys: Array = box.models.keys().filter(func(k): return k != box.shown)
				_show_box_model(keys[randi() % keys.size()])
				box.swap_t = lerpf(0.06, 0.34, pow(box.t / 3.2, 2))
				G.audio.tone(G.rnd(900, 1500), 0.035, 0.05, "square")
			box.light.light_energy = (1.5 + randf()) * G.light_k()
			if box.t >= 3.2:
				box.state = "offer"; box.t = 0.0
				_show_box_model(box.choice)
				var c := G.col(G.rarity_of(box.choice).color)
				(box.beam.material_override as ShaderMaterial).set_shader_parameter("color", c)
				box.light.light_color = c
				G.fx.particles(g.position + Vector3(0, 1.4, 0), G.rarity_of(box.choice).color, 24, Vector3.UP, 3)
				G.audio.box_reveal(G.rarity_key(box.choice))
		"offer":
			box.display.position.y = 1.3 + sin(box.t * 2.5) * 0.05
			box.display.rotation.y = sin(box.t * 0.9) * 0.5
			box.light.light_energy = 1.7 * pulse * G.light_k()
			if box.t > 9:
				box.state = "closing"; box.t = 0.0
				G.ui.toast("L’ARMA È TORNATA NELLA CASSA", "#9fd0ff")
		"closing":
			box.display.position.y = maxf(0.3, box.display.position.y - dt * 1.6)
			box.lid.rotation.x = -1.9 * (1 - G.smooth(clampf(box.t / 0.8, 0, 1)))
			if box.t > 1.1:
				# single use: the box vanishes and reappears somewhere else
				var p := g.position + Vector3(0, 0.8, 0)
				G.fx.particles(p, 0x9fd0ff, 30, Vector3.UP, 5)
				for i in 4:
					G.fx.spawn_smoke(p + Vector3(G.rnd(-0.8, 0.8), G.rnd(0, 0.6), G.rnd(-0.8, 0.8)), 0xaac8e0, 2)
				G.audio.swoosh(0.5); G.audio.tone(700, 0.5, 0.1, "triangle", 180)
				hide_box(); box.state = "away"; box.t = 0.0
		"away":
			if box.t > 3:
				place_box(false)
				G.fx.particles(g.position + Vector3(0, 1, 0), 0x9fd0ff, 30, Vector3.UP, 4)
				G.ui.toast("LA CASSA MISTERIOSA SI È SPOSTATA", "#9fd0ff")
				G.audio.power_spawn(0.8)
	box.beam.visible = box.state != "closing" and box.state != "away"
	box.beam.rotation.y += dt * 0.5
	if box.state == "away":
		box.light.light_energy = 0

# ---------------------------------------------------------------- interaction prompt (E)
func interact_target() -> Dictionary:
	var P: Node = G.player
	var MAP: Dictionary = G.world.MAP
	if box.group.visible and (box.state == "idle" or box.state == "offer") \
		and Vector2(P.pos.x - box.group.position.x, P.pos.z - box.group.position.z).length() < 2.4 and P.pos.y < 1.5:
		return { "type": "box" }
	var best: Dictionary = {}
	var bd := 1.8
	for d in drops:
		var dd := Vector2(P.pos.x - d.pos.x, P.pos.z - d.pos.z).length()
		if dd < bd and absf(P.pos.y - d.pos.y) < 1.2:
			best = d; bd = dd
	if not best.is_empty():
		return { "type": "drop", "drop": best }
	if P.pos.y < 1.5:
		for h in MAP.houses:
			if h.open:
				continue
			for door in h.doors:
				if Vector2(P.pos.x - door.x, P.pos.z - door.y).length() < 2.1:
					return { "type": "house", "house": h }
	for type in ["bench", "perks"]:
		if MAP.has(type) and Vector2(P.pos.x - MAP[type].x, P.pos.z - MAP[type].z).length() < 2.6 and P.pos.y < 1.5:
			return { "type": type }
	return {}

func interact() -> void:
	var t := interact_target()
	if t.is_empty():
		return
	match t.type:
		"drop":
			pickup_drop(t.drop)
		"bench":
			G.game.open_shop("bench")
		"house":
			var h: Dictionary = t.house
			if G.cash < h.cost:
				G.audio.tone(220, 0.15, 0.12, "square", 160); G.ui.toast("CREDITI INSUFFICIENTI", "#ff8a7a")
				return
			add_cash(-h.cost)
			G.world.set_house(h, true)
			for i in 9:
				G.audio.tone(95 + (i % 2) * 30, 0.07, 0.1, "sawtooth", 70, i * 0.09)
			G.audio.tone(520, 0.25, 0.1, "sine", 780, 0.85)
			G.ui.toast("%s · EDIFICIO APERTO" % h.name, "#8dffb0")
		"perks":
			if G.wave_break > 0:
				G.game.open_shop("perks")
			else:
				G.audio.tone(220, 0.15, 0.12, "square", 160); G.ui.toast("APERTO SOLO TRA UN’ONDATA E L’ALTRA", "#c98bff")
		"box":
			if box.state == "offer":
				take_box_weapon()
				return
			if G.cash < G.BOX_COST:
				G.audio.tone(220, 0.15, 0.12, "square", 160); G.ui.toast("CREDITI INSUFFICIENTI", "#ff8a7a")
				return
			add_cash(-G.BOX_COST)
			open_box()

func update_interact() -> void:
	var t := interact_target()
	var key: String = G.inp.key_label("E", "X")
	var Wp: Node = G.weapons
	if t.is_empty():
		G.ui.set_prompt("", "", "", "")
		return
	match t.type:
		"box":
			if box.state == "idle":
				G.ui.set_prompt(key, "Cassa misteriosa · arma casuale", str(G.BOX_COST), "no" if G.cash < G.BOX_COST else "price")
			else:
				var r: Dictionary = G.rarity_of(box.choice)
				G.ui.set_prompt(key, "Prendi %s" % Wp.W[box.choice].name, r.name, "#" + G.col(r.color).to_html(false))
		"house":
			G.ui.set_prompt(key, "Apri %s · un posto dove ripararsi" % t.house.name, str(t.house.cost), "no" if G.cash < t.house.cost else "price")
		"bench":
			G.ui.set_prompt(key, "Banco armi · potenzia danno, caricatore e ricarica", "", "")
		"perks":
			if G.wave_break > 0:
				G.ui.set_prompt(key, "Distributore · compra un perk", "", "")
			else:
				G.ui.set_prompt("", "Distributore di perk · apre tra un’ondata e l’altra", "", "")
		"drop":
			var r2: Dictionary = G.rarity_of(t.drop.key)
			G.ui.set_prompt(key, "Raccogli %s" % Wp.W[t.drop.key].name, r2.name, "#" + G.col(r2.color).to_html(false))

func add_cash(n: int) -> void:
	G.cash = maxi(0, G.cash + n)
	if n > 0:
		G.earned += n
		G.ui.flash_cash()
	else:
		G.spent -= n

func reset_arsenal() -> void:
	clear_throwables()
	while drops.size() > 0:
		remove_drop(drops[0])
	for k in G.equip:
		G.equip[k] = 0
	G.slots = [G.primary, "pistol"]
	G.upg = {}; G.perks = {}; G.revives = 1
	G.cash = 0; G.earned = 0; G.spent = 0; G.boss_kills = 0
	G.ui.render_perks()
