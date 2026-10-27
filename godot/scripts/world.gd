# Spariaps — Mappe (arena e quartiere), negozi, atmosfera, collisioni e navigazione.
# Ogni mappa ha la sua radice: la scenografia statica è unita per materiale, i volumi di collisione sono AABB
# (movimento di giocatore e nemici) e scatole fisiche (raggi: colpi, linea di vista).
class_name World
extends Node

const PI2 := PI / 2.0

var MAPS := {}
var MAP: Dictionary = {}
var B: Dictionary = {}           # map being built
var colliders: Array = []        # active AABBs
var map_version := 0
var font: SystemFont

var mats := {}
var deco_mats := {}
var city := { "facades": [], "signs": [], "glass": null, "pool": null, "lightI": 9.0 }
var beams: Array = []
var ambient: GPUParticles3D
var amb_mode := ""
var arena_on := false
var clouds: Array = []           # smoke grenade clouds (block sight), filled by items.gd

var grid := PackedByteArray()
var climb_grid := PackedByteArray()
const GN := 80
const HALF := 40

func _ready() -> void:
	G.world = self
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	font.font_weight = 700

# ============================================================ building helpers
func new_map(key: String, info: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Map_" + key
	root.visible = false
	G.scene_root.add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	root.add_child(body)
	var deco := Node3D.new()
	deco.visible = false
	root.add_child(deco)
	B = { "key": key, "root": root, "body": body, "batch": Gfx.Batch.new(), "boxes": [], "houses": [],
		"layer": { "solids": [], "pads": [], "deco": deco, "batch": Gfx.Batch.new() } }
	B.merge(info)
	MAPS[key] = B
	return B

func _shadow_for(m: Material) -> bool:
	if m is BaseMaterial3D:
		return m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	return true

# ray-blocking box on the map body; returns the shape node (disabled while open / hidden)
func ray_box(bb: AABB, body: StaticBody3D = null) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bb.size.max(Vector3(0.02, 0.02, 0.02))
	cs.shape = sh
	cs.position = bb.get_center()
	(body if body else B.body).add_child(cs)
	return cs

func put(mesh: Mesh, m: Material, x: float, y: float, z: float, ry := 0.0, pre := Basis(), shadow := -1) -> void:
	B.batch.add(mesh, m, Transform3D(Basis(Vector3.UP, ry) * pre, Vector3(x, y, z)), _shadow_for(m) if shadow < 0 else shadow == 1)

# something you can bump into: drawn in the batch, AABB collider + ray box
func solid(mesh: Mesh, m: Material, xf: Transform3D, ray := true) -> AABB:
	B.batch.add(mesh, m, xf, _shadow_for(m))
	var bb: AABB = xf * mesh.get_aabb()
	B.boxes.append(bb)
	if ray:
		ray_box(bb)
	return bb

func add_box(x: float, z: float, w: float, h: float, d: float, m: Material, y := 0.0) -> AABB:
	return solid(Gfx.box(w, h, d), m, Transform3D(Basis(), Vector3(x, y + h / 2.0, z)))

func tube(x: float, y: float, z: float, length: float, axis: String, m: Material = null, r := 0.035) -> void:
	var rot := Vector3(PI2, 0, 0) if axis == "z" else (Vector3(0, 0, PI2) if axis == "x" else Vector3.ZERO)
	B.batch.at(Gfx.capsule(r, length + 2.0 * r, 8), m if m else mats.neon, Vector3(x, y, z), rot, false)

func skirt(x: float, z: float, w: float, d: float) -> void:
	put(Gfx.box(w + 0.06, 0.35, d + 0.06), mats.trim, x, 0.175, z)

# flat ring / disc lying on the ground (XZ plane, facing up)
static func ring_mesh(inner: float, outer: float, seg := 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer), Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p[idx].x / outer * 0.5 + 0.5, p[idx].z / outer * 0.5 + 0.5))
			st.add_vertex(p[idx])
	return st.commit()

static func flat_quad(w: float, d: float) -> PlaneMesh:
	var m := PlaneMesh.new()
	m.size = Vector2(w, d)
	return m

# glowing shop sign: dark panel + text that lights up at night
func add_sign(text: String, color: String, xf: Transform3D, w: float, h: float, parent: Node3D = null) -> Label3D:
	B.batch.add(Gfx.plane(w, h), deco_mats.signbg, xf, false)
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 64
	l.outline_size = 0
	var px := minf(h * 0.62 / 64.0, w * 0.9 / maxf(1.0, text.length() * 36.0))
	l.pixel_size = px
	l.modulate = Color.html(color)
	l.double_sided = false
	l.transform = xf.translated_local(Vector3(0, 0, 0.012))
	(parent if parent else B.root).add_child(l)
	city.signs.append(l)
	return l

# ============================================================ build everything
func build() -> void:
	_materials()
	_build_arena()
	_build_city()
	B = MAPS.arena; _station("bench", 8, 38.9, PI); _station("perks", -8, -38.9, 0)
	B = MAPS.city; _station("bench", -39.2, 19.5, PI2); _station("perks", 38.9, -17.5, -PI2)
	for m in MAPS.values():
		B = m
		B.batch.commit(B.root)
		B.layer.batch.commit(B.layer.deco)
		m.grid = build_grid(0.0, m.boxes)
		m.climbGrid = build_grid(1.3, m.boxes)
	_skyline()
	_ambient()

func _materials() -> void:
	mats = {
		"wall": Gfx.surface("#bab3a7", "#a29b8e", 2, 4, 0.08, 0.78, 0.28),
		"concrete": Gfx.surface("#8e959d", "#7a8189", 2, 4, 0.12, 0.8),
		"trim": Gfx.mat(0x262b33, 0.4, 0.6),
		"pillar": Gfx.mat(0x3b4655, 0.32, 0.75),
		"crate": Gfx.mat(0xffffff, 0.75, 0.0, { "albedo_texture": Gfx.crate_tex() }),
		"cover": Gfx.mat(0x2f353e, 0.4, 0.55),
		"neon": Gfx.glow(0xff6a2a, 4.5),
		"neonBlue": Gfx.glow(0x3aa8ff, 4.0),
		"city": Gfx.mat(0x46505e, 0.6, 0.3),
		"windows": Gfx.glow(0xffc070, 1.6),
	}
	var wt := Gfx.windows_tex()
	mats.city.emission_enabled = true
	mats.city.emission = G.col(0xffc070)
	mats.city.emission_texture = wt
	mats.city.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mats.city.uv1_scale = Vector3(2, 3, 1)
	mats.city.emission_energy_multiplier = 0.5
	deco_mats = {
		"screen": Gfx.glow(0xffffff, 1.1),
		"lens": Gfx.glow(Color(1, 0.95, 0.85), 2.2),
		"lamp": Gfx.glow(Color(1, 0.8, 0.55), 2.0),
		"puddle": Gfx.transparent(0x0c0f14, 0.75, 0.04, 0.5),
		"stain": Gfx.transparent(0x0c0a08, 0.4, 0.9),
		"signbg": Gfx.mat(0x08090c, 0.5),
	}
	deco_mats.screen.albedo_color = Color(0.03, 0.04, 0.07)
	deco_mats.puddle.albedo_texture = Gfx.glow_tex()
	deco_mats.stain.albedo_texture = Gfx.glow_tex()
	for k in ["puddle", "stain"]:
		deco_mats[k].depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		deco_mats[k].render_priority = 1
	mats.crate.uv1_triplanar = true
	mats.crate.uv1_scale = Vector3(1 / 1.2, 1 / 1.2, 1 / 1.2)
	mats.crate.uv1_offset = Vector3(0.5, 0.5, 0.5)

# ------------------------------------------------------------ map 1: the test arena
func _build_arena() -> void:
	new_map("arena", {
		"name": "ARENA", "tag": "CAMPO DI PROVA", "desc": "L’arena di allenamento: muri bassi, casse e pilastri in uno spazio aperto e simmetrico.",
		"start": Vector3(0, 1, 0), "fallback": Vector2(-37.5, -37.5), "orbit": Vector2(46, 20), "shot": [Vector3(36, 30, 46), Vector3(0, 0, 0)],
		"boxSpots": [[0, -11.5], [11.5, 0], [-11.5, 0], [0, 11.5], [30, -19], [-30, 19], [19, 30], [-19, -30]],
		"pickups": {
			"equip": [[7, 3], [-7, -3], [-3, 7], [3, -7], [-34, -8], [34, 8], [8, 34], [-8, -34]],
			"health": [[0, -10.5], [0, 10.5], [-20, -12], [20, 12], [-34, -12], [34, 12], [-10, 34], [10, -34]],
			"armor": [[-30, -29], [30, 29], [26, -18], [-26, 18]],
		},
		"power": { "jump": [[-19, 0], [19, 0]], "haste": [[0, -19], [0, 19]], "ammo": [[-31, 31], [31, -31]], "quad": [[0, 0]], "god": [[35, 35], [-35, -35]] },
	})
	var floor_m := Gfx.surface("#7c828a", "#686d74", 1, 4, 0.12, 0.82)
	B.batch.add(flat_quad(80, 80), floor_m, Transform3D(), false)
	ray_box(AABB(Vector3(-60, -1, -60), Vector3(120, 1, 120)))
	var paint := Gfx.mat(0xf0b43a, 0.7)
	put(ring_mesh(9, 9.22, 96), paint, 0, 0.005, 0, 0, Basis(), 0)
	put(ring_mesh(9.5, 9.58, 96), paint, 0, 0.005, 0, 0, Basis(), 0)
	for a in [0.0, PI2]:
		for s in [-1, 1]:
			put(flat_quad(0.22, 18), paint, sin(a) * 26 * s, 0.005, cos(a) * 26 * s, a, Basis(), 0)
	for s in [-1, 1]:
		add_box(0, 40.5 * s, 82, 6, 1, mats.wall)
		add_box(40.5 * s, 0, 1, 6, 82, mats.wall)
		skirt(0, 40.5 * s, 80, 1); skirt(40.5 * s, 0, 1, 80)
		tube(0, 5.2, 39.96 * s, 80, "x", mats.neonBlue)
		tube(39.96 * s, 5.2, 0, 80, "z", mats.neonBlue)
	add_box(0, 0, 6, 1, 6, mats.concrete)
	for s in [-1, 1]:
		tube(3.03 * s, 0.82, 0, 5.4, "z"); tube(0, 0.82, 3.03 * s, 5.4, "x")
		for z in [-7, 7]:
			add_box(14 * s, z, 1, 3, 8, mats.wall); skirt(14 * s, z, 1, 8)
			add_box(z, 14 * s, 8, 3, 1, mats.wall); skirt(z, 14 * s, 8, 1)
			tube(14 * s, 3.01, z, 7.4, "z"); tube(z, 3.01, 14 * s, 7.4, "x")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			add_box(28 * sx, 24 * sz, 12, 4, 1, mats.wall); skirt(28 * sx, 24 * sz, 12, 1)
			add_box(22.5 * sx, 30 * sz, 1, 4, 11, mats.wall); skirt(22.5 * sx, 30 * sz, 1, 11)
			tube(28 * sx, 4.01, 24 * sz, 11.4, "x", mats.neonBlue, 0.03)
	for p in [[26, 0], [-26, 0], [0, 27], [0, -27]]:
		solid(Gfx.cyl(1.1, 1.1, 6, 32), mats.pillar, Transform3D(Basis(), Vector3(p[0], 3, p[1])))
		for y in [0.6, 3.0, 5.4]:
			B.batch.at(Gfx.torus(1.13, 0.04, 40), mats.neon, Vector3(p[0], y, p[1]), Vector3.ZERO, false)
	for c in [[-30, 12, 6, 0.6], [30, -12, 6, 0.6], [12, 30, 0.6, 6], [-12, -30, 0.6, 6], [-6, 20, 4, 0.6], [6, -20, 4, 0.6]]:
		add_box(c[0], c[1], c[2], 1.1, c[3], mats.cover)
		var ln: float = maxf(c[2], c[3]) - 0.6
		for s in [-1, 1]:
			if c[2] > c[3]:
				tube(c[0], 0.75, c[1] + s * (c[3] / 2.0 + 0.005), ln, "x", mats.neon, 0.022)
			else:
				tube(c[0] + s * (c[2] / 2.0 + 0.005), 0.75, c[1], ln, "z", mats.neon, 0.022)
	for c in [[-8, -22, 0], [-6.8, -22, 0], [-8, -22, 1.2], [8, 22, 0], [9.2, 22, 0], [8, 22, 1.2],
		[22, -8, 0], [22, -6.8, 0], [-22, 8, 0], [-22, 9.2, 0], [-22, 8, 1.2],
		[-18, -18, 0], [18, 18, 0], [18, -18, 0], [-18, 18, 0], [-33, 0, 0], [33, 0, 0], [0, -34, 0], [0, 34, 0],
		[-30, -34, 0], [30, 34, 0], [-34, 30, 0], [34, -30, 0], [10, -5, 0], [-10, 5, 0], [-4, -9, 0], [4, 9, 0]]:
		add_box(c[0], c[1], 1.2, 1.2, 1.2, mats.crate, c[2])
	mats.barrels = ["#b0382a", "#2d628f", "#3d6e3a"].map(func(c): return Gfx.mat(0xffffff, 0.38, 0.55, { "albedo_texture": Gfx.barrel_tex(c) }))
	for p in [[-12, -12], [-12.9, -11.6], [12, 12], [12.8, 12.6], [-35, -20], [35, 20], [20, -34], [-20, 34], [-3, 30], [3, -30], [30, 5], [-30, -5]]:
		solid(Gfx.cyl(0.42, 0.42, 1.15, 20), mats.barrels[randi() % 3], Transform3D(Basis(Vector3.UP, randf() * 6), Vector3(p[0], 0.575, p[1])))

	# big screens on top of the north and south walls
	for s in [-1, 1]:
		var ry := PI if s > 0 else 0.0
		var base := Transform3D(Basis(Vector3.UP, ry), Vector3(0, 0, 40.9 * s))
		B.batch.add(Gfx.box(17, 5.4, 0.5), mats.trim, base * Transform3D(Basis(), Vector3(0, 9.4, 0)))
		B.batch.add(Gfx.plane(16.2, 4.56), deco_mats.screen, base * Transform3D(Basis(), Vector3(0, 9.4, 0.26)), false)
		for x in [-6, 6]:
			B.batch.add(Gfx.cyl(0.18, 0.18, 1.2, 12), mats.trim, base * Transform3D(Basis(), Vector3(x, 6.5, 0)))
		var t1 := Label3D.new(); t1.font = font; t1.text = "SPARIAPS"; t1.font_size = 96; t1.pixel_size = 0.022
		t1.modulate = Color(1.6, 0.9, 0.7); t1.transform = base * Transform3D(Basis(), Vector3(-2.6, 9.4, 0.28)); B.root.add_child(t1)
		var t2 := Label3D.new(); t2.font = font; t2.text = "ARENA · LIVE\nSOPRAVVIVI ALLE ONDATE"; t2.font_size = 40; t2.pixel_size = 0.016
		t2.modulate = Color(0.6, 0.85, 1.2); t2.transform = base * Transform3D(Basis(), Vector3(4.6, 9.4, 0.28)); B.root.add_child(t2)
		city.signs.append(t1); city.signs.append(t2)

	# floodlight towers behind the corners, with soft light cones
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var sx: float = c[0]
		var sz: float = c[1]
		var head := Vector3(43 * sx, 18, 43 * sz)
		put(Gfx.cyl(0.28, 0.4, 18, 12), mats.pillar, 44 * sx, 9, 44 * sz)
		var target := Vector3(12 * sx, 0, 12 * sz)
		var look := Transform3D().looking_at(target - head, Vector3.UP)
		B.batch.add(Gfx.box(2.6, 1.3, 0.7), mats.trim, Transform3D(look.basis, head))
		B.batch.add(Gfx.plane(2.3, 1.05), deco_mats.lens, Transform3D(look.basis, head) * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.36)), false)
		var dir := (target - head)
		var L := dir.length()
		var cone := MeshInstance3D.new()
		cone.mesh = Gfx.cyl(0.05, 6.5, L, 24, true)
		cone.material_override = Gfx.beam(Color(1, 0.93, 0.8), 0.12, false)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.position = head + dir * 0.5
		cone.basis = Basis(Quaternion(Vector3.DOWN, dir.normalized()))
		B.root.add_child(cone)
		beams.append(cone)

	# outer walls: pipe runs with brackets and caged wall lamps
	for side in [["x", -1], ["x", 1], ["z", -1], ["z", 1]]:
		var ax: String = side[0]
		var s: float = side[1]
		var off := 39.72 * s
		var place := func(mesh: Mesh, m: Material, a: float, y: float, d: float, pre: Basis) -> void:
			if ax == "x":
				put(mesh, m, a, y, off - d * s, PI if s > 0 else 0.0, pre)
			else:
				put(mesh, m, off - d * s, y, a, -PI2 if s > 0 else PI2, pre)
		place.call(Gfx.cyl(0.12, 0.12, 79, 10), mats.pillar, 0, 4.75, 0.05, Basis(Vector3.BACK, PI2))
		place.call(Gfx.cyl(0.07, 0.07, 79, 8), mats.pillar, 0, 4.45, 0.05, Basis(Vector3.BACK, PI2))
		for a in range(-36, 37, 8):
			place.call(Gfx.box(0.12, 0.55, 0.3), mats.trim, a, 4.6, 0.0, Basis())
		for a in range(-35, 36, 10):
			place.call(Gfx.box(0.7, 0.3, 0.32), mats.trim, a, 3.35, 0.0, Basis())
			place.call(Gfx.plane(0.56, 0.16), deco_mats.lamp, a, 3.2, 0.2, Basis(Vector3.RIGHT, -PI2 + 0.6))

	# floor wear: puddles and stains
	for i in 16:
		put(flat_quad(G.rnd(1.6, 3.6), G.rnd(1.2, 2.6)), deco_mats.puddle, G.rnd(-37, 37), 0.012, G.rnd(-37, 37), randf() * TAU, Basis(), 0)
	for i in 26:
		var sz := G.rnd(1.5, 4)
		put(flat_quad(sz, G.rnd(1.5, 4)), deco_mats.stain, G.rnd(-38, 38), 0.008, G.rnd(-38, 38), randf() * TAU, Basis(), 0)

	# classic-mode layer: floating platforms + jump pads
	var MID := 3.4
	var SKY := 7.2
	for c in [[-1, -1], [1, 1], [1, -1], [-1, 1]]:
		_platform(20 * c[0], 20 * c[1], 6, 6, MID)
	_platform(0, 0, 6, 6, SKY)
	jump_pad(Vector3(13.5, 0, 20), Vector3(19.5, MID, 20), 0.9); jump_pad(Vector3(-13.5, 0, -20), Vector3(-19.5, MID, -20), 0.9)
	jump_pad(Vector3(20, 0, -13.5), Vector3(20, MID, -19.5), 0.9); jump_pad(Vector3(-20, 0, 13.5), Vector3(-20, MID, 19.5), 0.9)
	for c in [[-1, -1], [1, 1], [1, -1], [-1, 1]]:
		jump_pad(Vector3(18.2 * c[0], MID, 18.2 * c[1]), Vector3(1.4 * c[0], SKY, 1.4 * c[1]), 1.3)

var pad_mats := {}

func _platform(x: float, z: float, w: float, d: float, top: float, thick := 0.5) -> void:
	var L: Dictionary = B.layer
	var xf := Transform3D(Basis(), Vector3(x, top - thick / 2.0, z))
	var mesh := Gfx.box(w, thick, d)
	L.batch.add(mesh, mats.concrete, xf)
	var bb: AABB = xf * mesh.get_aabb()
	var shape := ray_box(bb)
	shape.disabled = true
	L.solids.append({ "box": bb, "shape": shape })
	if pad_mats.is_empty():
		pad_mats = { "base": Gfx.mat(0x252a33, 0.35, 0.8), "under": Gfx.glow(0x3aa8ff, 2.0) }
	for s in [-1, 1]:
		L.batch.at(Gfx.capsule(0.03, w - 0.24, 6), mats.neon, Vector3(x, top - 0.12, z + s * (d / 2.0 + 0.01)), Vector3(0, 0, PI2), false)
		L.batch.at(Gfx.capsule(0.03, d - 0.24, 6), mats.neon, Vector3(x + s * (w / 2.0 + 0.01), top - 0.12, z), Vector3(PI2, 0, 0), false)
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		L.batch.at(Gfx.cyl(0.28, 0.2, 0.18, 16), pad_mats.base, Vector3(x + c[0] * (w / 2.0 - 0.7), top - thick - 0.08, z + c[1] * (d / 2.0 - 0.7)))
		L.batch.at(Gfx.cyl(0.17, 0.17, 0.01, 16), pad_mats.under, Vector3(x + c[0] * (w / 2.0 - 0.7), top - thick - 0.175, z + c[1] * (d / 2.0 - 0.7)), Vector3.ZERO, false)

# jump pad: launch velocity solved so the arc lands on the target in T seconds (gravity 20)
func jump_pad(p: Vector3, t: Vector3, T := 1.0) -> void:
	var L: Dictionary = B.layer
	if pad_mats.is_empty():
		pad_mats = { "base": Gfx.mat(0x252a33, 0.35, 0.8), "under": Gfx.glow(0x3aa8ff, 2.0) }
	if not pad_mats.has("ring"):
		pad_mats.ring = Gfx.glow(0x3affe0, 4.0)
		pad_mats.disc = Gfx.additive(0x3affe0, 0.7, Gfx.glow_tex())
	var g := Node3D.new()
	g.position = p
	L.deco.add_child(g)
	Gfx.mesh_node(Gfx.cyl(0.95, 1.02, 0.12, 32), pad_mats.base, Vector3(0, 0.06, 0), Vector3.ZERO, g)
	var ring := Gfx.mesh_node(Gfx.torus(0.78, 0.035, 40), pad_mats.ring, Vector3(0, 0.13, 0), Vector3.ZERO, g)
	var disc := Gfx.mesh_node(flat_quad(1.8, 1.8), pad_mats.disc, Vector3(0, 0.125, 0), Vector3.ZERO, g)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := Gfx.mesh_node(Gfx.cyl(0.62, 0.78, 2.2, 24, true), Gfx.beam(0x3affe0, 0.4), Vector3(0, 1.1, 0), Vector3.ZERO, g)
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.pads.append({ "pos": p, "vel": Vector3((t.x - p.x) / T, (t.y - p.y + 10.0 * T * T) / T, (t.z - p.z) / T), "ring": ring, "beam": bm, "t": 0.0 })

# ------------------------------------------------------------ map 2: "Quartiere" — a small Italian neighbourhood around a crossroads
var CM := {}

func _cmat(c: int, r := 0.8, m := 0.0) -> StandardMaterial3D:
	return Gfx.mat(c, r, m)

func _build_city() -> void:
	new_map("city", {
		"name": "QUARTIERE", "tag": "CITTÀ", "desc": "Un incrocio di quartiere: piazza con fontana, vicoli, parcheggio e benzinaio. Quattro edifici da aprire con i crediti per ripararsi all’interno.",
		"start": Vector3(0, 0, 0), "fallback": Vector2(-37.5, -37.5), "orbit": Vector2(47, 27), "shot": [Vector3(-30, 28, 40), Vector3(2, 1, -4)],
		"roads": [[-5, -40, 5, 40], [-40, -5, 40, 5]],
		"boxSpots": [[27.5, -17], [9.5, -27], [-23, -37.4], [-37.6, -14], [-23.5, 18], [-11.5, 37.5], [14, 37.6], [37, 16]],
		"pickups": {
			"equip": [[-22.5, -30], [-9, -25], [9.5, -9.5], [37, -34], [-18.5, 38], [-36.5, 9.5], [10, 28], [36.5, 8.5]],
			"health": [[6.3, -13], [-6.3, 13], [-13, 6.3], [13, -6.3], [-22.5, -19.5], [18.5, -18.5], [-30, 18], [30, 27.5]],
			"armor": [[-37.5, -37.5], [37, -27], [-37, 24], [38.2, 38.4]],
		},
		"power": { "jump": [[-29, -11], [29.5, 10]], "haste": [[2.5, -35], [-2.5, 35]], "ammo": [[-18, 27], [26, -9]], "quad": [[22, 20]], "god": [[-37.5, -24], [38, 33]] },
	})
	CM = {
		"asphalt": Gfx.surface("#3c3f45", "#3c3f45", 1, 5, 0.16, 0.88),
		"outer": _cmat(0x34373c, 0.95),
		"sidewalk": Gfx.surface("#a5a39c", "#85837c", 4, 4, 0.1, 0.85),
		"plaza": Gfx.surface("#c2b092", "#96846a", 4, 3, 0.1, 0.8),
		"fore": Gfx.surface("#8f949a", "#7b8086", 2, 4, 0.14, 0.8),
		"brick": Gfx.surface("#a25d45", "#7a4332", 8, 4, 0.1, 0.85, 0.2),
		"curb": _cmat(0x8a8a86), "white": _cmat(0xa9a9a3),
		"cornice": _cmat(0xd9d2c2), "plinth": _cmat(0x55585d, 0.7), "door": _cmat(0x3d2c1e, 0.6), "shutter": _cmat(0x7d8288, 0.5, 0.5),
		"leaf": _cmat(0x45733a, 0.95), "trunk": _cmat(0x5a4532, 0.9), "soil": _cmat(0x3a2e24, 1.0),
		"water": Gfx.transparent(0x2c6f8f, 0.85, 0.05, 0.4), "stone": _cmat(0xcfc8b8, 0.7), "wood": _cmat(0x7a5234, 0.7),
		"carGlass": _cmat(0x0d1218, 0.08, 0.8), "tire": _cmat(0x121214, 0.9), "hub": _cmat(0xb9bec6, 0.35, 0.8),
		"head": Gfx.glow(Color(1, 0.96, 0.85), 1.6), "tail": Gfx.glow(Color(1, 0.12, 0.08), 1.5), "amber": Gfx.glow(Color(1, 0.75, 0.15), 1.5),
		"bus": _cmat(0xe07a1f, 0.4, 0.4), "taxi": _cmat(0xf2f2ee, 0.32, 0.5), "dump": _cmat(0x2f5d3a, 0.6, 0.3), "kiosk": _cmat(0x26513a, 0.6, 0.3),
		"awnR": _cmat(0xa8322a), "awnG": _cmat(0x2f6b45), "awnB": _cmat(0x27507f), "awnY": _cmat(0xd9a441),
		"canopy": _cmat(0xe9e9e4, 0.5, 0.1), "pump": _cmat(0xc0281f, 0.4, 0.4),
		"shelter": Gfx.transparent(0x9fc4d8, 0.35, 0.1, 0.3),
		"extA": Gfx.surface("#b3915a", "#b3915a", 1, 4, 0.16, 0.9), "extB": Gfx.surface("#a56a50", "#a56a50", 1, 4, 0.16, 0.9),
		"plaster": Gfx.surface("#d6cdb8", "#d6cdb8", 1, 4, 0.12, 0.92), "tileW": Gfx.surface("#d5dade", "#a9b0b7", 6, 3, 0.12, 0.35),
		"wallGrey": Gfx.surface("#8b8f93", "#74787c", 2, 3, 0.18, 0.85),
		"floorTile": Gfx.surface("#b3a995", "#8a8170", 4, 3, 0.12, 0.5), "floorShop": Gfx.surface("#c9ccd0", "#9a9fa5", 4, 3, 0.12, 0.35),
		"floorGarage": Gfx.surface("#5d6064", "#4c4f53", 2, 3, 0.22, 0.7),
		"ceil": _cmat(0xe4e1d8, 0.95), "roofing": _cmat(0x4b4e53, 0.9), "rack": _cmat(0x4a4f57, 0.55, 0.45),
		"neonG": Gfx.glow(0x3dff7a, 3.0),
		"fence": Gfx.transparent(0xa8aeb6, 0.35, 0.5, 0.6),
	}
	CM.paints = [0xb3261e, 0x1f4e8c, 0xd8d8d2, 0x2b2f36, 0x3f6b45, 0xc9a227].map(func(c): return Gfx.mat(c, 0.32, 0.55))
	var stripes := Gfx._img(32, 32, Color.html("#8b9097"))
	for y in range(0, 32, 8):
		Gfx._rect(stripes, 0, y, 32, 2, Color(0, 0, 0, 0.38)); Gfx._rect(stripes, 0, y + 2, 32, 2, Color(1, 1, 1, 0.2))
	CM.roller = Gfx.mat(0xffffff, 0.45, 0.6, { "albedo_texture": Gfx.tex(stripes), "uv1_triplanar": true, "uv1_scale": Vector3(1.6, 1.6, 1.6) })
	city.glass = Gfx.mat(0x0c1118, 0.08, 0.7)
	city.glass.emission_enabled = true
	city.glass.emission = G.col(0xffd9a0)
	city.glass.emission_texture = Gfx.shopwin_tex()
	city.glass.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	city.glass.emission_energy_multiplier = 0.25
	city.pool = Gfx.additive(0xffc98a, 0.0, Gfx.glow_tex())
	var FAC: Array = []
	for pair in [["#d9b36a", "#3f6a4a"], ["#c98566", "#5a4332"], ["#cfc9bb", "#3c5a78"], ["#e0c9a0", "#7a2e2a"]]:
		var tx: Array = Gfx.facade_tex(pair[0], pair[1])
		var m := Gfx.mat(0xffffff, 0.88)
		m.albedo_texture = tx[0]
		m.emission_enabled = true
		m.emission = G.col(0xffd9a0)
		m.emission_texture = tx[1]
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_energy_multiplier = 0.12
		city.facades.append(m)
		FAC.append(m)

	# ---- ground: asphalt everywhere, raised paving on the blocks, road markings
	B.batch.add(flat_quad(80, 80), CM.asphalt, Transform3D(), false)
	B.batch.add(flat_quad(320, 320), CM.outer, Transform3D(Basis(), Vector3(0, -0.04, 0)), false)
	ray_box(AABB(Vector3(-60, -1, -60), Vector3(120, 1, 120)))
	var slab := func(x0: float, z0: float, x1: float, z1: float, m: Material, h: float) -> void:
		var mesh := Gfx.box(x1 - x0, h, z1 - z0)
		var xf := Transform3D(Basis(), Vector3((x0 + x1) / 2.0, h / 2.0, (z0 + z1) / 2.0))
		B.batch.add(mesh, m, xf, false)
		ray_box(xf * mesh.get_aabb())
	slab.call(-40, -40, -5, -5, CM.sidewalk, 0.07)
	slab.call(5, -40, 40, -5, CM.plaza, 0.07)
	slab.call(-40, 5, -5, 7.5, CM.sidewalk, 0.07); slab.call(-7.5, 7.5, -5, 40, CM.sidewalk, 0.07)
	slab.call(5, 5, 40, 7.5, CM.sidewalk, 0.07); slab.call(5, 7.5, 7.5, 40, CM.sidewalk, 0.07)
	slab.call(7.5, 7.5, 40, 40, CM.fore, 0.04)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			put(Gfx.box(35, 0.1, 0.24), CM.curb, sx * 22.5, 0.05, sz * 5.02)
			put(Gfx.box(0.24, 0.1, 35), CM.curb, sx * 5.02, 0.05, sz * 22.5)
	var mark := func(w: float, d: float, x: float, z: float) -> void:
		put(flat_quad(w, d), CM.white, x, 0.012, z, 0, Basis(), 0)
	for s in [-1, 1]:
		for t in range(11, 39, 4):
			mark.call(0.16, 2, 0, s * t); mark.call(2, 0.16, s * t, 0)
		for k in range(-4, 5):
			mark.call(0.5, 2.6, k, s * 7); mark.call(2.6, 0.5, s * 7, k)
	for z in [13, 23]:
		for i in 11:
			mark.call(0.12, 5, -36.6 + i * 2.7, z)
	for b in [[-2, 24, 3, 2, 0.014], [3, -9, 2.4, 1.6, 0.014], [-22, 2, 3, 1.8, 0.014], [-22.5, -27, 2, 3, 0.085], [-33, -37.5, 3, 1.6, 0.085], [-20, 18, 3, 2.2, 0.014], [27, 13, 2.4, 1.8, 0.055], [12, -20, 2.6, 2, 0.085]]:
		put(flat_quad(b[2], b[3]), deco_mats.puddle, b[0], b[4], b[1], randf() * TAU, Basis(), 0)
	for b in [[-19, 13, 2, 2, 0.013], [-29.8, 13, 2.2, 2.2, 0.013], [-24.4, 23, 2, 2.4, 0.013], [22, 14.5, 3, 2, 0.053], [24, 20, 3, 3, 0.053], [2.5, -22, 3, 6, 0.013], [-37.5, -27, 3, 4, 0.083], [-25, 30, 3, 3, 0.013], [0, 0, 4, 4, 0.013]]:
		put(flat_quad(b[2], b[3]), deco_mats.stain, b[0], b[4], b[1], randf() * TAU, Basis(), 0)

	# ---- buildings around the edge
	var ring := {}
	var HS := [12.8, 9.6, 16, 12.8, 16, 9.6]
	var spans := [[-41, -30], [-30, -19], [-19, -7.5], [7.5, 19], [19, 30], [30, 41]]
	for i in spans.size():
		var c: float = (spans[i][0] + spans[i][1]) / 2.0
		var w: float = spans[i][1] - spans[i][0]
		ring["N%d" % i] = bld(c, -43, w, HS[i], 6, FAC[i % 4])
		ring["S%d" % i] = bld(c, 43, w, HS[(i + 2) % 6], 6, FAC[(i + 1) % 4])
		ring["W%d" % i] = bld(-43, c, 6, HS[(i + 3) % 6], w, FAC[(i + 2) % 4])
		ring["E%d" % i] = bld(43, c, 6, HS[(i + 4) % 6], w, FAC[(i + 3) % 4])
		dress(ring["N%d" % i], "S"); dress(ring["S%d" % i], "N"); dress(ring["W%d" % i], "E"); dress(ring["E%d" % i], "W")
	# the streets carry on past the roadblocks
	for s in [-1, 1]:
		for side in [-1, 1]:
			for tk in [[54, 16, 0], [69, 12.8, 2]]:
				put(Gfx.facade_box(11, tk[1], 14), FAC[(tk[2] + (s + side + 2)) % 4], side * 13, tk[1] / 2.0, s * tk[0])
				put(Gfx.facade_box(14, tk[1], 11), FAC[(tk[2] + 1 + (s + side + 2)) % 4], s * tk[0], tk[1] / 2.0, side * 13)

	# ---- props shared by the whole map
	for s in [-1, 1]:
		for t in [14, 30]:
			for side in [-1, 1]:
				lamp(side * 6.2, s * t, -side, 0); lamp(s * t, side * 6.2, 0, -side)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			put(Gfx.cyl(0.06, 0.08, 3.4, 8), mats.pillar, sx * 5.7, 1.7, sz * 5.7)
			put(Gfx.box(0.3, 0.9, 0.3), mats.trim, sx * 5.7, 3.7, sz * 5.7)
			put(Gfx.sphere(0.09, 10, 6), CM.tail, sx * 5.7 - sx * 0.16, 3.98, sz * 5.7)
			put(Gfx.sphere(0.09, 10, 6), CM.amber, sx * 5.7, 3.7, sz * 5.7 - sz * 0.16)
	# roadblocks where the streets leave the map
	for s in [-1, 1]:
		for k in [-5.4, -1.8, 1.8, 5.4]:
			add_box(k, s * 38.3, 3.2, 0.9, 0.6, mats.concrete)
			add_box(s * 38.3, k, 0.6, 0.9, 3.2, mats.concrete)
			put(Gfx.box(2.6, 0.18, 0.62), CM.awnR, k, 0.6, s * 38.3); put(Gfx.box(0.62, 0.18, 2.6), CM.awnR, s * 38.3, 0.6, k)
		add_box(0, s * 39.75, 15, 3.2, 0.08, CM.fence)
		add_box(s * 39.75, 0, 0.08, 3.2, 15, CM.fence)
		for k in range(-7, 9, 3):
			put(Gfx.cyl(0.05, 0.05, 3.3, 6), mats.pillar, k - 0.5, 1.65, s * 39.75); put(Gfx.cyl(0.05, 0.05, 3.3, 6), mats.pillar, s * 39.75, 1.65, k - 0.5)
		add_sign("STRADA CHIUSA", "#ff6a5a", Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), Vector3(0, 2.2, s * 39.68)), 3.6, 0.9)
		add_sign("STRADA CHIUSA", "#ff6a5a", Transform3D(Basis(Vector3.UP, -PI2 if s > 0 else PI2), Vector3(s * 39.68, 2.2, 0)), 3.6, 0.9)
	# traffic left in the streets
	car(2.6, -22, 0, CM.bus, "bus"); car(-2.5, -33, 2, CM.paints[1])
	car(-2.4, 16, 0, CM.taxi, "taxi"); car(2.5, 29, 2, CM.paints[0])
	car(-26, 2.4, 1, CM.paints[3]); car(-15, -2.4, 3, CM.paints[2], "van")
	car(17, -2.4, 3, CM.paints[5]); car(30, 2.5, 1, CM.paints[4])

	# ---- north-west: two apartment blocks, back alleys, a newsstand and the bus stop
	var A := bld(-29, -26, 10, 12.8, 18, FAC[0], 3.2)
	var Bb := bld(-16.5, -28.5, 9, 9.6, 13, FAC[1], 3.2)
	front(A, "S", 0, 8, "ALIMENTARI", CM.awnG, "#8dffb0")
	front(Bb, "E", 0, 9, "FARMACIA", null, "#5dff8a")
	front(Bb, "S", 0, 6, "TABACCHI", CM.awnB, "#ffd45a")
	house(A, { "name": "ALIMENTARI", "cost": 3500, "ext": CM.extA, "int": CM.plaster, "floor": CM.floorTile, "lights": [[-29, -21.5], [-29, -30.5]],
		"ops": [["S", 2, 2.6, "door"], ["S", -2, 2.6, "win"], ["N", 2, 2.6, "door"], ["E", 2, 2.6, "win"], ["W", 4, 2.6, "win"]] })
	shelf(-31, -28.5, 7, false); shelf(-28, -28.5, 7, false); shelf(-33.5, -29, 8, false, 2.1, [1])
	fridge(-27, -34.32, 4.6, "S"); counter(-25.3, -21.5, 1, 3.2)
	for p in [[-31.6, -19.3], [-30.3, -19.3], [-33, -19.6]]:
		add_box(p[0], p[1], 1.1, 0.55, 0.8, mats.crate)
		for i in 9:
			put(Gfx.sphere(0.1, 8, 5), CM.paints[0 if i % 2 else 5], p[0] - 0.36 + (i % 3) * 0.36, 0.62, p[1] - 0.22 + (i / 3) * 0.22)
	house(Bb, { "name": "FARMACIA", "cost": 3000, "ext": CM.extB, "int": CM.tileW, "floor": CM.floorShop, "lights": [[-16.5, -28.5]],
		"ops": [["E", -0.5, 2.6, "door"], ["E", 3.5, 2.6, "win"], ["E", -4.5, 2.6, "win"], ["S", -0.5, 2.6, "door"], ["W", -1.5, 2.6, "win"]] })
	counter(-18.5, -30, 0.7, 7, CM.cornice)
	shelf(-20.52, -33, 3, false, 2.2, [1]); shelf(-20.52, -27.2, 2.4, false, 2.2, [1]); shelf(-15.6, -34.3, 5.6, true, 2.2, [1]); shelf(-15, -25.3, 2, true, 1.25)
	put(Gfx.box(0.9, 0.3, 0.06), CM.neonG, -20.66, 2.55, -24.2, PI2); put(Gfx.box(0.3, 0.9, 0.06), CM.neonG, -20.66, 2.55, -24.2, PI2)
	dress(A, "S"); dress(A, "E", 2); dress(Bb, "E"); dress(Bb, "S"); dress(Bb, "W", 2)
	face(Bb, "E", Gfx.box(0.9, 0.3, 0.1), mats.neonBlue, 3.2, 5.2, 0.5); face(Bb, "E", Gfx.box(0.3, 0.9, 0.1), mats.neonBlue, 3.2, 5.2, 0.5)
	for f in [[A, "N", -3], [A, "W", -5], [A, "W", 0.5], [Bb, "N", 1], [A, "E", 6]]:
		face(f[0], f[1], Gfx.box(0.9, 0.6, 0.4), CM.shutter, f[2], 3.9, 0.2)
	for f in [[A, "E"], [Bb, "W"], [A, "N"], [A, "W"]]:
		face(f[0], f[1], Gfx.box(0.34, 0.14, 0.3), mats.trim, 0, 3.5, 0.15)
		face(f[0], f[1], Gfx.plane(0.26, 0.22), deco_mats.lamp, 0, 3.42, 0.17, Basis(Vector3.RIGHT, PI2))
	dumpster(-29, -38.55, 0); dumpster(-26.6, -38.55, 0); dumpster(-38.55, -29, 1); dumpster(-38.55, -20, 1)
	for c in [[-38.7, -33.5, 0], [-37.5, -34, 0], [-38.7, -33.5, 1.2], [-18, -38.8, 0], [-13.5, -38.8, 0], [-13.5, -38.8, 1.2]]:
		add_box(c[0], c[1], 1.2, 1.2, 1.2, mats.crate, c[2] + 0.07)
	# newsstand
	add_box(-10.5, -12.5, 3, 2.6, 2.4, CM.kiosk, 0.07)
	put(Gfx.box(3.7, 0.12, 3.1), CM.dump, -10.5, 2.75, -12.5)
	add_sign("EDICOLA", "#ffe9a8", Transform3D(Basis(), Vector3(-10.5, 2.3, -11.28)), 2.4, 0.6)
	put(Gfx.plane(2.4, 1.1), city.glass, -10.5, 1.35, -11.28)
	for i in 5:
		put(Gfx.box(0.4, 0.55, 0.06), CM.paints[i], -11.4 + i * 0.45, 0.6, -11.2)
	# bus stop
	add_box(-18, -7.3, 3.6, 2.3, 0.1, CM.shelter, 0.07)
	put(Gfx.box(3.9, 0.1, 1.6), mats.trim, -18, 2.45, -6.7)
	for s in [-1, 1]:
		put(Gfx.cyl(0.05, 0.05, 2.4, 6), mats.pillar, -18 + s * 1.8, 1.27, -6.05)
	put(Gfx.box(2.6, 0.08, 0.4), CM.wood, -18, 0.55, -6.95)
	put(Gfx.cyl(0.04, 0.04, 2.8, 6), mats.pillar, -15.4, 1.45, -5.6); put(Gfx.box(0.5, 0.5, 0.05), CM.awnB, -15.4, 2.7, -5.6)
	tree(-19, -14.5); tree(-33, -11); tree(-9, -20.5)
	scooter(-13.6, -9.2, 0.15, CM.paints[0]); scooter(-12.6, -9.3, -0.1, CM.paints[4]); scooter(-31, -15.6, 1.4, CM.paints[5])
	bench(-27.5, -9, 0)

	# ---- north-east: the piazza with its fountain, café tables and a drinks kiosk
	solid(Gfx.cyl(3.2, 3.3, 0.65, 32), CM.stone, Transform3D(Basis(), Vector3(23, 0.395, -23)))
	put(Gfx.cyl(2.85, 2.85, 0.04, 32), CM.water, 23, 0.74, -23)
	solid(Gfx.cyl(0.5, 0.75, 1.9, 16), CM.stone, Transform3D(Basis(), Vector3(23, 1.67, -23)))
	put(Gfx.cyl(1.5, 0.5, 0.4, 24), CM.stone, 23, 2.75, -23)
	put(Gfx.cyl(1.38, 1.38, 0.03, 24), CM.water, 23, 2.96, -23)
	put(Gfx.cyl(0.16, 0.22, 0.7, 12), CM.stone, 23, 3.3, -23); put(Gfx.sphere(0.26, 14, 8), CM.stone, 23, 3.8, -23)
	for i in 12:
		var a := i / 12.0 * TAU
		put(flat_quad(0.7, 3.2), CM.cornice, 23 + cos(a) * 5.6, 0.078, -23 + sin(a) * 5.6, -a + PI2, Basis(), 0)
	tree(13, -13, 1.1); tree(33, -13, 1.1); tree(13, -33, 1.1); tree(33, -33, 1.1)
	bench(23, -15, 2); bench(23, -31, 0); bench(15, -23, 1); bench(31, -23, 3)
	table(17.5, -36.6, CM.awnR); table(23, -36.6, CM.awnG); table(28.5, -36.6, CM.awnY); table(36.8, -24.5, CM.awnB)
	shop(ring.N3, "S", 0, 8, "BAR", CM.awnR, "#ffb36b"); shop(ring.N4, "S", 0, 8, "PIZZERIA", CM.awnG, "#ff8a7a"); shop(ring.N5, "S", 0, 8, "GELATERIA", CM.awnY, "#ffb3e6")
	shop(ring.E1, "W", 0, 8, "LIBRERIA", CM.awnB, "#9ad4ff"); shop(ring.E2, "W", 0, 8, "FIORI", CM.awnG, "#b6ff9a")
	var k := { "x": 35.5, "z": -12.0, "w": 5.0, "h": 3.2, "d": 4.0 }
	add_box(k.x, k.z, k.w, k.h - 0.07, k.d, CM.kiosk, 0.07)
	put(Gfx.box(5.6, 0.14, 4.6), CM.dump, k.x, k.h - 0.06, k.z)
	face(k, "W", Gfx.plane(2.8, 1.2), city.glass, 0, 1.7, 0.02); face(k, "W", Gfx.box(3.2, 0.1, 0.5), CM.stone, 0, 1.05, 0.25)
	sign_face(k, "W", "BIBITE", "#7fd0ff", 0, 2.72, 0.03, 2.6, 0.65)
	face(k, "W", Gfx.box(3.6, 0.06, 1.3), CM.awnB, 0, 2.3, 0.7, Basis(Vector3.RIGHT, 0.3))

	# ---- south-west: car park and the mechanic's garage
	for c in [[0, 13, 0, 4], [2, 13, 2, 2], [6, 13, 0, 0], [8, 13, 0, 3], [1, 23, 2, 5], [4, 23, 0, 1], [9, 23, 2, 2]]:
		car(-35.25 + c[0] * 2.7, c[1], c[2], CM.paints[c[3]])
	car(-14, 32, 1, CM.paints[2], "van")
	var g := { "x": -32.0, "z": 33.0, "w": 12.0, "h": 3.4, "d": 12.0 }
	house(g, { "name": "OFFICINA", "cost": 2000, "H": 3.0, "ext": CM.brick, "int": CM.wallGrey, "floor": CM.floorGarage, "roof": [g.h, CM.brick], "lights": [[-32, 33]],
		"ops": [["E", 3, 3.6, "door"], ["E", -3, 3.6, "door"], ["N", 3, 2.6, "door"]] })
	car(-31.5, 30, 1, CM.paints[1])
	add_box(-37.1, 35, 1.1, 0.95, 5, CM.rack); put(Gfx.box(1.2, 0.07, 5.1), CM.wood, -37.1, 0.98, 35)
	put(Gfx.box(0.06, 1.2, 4.4), mats.trim, -37.66, 1.9, 35)
	for i in 9:
		put(Gfx.box(0.04, G.rnd(0.25, 0.6), 0.07), mats.pillar if i % 3 else CM.awnR, -37.6, 1.9 + G.rnd(-0.2, 0.2), 33.1 + i * 0.47)
	put(Gfx.box(0.4, 0.3, 0.5), CM.awnR, -37.1, 1.17, 33.4); put(Gfx.box(0.3, 0.24, 0.3), mats.pillar, -37.2, 1.14, 36.6)
	shelf(-31.5, 38.3, 6, true, 2.1, [-1])
	for z in [34.7, 37.3]:
		add_box(-33.5, z, 0.3, 2.5, 0.3, CM.awnY); put(Gfx.box(4.2, 0.12, 0.5), CM.awnY, -33.5, 0.16, z + (0.75 if z < 36 else -0.75))
	for p in [[-36.9, 28.2], [-27, 33]]:
		solid(Gfx.cyl(0.42, 0.42, 1.1, 18), CM.tire if p[0] < -30 else mats.barrels[0], Transform3D(Basis(), Vector3(p[0], 0.55, p[1])))
	for s in [-1, 1]:
		put(Gfx.box(12.3, 0.4, 0.3), CM.cornice, g.x, 3.5, g.z + s * 6); put(Gfx.box(0.3, 0.4, 12.3), CM.cornice, g.x + s * 6, 3.5, g.z)
	face(g, "E", Gfx.box(2.2, 0.38, 0.1), mats.trim, 0, 3.2, 0.04)
	sign_face(g, "E", "OFFICINA", "#ffb36b", 0, 3.2, 0.1, 2.0, 0.34)
	face(g, "N", Gfx.box(0.9, 0.6, 0.4), CM.shutter, -2, 2.4, 0.2)
	for p in [[-24.9, 26.8], [-24.2, 27.4], [-24.9, 39]]:
		solid(Gfx.cyl(0.4, 0.4, 0.9, 16), CM.tire, Transform3D(Basis(), Vector3(p[0], 0.45, p[1])))
	add_box(-28.5, 25.6, 1.2, 1.2, 1.2, mats.crate)
	add_box(-9.6, 10.3, 1.6, 2.4, 1.6, CM.canopy)
	put(Gfx.box(2, 0.1, 2), mats.trim, -9.6, 2.45, 10.3); put(Gfx.plane(1, 0.8), CM.carGlass, -9.6, 1.6, 9.49, PI)
	put(Gfx.box(3.6, 0.1, 0.1), CM.white, -12.4, 1.05, 9.3); put(Gfx.box(0.2, 1.05, 0.2), CM.awnR, -10.55, 0.52, 9.3)
	lamp(-22.5, 18, 0, 1); lamp(-22.5, 18, 0, -1); lamp(-9, 27, -1, 0)
	shop(ring.W3, "E", 0, 8, "FERRAMENTA", null, "#ffd45a")
	tree(-9.2, 20, 0.9); tree(-9.2, 37.5, 0.9)

	# ---- south-east: petrol station with its canopy, pumps and a small market
	add_box(22, 20, 14, 0.5, 9, CM.canopy, 4.8)
	for s in [-1, 1]:
		tube(22, 5.05, 20 + s * 4.53, 13.4, "x", mats.neon, 0.045); tube(22 + s * 7.03, 5.05, 20, 8.4, "z", mats.neon, 0.045)
	for x in [16.5, 27.5]:
		for z in [17, 23]:
			add_box(x, z, 0.5, 4.8, 0.5, CM.canopy)
			put(Gfx.plane(1.4, 0.5), deco_mats.lamp, x + (2.8 if x < 22 else -2.8), 4.79, z, 0, Basis(Vector3.RIGHT, PI2))
	for z in [17, 23]:
		put(Gfx.box(4.4, 0.18, 1.2), CM.curb, 22, 0.13, z)
		for x in [21, 23]:
			add_box(x, z, 0.8, 1.6, 0.5, CM.pump, 0.2)
			put(Gfx.box(0.84, 0.22, 0.54), CM.canopy, x, 1.9, z)
			for s in [-1, 1]:
				put(Gfx.plane(0.5, 0.34), CM.carGlass, x, 1.45, z + s * 0.26, 0.0 if s > 0 else PI)
	var mk := { "x": 29.0, "z": 35.5, "w": 14.0, "h": 3.6, "d": 7.0 }
	house(mk, { "name": "MARKET 24H", "cost": 2500, "H": 3.0, "ext": CM.canopy, "int": CM.tileW, "floor": CM.floorShop, "roof": [mk.h, CM.canopy], "lights": [[29, 35.5]],
		"ops": [["N", 0, 2.6, "door"], ["N", 4, 2.6, "win"], ["N", -4, 2.6, "win"], ["E", -0.5, 2.6, "door"]] })
	fridge(27.5, 38.32, 10, "N"); shelf(25.2, 35.4, 3.6, true); shelf(32, 35.4, 3, true); shelf(22.7, 35.2, 4.4, false, 2.1, [1])
	counter(34.9, 33.5, 1, 2)
	for s in [-1, 1]:
		put(Gfx.box(14.3, 0.4, 0.3), mats.trim, mk.x, 3.7, mk.z + s * 3.5); put(Gfx.box(0.3, 0.4, 7.3), mats.trim, mk.x + s * 7, 3.7, mk.z)
	front(mk, "N", 0, 11, "MARKET 24H", null, "#7fd0ff")
	face(mk, "W", Gfx.box(0.9, 0.6, 0.4), CM.shutter, 0, 2.3, 0.2)
	# price totem
	add_box(10.5, 10.5, 0.5, 7.2, 0.5, mats.trim)
	put(Gfx.box(2.4, 3, 0.36), mats.trim, 10.5, 5.6, 10.5)
	for s in [-1, 1]:
		var ry := 0.0 if s > 0 else PI
		add_sign("CARBURANTI", "#ffb36b", Transform3D(Basis(Vector3.UP, ry), Vector3(10.5, 6.6, 10.5 + s * 0.19)), 2.2, 0.55)
		add_sign("SELF 1.839", "#8dffb0", Transform3D(Basis(Vector3.UP, ry), Vector3(10.5, 5.85, 10.5 + s * 0.19)), 2.2, 0.55)
		add_sign("DIESEL 1.729", "#ffe9a8", Transform3D(Basis(Vector3.UP, ry), Vector3(10.5, 5.1, 10.5 + s * 0.19)), 2.2, 0.55)
	car(22, 14.3, 1, CM.paints[0]); car(33.5, 23, 0, CM.paints[3])
	dumpster(38.5, 28, 1)
	add_box(37.6, 12, 0.6, 1.4, 0.5, CM.awnB, 0.04)
	for p in [[12.5, 38.6], [13.3, 38.2]]:
		solid(Gfx.cyl(0.42, 0.42, 1.15, 18), mats.barrels[1], Transform3D(Basis(), Vector3(p[0], 0.615, p[1])))
	lamp(38.5, 20, -1, 0); tree(9.2, 36, 0.9)

	# ---- classic mode: jump pads up to the low roofs
	jump_pad(Vector3(-22, 0, 33), Vector3(-30, 3.4, 33), 0.9)
	jump_pad(Vector3(17, 0.04, 35.5), Vector3(25, 3.6, 35.5), 0.9)
	jump_pad(Vector3(23.5, 3.6, 33.4), Vector3(22, 5.3, 21), 1.1)
	jump_pad(Vector3(-22.5, 0.07, -12), Vector3(-16.5, 9.6, -27), 1.5)
	jump_pad(Vector3(-2, 0, -13), Vector3(2.6, 3, -20), 0.85)
	jump_pad(Vector3(29.5, 0.07, -12), Vector3(35.5, 3.2, -12), 0.95)

# ------------------------------------------------------------ city helpers
# `base` lifts the facade off the ground for buildings with a hollow ground floor
func bld(x: float, z: float, w: float, h: float, d: float, m: Material, base := 0.0) -> Dictionary:
	solid(Gfx.facade_box(w, h - base, d), m, Transform3D(Basis(), Vector3(x, (h + base) / 2.0, z)))
	for s in [-1, 1]:
		put(Gfx.box(w + 0.3, 0.5, 0.3), CM.cornice, x, h + 0.1, z + s * d / 2.0)
		put(Gfx.box(0.3, 0.5, d + 0.3), CM.cornice, x + s * w / 2.0, h + 0.1, z)
	put(Gfx.box(1.4, 0.9, 1), CM.shutter, x + G.rnd(-w / 4, w / 4), h + 0.45, z + G.rnd(-d / 4, d / 4))
	put(Gfx.cyl(0.03, 0.03, 2.6, 6), mats.trim, x + G.rnd(-w / 3, w / 3), h + 1.3, z + G.rnd(-d / 3, d / 3))
	return { "x": x, "z": z, "w": w, "h": h, "d": d }

func _face_xf(b: Dictionary, side: String, a: float, y: float, out: float) -> Array:
	match side:
		"S": return [Vector3(b.x + a, y, b.z + b.d / 2.0 + out), 0.0]
		"N": return [Vector3(b.x - a, y, b.z - b.d / 2.0 - out), PI]
		"E": return [Vector3(b.x + b.w / 2.0 + out, y, b.z - a), PI2]
	return [Vector3(b.x - b.w / 2.0 - out, y, b.z + a), -PI2]

# place geometry on a wall: local +z points away from the wall, `a` runs along it
func face(b: Dictionary, side: String, mesh: Mesh, m: Material, a: float, y: float, out := 0.0, pre := Basis()) -> void:
	var f := _face_xf(b, side, a, y, out)
	put(mesh, m, f[0].x, f[0].y, f[0].z, f[1], pre)

func sign_face(b: Dictionary, side: String, text: String, color: String, a: float, y: float, out: float, w: float, h: float) -> void:
	var f := _face_xf(b, side, a, y, out)
	add_sign(text, color, Transform3D(Basis(Vector3.UP, f[1]), f[0]), w, h)

func face_len(b: Dictionary, side: String) -> float:
	return b.w if side == "S" or side == "N" else b.d

# awning and glowing sign over a shop front
func front(b: Dictionary, side: String, a: float, length: float, text: String, awn: Variant, color: String) -> void:
	if awn:
		face(b, side, Gfx.box(length + 0.2, 0.06, 1.5), awn, a, 3.05, 0.8, Basis(Vector3.RIGHT, 0.32))
	if text != "":
		face(b, side, Gfx.box(4, 1, 0.1), mats.trim, a, 3.72, 0.05)
		sign_face(b, side, text, color, a, 3.72, 0.11, 3.7, 0.92)

func shop(b: Dictionary, side: String, a: float, length: float, text: String, awn: Variant, color: String) -> void:
	face(b, side, Gfx.box(length + 0.3, 3.1, 0.12), mats.trim, a, 1.55, 0.02)
	face(b, side, Gfx.plane(length - 0.3, 2.3), city.glass, a, 1.6, 0.09)
	face(b, side, Gfx.box(length + 0.3, 0.4, 0.2), CM.plinth, a, 0.2, 0.06)
	var n := maxi(1, roundi(length / 2.6))
	for k in n + 1:
		face(b, side, Gfx.box(0.12, 2.4, 0.16), mats.trim, a - length / 2.0 + k * length / n, 1.6, 0.08)
	face(b, side, Gfx.box(1.1, 2.3, 0.1), CM.door, a + length / 2.0 - 0.85, 1.5, 0.12)
	front(b, side, a, length, text, awn, color)

func balcony(b: Dictionary, side: String, a: float, fl: int) -> void:
	var y := fl * 3.2 + 0.55
	face(b, side, Gfx.box(2.4, 0.14, 0.9), CM.cornice, a, y, 0.45)
	face(b, side, Gfx.box(2.4, 0.05, 0.05), mats.trim, a, y + 0.95, 0.87)
	var kk := -1.15
	while kk <= 1.16:
		face(b, side, Gfx.box(0.03, 0.9, 0.03), mats.trim, a + kk, y + 0.5, 0.87)
		kk += 0.23
	for s in [-1, 1]:
		face(b, side, Gfx.box(0.05, 0.05, 0.9), mats.trim, a + s * 1.18, y + 0.95, 0.45)

# balconies on a third of the windows, a drainpipe at one end
func dress(b: Dictionary, side: String, from := 2) -> void:
	var length := face_len(b, side)
	var nb := maxi(1, roundi(length / 3.2))
	var nf := roundi(b.h / 3.2)
	for f in range(from, nf):
		for i in nb:
			if (i + f * 2) % 3 == 0:
				balcony(b, side, -length / 2.0 + (i + 0.5) * length / nb, f)
	face(b, side, Gfx.cyl(0.06, 0.06, b.h, 8), mats.pillar, length / 2.0 - 0.25, b.h / 2.0, 0.08)

# quarter-turn helper: local (lx, lz) -> world; boxes swap their footprint on odd turns
func _turned(x: float, z: float, rot: int) -> Dictionary:
	var R := -rot * PI2
	return { "x": x, "z": z, "c": roundf(cos(R)), "s": roundf(sin(R)), "odd": rot % 2 != 0, "R": R }

func _tw(T: Dictionary, lx: float, lz: float) -> Vector2:
	return Vector2(T.x + lx * T.c + lz * T.s, T.z - lx * T.s + lz * T.c)

func _tbox(T: Dictionary, lx: float, lz: float, w: float, h: float, d: float, m: Material, y: float) -> void:
	var p := _tw(T, lx, lz)
	add_box(p.x, p.y, d if T.odd else w, h, w if T.odd else d, m, y)

func _tput(T: Dictionary, mesh: Mesh, m: Material, lx: float, y: float, lz: float, pre := Basis()) -> void:
	var p := _tw(T, lx, lz)
	put(mesh, m, p.x, y, p.y, T.R, pre)

# vehicles: rot 0 = nose toward -z, each step is a quarter turn
func car(x: float, z: float, rot: int, paint: Material, kind := "car") -> void:
	var T := _turned(x, z, rot)
	var S: Array = { "car": [1.8, 4.3, 0.33, 1.35], "taxi": [1.8, 4.3, 0.33, 1.35], "van": [1.95, 5.0, 0.36, 1.6], "bus": [2.6, 10.5, 0.5, 3.4] }[kind]
	var w: float = S[0]
	var ln: float = S[1]
	var wr: float = S[2]
	var wz: float = S[3]
	if kind == "bus":
		_tbox(T, 0, 0, w, 2.65, ln, paint, 0.35)
		_tput(T, Gfx.box(w + 0.04, 0.95, ln - 1), CM.carGlass, 0, 2.15, 0)
		_tput(T, Gfx.box(w - 0.3, 1.1, 0.06), CM.carGlass, 0, 2.05, -ln / 2.0 - 0.01)
		var p := _tw(T, 0, -ln / 2.0 - 0.02)
		add_sign("64 CENTRO", "#ffb347", Transform3D(Basis(Vector3.UP, T.R + PI), Vector3(p.x, 2.78, p.y)), 1.6, 0.3)
	elif kind == "van":
		_tbox(T, 0, 0, w, 1.8, ln, paint, 0.35)
		_tput(T, Gfx.box(w - 0.2, 0.7, 0.06), CM.carGlass, 0, 1.65, -ln / 2.0 - 0.01)
		for s in [-1, 1]:
			_tput(T, Gfx.box(0.06, 0.6, 1), CM.carGlass, s * (w / 2.0 + 0.005), 1.65, -ln / 2.0 + 0.9)
	else:
		_tbox(T, 0, 0, w, 0.62, ln, paint, 0.3)
		_tbox(T, 0, 0.25, w - 0.18, 0.55, 2.3, paint, 0.92)
		for s in [-1, 1]:
			_tput(T, Gfx.box(w - 0.5, 0.36, 0.05), CM.carGlass, 0, 1.2, 0.25 + s * 1.14)
			_tput(T, Gfx.box(0.05, 0.34, 1.75), CM.carGlass, s * (w / 2.0 - 0.08), 1.2, 0.25)
		if kind == "taxi":
			_tput(T, Gfx.box(0.5, 0.17, 0.22), CM.amber, 0, 1.6, 0.1)
	var yb := 0.72 if kind == "car" or kind == "taxi" else 0.9
	for s in [-1, 1]:
		for lz in [-wz, wz]:
			_tput(T, Gfx.cyl(wr, wr, 0.24, 14), CM.tire, s * (w / 2.0 - 0.08), wr, lz, Basis(Vector3.BACK, PI2))
			_tput(T, Gfx.cyl(wr * 0.55, wr * 0.55, 0.26, 10), CM.hub, s * (w / 2.0 - 0.08), wr, lz, Basis(Vector3.BACK, PI2))
		_tput(T, Gfx.box(0.36, 0.14, 0.06), CM.head, s * (w / 2.0 - 0.3), yb, -ln / 2.0 - 0.01)
		_tput(T, Gfx.box(0.34, 0.12, 0.06), CM.tail, s * (w / 2.0 - 0.3), yb, ln / 2.0 + 0.01)
	for s in [-1, 1]:
		_tput(T, Gfx.box(w + 0.04, 0.2, 0.16), mats.trim, 0, 0.45, s * (ln / 2.0 - 0.04))

func tree(x: float, z: float, s := 1.0) -> void:
	add_box(x, z, 1.5, 0.5, 1.5, mats.concrete)
	put(Gfx.box(1.2, 0.06, 1.2), CM.soil, x, 0.5, z)
	solid(Gfx.cyl(0.14 * s, 0.2 * s, 3.2 * s, 8), CM.trunk, Transform3D(Basis(), Vector3(x, 0.5 + 1.6 * s, z)))
	for l in [[0, 0, 0, 1.5], [0.8, -0.3, 0.3, 1.1], [-0.7, -0.2, -0.4, 1.2], [0.1, 0.7, -0.2, 1.1], [-0.2, -0.4, 0.8, 1.0]]:
		put(Gfx.sphere(l[3] * s, 8, 5), CM.leaf, x + l[0] * s, 0.5 + 3.7 * s + l[1] * s, z + l[2] * s, randf() * 6)

# street lamp with its arm reaching toward (ax, az); the ground pool only shows at night
func lamp(x: float, z: float, ax: float, az: float) -> void:
	var ry := atan2(ax, az)
	put(Gfx.cyl(0.07, 0.1, 6, 8), mats.pillar, x, 3, z)
	put(Gfx.cyl(0.16, 0.2, 0.5, 8), mats.trim, x, 0.25, z)
	put(Gfx.box(0.08, 0.08, 1.6), mats.pillar, x + ax * 0.8, 5.95, z + az * 0.8, ry)
	put(Gfx.box(0.34, 0.12, 0.7), mats.trim, x + ax * 1.5, 5.9, z + az * 1.5, ry)
	put(Gfx.plane(0.26, 0.56), deco_mats.lamp, x + ax * 1.5, 5.83, z + az * 1.5, ry, Basis(Vector3.RIGHT, PI2))
	put(flat_quad(10, 10), city.pool, x + ax * 1.5, 0.1, z + az * 1.5, 0, Basis(), 0)

func bench(x: float, z: float, rot: int) -> void:
	var T := _turned(x, z, rot)
	_tbox(T, 0, 0, 1.9, 0.45, 0.5, CM.wood, 0)
	_tput(T, Gfx.box(1.9, 0.5, 0.07), CM.wood, 0, 0.75, 0.24)

func dumpster(x: float, z: float, rot: int) -> void:
	var T := _turned(x, z, rot)
	_tbox(T, 0, 0, 2, 1.15, 1.1, CM.dump, 0.1)
	_tput(T, Gfx.box(2.06, 0.08, 1.16), mats.trim, 0, 1.29, 0)

func table(x: float, z: float, awn: Material) -> void:
	solid(Gfx.cyl(0.5, 0.42, 0.76, 12), CM.stone, Transform3D(Basis(), Vector3(x, 0.45, z)))
	for dx in [0.95, -0.95]:
		put(Gfx.box(0.42, 0.05, 0.42), mats.trim, x + dx, 0.52, z)
		put(Gfx.box(0.42, 0.45, 0.05), mats.trim, x + dx * 1.2, 0.76, z, PI2)
		put(Gfx.cyl(0.03, 0.03, 0.45, 6), mats.trim, x + dx, 0.29, z)
	put(Gfx.cyl(0.03, 0.03, 2.5, 6), mats.trim, x, 1.3, z)
	put(Gfx.cyl(0.0, 1.5, 0.5, 8), awn, x, 2.7, z)

func scooter(x: float, z: float, ry: float, paint: Material) -> void:
	var pt := func(mesh: Mesh, m: Material, lx: float, y: float, lz: float, pre: Basis) -> void:
		put(mesh, m, x + lx * cos(ry) + lz * sin(ry), y, z - lx * sin(ry) + lz * cos(ry), ry, pre)
	pt.call(Gfx.box(0.36, 0.5, 0.9), paint, 0, 0.55, 0.2, Basis()); pt.call(Gfx.box(0.3, 0.1, 0.7), mats.trim, 0, 0.84, 0.3, Basis())
	pt.call(Gfx.box(0.34, 0.7, 0.12), paint, 0, 0.7, -0.45, Basis()); pt.call(Gfx.box(0.6, 0.04, 0.04), mats.trim, 0, 1.08, -0.5, Basis())
	for lz in [-0.6, 0.65]:
		pt.call(Gfx.cyl(0.22, 0.22, 0.12, 12), CM.tire, 0, 0.22, lz, Basis(Vector3.BACK, PI2))

# shelving along x or z: a steel core with rows of stock on the open sides
func shelf(x: float, z: float, length: float, along_x: bool, h := 1.7, sides := [-1, 1]) -> void:
	var stock: Array = CM.paints + [CM.cornice, CM.awnY, CM.awnR, CM.awnB]
	var P := func(t: float, o: float) -> Vector2: return Vector2(x + t, z + o) if along_x else Vector2(x + o, z + t)
	var Gm := func(l: float, hh: float, dd: float) -> BoxMesh: return Gfx.box(l if along_x else dd, hh, dd if along_x else l)
	add_box(x, z, length if along_x else 0.3, h, 0.3 if along_x else length, CM.rack)
	var lo := 0.39 if sides.has(-1) else 0.17
	var hi := 0.39 if sides.has(1) else 0.17
	B.boxes.append(AABB(Vector3(x - (length / 2.0 if along_x else lo), 0, z - (lo if along_x else length / 2.0)),
		Vector3(length if along_x else lo + hi, h, lo + hi if along_x else length)))
	put(Gm.call(length + 0.04, 0.05, 0.8), CM.rack, x, h + 0.02, z)
	for s in sides:
		var y := 0.3
		while y < h - 0.3:
			var bp: Vector2 = P.call(0, s * 0.27)
			put(Gm.call(length, 0.03, 0.24), CM.cornice, bp.x, y, bp.y)
			var t := -length / 2.0 + 0.08
			while t < length / 2.0 - 0.3:
				var w := G.rnd(0.14, 0.32)
				var hh := G.rnd(0.16, 0.34)
				var pp: Vector2 = P.call(t + w / 2.0, s * 0.27)
				if randf() < 0.85:
					put(Gm.call(w, hh, 0.18), stock[randi() % stock.size()], pp.x, y + 0.015 + hh / 2.0, pp.y)
				t += w + G.rnd(0.02, 0.1)
			y += 0.48

# glass-fronted fridge against a wall, `side` is the way the doors look
func fridge(x: float, z: float, length: float, side: String) -> void:
	var ns := side == "N" or side == "S"
	var k := { "x": x, "z": z, "w": length if ns else 0.75, "d": 0.75 if ns else length }
	add_box(x, z, k.w, 2.1, k.d, mats.trim)
	face(k, side, Gfx.plane(length - 0.2, 1.6), city.glass, 0, 1.15, 0.012)
	var n := maxi(1, roundi(length / 1.1))
	var t := -length / 2.0 + 0.1
	while t <= length / 2.0 - 0.09:
		face(k, side, Gfx.box(0.06, 1.6, 0.05), CM.rack, t, 1.15, 0.03)
		t += (length - 0.2) / n
	face(k, side, Gfx.box(length - 0.2, 0.05, 0.04), deco_mats.lamp, 0, 2, 0.02)

func counter(x: float, z: float, w: float, d: float, top: Material = null) -> void:
	add_box(x, z, w, 1, d, CM.wood)
	put(Gfx.box(w + 0.12, 0.06, d + 0.12), top if top else CM.stone, x, 1.03, z)
	var oz := d / 2.0 - 0.5 if d > w else 0.0
	put(Gfx.box(0.42, 0.26, 0.36), mats.trim, x, 1.19, z + oz)
	put(Gfx.box(0.3, 0.2, 0.02), deco_mats.screen, x, 1.42, z + oz)

# enterable building: a hollow ground floor shut behind roller shutters until you pay for it.
# Doors let everyone through; windows have a sill that only zombies (and a jumping player) get over.
const SIDE_YAW := { "S": 0.0, "N": PI, "E": PI2, "W": -PI2 }

func house(b: Dictionary, o: Dictionary) -> Dictionary:
	var H: float = o.get("H", 3.2)
	var T := 0.3
	var TOP := 3.0
	var x0: float = b.x - b.w / 2.0
	var x1: float = b.x + b.w / 2.0
	var z0: float = b.z - b.d / 2.0
	var z1: float = b.z + b.d / 2.0
	var h := { "name": o.name, "cost": o.cost, "open": false, "t": 0.0, "shutters": [], "doors": [], "lights": [], "fill": AABB(Vector3(x0, 0, z0), Vector3(b.w, TOP, b.d)) }
	var at := func(side: String, a: float, out: float) -> Vector2:
		match side:
			"S": return Vector2(b.x + a, z1 + out)
			"N": return Vector2(b.x - a, z0 - out)
			"E": return Vector2(x1 + out, b.z - a)
		return Vector2(x0 - out, b.z + a)
	var piece := func(side: String, a0: float, a1: float, y0: float, y1: float) -> void:
		if a1 - a0 < 0.02 or y1 - y0 < 0.02:
			return
		var ns := side == "S" or side == "N"
		var ln := a1 - a0
		var p: Vector2 = at.call(side, (a0 + a1) / 2.0, -T / 2.0)
		solid(Gfx.box(ln if ns else T, y1 - y0, T if ns else ln), o.ext, Transform3D(Basis(), Vector3(p.x, (y0 + y1) / 2.0, p.y)))
		# interior face
		var pi: Vector2 = at.call(side, (a0 + a1) / 2.0, -T - 0.005)
		put(Gfx.plane(ln, y1 - y0), o.int, pi.x, (y0 + y1) / 2.0, pi.y, SIDE_YAW[side] + PI, Basis(), 0)
	for side in "SNEW":
		var L := face_len(b, side)
		var end := L / 2.0 - (T if side == "E" or side == "W" else 0.0)
		var a := -end
		var ops: Array = o.ops.filter(func(op): return op[0] == side)
		ops.sort_custom(func(p, q): return p[1] < q[1])
		for op in ops:
			var c: float = op[1]
			var w: float = op[2]
			var sill := 1.0 if op[3] == "win" else 0.0
			piece.call(side, a, c - w / 2.0, 0, H); piece.call(side, c - w / 2.0, c + w / 2.0, TOP, H); piece.call(side, c - w / 2.0, c + w / 2.0, 0, sill)
			if sill > 0:
				face(b, side, Gfx.box(w + 0.2, 0.08, T + 0.24), CM.stone, c, sill + 0.04, -T / 2.0)
			for s in [-1, 1]:
				face(b, side, Gfx.box(0.1, TOP - sill, T + 0.08), mats.trim, c + s * (w / 2.0 - 0.05), (TOP + sill) / 2.0, -T / 2.0)
			face(b, side, Gfx.box(w, 0.1, T + 0.08), mats.trim, c, TOP - 0.05, -T / 2.0)
			face(b, side, Gfx.box(w + 0.1, 0.24, 0.2), CM.shutter, c, TOP + 0.1, 0.1)
			# roller shutter hanging from the lintel: it rolls up when the building is bought
			var sw := w - 0.2
			var sh := TOP - sill - 0.1
			var sp: Vector2 = at.call(side, c, -0.1)
			var pivot := Node3D.new()
			pivot.position = Vector3(sp.x, TOP - 0.1, sp.y)
			pivot.rotation.y = SIDE_YAW[side]
			B.root.add_child(pivot)
			Gfx.mesh_node(Gfx.box(sw, sh, 0.06), CM.roller, Vector3(0, -sh / 2.0, 0), Vector3.ZERO, pivot)
			var ns2 := side == "S" or side == "N"
			var ssz := Vector3(sw if ns2 else 0.1, sh, 0.1 if ns2 else sw)
			var shape := ray_box(AABB(Vector3(sp.x, TOP - 0.1 - sh / 2.0, sp.y) - ssz / 2.0, ssz))
			if sill == 0:
				var lbl := Label3D.new()
				lbl.text = "APRI · %d" % o.cost
				lbl.font = font; lbl.font_size = 48; lbl.pixel_size = 0.006
				lbl.modulate = Color(1.4, 0.45, 0.38)
				lbl.position = Vector3(0, -1.15, 0.05)
				pivot.add_child(lbl)
				h.doors.append(at.call(side, c, 0.5))
			h.shutters.append({ "node": pivot, "shape": shape })
			a = c + w / 2.0
		piece.call(side, a, end, 0, H)
	var ft := flat_quad(b.w - 2 * T, b.d - 2 * T)
	put(ft, o.floor, b.x, 0.085, b.z, 0, Basis(), 0)
	if o.has("roof"):
		var top: float = o.roof[0]
		solid(Gfx.box(b.w, top - H, b.d), o.roof[1], Transform3D(Basis(), Vector3(b.x, (top + H) / 2.0, b.z)))
		put(flat_quad(b.w - 2 * T, b.d - 2 * T), CM.ceil, b.x, H - 0.01, b.z, 0, Basis(Vector3.RIGHT, PI), 0)
	else:
		put(flat_quad(b.w - 2 * T, b.d - 2 * T), CM.ceil, b.x, H - 0.01, b.z, 0, Basis(Vector3.RIGHT, PI), 0)
		for s in [-1, 1]:
			put(Gfx.box(b.w + 0.16, 0.22, 0.14), CM.cornice, b.x, H, b.z + s * (b.d / 2.0 + 0.02))
			put(Gfx.box(0.14, 0.22, b.d + 0.16), CM.cornice, b.x + s * (b.w / 2.0 + 0.02), H, b.z)
	for lp in o.lights:
		put(Gfx.box(1.5, 0.06, 0.34), mats.trim, lp[0], H - 0.04, lp[1])
		put(Gfx.plane(1.4, 0.24), deco_mats.lamp, lp[0], H - 0.075, lp[1], 0, Basis(Vector3.RIGHT, PI2))
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.9, 0.77)
		l.light_energy = 0
		l.omni_range = 14
		l.omni_attenuation = 1.6
		l.position = Vector3(lp[0], H - 0.5, lp[1])
		B.root.add_child(l)
		h.lights.append(l)
	B.boxes.append(h.fill)
	B.houses.append(h)
	return h

# ------------------------------------------------------------ shop stations, placed on every map
func _sadd(xf: Transform3D, mesh: Mesh, m: Material, p: Vector3, pre := Basis()) -> void:
	B.batch.add(mesh, m, xf * Transform3D(pre, p), _shadow_for(m))

func _station(kind: String, x: float, z: float, ry: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, ry), Vector3(x, 0, z))
	var body_bb: AABB
	if kind == "bench":
		var olive := Gfx.mat(0x4a5540, 0.6, 0.2)
		var bm := Gfx.box(2.4, 0.9, 0.9)
		_sadd(xf, bm, mats.cover, Vector3(0, 0.45, 0))
		body_bb = xf * Transform3D(Basis(), Vector3(0, 0.45, 0)) * bm.get_aabb()
		_sadd(xf, Gfx.box(2.5, 0.08, 1), mats.crate, Vector3(0, 0.94, 0))
		for dx in [-0.6, 0.6]:
			_sadd(xf, Gfx.box(1.05, 0.3, 0.03), mats.trim, Vector3(dx, 0.6, 0.455))
		_sadd(xf, Gfx.box(2.4, 1.4, 0.08), mats.trim, Vector3(0, 1.68, -0.42))
		_sadd(xf, Gfx.box(0.95, 0.09, 0.05), mats.pillar, Vector3(0.35, 1.9, -0.36))
		_sadd(xf, Gfx.box(0.3, 0.16, 0.05), mats.crate, Vector3(0.95, 1.86, -0.36))
		for t in [[-0.95, 1.75, 0.5], [-0.75, 1.79, 0.42]]:
			_sadd(xf, Gfx.box(0.07, t[2], 0.03), mats.pillar, Vector3(t[0], t[1], -0.37))
		_sadd(xf, Gfx.box(0.26, 0.24, 0.32), mats.pillar, Vector3(-0.85, 1.1, 0.1))
		for t in [[0.75, 1.08, 0.12], [0.82, 1.28, 0.1], [0.35, 1.08, 0.2]]:
			_sadd(xf, Gfx.box(0.32, 0.2, 0.22), olive, Vector3(t[0], t[1], t[2]))
		_sadd(xf, Gfx.capsule(0.03, 2.26, 8), mats.neon, Vector3(0, 2.44, -0.37), Basis(Vector3.BACK, PI2))
		_sadd(xf, Gfx.box(2.1, 0.56, 0.06), mats.trim, Vector3(0, 2.78, -0.42))
		add_sign("BANCO ARMI", "#ffb36b", xf * Transform3D(Basis(), Vector3(0, 2.78, -0.385)), 2.0, 0.5)
	else:
		var shell := Gfx.mat(0x3a1f5c, 0.35, 0.6)
		var bm := Gfx.box(1.5, 2.3, 0.9)
		_sadd(xf, bm, shell, Vector3(0, 1.15, 0))
		body_bb = xf * Transform3D(Basis(), Vector3(0, 1.15, 0)) * bm.get_aabb()
		# glowing front with the bottles
		var im := Gfx._img(128, 192, Color.html("#1a0b2c"))
		var i := 0
		for k in G.PERK_ORDER.slice(0, 6):
			var bx := 22 + (i % 3) * 42
			var by := 48 + (i / 3) * 65
			var c := Color.html(G.PERKS[k].css)
			Gfx._rect(im, bx - 8, by, 16, 30, c); Gfx._rect(im, bx - 3, by - 11, 7, 12, c)
			Gfx._rect(im, bx - 8, by + 10, 16, 10, Color(0, 0, 0, 0.45))
			i += 1
		var front_m := Gfx.glow(0xffffff, 1.3)
		front_m.emission_texture = Gfx.tex(im)
		front_m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		_sadd(xf, Gfx.plane(1.2, 1.7), front_m, Vector3(0, 1.35, 0.455))
		_sadd(xf, Gfx.box(1.1, 0.22, 0.06), mats.trim, Vector3(0, 0.3, 0.45))
		for s in [-1, 1]:
			_sadd(xf, Gfx.capsule(0.03, 1.96, 8), mats.neonBlue, Vector3(s * 0.72, 1.2, 0.46))
		_sadd(xf, Gfx.box(1.6, 0.5, 0.5), shell, Vector3(0, 2.55, 0.1))
		add_sign("PERK", "#d9a8ff", xf * Transform3D(Basis(), Vector3(0, 2.55, 0.355)), 1.4, 0.35)
	B.boxes.append(body_bb)
	ray_box(body_bb)
	B[kind] = Vector3(x, 0, z)

# far skyline around both maps, plus drifting dust / embers
func _skyline() -> void:
	var batch := Gfx.Batch.new()
	for i in 70:
		var a := i / 70.0 * TAU + G.rnd(-0.03, 0.03)
		var r := G.rnd(75, 140)
		var w := G.rnd(8, 20)
		var h := G.rnd(12, 60)
		var d := G.rnd(8, 20)
		batch.at(Gfx.box(w, h, d), mats.city, Vector3(cos(a) * r, h / 2.0, sin(a) * r), Vector3(0, -a, 0), false)
		if randf() < 0.55:
			batch.at(Gfx.box(w * 0.85, 0.35, d + 0.1), mats.windows, Vector3(cos(a) * r, h / 2.0 + G.rnd(-h / 4, h / 3), sin(a) * r), Vector3(0, -a, 0), false)
	var root := Node3D.new()
	G.scene_root.add_child(root)
	batch.commit(root)

func _ambient() -> void:
	ambient = GPUParticles3D.new()
	ambient.amount = 520
	ambient.lifetime = 14.0
	ambient.preprocess = 14.0
	ambient.local_coords = false
	ambient.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 6, 22)
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	ambient.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := Gfx.additive(0xfff1dc, 0.4, Gfx.glow_tex())
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	ambient.draw_pass_1 = q
	G.scene_root.add_child(ambient)

func update_ambient() -> void:
	ambient.visible = G.settings.quality != "low"
	ambient.global_position = G.camera.global_position
	if amb_mode == G.mode:
		return
	amb_mode = G.mode
	var z := G.mode == "zombie"
	var pm: ParticleProcessMaterial = ambient.process_material
	pm.gravity = Vector3(0, -0.15, 0) if z else Vector3.ZERO
	pm.initial_velocity_max = 0.9 if z else 0.3
	var q: QuadMesh = ambient.draw_pass_1
	q.size = Vector2(0.075, 0.075) if z else Vector2(0.05, 0.05)
	var m: StandardMaterial3D = q.material
	m.albedo_color = Color(1.6, 0.6, 0.25, 0.85) if z else Color(1, 0.95, 0.86, 0.35)

# ============================================================ arena layer (classic mode only)
func set_arena(on: bool) -> void:
	MAP.layer.deco.visible = on
	if on == arena_on:
		return
	arena_on = on
	for s in MAP.layer.solids:
		s.shape.disabled = not on
		if on:
			colliders.append(s.box)
		else:
			colliders.erase(s.box)

func update_arena(dt: float) -> void:
	if not arena_on:
		return
	for p in MAP.layer.pads:
		p.t = maxf(0.0, p.t - dt)
		p.ring.scale = Vector3.ONE * (1.0 + sin(G.now * 4.0) * 0.04 + p.t * 0.6)
		p.beam.scale.y = 1.0 + p.t * 1.5

func try_jump_pad() -> void:
	var P: Node = G.player
	if not arena_on or not P.on_ground:
		return
	for p in MAP.layer.pads:
		if absf(P.pos.y - p.pos.y) > 0.3 or Vector2(P.pos.x - p.pos.x, P.pos.z - p.pos.z).length() > 0.95:
			continue
		P.vel = p.vel
		P.on_ground = false; P.air_jumps = 1; P.crouch = false
		p.t = 0.5
		G.audio.boing()
		G.fx.particles(p.pos + Vector3(0, 0.3, 0), 0x3affe0, 22, Vector3.UP, 5)
		return

# ============================================================ atmosphere per mode
const ATMOS := {
	"classic": { "fog": 0xc4d3e2, "near": 45.0, "far": 175.0, "top": 0x2a64b0, "bottom": 0x8c98a6, "sun": 0xfff0dd, "sunI": 1.35, "amb": 0.32, "exposure": 0.95, "glow": 1.0,
		"neon": 0xff6a2a, "neonB": 0x3aa8ff, "windows": 0xffc070, "tint": Color(1, 1, 1), "bloom": 0.5, "torch": 0.0 },
	"zombie": { "fog": 0x241c2a, "near": 14.0, "far": 85.0, "top": 0x07060f, "bottom": 0x151016, "sun": 0x9fb4ff, "sunI": 0.35, "amb": 0.14, "exposure": 1.05, "glow": 0.35,
		"neon": 0xff2a1a, "neonB": 0x7a3aff, "windows": 0xff5030, "tint": Color(0.92, 1.0, 0.95), "bloom": 0.75, "torch": 1.0 },
}

func apply_atmosphere(m: String) -> void:
	var a: Dictionary = ATMOS[m]
	var M: Node = G.main
	set_arena(m == "classic")
	var env: Environment = M.env
	env.fog_light_color = G.col(a.fog)
	env.fog_depth_begin = a.near
	env.fog_depth_end = a.far
	var sky: ProceduralSkyMaterial = M.sky_mat
	sky.sky_top_color = G.col(a.top)
	sky.sky_horizon_color = G.col(a.fog)
	sky.ground_horizon_color = G.col(a.fog)
	sky.ground_bottom_color = G.col(a.bottom)
	sky.sun_angle_max = 30.0 * a.glow
	M.sun.light_color = G.col(a.sun)
	M.sun.light_energy = a.sunI
	env.ambient_light_energy = a.amb
	env.tonemap_exposure = a.exposure * G.settings.bright
	var L: float = G.settings.lights
	var night := m == "zombie"
	mats.neon.emission = G.col(a.neon); mats.neonBlue.emission = G.col(a.neonB); mats.windows.emission = G.col(a.windows)
	mats.neon.emission_energy_multiplier = 4.5 * L; mats.neonBlue.emission_energy_multiplier = 4.0 * L; mats.windows.emission_energy_multiplier = 1.6 * L
	mats.city.emission_energy_multiplier = (1.3 if night else 0.35) * L
	deco_mats.screen.emission = G.col(0xff8080 if night else 0xffffff)
	deco_mats.screen.emission_energy_multiplier = (0.8 if night else 1.1) * maxf(0.3, L)
	deco_mats.lamp.emission_energy_multiplier = 0.5 + 1.8 * L
	deco_mats.lens.emission_energy_multiplier = 0.6 + 1.8 * L
	for b in beams:
		(b.material_override as ShaderMaterial).set_shader_parameter("k", (0.28 if night else 0.1) * L)
	for f in city.facades:
		f.emission_energy_multiplier = (1.15 if night else 0.06) * L
	var sk := (2.2 if night else 0.9) * maxf(0.3, L)
	for s in city.signs:
		var c: Color = s.modulate
		var base := c / maxf(0.001, maxf(c.r, maxf(c.g, c.b)))
		s.modulate = Color(base.r * sk, base.g * sk, base.b * sk)
	city.glass.emission_energy_multiplier = (1.3 if night else 0.22) * L
	city.pool.albedo_color.a = 0.5 * minf(1.0, L) if night else 0.0
	city.lightI = (2.2 if night else 3.0) * (0.4 + 0.6 * minf(1.0, L))
	house_lights()
	env.glow_intensity = a.bloom * L * 0.8
	M.grade_tint = a.tint
	M.torch.light_energy = a.torch * 6.0 * (0.4 + 0.6 * minf(1.0, L))
	M.torch.visible = a.torch > 0
	if G.items:
		G.items.atmosphere_changed()

# ============================================================ collision helpers
func collide_circle(pos: Vector3, r: float, feet_y: float, height: float) -> Vector3:
	for b in colliders:
		var bmax: Vector3 = b.end
		var bmin: Vector3 = b.position
		if bmax.y <= feet_y + 0.36 or bmin.y >= feet_y + height:
			continue
		var cx := clampf(pos.x, bmin.x, bmax.x)
		var cz := clampf(pos.z, bmin.z, bmax.z)
		var dx := pos.x - cx
		var dz := pos.z - cz
		var d2 := dx * dx + dz * dz
		if d2 >= r * r:
			continue
		if d2 > 1e-8:
			var d := sqrt(d2)
			pos.x += dx / d * (r - d); pos.z += dz / d * (r - d)
		else:
			var opts := [[pos.x - bmin.x + r, -1, 0], [bmax.x - pos.x + r, 1, 0], [pos.z - bmin.z + r, 0, -1], [bmax.z - pos.z + r, 0, 1]]
			opts.sort_custom(func(p, q): return p[0] < q[0])
			pos.x += opts[0][1] * opts[0][0]; pos.z += opts[0][2] * opts[0][0]
	pos.x = clampf(pos.x, -40 + r, 40 - r)
	pos.z = clampf(pos.z, -40 + r, 40 - r)
	return pos

func ground_at(x: float, z: float, feet_y: float, r: float) -> float:
	var g := 0.0
	var e := r * 0.6
	for b in colliders:
		var bmin: Vector3 = b.position
		var bmax: Vector3 = b.end
		if x + e > bmin.x and x - e < bmax.x and z + e > bmin.z and z - e < bmax.z and bmax.y <= feet_y + 0.36:
			g = maxf(g, bmax.y)
	return g

# lowest overhead surface the head would pass through this step (INF = none)
func ceiling_at(x: float, z: float, r: float, h0: float, h1: float) -> float:
	var c := INF
	var e := r * 0.6
	for b in colliders:
		var bmin: Vector3 = b.position
		var bmax: Vector3 = b.end
		if x + e > bmin.x and x - e < bmax.x and z + e > bmin.z and z - e < bmax.z and bmin.y >= h0 - 0.05 and bmin.y < h1:
			c = minf(c, bmin.y)
	return c

# true when something solid crosses the column over (x, z) between the two heights
func column_blocked(x: float, z: float, r: float, y0: float, y1: float) -> bool:
	var e := r * 0.6
	for b in colliders:
		var bmin: Vector3 = b.position
		var bmax: Vector3 = b.end
		if x + e > bmin.x and x - e < bmax.x and z + e > bmin.z and z - e < bmax.z and bmin.y < y1 and bmax.y > y0:
			return true
	return false

# physics ray against the world (mask 1) and optionally enemy hitboxes (mask 2)
func ray(a: Vector3, b: Vector3, enemies := false) -> Dictionary:
	var space := G.scene_root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | (2 if enemies else 0))
	q.collide_with_areas = enemies
	q.hit_back_faces = false
	return space.intersect_ray(q)

func world_clear(a: Vector3, b: Vector3) -> bool:
	if a.distance_squared_to(b) < 1e-8:
		return true
	return ray(a, b).is_empty()

# smoke clouds (from smoke grenades) block sight like walls do
func smoke_blocks(a: Vector3, b: Vector3) -> bool:
	for c in clouds:
		if c.r < 1.0:
			continue
		var ab := b - a
		var t := clampf((c.pos - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
		if (a + ab * t).distance_to(c.pos) < c.r * 0.9:
			return true
	return false

func line_of_sight(a: Vector3, b: Vector3) -> bool:
	return not smoke_blocks(a, b) and world_clear(a, b)

# ============================================================ navigation grid + A*
func build_grid(max_climb: float, boxes: Array) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(GN * GN)
	for j in GN:
		for i in GN:
			var x := i - HALF + 0.5
			var z := j - HALF + 0.5
			var b := 1 if (i == 0 or j == 0 or i == GN - 1 or j == GN - 1) else 0
			if b == 0:
				for c in boxes:
					var cmin: Vector3 = c.position
					var cmax: Vector3 = c.end
					if cmax.y <= max_climb or cmin.y > 2.2:
						continue
					if x > cmin.x - 0.55 and x < cmax.x + 0.55 and z > cmin.z - 0.55 and z < cmax.z + 0.55:
						b = 1
						break
			g[i + j * GN] = b
	return g

func cell_idx(x: float, z: float) -> int:
	return clampi(int(floor(x + HALF)), 0, GN - 1) + clampi(int(floor(z + HALF)), 0, GN - 1) * GN

func blocked_at(x: float, z: float, g: PackedByteArray = PackedByteArray()) -> bool:
	if g.is_empty():
		g = grid
	return g[cell_idx(x, z)] == 1

func nearest_free(idx: int, g: PackedByteArray) -> int:
	if g[idx] == 0:
		return idx
	var i0 := idx % GN
	var j0 := idx / GN
	for r in range(1, 12):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var i := i0 + di
				var j := j0 + dj
				if i < 0 or j < 0 or i >= GN or j >= GN:
					continue
				if g[i + j * GN] == 0:
					return i + j * GN
	return idx

func walk_line(ax: float, az: float, bx: float, bz: float, g: PackedByteArray) -> bool:
	var dx := bx - ax
	var dz := bz - az
	var n := int(ceil(sqrt(dx * dx + dz * dz) / 0.3))
	for s in range(1, n + 1):
		if g[cell_idx(ax + dx * s / n, az + dz * s / n)] == 1:
			return false
	return true

var _gs := PackedFloat32Array()
var _fs := PackedFloat32Array()
var _came := PackedInt32Array()
var _seen := PackedInt32Array()
var _closed := PackedInt32Array()
var _search := 0

func find_path(sx: float, sz: float, tx: float, tz: float, g: PackedByteArray) -> Array:
	if _gs.is_empty():
		_gs.resize(GN * GN); _fs.resize(GN * GN); _came.resize(GN * GN); _seen.resize(GN * GN); _closed.resize(GN * GN)
	var start := nearest_free(cell_idx(sx, sz), g)
	var goal := nearest_free(cell_idx(tx, tz), g)
	if start == goal:
		return []
	_search += 1
	var sid := _search
	var heap: Array[int] = []
	var gi := goal % GN
	var gj := goal / GN
	var h := func(k: int) -> float:
		var ddx := absi(k % GN - gi)
		var ddy := absi(k / GN - gj)
		return ddx + ddy - 0.5858 * mini(ddx, ddy)
	_seen[start] = sid; _gs[start] = 0; _fs[start] = h.call(start); _came[start] = -1
	_heap_push(heap, start)
	var iter := 0
	while heap.size() > 0 and iter < 6000:
		iter += 1
		var cur := _heap_pop(heap)
		if cur == goal:
			break
		if _closed[cur] == sid:
			continue
		_closed[cur] = sid
		var ci := cur % GN
		var cj := cur / GN
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ni := ci + di
				var nj := cj + dj
				if ni < 0 or nj < 0 or ni >= GN or nj >= GN:
					continue
				var nk := ni + nj * GN
				if g[nk] == 1 or _closed[nk] == sid:
					continue
				if di != 0 and dj != 0 and (g[ci + di + cj * GN] == 1 or g[ci + (cj + dj) * GN] == 1):
					continue
				var ng := _gs[cur] + (1.4142 if di != 0 and dj != 0 else 1.0)
				if _seen[nk] != sid or ng < _gs[nk]:
					_seen[nk] = sid; _gs[nk] = ng; _fs[nk] = ng + h.call(nk); _came[nk] = cur
					_heap_push(heap, nk)
	if _seen[goal] != sid:
		return []
	var pts: Array = []
	var k := goal
	while k != start and k != -1:
		pts.append(Vector2(k % GN - HALF + 0.5, k / GN - HALF + 0.5))
		k = _came[k]
	pts.reverse()
	var out: Array = []
	var cx := sx
	var cz := sz
	var i := 0
	while i < pts.size():
		var far := i
		for kk in range(mini(pts.size() - 1, i + 25), i, -1):
			if walk_line(cx, cz, pts[kk].x, pts[kk].y, g):
				far = kk
				break
		out.append(pts[far]); cx = pts[far].x; cz = pts[far].y; i = far + 1
	return out

func _heap_push(heap: Array[int], k: int) -> void:
	heap.append(k)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if _fs[heap[p]] <= _fs[heap[i]]:
			break
		var t := heap[p]; heap[p] = heap[i]; heap[i] = t
		i = p

func _heap_pop(heap: Array[int]) -> int:
	var top := heap[0]
	var last: int = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		var i := 0
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < heap.size() and _fs[heap[l]] < _fs[heap[m]]: m = l
			if r < heap.size() and _fs[heap[r]] < _fs[heap[m]]: m = r
			if m == i:
				break
			var t := heap[m]; heap[m] = heap[i]; heap[i] = t
			i = m
	return top

# ============================================================ map switching and enterable buildings
func set_map(key: String) -> void:
	if not MAP.is_empty():
		set_arena(false)
		MAP.root.visible = false
		MAP.body.collision_layer = 0
	MAP = MAPS.get(key, MAPS.city)
	MAP.root.visible = true
	MAP.layer.deco.visible = false
	MAP.body.collision_layer = 1
	colliders = MAP.boxes.duplicate()
	grid = MAP.grid
	climb_grid = MAP.climbGrid
	map_version += 1

func house_lights() -> void:
	for h in MAPS.city.houses:
		for l in h.lights:
			l.light_energy = city.lightI if h.open else 0.0

# buying a building rolls its shutters up and removes the solid volume that kept everyone out
func set_house(h: Dictionary, open: bool) -> void:
	h.open = open
	h.t = 1.0 if open else 0.0
	if open:
		MAP.boxes.erase(h.fill); colliders.erase(h.fill)
	else:
		if not MAP.boxes.has(h.fill): MAP.boxes.append(h.fill)
		if not colliders.has(h.fill): colliders.append(h.fill)
	for s in h.shutters:
		s.shape.disabled = open
		s.node.visible = true
		s.node.scale.y = 1.0
		for c in s.node.get_children():
			if c is Label3D:
				c.visible = not open
	MAP.grid = build_grid(0.0, MAP.boxes)
	MAP.climbGrid = build_grid(1.3, MAP.boxes)
	grid = MAP.grid; climb_grid = MAP.climbGrid
	house_lights()
	map_version += 1

func update_houses(dt: float) -> void:
	for h in MAP.houses:
		if h.t <= 0.0:
			continue
		h.t -= dt * 1.1
		for s in h.shutters:
			s.node.scale.y = maxf(0.03, h.t)
			s.node.visible = h.t > 0.0
