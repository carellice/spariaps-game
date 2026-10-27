# Spariaps — Nemici: bot, zombie e boss, con le loro animazioni procedurali.
# Le parti fisse di ogni osso sono unite per materiale; le zone colpibili sono Area3D (testa, corpo, arti) sul livello 2.
extends Node

var list: Array = []
var spawn_queue: Array = []
var bot_counter := 0
var TEX := {}
var flash_mat: StandardMaterial3D
var laser_mat: StandardMaterial3D

const BOT_NAMES := ["Alfa", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Romeo", "Sierra", "Tango", "Victor"]
const RIG_MUZZLE := Vector3(0.22, 0.01, 1.03)

func _ready() -> void:
	G.enemies = self

func setup() -> void:
	TEX = {
		"armor": [["#b4412f", "#f2c230"], ["#a3362c", "#e8e8e8"], ["#bf5230", "#f2c230"], ["#96383a", "#e8e8e8"]].map(func(a): return Gfx.armor_tex(a[0], a[1])),
		"boss": Gfx.armor_tex("#3b3f4a", "#ff2a55"),
		"dark": Gfx.armor_tex("#2a2e36", ""),
		"skin": ["#6c775d", "#5f6951", "#77796a"].map(func(c): return Gfx.blotch_tex(c, [], 128, 0.06, "skin")),
		"climber": Gfx.blotch_tex("#5f6674", [], 128, 0.06, "skin"),
		"zboss": Gfx.blotch_tex("#6e3830", [], 128, 0.06, "skin"),
		"shirts": ["#5f4d3d", "#405060", "#6f3e3e", "#4e5e3d", "#606066"].map(func(c): return Gfx.blotch_tex(c, [], 128, 0.04, "cloth")),
		"pants": Gfx.blotch_tex("#3a3f4e", [], 128, 0.04, "cloth"),
	}
	flash_mat = Gfx.additive(Color(1, 0.8, 0.5), 1.0, Gfx.flash_tex(), 2.0)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	laser_mat = Gfx.additive(Color(1, 0.08, 0.05), 0.6, null, 2.5)

func alive() -> int:
	var n := 0
	for e in list:
		if not e.dead:
			n += 1
	return n

func boss() -> Object:
	for e in list:
		if e.boss and not e.dead:
			return e
	return null

func clear() -> void:
	for e in list:
		e.remove()
	list.clear()
	spawn_queue.clear()

# ============================================================ shared rig + behaviour
class Enemy extends RefCounted:
	var pos := Vector3.ZERO
	var hp := 100.0
	var max_hp := 100.0
	var lag_hp := 100.0
	var dead := false
	var death_t := 0.0
	var path: Array = []
	var repath_t := 0.0
	var walk := 0.0
	var hurt_t := 0.0
	var climb_nav := false
	var stun_t := 0.0
	var flinch := 0.0
	var flinch_side := 0.0
	var death_twist := 0.0
	var phase := 1
	var yaw := 0.0
	var boss := 0
	var kind := ""
	var name := ""
	var points: Array = [100, 150, 200]
	var spark_color := 0xffaa33
	var drop_chance := 0.1
	var bar_y := 2.3
	var hb_visible := true
	var climber := false
	var climbing := false
	var reaction := 0.5
	var scale_k := 1.0
	var bar_lag := -1.0
	var mats: Array = []
	var flash_mats: Array = []
	var group: Node3D
	var pivot: Node3D
	var hips: Node3D
	var spine: Node3D
	var head_g: Node3D
	var legs: Array = []
	var batches := {}       # bone node -> Gfx.Batch

	func _init() -> void:
		group = Node3D.new()
		pivot = Node3D.new(); group.add_child(pivot)
		hips = Node3D.new(); hips.position.y = 0.88; pivot.add_child(hips)
		spine = Node3D.new(); spine.position.y = 0.04; hips.add_child(spine)
		head_g = Node3D.new(); spine.add_child(head_g)

	func base(x: float, z: float, max_hp_: float) -> void:
		pos = Vector3(x, 0, z)
		hp = max_hp_; max_hp = max_hp_; lag_hp = max_hp_
		walk = randf() * 6.0
		death_twist = G.rnd(-0.4, 0.4)
		var P: Node = G.player
		yaw = atan2(P.pos.x - x, P.pos.z - z)

	func mat(color: Variant, rough := 0.8, metal := 0.0, tex: Texture2D = null) -> StandardMaterial3D:
		var m := Gfx.mat(color, rough, metal)
		m.rim_enabled = true
		m.rim = 0.3
		m.rim_tint = 0.4
		if tex:
			m.albedo_texture = tex
		mats.append(m)
		return m

	func gmat(color: int, energy: float) -> StandardMaterial3D:
		var m := Gfx.glow(color, energy)
		mats.append(m)
		return m

	# mesh on a bone; a `part` ("head", "body", "limb") also gets a hitbox
	func add(mesh: Mesh, m: Material, p: Vector3, part: String, parent: Node3D, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
		if not batches.has(parent):
			batches[parent] = Gfx.Batch.new()
		var xf := Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), p)
		batches[parent].add(mesh, m, xf, true)
		if part != "":
			var a := Area3D.new()
			a.collision_layer = 2
			a.collision_mask = 0
			a.monitoring = false
			a.monitorable = true
			a.set_meta("enemy", self)
			a.set_meta("part", part)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			var bb: AABB = xf * mesh.get_aabb()
			sh.size = bb.size.max(Vector3(0.04, 0.04, 0.04))
			cs.shape = sh
			cs.position = bb.get_center()
			a.add_child(cs)
			parent.add_child(a)

	# two jointed legs: hip -> thigh, knee -> shin + foot
	func build_legs(thigh: Mesh, shin: Mesh, foot: Mesh, knee_m: Mesh, thigh_mat: Material, shin_mat: Material, foot_mat: Material, knee_mat: Material) -> void:
		for lx in [-0.13, 0.13]:
			var hip := Node3D.new(); hip.position = Vector3(lx, 0, 0); hips.add_child(hip)
			add(thigh, thigh_mat, Vector3(0, -0.21, 0), "limb", hip)
			var knee := Node3D.new(); knee.position.y = -0.44; hip.add_child(knee)
			if knee_mat:
				add(knee_m, knee_mat, Vector3(0, 0, 0.02), "limb", knee)
			add(shin, shin_mat, Vector3(0, -0.2, 0), "limb", knee)
			add(foot, foot_mat, Vector3(0, -0.395, 0.05), "limb", knee)
			legs.append({ "hip": hip, "knee": knee })

	func finish() -> void:
		for node in batches:
			for mi in batches[node].commit(node):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if G.settings.quality != "low" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batches.clear()
		group.position = pos
		group.rotation.y = yaw
		G.scene_root.add_child(group)

	func gait(dt: float, speed_now: float, g: Dictionary) -> float:
		var amt := clampf(speed_now / g.ref, 0, 1.25)
		walk += dt * speed_now * g.rate
		for i in legs.size():
			var L: Dictionary = legs[i]
			var ph := walk + i * PI
			var k: float = g.get("limp", 1.0) if i == 0 else 1.0
			L.hip.rotation.x = -sin(ph) * g.stride * amt * k
			L.knee.rotation.x = (0.05 + maxf(0, -cos(ph)) * g.knee) * amt * k
		hips.position.y = 0.88 + (absf(cos(walk)) - 0.6) * g.bob * amt
		return amt

	func on_death_pose(_fall: float) -> void:
		pass

	func animate_death(dt: float) -> bool:
		death_t += dt
		var t := death_t
		var buckle := G.smooth(clampf(t / 0.3, 0, 1))
		var fall := G.smooth(clampf((t - 0.12) / 0.55, 0, 1))
		for i in legs.size():
			legs[i].knee.rotation.x = buckle * (1.1 + i * 0.3)
			legs[i].hip.rotation.x = -buckle * (0.4 + i * 0.2)
		hips.position.y = 0.88 - buckle * 0.32
		pivot.rotation.x = -fall * 1.35
		pivot.rotation.z = fall * death_twist
		spine.rotation.x = lerpf(spine.rotation.x, 0.35, fall)
		head_g.rotation.x = -fall * 0.35
		on_death_pose(fall)
		if t > 2.2:
			for m in mats:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = maxf(0, 3.2 - t)
		return t < 3.2

	func on_hurt() -> void:
		pass

	func on_death() -> void:
		pass

	func on_phase() -> void:
		pass

	func damage(amount: float, head: bool, weapon_key: String) -> bool:
		if dead:
			return false
		hp -= amount; hurt_t = 0.08
		flinch = 1; flinch_side = G.rnd(-1, 1)
		on_hurt()
		# bosses change phase at two thirds and one third of their health
		if boss and hp > 0:
			var ph := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
			if ph > phase:
				phase = ph
				G.enemies.boss_phase(self)
		if hp > 0:
			return false
		hp = 0; dead = true
		on_death()
		if boss:
			G.game.boss_defeated(self)
		G.kills += 1
		if head:
			G.headshots += 1
		var pts: float = points[2 if weapon_key == "knife" or weapon_key == "tknife" else (1 if head else 0)]
		G.score += roundi(pts * G.D.score)
		G.items.add_cash(roundi(pts * G.D.score * (1.3 if G.perks.has("loot") else 1.0)))
		G.ui.killfeed(name, head, weapon_key)
		G.fx.particles(pos + Vector3(0, 1.2, 0), spark_color, 20, null, 5)
		G.fx.spawn_smoke(pos + Vector3(0, 1.2, 0), 0x555555, 1.4)
		hb_visible = false
		_disable_hitboxes()
		if randf() < drop_chance:
			G.items.temp_pickup("health", pos.x, pos.z)
		elif randf() < 0.16:
			G.items.temp_pickup("equip", pos.x, pos.z)
		return true

	func _disable_hitboxes() -> void:
		for a in group.find_children("*", "Area3D", true, false):
			a.collision_layer = 0

	func remove() -> void:
		group.queue_free()

	func steer_to(tx: float, tz: float, dt: float) -> Vector3:
		var Wd: Node = G.world
		var g: PackedByteArray = Wd.climb_grid if climb_nav else Wd.grid
		repath_t -= dt
		if Wd.walk_line(pos.x, pos.z, tx, tz, g):
			path.clear()
		else:
			if repath_t <= 0 or path.is_empty():
				repath_t = G.rnd(0.5, 0.9)
				path = Wd.find_path(pos.x, pos.z, tx, tz, g)
			while path.size() > 0 and Vector2(path[0].x - pos.x, path[0].y - pos.z).length() < 0.5:
				path.pop_front()
			if path.size() > 0:
				tx = path[0].x; tz = path[0].y
		var d := Vector3(tx - pos.x, 0, tz - pos.z)
		return d.normalized() if d.length_squared() > 0.01 else Vector3.ZERO

	func turn_to(y: float, dt: float, rate := 10.0) -> void:
		var d := wrapf(y - yaw, -PI, PI)
		yaw += d * minf(1, dt * rate)

	func move_and_collide(move: Vector3, speed: float, dt: float, radius: float, direct := false) -> void:
		var Wd: Node = G.world
		if direct:
			# climber going straight for you: scale any face in the way, then walk over the top
			var nx := pos.x + move.x * speed * dt
			var nz := pos.z + move.z * speed * dt
			var ahead: float = Wd.ground_at(nx, nz, 99, radius)
			if ahead > pos.y + 0.25:
				climbing = true; pos.y = minf(ahead, pos.y + dt * 2.8)
			else:
				climbing = false; pos.x = nx; pos.z = nz
				var g: float = Wd.ground_at(pos.x, pos.z, 99, radius)
				pos.y = minf(g, pos.y + dt * 3.5) if g > pos.y else maxf(g, pos.y - dt * 7)
			for o in G.enemies.list:
				if o == self or o.dead or absf(o.pos.y - pos.y) > 1:
					continue
				var dx: float = pos.x - o.pos.x
				var dz: float = pos.z - o.pos.z
				var d := sqrt(dx * dx + dz * dz)
				if d < 0.8 and d > 1e-4:
					pos.x += dx / d * (0.8 - d) * 0.5; pos.z += dz / d * (0.8 - d) * 0.5
			pos.x = clampf(pos.x, -40 + radius, 40 - radius); pos.z = clampf(pos.z, -40 + radius, 40 - radius)
			return
		climbing = false
		pos += move * speed * dt
		for o in G.enemies.list:
			if o == self or o.dead:
				continue
			var dx: float = pos.x - o.pos.x
			var dz: float = pos.z - o.pos.z
			var d := sqrt(dx * dx + dz * dz)
			if d < 0.85 and d > 1e-4:
				pos.x += dx / d * (0.85 - d) * 0.5; pos.z += dz / d * (0.85 - d) * 0.5
		if climb_nav:
			# climb onto low obstacles, drop back down when stepping off
			pos = Wd.collide_circle(pos, radius, 1.0, 1.9)
			var target: float = Wd.ground_at(pos.x, pos.z, 0.95, radius)
			pos.y = minf(target, pos.y + dt * 3.5) if target > pos.y else maxf(target, pos.y - dt * 7)
		else:
			pos = Wd.collide_circle(pos, radius, 0, 1.9)

	# flashbanged: stagger in place, no attacks
	func stunned_update(dt: float) -> bool:
		stun_t -= dt
		gait(dt, 0, { "stride": 0.4, "knee": 0.5, "rate": 2.0, "bob": 0.04, "ref": 3.0 })
		var w := minf(1, stun_t)
		var n: float = G.now
		spine.rotation = Vector3(0.25 * w + sin(n * 3.1) * 0.08, sin(n * 2.3) * 0.3 * w, sin(n * 4.2) * 0.16 * w)
		head_g.rotation = Vector3(0.3 * w, sin(n * 5) * 0.4 * w, sin(n * 3.7) * 0.25 * w)
		yaw += sin(n * 1.7) * dt * 0.8
		if randf() < dt * 3:
			G.fx.particles(pos + Vector3(0, bar_y - 0.2, 0), 0xfff3a0, 2, Vector3.UP, 1.2)
		common_update(dt)
		return true

	func common_update(dt: float) -> void:
		hurt_t -= dt
		flinch *= exp(-dt * 8)
		var h := 0.8 if hurt_t > 0 else 0.0
		for m in flash_mats:
			m.emission = Color(h, h, h)
		group.position = pos
		group.rotation.y = yaw
		if lag_hp < hp:
			lag_hp = hp
		lag_hp = maxf(hp, lag_hp - max_hp * 0.7 * dt)

	func update(_dt: float) -> bool:
		return true

# ---------------------------------------------------------------- bot (classic mode)
class Bot extends Enemy:
	var aim_t := 0.0
	var dmg_mul := 1.0
	var rocket_t := 3.0
	var barrage_t := 4.0
	var accuracy := 0.5
	var fire_rate := 1.0
	var speed := 3.5
	var los_t := 0.0
	var has_los := false
	var seen_t := 0.0
	var fire_cd := 1.0
	var strafe_dir := 1.0
	var strafe_t := 0.0
	var flash_t := 0.0
	var kick := 0.0
	var rig: Node3D
	var flash: MeshInstance3D
	var laser: MeshInstance3D
	var glow_mat: StandardMaterial3D

	func _init(x: float, z: float, wave: int, boss_lv := 0, kind_ := "?") -> void:
		super()
		var D: Dictionary = G.D
		var k := kind_
		if boss_lv:
			k = ""
		elif k == "?":
			var snipers := 0
			for e in G.enemies.list:
				if e.kind == "sniper" and not e.dead:
					snipers += 1
			k = "sniper" if wave >= 3 and randf() < minf(0.22, wave * 0.03) and snipers < 2 else ""
		base(x, z, roundf((1200 + 850 * (boss_lv - 1) if boss_lv else (70 if k == "sniper" else 100)) * D.hp))
		kind = k
		boss = boss_lv
		name = "COLOSSO Mk.%d" % boss_lv if boss_lv else ("Cecchino-" if k == "sniper" else "Bot-") + G.enemies.BOT_NAMES[G.enemies.bot_counter % G.enemies.BOT_NAMES.size()]
		G.enemies.bot_counter += 1
		points = [1500 * boss_lv, 1500 * boss_lv, 1500 * boss_lv] if boss_lv else ([150, 220, 260] if k == "sniper" else [100, 150, 200])
		dmg_mul = 0.9 + boss_lv * 0.2 if boss_lv else 1.0
		spark_color = 0xffaa33
		drop_chance = 0.18
		bar_y = 2.3
		accuracy = minf(0.85, (0.3 + wave * 0.04) * D.acc)
		reaction = maxf(0.18, (0.85 - wave * 0.05) / D.acc)
		fire_rate = maxf(0.5, 1 - wave * 0.04) / D.acc
		speed = minf(5, (3.2 + wave * 0.12) * D.speed)
		los_t = randf() * 0.2
		fire_cd = G.rnd(0.6, 1.4)
		var T: Dictionary = G.enemies.TEX
		var armor_tex: Texture2D = T.boss if boss_lv else T.armor[randi() % T.armor.size()]
		var armor := mat(0xffffff, 0.36, 0.8 if boss_lv else 0.5, armor_tex)
		var dark := mat(0xffffff, 0.42, 0.75, T.dark)
		var glow := gmat(0xff1e5a if boss_lv else (0x3aa8ff if k == "sniper" else 0xff4a10), 4.0 * G.light_k())
		var chrome := mat(0xb8bec6, 0.2, 0.95)
		glow_mat = glow
		flash_mats = [armor, dark]
		for fm in flash_mats:
			fm.emission_enabled = true; fm.emission = Color.BLACK
		var S := spine
		var H := head_g
		build_legs(Gfx.capsule(0.085, 0.43, 10), Gfx.box(0.17, 0.42, 0.19), Gfx.box(0.2, 0.1, 0.34), Gfx.sphere(0.1, 12, 8), dark, armor, dark, armor)
		for L in legs:
			add(Gfx.box(0.17, 0.26, 0.08), armor, Vector3(0, -0.2, 0.075), "limb", L.hip)
			add(Gfx.cyl(0.018, 0.018, 0.34, 6), chrome, Vector3(0, -0.2, -0.105), "", L.knee)
		add(Gfx.box(0.42, 0.2, 0.26), dark, Vector3(0, 0.02, 0), "body", S)
		for s in [-1, 1]:
			add(Gfx.box(0.08, 0.2, 0.24), armor, Vector3(0.24 * s, -0.03, 0), "body", S, Vector3(0, 0, 0.18 * s))
		var i := 0
		for y in [0.12, 0.2, 0.28]:
			add(Gfx.box(0.34, 0.085, 0.22), dark, Vector3(0, y, 0), "body", S, Vector3.ZERO, Vector3(1 - i * 0.04, 1, 1))
			i += 1
		add(Gfx.box(0.5, 0.34, 0.3), dark, Vector3(0, 0.5, 0), "body", S)
		add(Gfx.box(0.56, 0.32, 0.16), armor, Vector3(0, 0.5, 0.1), "body", S)
		for s in [-1, 1]:
			for vy in [0.0, -0.034, -0.068]:
				add(Gfx.box(0.12, 0.016, 0.02), dark, Vector3(0.16 * s, 0.47 + vy, 0.182), "", S)
			add(Gfx.box(0.1, 0.018, 0.01), glow, Vector3(0.16 * s, 0.61, 0.182), "", S)
		add(Gfx.cyl(0.06, 0.06, 0.004, 20), glow, Vector3(0, 0.52, 0.184), "", S, Vector3(PI / 2, 0, 0))
		add(Gfx.torus(0.07, 0.014, 20), chrome, Vector3(0, 0.52, 0.182), "", S, Vector3(PI / 2, 0, 0))
		add(Gfx.torus(0.12, 0.035, 16), dark, Vector3(0, 0.68, 0), "", S)
		add(Gfx.box(0.38, 0.44, 0.18), dark, Vector3(0, 0.45, -0.22), "body", S)
		for y in [0.52, 0.46, 0.4]:
			add(Gfx.box(0.26, 0.028, 0.02), glow, Vector3(0, y, -0.312), "", S)
		add(Gfx.cyl(0.01, 0.01, 0.4, 6), dark, Vector3(-0.12, 0.8, -0.26), "", S)
		add(Gfx.sphere(0.028, 8, 6), glow, Vector3(-0.12, 1.01, -0.26), "", S)
		for s in [-1, 1]:
			add(Gfx.sphere(0.17, 14, 8), armor, Vector3(0.34 * s, 0.6, 0), "body", S, Vector3(0, 0, -0.3 * s), Vector3(1.05, 0.9, 1.1))
			add(Gfx.torus(0.165, 0.02, 20), dark, Vector3(0.34 * s, 0.6, 0), "", S, Vector3(0, 0.3 * s, 0))
		add(Gfx.cyl(0.06, 0.07, 0.12, 12), dark, Vector3(0, 0.72, 0), "body", S)
		# helmet with a T-shaped visor
		H.position = Vector3(0, 0.88, 0)
		add(Gfx.box(0.3, 0.31, 0.33), armor, Vector3(0, 0.02, 0), "head", H)
		add(Gfx.box(0.22, 0.09, 0.12), dark, Vector3(0, -0.1, 0.075), "head", H)
		add(Gfx.box(0.25, 0.045, 0.03), glow, Vector3(0, 0.04, 0.162), "", H)
		add(Gfx.box(0.045, 0.09, 0.03), glow, Vector3(0, -0.02, 0.162), "", H)
		for s in [-1, 1]:
			add(Gfx.cyl(0.05, 0.05, 0.04, 12), dark, Vector3(0.155 * s, 0, 0), "", H, Vector3(0, 0, PI / 2))
			add(Gfx.box(0.02, 0.12, 0.16), dark, Vector3(0.1 * s, 0.18, -0.03), "", H, Vector3(0, 0, -0.25 * s))
		# weapon rig (arms + rifle) pivots at the shoulders so it can aim and recoil
		rig = Node3D.new(); rig.position = Vector3(0, 0.4, 0); S.add_child(rig)
		for ab in [[Vector3(0.32, 0.1, 0.04), Vector3(0.24, -0.02, 0.42)], [Vector3(-0.32, 0.1, 0.04), Vector3(0.12, -0.04, 0.62)]]:
			var a: Vector3 = ab[0]
			var b: Vector3 = ab[1]
			var d := b - a
			var q := Basis(Quaternion(Vector3.UP, d.normalized()))
			add(Gfx.capsule(0.065, d.length(), 10), dark, (a + b) * 0.5, "limb", rig, q.get_euler())
			add(Gfx.box(0.13, 0.22, 0.11), armor, a.lerp(b, 0.62), "limb", rig, q.get_euler())
			add(Gfx.box(0.09, 0.09, 0.1), dark, b + Vector3(0, -0.02, 0), "", rig)
		add(Gfx.box(0.09, 0.13, 0.4), dark, Vector3(0.22, -0.02, 0.5), "", rig)
		add(Gfx.box(0.08, 0.08, 0.26), armor, Vector3(0.22, 0.005, 0.78), "", rig)
		add(Gfx.cyl(0.02, 0.024, 0.2, 10), chrome, Vector3(0.22, 0.01, 0.95), "", rig, Vector3(PI / 2, 0, 0))
		add(Gfx.box(0.06, 0.17, 0.08), dark, Vector3(0.22, -0.15, 0.5), "", rig, Vector3(0.2, 0, 0))
		add(Gfx.cyl(0.035, 0.035, 0.16, 12), dark, Vector3(0.22, 0.1, 0.48), "", rig, Vector3(PI / 2, 0, 0))
		add(Gfx.cyl(0.03, 0.03, 0.004, 12), glow, Vector3(0.22, 0.1, 0.561), "", rig, Vector3(PI / 2, 0, 0))
		add(Gfx.box(0.07, 0.12, 0.18), dark, Vector3(0.22, -0.04, 0.23), "", rig)
		if k == "sniper":
			# pale armour, a long barrel with a big scope, and the laser that gives the shot away
			armor.albedo_color = G.col(0xa9c4ff)
			add(Gfx.cyl(0.02, 0.024, 0.2, 10), chrome, Vector3(0.22, 0.01, 1.2), "", rig, Vector3(PI / 2, 0, 0))
			add(Gfx.cyl(0.035, 0.035, 0.16, 12), dark, Vector3(0.22, 0.12, 0.62), "", rig, Vector3(PI / 2, 0, 0), Vector3.ONE * 1.5)
			laser = MeshInstance3D.new()
			laser.mesh = Gfx.cyl(0.014, 0.014, 1, 6, true)
			laser.material_override = G.enemies.laser_mat.duplicate()
			laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			laser.visible = false
			G.scene_root.add_child(laser)
			speed *= 0.85
		flash = MeshInstance3D.new()
		flash.mesh = Gfx.plane(0.7, 0.7)
		flash.material_override = G.enemies.flash_mat
		flash.position = G.enemies.RIG_MUZZLE
		flash.visible = false
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(flash)
		finish()
		G.fx.particles(pos + Vector3(0, 1, 0), 0xff6a3d, 14, null, 3)
		G.fx.spawn_smoke(pos + Vector3(0, 0.6, 0), 0x888888, 1.6)

	func on_hurt() -> void:
		seen_t = maxf(seen_t, reaction * 0.5)

	func on_death_pose(fall: float) -> void:
		rig.rotation.x = fall * 0.9
		flash.visible = false
		if laser:
			laser.visible = false

	func remove() -> void:
		super.remove()
		if laser:
			laser.queue_free()

	func on_phase() -> void:
		glow_mat.emission = G.col(0xffa020 if phase == 2 else 0xffffff)

	func muzzle(z := -1.0) -> Vector3:
		var m: Vector3 = G.enemies.RIG_MUZZLE
		if z > 0:
			m.z = z
		return rig.global_transform * m

	# sniper: one heavy round after the laser has been on you; moving (or breaking the line) is how you dodge it
	func fire_sniper(dist: float) -> void:
		var P: Node = G.player
		var m := muzzle(1.3)
		var target: Vector3 = P.eye() + Vector3(0, -0.3, 0)
		var ps := Vector2(P.vel.x, P.vel.z).length()
		var p := clampf((0.25 if ps > 6 else (0.55 if ps > 1 else 0.92)) - (0.0 if P.on_ground else 0.12) + (G.D.acc - 1) * 0.15, 0.1, 0.95)
		var end := target
		if randf() < p:
			P.damage(38, pos)
		else:
			var dir := (target + Vector3(G.rnd(-0.9, 0.9), G.rnd(-0.5, 0.7), G.rnd(-0.9, 0.9)) - m).normalized()
			var h: Dictionary = G.world.ray(m, m + dir * 120)
			end = h.position if not h.is_empty() else m + dir * 120
			if not h.is_empty():
				G.fx.decal(h.position, h.normal)
		G.fx.tracer(m, end, 0xff4030)
		flash_t = 0.08; kick = 1.6
		G.audio.with_cat("enemies", func(): G.audio.shot("sniper", clampf(1.2 - dist / 80, 0.3, 0.9), pos, clampf(dist / 60, 0, 1)))

	func fire(dist: float) -> void:
		var P: Node = G.player
		var m := muzzle()
		var target: Vector3 = P.eye() + Vector3(0, -0.3, 0)
		var ps := Vector2(P.vel.x, P.vel.z).length()
		var p := clampf(accuracy - dist * 0.007 - (0.14 if ps > 6 else (0.07 if ps > 1 else 0.0)) - (0.0 if P.on_ground else 0.1) - P.crouch_t * 0.07, 0.05, 0.9)
		var end: Vector3
		if randf() < p:
			end = target
			P.damage(G.rnd(6, 10) * dmg_mul, pos)
		else:
			var dir := (target + Vector3(G.rnd(-1.2, 1.2), G.rnd(-0.8, 0.9), G.rnd(-1.2, 1.2)) - m).normalized()
			var h: Dictionary = G.world.ray(m, m + dir * 80)
			end = h.position if not h.is_empty() else m + dir * 80
			if not h.is_empty():
				G.fx.decal(h.position, h.normal)
		G.fx.tracer(m, end, 0xff7a40)
		flash_t = 0.06; kick = 1
		G.audio.shot("bot", clampf(1.1 - dist / 60, 0.15, 0.75), pos, clampf(dist / 45, 0, 1))

	func update(dt: float) -> bool:
		if dead:
			return animate_death(dt)
		var P: Node = G.player
		var Wd: Node = G.world
		if stun_t > 0:
			flash_t = 0; flash.visible = false; has_los = false; seen_t = 0
			if laser:
				laser.visible = false; aim_t = 0
			return stunned_update(dt)
		var eye := Vector3(pos.x, 1.75 + pos.y, pos.z)
		var p_eye: Vector3 = P.eye()
		var to_p := p_eye - eye
		var dist := to_p.length()
		los_t -= dt
		if los_t <= 0:
			los_t = 0.15
			has_los = dist < 70 and Wd.line_of_sight(eye, p_eye)
		seen_t = seen_t + dt if has_los else 0.0
		var move := Vector3.ZERO
		var spd := speed
		var face_yaw := INF
		if has_los:
			face_yaw = atan2(to_p.x, to_p.z)
			strafe_t -= dt
			if strafe_t <= 0:
				strafe_t = G.rnd(0.7, 1.8); strafe_dir = -1.0 if randf() < 0.5 else 1.0
			var flat := Vector3(to_p.x, 0, to_p.z).normalized()
			if kind == "sniper":
				# keeps its distance: closes in only when far away, backs off (strafing) when you rush it
				if dist > 46:
					move = steer_to(P.pos.x, P.pos.z, dt)
				elif dist < 18:
					move = (-flat + Vector3(flat.z, 0, -flat.x) * strafe_dir * 0.6).normalized()
					if Wd.blocked_at(pos.x + move.x * 0.8, pos.z + move.z * 0.8):
						move = Vector3(flat.z, 0, -flat.x) * strafe_dir
			elif dist > 22:
				move = steer_to(P.pos.x, P.pos.z, dt)
			else:
				move = (Vector3(flat.z, 0, -flat.x) * strafe_dir + flat * (0.6 if dist > 12 else (-0.7 if dist < 6 else 0.0))).normalized()
				spd *= 0.55
				if Wd.blocked_at(pos.x + move.x * 0.8, pos.z + move.z * 0.8):
					strafe_dir *= -1; strafe_t = G.rnd(0.7, 1.5)
			fire_cd -= dt
			if kind == "sniper":
				# laser on for 1.5 s (it thickens as the shot gets close), then a long pause
				if seen_t > reaction:
					aim_t += dt
				if aim_t > 1.5:
					fire_sniper(dist); aim_t = -G.rnd(2.4, 3.6) * fire_rate
				if aim_t > 0:
					var a := muzzle(1.3)
					var b := p_eye + Vector3(0, -0.3, 0)
					var kk := aim_t / 1.5
					laser.visible = true
					laser.global_position = (a + b) * 0.5
					laser.global_basis = Basis(Quaternion(Vector3.UP, (b - a).normalized())) * Basis.from_scale(Vector3(1 + kk * 1.6, a.distance_to(b), 1 + kk * 1.6))
					var lm: StandardMaterial3D = laser.material_override
					lm.albedo_color.a = (0.35 + 0.5 * kk) * ((0.6 + 0.4 * sin(G.now * 50)) if kk > 0.75 else 1.0)
				else:
					laser.visible = false
			elif seen_t > reaction and fire_cd <= 0:
				fire(dist)
				fire_cd = G.rnd(0.4, 0.9) * fire_rate * (0.8 / (1 + 0.3 * (phase - 1)) if boss else 1.0)
			# boss: rocket volleys you have to dodge
			if boss and seen_t > reaction:
				rocket_t -= dt
				if rocket_t <= 0:
					rocket_t = maxf(2, 4.6 - boss * 0.4)
					var m := muzzle()
					var aim := (p_eye + Vector3(0, -0.5, 0) - m).normalized()
					for i in phase:
						G.items.launch("erocket", m, aim.rotated(Vector3.UP, (i - (phase - 1) / 2.0) * 0.14) * (19 + boss))
					G.audio.rocket_launch(pos)
		else:
			move = steer_to(P.pos.x, P.pos.z, dt)
			fire_cd = maxf(fire_cd, 0.3)
			if laser:
				laser.visible = false; aim_t = minf(aim_t, 0)
		# boss, from phase 2: mortar barrage on your position (even behind cover) — get out of the red circles
		if boss and phase >= 2:
			barrage_t -= dt
			if barrage_t <= 0:
				barrage_t = 5.0 if phase == 3 else 7.5
				for i in 3 + phase:
					var a := randf() * TAU
					var r := G.rnd(2.5, 7) if i else 0.0
					var hp_ := Vector3(clampf(P.pos.x + cos(a) * r, -38, 38), Wd.ground_at(P.pos.x, P.pos.z, P.pos.y, 0.4), clampf(P.pos.z + sin(a) * r, -38, 38))
					G.fx.hazard(hp_, 3.2, 1.2 + i * 0.16, G.items.enemy_blast.bind(hp_ + Vector3(0, 0.4, 0)))
				G.audio.with_cat("enemies", func(): G.audio.tone(90, 0.5, 0.3, "sawtooth", 40); G.audio.tone(1400, 0.9, 0.05, "sine", 500, 0.2))
		if boss and phase == 3:
			spd *= 1.15
		if face_yaw == INF and move.length_squared() > 0:
			face_yaw = atan2(move.x, move.z)
		if face_yaw != INF:
			turn_to(face_yaw, dt)
		move_and_collide(move, spd, dt, 0.6 if boss else 0.42)
		# animation
		var amt := gait(dt, spd if move.length_squared() > 0 else 0.0, { "stride": 0.55, "knee": 0.85, "rate": 2.5, "bob": 0.05, "ref": 3.2 })
		kick *= exp(-dt * 14)
		var aim_pitch := asin(clampf(to_p.y / maxf(dist, 0.01), -0.6, 0.6)) if has_los else 0.0
		var n: float = G.now
		spine.rotation = Vector3(0.06 * amt - flinch * 0.35 + sin(n * 2 + walk) * 0.012, sin(walk) * 0.1 * amt, flinch_side * flinch * 0.2)
		head_g.rotation.x = -aim_pitch * 0.5
		# scanning head while searching, pulsing core and visor (with the odd glitch)
		head_g.rotation.y = 0.0 if has_los else sin(n * 1.3 + walk) * 0.45
		glow_mat.emission_energy_multiplier = (3.6 + sin(n * 7 + walk) * 0.7) * G.light_k() * (0.15 if randf() < 0.012 else 1.0)
		rig.rotation.x = -aim_pitch * 0.9 - kick * 0.22
		rig.position.z = -kick * 0.07
		flash_t -= dt
		flash.visible = flash_t > 0
		common_update(dt)
		return true

# ---------------------------------------------------------------- zombie (zombie mode)
class Zombie extends Enemy:
	var fuse_t := 0.0
	var spit_cd := 1.5
	var spit_t := 0.0
	var los_t := 0.0
	var has_los := false
	var slam_t := 0.0
	var slam_cd := 3.0
	var volley_cd := 3.0
	var runner := false
	var reach := 1.3
	var charge_t := 5.0
	var charging := 0.0
	var speed := 2.5
	var hit_dmg := 14.0
	var attack_t := 0.0
	var attack_cd := 0.0
	var hit_done := false
	var groan_t := 3.0
	var limp := 1.0
	var head_tilt := 0.0
	var tw := Vector3.ZERO
	var tw_k := 0.0
	var twitch_t := 1.0
	var blown := false
	var jaw: Node3D
	var arms: Array = []
	var eyes_mat: StandardMaterial3D
	var pus_mat: StandardMaterial3D
	var sac_mat: StandardMaterial3D

	func _init(x: float, z: float, wave: int, boss_lv := 0, kind_ := "?") -> void:
		super()
		var D: Dictionary = G.D
		var k := kind_
		# special breeds join in as the waves go on: spitters (ranged), bombers (explode) and armoured ones
		if boss_lv:
			k = ""
		elif k == "?":
			k = ""
			var r := randf()
			for e in [["spitter", 2, minf(0.18, 0.05 + wave * 0.015)], ["bomber", 3, minf(0.16, 0.03 + wave * 0.015)], ["armored", 4, minf(0.18, wave * 0.02)]]:
				if wave < e[1]:
					continue
				if r < e[2]:
					k = e[0]
					break
				r -= e[2]
		# climbers scale walls and crates: more of them on harder difficulties and later waves
		var climb := boss_lv > 0 or (k == "" and randf() < minf(0.7, D.climb + wave * 0.012))
		var run := k == "" and not climb and randf() < minf(0.45, 0.06 + wave * 0.05)
		var base_hp := 190.0 if k == "armored" else (60.0 if k == "bomber" else (85.0 if k == "spitter" else (110.0 if climb else (70.0 if run else 100.0))))
		base(x, z, roundf((1800 + 1100 * (boss_lv - 1) if boss_lv else base_hp * (1 + (wave - 1) * 0.06)) * D.hp))
		kind = k
		spit_cd = G.rnd(1, 2.5)
		runner = run; climber = climb
		boss = boss_lv; reach = 2.3 if boss_lv else 1.3
		name = "ABOMINIO Lv.%d" % boss_lv if boss_lv else ({ "bomber": "Zombie esplosivo", "armored": "Zombie corazzato", "spitter": "Zombie sputatore" }.get(k, "Zombie arrampicatore" if climb else ("Zombie corridore" if run else "Zombie")))
		points = [1200 * boss_lv, 1200 * boss_lv, 1200 * boss_lv] if boss_lv else ([110, 150, 200] if k == "armored" else ([80, 110, 150] if k != "" else [60, 90, 120]))
		spark_color = 0xb8ff5a
		drop_chance = 0.1
		bar_y = 2.05
		speed = (minf(6.2, 5 + wave * 0.06) if run else (minf(4, 2.7 + wave * 0.09) if climb else minf(3.6, 2.1 + wave * 0.1))) * D.speed
		hit_dmg = 26 + 8 * boss_lv if boss_lv else (20.0 if k == "armored" else (9.0 if run else 14.0))
		if boss_lv:
			speed = minf(4.2, 2.9 + boss_lv * 0.2) * D.speed
		if k != "":
			speed = (minf(5, 3.6 + wave * 0.08) if k == "bomber" else (minf(2.6, 1.7 + wave * 0.06) if k == "armored" else minf(3.4, 2.4 + wave * 0.08))) * D.speed
		groan_t = G.rnd(1, 6)
		limp = 1.0 if run else G.rnd(0.55, 1)
		climb_nav = true
		head_tilt = G.rnd(-0.3, 0.3)
		twitch_t = G.rnd(0.5, 3)
		var T: Dictionary = G.enemies.TEX
		var skin_tex: Texture2D = T.zboss if boss_lv else (T.climber if climb else T.skin[randi() % T.skin.size()])
		var skin := mat(0xffffff, 0.86, 0.0, skin_tex)
		var skin_dark := mat(0x2a2620, 0.9)
		var shirt := mat(0xffffff, 0.95, 0.0, T.shirts[randi() % T.shirts.size()])
		var pants := mat(0xffffff, 0.95, 0.0, T.pants)
		var ec = 0xff1e2a if boss_lv else ({ "bomber": 0xff7a1a, "spitter": 0x7dff3a, "armored": 0x6cd4ff }.get(k, 0x9a6bff if climb else (0xff3010 if run else 0xffd040)))
		var eyes := gmat(ec, 5.0 * G.light_k())
		var hole := mat(0x0c0505, 1.0)
		var gore := mat(0x4a0707, 0.22, 0.1)
		var bone := mat(0x9c9072, 0.75)
		var nail := mat(0x2a2218, 0.4)
		eyes_mat = eyes
		flash_mats = [skin, shirt, pants]
		for fm in flash_mats:
			fm.emission_enabled = true; fm.emission = Color.BLACK
		var S := spine
		var H := head_g
		build_legs(Gfx.capsule(0.075, 0.42, 8), Gfx.capsule(0.068, 0.41, 8), Gfx.box(0.15, 0.08, 0.27), null, pants, pants, skin_dark, null)
		add(Gfx.box(0.38, 0.18, 0.24), pants, Vector3(0, 0.02, 0), "body", S)
		add(Gfx.box(0.44, 0.52, 0.26), shirt, Vector3(0, 0.33, 0), "body", S)
		if randf() < 0.7:
			for hm in [[-0.15, -0.02, 0.2], [0.02, -0.035, -0.12], [0.16, -0.015, 0.25]]:
				add(Gfx.box(0.04, 0.1, 0.012), shirt, Vector3(hm[0], 0.09 + hm[1], 0.128), "", S, Vector3(0, 0, hm[2]))
		# open chest wound with ribs showing
		if randf() < 0.65 or boss_lv:
			var wx := G.rnd(-0.1, 0.1)
			var wy := G.rnd(0.3, 0.42)
			add(Gfx.cyl(0.105, 0.105, 0.004, 16), gore, Vector3(wx, wy, 0.132), "", S, Vector3(PI / 2, 0, 0), Vector3(0.85, 1, 1))
			for rb in [[0.045, -0.12], [0.0, -0.08], [-0.045, -0.04]]:
				add(Gfx.capsule(0.012, 0.154, 6), bone, Vector3(wx, wy + rb[0], 0.136), "", S, Vector3(0, 0, PI / 2 + rb[1]))
		add(Gfx.cyl(0.055, 0.065, 0.14, 10), skin, Vector3(0, 0.65, 0.02), "body", S)
		# head: sunken glowing eyes, heavy brow, hanging jaw full of teeth
		H.position = Vector3(0, 0.8, 0.04)
		add(Gfx.sphere(0.165, 18, 12), skin, Vector3(0, 0.02, 0), "head", H, Vector3.ZERO, Vector3(0.92, 1.12, 1.02))
		add(Gfx.box(0.25, 0.05, 0.09), skin, Vector3(0, 0.078, 0.113), "head", H, Vector3(-0.15, 0, 0))
		for s in [-1, 1]:
			add(Gfx.sphere(0.046, 10, 6), hole, Vector3(0.062 * s, 0.032, 0.13), "", H, Vector3.ZERO, Vector3(1, 0.85, 0.55))
			add(Gfx.sphere(0.016, 8, 5), eyes, Vector3(0.062 * s, 0.03, 0.146), "", H)
		add(Gfx.cyl(0.0, 0.024, 0.045, 3), hole, Vector3(0, -0.012, 0.158), "", H, Vector3(PI, 0, 0), Vector3(1, 1, 0.5))
		add(Gfx.sphere(0.06, 10, 6), hole, Vector3(0, -0.078, 0.128), "", H, Vector3.ZERO, Vector3(1.15, 0.62, 0.5))
		add(Gfx.box(0.1, 0.028, 0.012), bone, Vector3(0, -0.07, 0.152), "", H)
		if randf() < 0.45:
			add(Gfx.sphere(0.169, 12, 6), bone, Vector3(0, 0.05, -0.02), "", H, Vector3(G.rnd(-0.3, 0.3), randf() * 6, 0), Vector3(0.6, 0.5, 0.6))
		if randf() < 0.6:
			for hr in [[-0.07, 0.12, -0.06, -0.6, 0.5], [0.02, 0.15, -0.08, -0.9, -0.2], [0.09, 0.1, -0.09, -1.1, -0.6], [-0.1, 0.05, -0.1, -1.3, 0.9], [0.05, 0.06, -0.14, -1.5, -0.3]]:
				add(Gfx.cyl(0.0, 0.018, 0.14, 5), skin_dark, Vector3(hr[0], hr[1] + 0.02, hr[2]), "", H, Vector3(hr[3], 0, hr[4]))
		jaw = Node3D.new(); jaw.position = Vector3(0, -0.07, 0.02); H.add_child(jaw)
		add(Gfx.box(0.15, 0.045, 0.13), skin, Vector3(0, -0.035, 0.06), "head", jaw)
		add(Gfx.box(0.09, 0.024, 0.012), bone, Vector3(0, -0.012, 0.118), "", jaw)
		for s in [-1, 1]:
			var sh := Node3D.new(); sh.position = Vector3(0.27 * s, 0.56, 0); S.add_child(sh)
			if climb:
				sh.scale = Vector3(1, 1.22, 1)   # long clawing arms
			add(Gfx.capsule(0.058, 0.316, 8), shirt, Vector3(0, -0.16, 0), "limb", sh)
			var el := Node3D.new(); el.position.y = -0.32; sh.add_child(el)
			if randf() < 0.3:
				# flesh torn off the forearm: bare bone
				add(Gfx.capsule(0.026, 0.252, 6), bone, Vector3(0, -0.15, 0), "limb", el)
				add(Gfx.torus(0.048, 0.022, 12), gore, Vector3(0, -0.05, 0), "", el)
				add(Gfx.torus(0.048, 0.022, 12), gore, Vector3(0, -0.25, 0), "", el)
			else:
				add(Gfx.capsule(0.05, 0.29, 8), skin, Vector3(0, -0.15, 0), "limb", el)
			add(Gfx.sphere(0.06, 10, 6), skin, Vector3(0, -0.3, 0.01), "limb", el, Vector3.ZERO, Vector3(1, 0.8, 1.25))
			for cl in [[-0.036, -0.07, 0.02], [-0.012, -0.08, 0.03], [0.012, -0.08, 0.03], [0.036, -0.07, 0.02]]:
				add(Gfx.cyl(0.0, 0.011, 0.09, 5), nail, Vector3(cl[0], -0.3 + cl[1], 0.01 + cl[2]), "", el, Vector3(PI + 0.25, 0, 0))
			arms.append({ "sh": sh, "el": el, "s": s })
		if boss_lv:
			spine.scale = Vector3(1.3, 1.05, 1.3)   # hulking torso
		if k == "bomber":
			# bloated body covered in glowing pustules
			spine.scale = Vector3(1.35, 1.08, 1.5)
			pus_mat = gmat(0xff7a1a, 3.0)
			for pp in [[0.1, 0.5, 0.15, 0.1], [-0.13, 0.36, 0.16, 0.08], [0.02, 0.24, 0.17, 0.07], [0.17, 0.3, 0.05, 0.07], [-0.1, 0.56, -0.14, 0.09], [0.12, 0.34, -0.15, 0.08], [-0.2, 0.5, 0.02, 0.07]]:
				add(Gfx.sphere(pp[3], 8, 5), pus_mat, Vector3(pp[0], pp[1], pp[2]), "body", S)
		elif k == "armored":
			# riot gear: vest, shoulder pads and a helmet with a visor
			var plate := mat(0x1c2330, 0.4, 0.7)
			var visor := mat(0x0a0f16, 0.1, 0.9)
			add(Gfx.box(0.5, 0.5, 0.34), plate, Vector3(0, 0.42, 0), "body", S)
			for sd in [-1, 1]:
				add(Gfx.box(0.2, 0.12, 0.26), plate, Vector3(0.3 * sd, 0.63, 0), "body", S)
			add(Gfx.sphere(0.2, 14, 8), plate, Vector3(0, 0.06, 0), "head", H, Vector3.ZERO, Vector3(1, 0.7, 1))
			add(Gfx.box(0.3, 0.12, 0.05), visor, Vector3(0, 0.0, 0.165), "head", H)
		elif k == "spitter":
			# sickly green skin and a glowing acid sac under the jaw
			skin.albedo_color = G.col(0xa8d890)
			sac_mat = gmat(0x7dff3a, 2.5)
			add(Gfx.sphere(0.11, 10, 6), sac_mat, Vector3(0, 0.72, 0.11), "body", S)
			add(Gfx.sphere(0.07, 8, 5), sac_mat, Vector3(0.1, 0.5, 0.15), "", S)
			add(Gfx.sphere(0.06, 8, 5), sac_mat, Vector3(-0.12, 0.42, 0.15), "", S)
		finish()
		G.fx.particles(pos + Vector3(0, 0.3, 0), 0x6a5a40, 16, Vector3.UP, 3, false)
		G.fx.spawn_smoke(pos + Vector3(0, 0.4, 0), 0x4a4038, 1.8)

	func on_death() -> void:
		var d: float = G.player.eye().distance_to(pos)
		if d < 30:
			G.audio.with_cat("enemies", func(): G.audio.groan(clampf(1.1 - d / 30, 0.15, 0.9), pos, "death"))
		if kind == "bomber":
			blow()

	# armour shrugs off bullets (explosions and blades go through)
	func damage(amount: float, head: bool, weapon_key: String) -> bool:
		if kind == "armored" and not dead and not weapon_key in ["frag", "rocket", "raygun", "knife", "tknife"]:
			amount *= 0.6 if head else 0.35
			if randf() < 0.5:
				G.audio.tone(G.rnd(1800, 2400), 0.04, 0.05, "square", 900)
		return super.damage(amount, head, weapon_key)

	# bomber: blast that hurts you and every zombie around (chain reactions welcome)
	func blow() -> void:
		if blown:
			return
		blown = true
		var p := pos + Vector3(0, 1, 0)
		G.items.explode(p, { "radius": 4.5, "dmg": 150.0, "key": "frag", "color": 0xff8a2a, "skip": self })
		var P: Node = G.player
		var body: Vector3 = P.pos + Vector3(0, 0.9, 0)
		var pd := body.distance_to(p)
		if pd < 4.5 and G.world.world_clear(p, body):
			P.damage(38 * (1 - pd / 4.5 * 0.7), p)

	func on_phase() -> void:
		eyes_mat.emission = G.col(0xff7a1a if phase == 2 else 0xffffff)
		speed *= 1.12

	# boss slam: a shockwave along the ground — be in the air when it lands
	func slam() -> void:
		var P: Node = G.player
		var p := pos + Vector3(0, 0.12, 0)
		var R := 8.5
		G.fx.shock(p, R, 0.45)
		G.fx.particles(p, 0x8a7a60, 40, Vector3.UP, 8, false)
		for i in 8:
			G.fx.spawn_smoke(p + Vector3(cos(i * 0.785) * 2.5, 0.3, sin(i * 0.785) * 2.5), 0x5a5048, 2.4)
		var d := Vector2(P.pos.x - pos.x, P.pos.z - pos.z).length()
		G.audio.boom(clampf(1.2 - d / 40, 0.3, 1.1), pos, clampf(d / 40, 0, 1))
		P.shake = maxf(P.shake, clampf(1.2 - d / 16, 0, 1))
		if d < R and P.on_ground and absf(P.pos.y - pos.y) < 1.2:
			P.damage(22 + 6 * boss, pos)
			var push := Vector3(P.pos.x - pos.x, 0, P.pos.z - pos.z).normalized() * 7
			P.vel += push
			P.vel.y = 6
			P.on_ground = false

	func spit(spread := 0.0) -> void:
		var P: Node = G.player
		var k := group.scale.y
		var m := pos + Vector3(0, 1.55 * k, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.3 * k
		var d: Vector3 = P.eye() + Vector3(0, -0.4, 0) - m
		var T := maxf(0.25, Vector2(d.x, d.z).length() / 17)
		# lobbed with a little lead: keep moving and it lands behind you
		var v := Vector3((d.x + P.vel.x * T * 0.6) / T, d.y / T + 4.5 * T, (d.z + P.vel.z * T * 0.6) / T).rotated(Vector3.UP, spread)
		G.items.launch("acid", m, v)
		var dist: float = P.eye().distance_to(m)
		G.audio.with_cat("enemies", func(): G.audio.swoosh(clampf(0.5 - dist / 60, 0.08, 0.4)); G.audio.groan(clampf(0.8 - dist / 40, 0.1, 0.6), pos, "attack"))

	func on_death_pose(fall: float) -> void:
		for a in arms:
			a.sh.rotation.x = lerpf(a.sh.rotation.x, -2.6, fall)
			a.el.rotation.x = -0.2

	func update(dt: float) -> bool:
		if dead:
			return animate_death(dt)
		if stun_t > 0:
			attack_t = 0
			return stunned_update(dt)
		var P: Node = G.player
		var n: float = G.now
		var dx: float = P.pos.x - pos.x
		var dz: float = P.pos.z - pos.z
		var dh := sqrt(dx * dx + dz * dz)
		var dist: float = P.eye().distance_to(pos + Vector3(0, 1.6, 0))
		# swipes reach your legs on a low crate; anything higher needs a climber
		var dy: float = P.pos.y - pos.y
		var reachable := dy > -1.1 and dy < (2.6 if boss else 1.65)
		var direct = climber and (P.pos.y > 1.3 or pos.y > 1.3) and dh < 16
		attack_cd -= dt
		var move := Vector3.ZERO
		var spd := speed
		var hold := false
		if kind == "bomber":
			# lights its fuse next to you, then goes off (no kill reward for letting it)
			attack_cd = 9
			if fuse_t <= 0 and dh < 2 and absf(dy) < 2.2:
				fuse_t = 0.55; G.audio.tone(900, 0.5, 0.12, "square", 2400)
			if fuse_t > 0:
				fuse_t -= dt
				if fuse_t <= 0:
					blow(); hp = 0; dead = true; hb_visible = false; _disable_hitboxes()
					return animate_death(dt)
			pus_mat.emission_energy_multiplier = (2.6 + sin(n * (40.0 if fuse_t > 0 else 5.0) + walk) * 1.6) * G.light_k() * (2.0 if fuse_t > 0 else 1.0)
		elif kind == "spitter":
			# stops at range with a clear view and lobs acid; still claws if you walk up to it
			los_t -= dt
			if los_t <= 0:
				los_t = 0.25
				has_los = dh < 26 and G.world.line_of_sight(pos + Vector3(0, 1.55, 0), P.eye())
			spit_cd -= dt
			if has_los and dh > 6 and dh < 24:
				hold = true
				if spit_cd <= 0 and attack_t <= 0 and spit_t <= 0:
					spit_cd = G.rnd(2.2, 3.4); spit_t = 0.45
			if spit_t > 0:
				spit_t -= dt
				if spit_t <= 0:
					spit()
			sac_mat.emission_energy_multiplier = (2.2 + sin(n * 4 + walk) * 0.8 + (4.0 if spit_t > 0 else 0.0)) * G.light_k()
		if attack_t > 0:
			attack_t += dt
			var p := attack_t / 0.7
			if not hit_done and p > 0.55:
				hit_done = true
				if dh < reach + 0.45 and reachable:
					P.damage(hit_dmg, pos)
					if boss:
						P.vel += Vector3(dx, 0, dz).normalized() * 9
						P.vel.y = 5; P.on_ground = false; P.shake = 1
					G.audio.with_cat("enemies", func(): G.audio.bite(0.9))
				else:
					G.audio.with_cat("enemies", func(): G.audio.swoosh(0.25))
			if p >= 1:
				attack_t = 0; attack_cd = G.rnd(0.35, 0.8)
			if dh > 0.9:
				move = Vector3(dx, 0, dz).normalized() * 0.35
		elif dh < reach and reachable and attack_cd <= 0:
			attack_t = 0.0001; hit_done = false
			G.audio.with_cat("enemies", func(): G.audio.groan(0.75, pos, "attack"))
		elif not hold and (dh > reach * 0.73 or (direct and not reachable and dh > 0.05)):
			move = Vector3(dx, 0, dz).normalized() if direct else steer_to(P.pos.x, P.pos.z, dt)
		# boss: roars and charges when you keep your distance
		if boss:
			charging = maxf(0, charging - dt)
			charge_t -= dt
			if charge_t <= 0 and dh > 5 and dh < 22:
				charge_t = maxf(4, 8 - boss * 0.6); charging = 1.8
				G.audio.with_cat("enemies", func(): G.audio.groan(1, pos, "attack"))
				P.shake = maxf(P.shake, 0.4)
			if charging > 0:
				spd *= 2.3
			if phase >= 2:
				# ground slam: rears up for a moment, then the shockwave
				if slam_t > 0:
					move = Vector3.ZERO
					slam_t -= dt
					if slam_t <= 0:
						slam()
				else:
					slam_cd -= dt
					if slam_cd <= 0 and dh < 9 and attack_t <= 0:
						slam_cd = 5.0 if phase == 3 else 7.5; slam_t = 0.9; charging = 0
						G.audio.with_cat("enemies", func(): G.audio.groan(1, pos, "attack"))
				# acid volley when you keep away
				volley_cd -= dt
				if volley_cd <= 0 and dh > 10 and dh < 32 and slam_t <= 0:
					volley_cd = 4.5 if phase == 3 else 6.5
					for i in range(-1, 2):
						spit(i * 0.2)
		var face := atan2(dx, dz) if dh < 5 or attack_t > 0 or hold else (atan2(move.x, move.z) if move.length_squared() > 0 else yaw)
		turn_to(face, dt, 9.0 if runner else 5.0)
		move_and_collide(move, spd, dt, 0.6 if boss else 0.38, direct)

		groan_t -= dt
		if groan_t <= 0:
			groan_t = G.rnd(3, 8)
			if dh < 28:
				G.audio.with_cat("enemies", func(): G.audio.groan(clampf(1.1 - dh / 28, 0.1, 0.8), pos))
		# animation: shambling or sprinting gait, arms reaching, overhead swipe when attacking
		var moving := move.length() * spd
		var amt := gait(dt, 2.2 if climbing else moving, { "stride": 0.75, "knee": 1.2, "rate": 2.0, "bob": 0.09, "ref": 5.0 } if runner \
			else { "stride": 0.42, "knee": 0.55, "rate": 2.9, "bob": 0.06, "ref": 2.2, "limp": limp })
		var lean := 0.42 if runner else 0.26
		spine.rotation = Vector3(lean - flinch * 0.45 + sin(n * 1.3 + walk) * 0.02, sin(walk) * 0.12 * amt,
			sin(walk) * (0.06 if runner else 0.16) * amt + flinch_side * flinch * 0.3)
		if spit_t > 0:
			spine.rotation.x -= 0.55 * sin(spit_t / 0.45 * PI)   # rears back before spitting
		head_g.rotation = Vector3(-lean * 0.6 + sin(n * 2.1 + walk) * 0.05, 0, head_tilt + sin(n * 0.9) * 0.08)
		# sudden neck jerks, chattering jaw, flickering eyes
		twitch_t -= dt
		if twitch_t <= 0:
			twitch_t = G.rnd(0.7, 3.2); tw = Vector3(G.rnd(-0.35, 0.35), G.rnd(-0.55, 0.55), G.rnd(-0.45, 0.45)); tw_k = 1
		tw_k = maxf(0, tw_k - dt * 4.5)
		head_g.rotation += tw * tw_k * tw_k
		var open := 0.6 if attack_t > 0 or spit_t > 0 else 0.16 + maxf(0, sin(n * 11 + walk * 2)) * 0.14
		jaw.rotation.x = lerpf(jaw.rotation.x, open, minf(1, dt * 14))
		eyes_mat.emission_energy_multiplier = (4.2 + sin(n * 9 + walk) * 1.2 + (-3.0 if randf() < 0.03 else 0.0)) * G.light_k()
		var swing := INF
		if attack_t > 0:
			var p := attack_t / 0.7
			swing = lerpf(-1.4, -2.5, G.smooth(p / 0.45)) if p < 0.45 else lerpf(-2.5, -0.35, G.smooth(clampf((p - 0.45) / 0.25, 0, 1)))
			spine.rotation.x += sin(minf(1, p) * PI) * 0.3
		for i in arms.size():
			var a: Dictionary = arms[i]
			var ph := walk + i * PI
			if slam_t > 0:
				a.sh.rotation.x = -3 + (0.9 - slam_t) * 0.4; a.el.rotation.x = -0.1
			elif swing != INF:
				a.sh.rotation.x = swing + i * 0.15; a.el.rotation.x = -0.15
			elif climbing:
				a.sh.rotation.x = -2.75 + sin(n * 9 + i * PI) * 0.45; a.el.rotation.x = -0.5 - maxf(0, sin(n * 9 + i * PI)) * 0.6
			elif runner:
				a.sh.rotation.x = -0.5 + sin(ph) * 0.9 * amt; a.el.rotation.x = -1.1
			else:
				a.sh.rotation.x = -1.35 + sin(n * 1.7 + i * 1.3) * 0.12 + sin(ph) * 0.1 * amt; a.el.rotation.x = -0.25
			a.sh.rotation.z = a.s * (0.08 + sin(n * 1.3 + i) * 0.04)
		common_update(dt)
		return true

# ============================================================ spawning, boss phases, update
func spawn_enemy() -> void:
	var Wd: Node = G.world
	var P: Node = G.player
	var spot := Vector2.INF
	var lvl: int = G.wave / 5 if G.boss_wave else 0
	var pe: Vector3 = P.eye()
	var min_d := 26.0 if lvl else (16.0 if G.mode == "zombie" else 22.0)
	for t in 80:
		var i := 1 + randi() % (World.GN - 2)
		var j := 1 + randi() % (World.GN - 2)
		if Wd.grid[i + j * World.GN] == 1:
			continue
		var x := i - World.HALF + 0.5
		var z := j - World.HALF + 0.5
		if Vector2(x - P.pos.x, z - P.pos.z).length() < min_d:
			continue
		var crowded := false
		for b in list:
			if not b.dead and Vector2(b.pos.x - x, b.pos.z - z).length() < 2:
				crowded = true
				break
		if crowded:
			continue
		spot = Vector2(x, z)
		if not Wd.line_of_sight(Vector3(x, 1.6, z), pe):
			break
	if spot == Vector2.INF:
		spot = Wd.MAP.fallback
	var e: Enemy = Zombie.new(spot.x, spot.y, G.wave, lvl) if G.mode == "zombie" else Bot.new(spot.x, spot.y, G.wave, lvl)
	if lvl:
		# twice the size, its own health bar at the top of the screen
		var k := 2.0 if G.mode == "zombie" else 1.9
		e.group.scale = Vector3.ONE * k
		e.scale_k = k
		e.bar_y *= 2; e.hb_visible = false
		e.drop_chance = 0; e.reaction = 0.4
		var p := e.pos + Vector3(0, 1, 0)
		for i in 6:
			G.fx.spawn_smoke(p + Vector3(G.rnd(-1.5, 1.5), G.rnd(0, 2), G.rnd(-1.5, 1.5)), 0x444048, 3)
		G.fx.particles(p, 0xff3030 if G.mode == "zombie" else 0xff1e5a, 40, Vector3.UP, 7)
		G.audio.with_cat("enemies", func(): G.audio.boss_horn())
	list.append(e)

func boss_phase(b: Enemy) -> void:
	var z := b is Zombie
	var sub := ("COLPO A TERRA E ACIDO · SALTA PER SCHIVARE L’ONDA" if z else "BOMBARDAMENTO · ESCI DAI CERCHI ROSSI") if b.phase == 2 \
		else ("FURIA · ARRIVA L’ORDA" if z else "FURIA · ARRIVANO I RINFORZI")
	G.ui.banner("%s · FASE %d" % [b.name, b.phase], sub)
	G.audio.with_cat("enemies", func(): G.audio.boss_horn())
	G.player.shake = maxf(G.player.shake, 0.8)
	var p := b.pos + Vector3(0, 1.5, 0)
	G.fx.particles(p, b.spark_color, 50, Vector3.UP, 9)
	G.fx.flash(p, 0xffc070, 8, 0.3)
	G.fx.shock(b.pos + Vector3(0, 0.12, 0), 7, 0.5)
	b.stun_t = maxf(b.stun_t, 1.1)   # staggers for a moment: a window to reload or back off
	b.on_phase()
	# reinforcements: a couple at phase 2, a pack at phase 3
	spawn_queue.append({ "b": b, "n": 2 if b.phase == 2 else 3 + mini(2, b.boss) })

func update(dt: float) -> void:
	for q in spawn_queue:
		var i := 0
		var t := 0
		while i < q.n and t < 60:
			t += 1
			var a := randf() * TAU
			var r := G.rnd(3, 8)
			var x: float = q.b.pos.x + cos(a) * r
			var z: float = q.b.pos.z + sin(a) * r
			if absf(x) > 38 or absf(z) > 38 or G.world.blocked_at(x, z):
				continue
			list.append(Zombie.new(x, z, G.wave, 0) if q.b is Zombie else Bot.new(x, z, G.wave, 0))
			G.wave_total += 1
			i += 1
	spawn_queue.clear()
	var keep: Array = []
	for e in list:
		if e.update(dt):
			keep.append(e)
		else:
			e.remove()
	list = keep
