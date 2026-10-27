# Spariaps — Effetti visivi: scintille, fumo, traccianti, fori, esplosioni, cerchi di pericolo.
# Ogni tipo di effetto è un MultiMesh: centinaia di particelle costano una sola chiamata di disegno.
extends Node

class Pool:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var cap: int
	var items: Array = []
	func _init(parent: Node3D, mesh: Mesh, m: Material, cap_: int, shadow := false) -> void:
		cap = cap_
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 16384
		parent.add_child(node)
	func add(d: Dictionary) -> void:
		if items.size() >= cap:
			items.pop_front()
		items.append(d)
	func flush() -> void:
		var n := items.size()
		mm.visible_instance_count = n
		for i in n:
			var it: Dictionary = items[i]
			mm.set_instance_transform(i, it.xf)
			mm.set_instance_color(i, it.c)
	func clear() -> void:
		items.clear()
		mm.visible_instance_count = 0

var sparks: Pool
var dust: Pool
var smoke: Pool
var tracers: Pool
var holes: Pool
var fire: Pool
var flashes: Pool
var debris: Pool
var scorch: Pool
var clouds: Pool
var rings: Array = []          # shockwaves and boss hazard circles: { node, mat, ... }
var boom_light: OmniLight3D
var boom_t := 0.0

func _ready() -> void:
	G.fx = self

func setup() -> void:
	var root: Node3D = G.scene_root
	var spark_m := Gfx.additive(Color.WHITE, 1.0, null, 1.0)
	spark_m.vertex_color_use_as_albedo = true
	spark_m.albedo_color = Color(4, 4, 4, 1)
	sparks = Pool.new(root, Gfx.sphere(0.028, 6, 4), spark_m, 900)
	var dust_m := StandardMaterial3D.new()
	dust_m.vertex_color_use_as_albedo = true
	dust_m.roughness = 0.9
	dust = Pool.new(root, Gfx.sphere(0.028, 6, 4), dust_m, 500)
	var smoke_m := StandardMaterial3D.new()
	smoke_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_m.vertex_color_use_as_albedo = true
	smoke_m.albedo_texture = Gfx.smoke_tex()
	smoke_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_m.billboard_keep_scale = true
	smoke_m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	smoke = Pool.new(root, Gfx.plane(1, 1), smoke_m, 420)
	var cloud_m: StandardMaterial3D = smoke_m.duplicate()
	cloud_m.albedo_texture = Gfx.cloud_tex()
	clouds = Pool.new(root, Gfx.plane(1, 1), cloud_m, 220)
	var tr_m := Gfx.additive(Color.WHITE, 1.0)
	tr_m.vertex_color_use_as_albedo = true
	tr_m.albedo_color = Color(3, 3, 3, 1)
	tracers = Pool.new(root, Gfx.box(1, 1, 1), tr_m, 120)
	var hole_m := StandardMaterial3D.new()
	hole_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_m.vertex_color_use_as_albedo = true
	hole_m.albedo_texture = Gfx.hole_tex()
	hole_m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	hole_m.render_priority = 2
	holes = Pool.new(root, Gfx.plane(0.16, 0.16), hole_m, 100)
	var sc_m: StandardMaterial3D = hole_m.duplicate()
	scorch = Pool.new(root, World.flat_quad(1, 1), sc_m, 14)
	var fire_m := Gfx.additive(Color.WHITE, 1.0, Gfx.fire_tex(), 1.0)
	fire_m.vertex_color_use_as_albedo = true
	fire_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_m.billboard_keep_scale = true
	fire = Pool.new(root, Gfx.plane(1, 1), fire_m, 160)
	var fl_m: StandardMaterial3D = fire_m.duplicate()
	fl_m.albedo_texture = Gfx.flash_tex()
	flashes = Pool.new(root, Gfx.plane(1, 1), fl_m, 40)
	var deb_m := StandardMaterial3D.new()
	deb_m.vertex_color_use_as_albedo = true
	deb_m.roughness = 0.8
	debris = Pool.new(root, Gfx.box(0.12, 0.08, 0.1), deb_m, 160, true)
	boom_light = OmniLight3D.new()
	boom_light.omni_range = 24
	boom_light.light_energy = 0
	root.add_child(boom_light)

func clear() -> void:
	for p in [sparks, dust, smoke, tracers, holes, fire, flashes, debris, scorch, clouds]:
		p.clear()
	for r in rings:
		r.node.queue_free()
	rings.clear()
	boom_light.light_energy = 0

# ============================================================ spawners
func particles(p: Vector3, color: int, n: int, normal: Variant = null, speed := 4.0, glow := true) -> void:
	var c := G.col(color)
	var pool: Pool = sparks if glow else dust
	if G.settings.quality == "low":
		n = maxi(1, n / 2)
	for i in n:
		var v := Vector3(G.rnd(-1, 1), G.rnd(-0.2, 1.2), G.rnd(-1, 1))
		if normal is Vector3:
			v += normal * 1.5
		v = v.normalized() * G.rnd(0.4, 1.0) * speed
		pool.add({ "p": p, "v": v, "life": G.rnd(0.25, 0.6), "s": G.rnd(0.6, 1.3), "c": c, "xf": Transform3D() })

func spawn_smoke(p: Vector3, color := 0xbbbbbb, size := 0.5, life := 0.9, rise := 0.5, dense := 0.5) -> void:
	smoke.add({ "p": p, "v": Vector3(G.rnd(-0.2, 0.2), rise + G.rnd(-0.2, 0.2), G.rnd(-0.2, 0.2)), "life": life, "max": life, "size": size, "dense": dense,
		"base": G.col(color), "c": Color(0, 0, 0, 0), "xf": Transform3D() })

func tracer(a: Vector3, b: Vector3, color: int) -> void:
	var L := a.distance_to(b)
	if L < 0.05:
		return
	var basis := Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT) * Basis.from_scale(Vector3(0.011, 0.011, L))
	tracers.add({ "life": 0.07, "base": G.col(color), "xf": Transform3D(basis, (a + b) * 0.5), "c": G.col(color) })

func decal(p: Vector3, n: Vector3) -> void:
	var up := Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(-n, up).rotated(n, randf() * TAU)
	holes.add({ "xf": Transform3D(basis, p + n * 0.01), "c": Color(1, 1, 1, 1) })

func flash(p: Vector3, color: int, size: float, life: float) -> void:
	flashes.add({ "p": p, "life": life, "max": life, "size": size, "base": G.col(color), "c": G.col(color), "xf": Transform3D() })

func light_burst(p: Vector3, color: int, intensity: float) -> void:
	boom_light.light_color = G.col(color)
	boom_light.position = p + Vector3(0, 0.8, 0)
	boom_light.light_energy = intensity * 0.05 * G.light_k()
	boom_t = 0.5

# layered fireball, ground shockwave + dust ring, scorch mark, bouncing debris and a column of smoke
func blast(p: Vector3, radius: float, color: int, big := true) -> void:
	var low: bool = G.settings.quality == "low"
	var ground: float = G.world.ground_at(p.x, p.z, p.y + 0.5, 0.3)
	var near_ground := p.y - ground < 1.2
	var c := G.col(color)
	for i in (5 if low else (12 if big else 7)):
		var life := G.rnd(0.45, 0.8)
		fire.add({ "p": p + Vector3(G.rnd(-1, 1), G.rnd(-0.3, 1), G.rnd(-1, 1)) * radius * 0.18,
			"v": Vector3(G.rnd(-1, 1), G.rnd(0.4, 1.6), G.rnd(-1, 1)) * radius * 0.55, "life": life, "max": life,
			"s0": radius * G.rnd(0.35, 0.6), "base": c.lerp(Color(1, 0.95, 0.75), 0.4), "c": c, "xf": Transform3D() })
	if near_ground:
		ring(Vector3(p.x, ground + 0.06, p.z), radius * 1.5, 0.45, c * 1.6, true)
		for i in (4 if low else 10):
			var a := i / 10.0 * TAU + G.rnd(-0.2, 0.2)
			var q := Vector3(p.x, ground + 0.3, p.z) + Vector3(cos(a), 0, sin(a)) * radius * G.rnd(0.35, 0.6)
			spawn_smoke(q, 0x3a3530 if G.mode == "zombie" else 0x9a9082, radius * 0.7, G.rnd(1.4, 2.2), 0.3, 0.45)
		var sz := radius * G.rnd(0.7, 0.9)
		scorch.add({ "life": 25.0, "xf": Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sz, 1, sz)), Vector3(p.x, ground + 0.015, p.z)), "c": Color(1, 1, 1, 0.85) })
	for i in (5 if low else (16 if big else 6)):
		var hot := i % 4 == 0
		debris.add({ "p": p + Vector3(0, 0.2, 0), "v": Vector3(G.rnd(-1, 1), G.rnd(0.6, 1.4), G.rnd(-1, 1)).normalized() * G.rnd(4, 11) * (1.0 if big else 0.6),
			"spin": Vector3(G.rnd(-12, 12), G.rnd(-12, 12), G.rnd(-12, 12)), "rot": Vector3.ZERO, "life": G.rnd(2.2, 3.4), "ground": ground,
			"s": G.rnd(0.6, 1.4) * (1.0 if big else 0.6), "c": Color(3, 1.1, 0.25) if hot else (Color(0.55, 0.57, 0.6) if i % 2 else Color(0.15, 0.17, 0.2)), "xf": Transform3D() })
	for i in (3 if low else (9 if big else 4)):
		spawn_smoke(p + Vector3(G.rnd(-0.6, 0.6), G.rnd(0, 1.4), G.rnd(-0.6, 0.6)) * radius * 0.25, 0x2f2b28 if i % 3 else 0x55504a, radius * G.rnd(0.8, 1.2), G.rnd(2.6, 4.2), G.rnd(0.8, 1.6), 0.6)

# ground ring: expanding shockwave (wave = true) or a red warning circle that fills up and then calls on_fire
func ring(p: Vector3, radius: float, dur: float, color: Color, wave: bool, on_fire: Callable = Callable()) -> void:
	var m := Gfx.additive(color, 0.9)
	var node := MeshInstance3D.new()
	node.mesh = World.ring_mesh(0.9 if not wave else 0.72, 1.0, 56)
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = p
	node.scale = Vector3.ONE * (radius if not wave else 0.01)
	G.scene_root.add_child(node)
	var r := { "node": node, "mat": m, "radius": radius, "t": dur, "max": dur, "wave": wave, "on_fire": on_fire }
	if not wave:
		var dm := Gfx.additive(Color(0.8, 0.1, 0.05), 0.22)
		var disc := MeshInstance3D.new()
		disc.mesh = World.ring_mesh(0.0, 1.0, 40)
		disc.material_override = dm
		disc.position = p + Vector3(0, 0.005, 0)
		disc.scale = Vector3.ONE * 0.01
		G.scene_root.add_child(disc)
		r.disc = disc
	rings.append(r)

func hazard(p: Vector3, radius: float, delay: float, on_fire: Callable) -> void:
	ring(p + Vector3(0, 0.06, 0), radius, delay, Color(1.6, 0.19, 0.1), false, on_fire)

func shock(p: Vector3, radius: float, dur: float) -> void:
	ring(p, radius, dur, Color(1.6, 1.4, 1.0), true)

# ============================================================ update
func update(dt: float) -> void:
	var cam: Camera3D = G.camera
	for pool in [sparks, dust]:
		var keep: Array = []
		for it in pool.items:
			it.life -= dt
			if it.life <= 0.0:
				continue
			it.v.y -= 12.0 * dt
			it.p += it.v * dt
			if it.p.y < 0.03:
				it.p.y = 0.03; it.v *= 0.4; it.v.y *= -0.3
			it.xf = Transform3D(Basis().scaled(Vector3.ONE * it.s), it.p)
			keep.append(it)
		pool.items = keep
		pool.flush()
	var ks: Array = []
	for it in smoke.items:
		it.life -= dt
		if it.life <= 0.0:
			continue
		var t = 1.0 - it.life / it.max
		it.p += it.v * dt
		it.v *= exp(-dt * 0.6)
		var a: float = it.dense * (1.0 - t) * minf(1.0, t * 8.0 + 0.3)
		it.c = Color(it.base.r, it.base.g, it.base.b, a)
		it.xf = Transform3D(Basis().scaled(Vector3.ONE * it.size * (0.4 + t)), it.p)
		ks.append(it)
	smoke.items = ks
	smoke.flush()
	var kt: Array = []
	for it in tracers.items:
		it.life -= dt
		if it.life <= 0.0:
			continue
		var k: float = it.life / 0.07
		it.c = Color(it.base.r, it.base.g, it.base.b, 0.9 * k)
		kt.append(it)
	tracers.items = kt
	tracers.flush()
	holes.flush()
	var kf: Array = []
	for it in fire.items:
		it.life -= dt
		if it.life <= 0.0:
			continue
		var t = 1.0 - it.life / it.max
		it.p += it.v * dt
		it.v *= exp(-dt * 4.0)
		it.v.y += dt * 1.5
		var col: Color = it.base.lerp(Color(1, 0.95, 0.75), maxf(0.0, 0.5 - t)) * (1.0 - t * 0.6)
		it.c = Color(col.r, col.g, col.b, pow(1.0 - t, 1.4))
		it.xf = Transform3D(Basis().scaled(Vector3.ONE * it.s0 * (0.7 + G.smooth(minf(1.0, t * 1.6)) * 1.3)), it.p)
		kf.append(it)
	fire.items = kf
	fire.flush()
	var kl: Array = []
	for it in flashes.items:
		it.life -= dt
		if it.life <= 0.0:
			continue
		var t = 1.0 - it.life / it.max
		it.c = Color(it.base.r, it.base.g, it.base.b, 1.0 - t)
		it.xf = Transform3D(Basis().scaled(Vector3.ONE * it.size * (0.5 + t)), it.p)
		kl.append(it)
	flashes.items = kl
	flashes.flush()
	var kd: Array = []
	for it in debris.items:
		it.life -= dt
		if it.life <= 0.0:
			continue
		it.v.y -= 20.0 * dt
		it.p += it.v * dt
		it.rot += it.spin * dt
		if it.p.y < it.ground + 0.04:
			it.p.y = it.ground + 0.04; it.v.y *= -0.35; it.v.x *= 0.55; it.v.z *= 0.55; it.spin *= 0.5
		if it.life < 0.5:
			it.s *= exp(-dt * 8.0)
		it.xf = Transform3D(Basis.from_euler(it.rot).scaled(Vector3.ONE * it.s), it.p)
		kd.append(it)
	debris.items = kd
	debris.flush()
	for it in scorch.items:
		it.life -= dt
		it.c = Color(1, 1, 1, 0.85 * clampf(it.life / 6.0, 0.0, 1.0))
	scorch.flush()
	boom_t -= dt
	boom_light.light_energy = boom_light.light_energy * exp(-dt * 9.0) * G.rnd(0.85, 1.1) if boom_t > 0.0 else 0.0
	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r.t -= dt
		var k: float = 1.0 - r.t / r.max
		if r.wave:
			r.node.scale = Vector3.ONE * maxf(0.01, r.radius * k)
			r.mat.albedo_color.a = 0.9 * (1.0 - k)
		else:
			r.disc.scale = Vector3.ONE * maxf(0.01, r.radius * k)
			r.mat.albedo_color.a = 0.6 + 0.4 * sin(G.now * 22.0)
		if r.t > 0.0:
			continue
		if r.on_fire.is_valid():
			r.on_fire.call()
		r.node.queue_free()
		if r.has("disc"):
			r.disc.queue_free()
		rings.remove_at(i)
	if cam:
		pass
