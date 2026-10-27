# Spariaps — Giocatore: movimento, scivolata, scavalcamento, sporgersi, danni e seconda vita.
extends Node

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var on_ground := true
var hp := 100.0
var armor := 0.0
var last_hit := -99.0
var r := 0.4
var crouch := false
var crouch_t := 0.0
var bob := 0.0
var land_off := 0.0
var shake := 0.0
var roll := 0.0
var sprint_t := 0.0
var air_jumps := 1
var lean := 0
var lean_t := 0.0
var lean_v := Vector3.ZERO
var slide_t := 0.0
var slide_cd := 0.0
var slide_dir := Vector3.ZERO
var vault_cd := 0.0

const SLIDE_T := 0.8

func _ready() -> void:
	G.player = self

func reset(start: Vector3, armor0: float) -> void:
	pos = start; vel = Vector3.ZERO
	hp = 100; armor = armor0; yaw = 0; pitch = 0; on_ground = true; last_hit = -99
	crouch = false; crouch_t = 0; land_off = 0; shake = 0; roll = 0; sprint_t = 0; slide_t = 0; slide_cd = 0; vault_cd = 0
	lean = 0; lean_t = 0; lean_v = Vector3.ZERO; air_jumps = 1

func eye_height() -> float:
	return lerpf(1.62, 1.02, G.smooth(crouch_t))

func eye() -> Vector3:
	return Vector3(pos.x, pos.y + eye_height(), pos.z) + lean_v

func fwd() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

func is_aiming() -> bool:
	return G.aiming or (G.settings.autoAds and G.firing)

func toggle_lean(dir: int) -> void:
	lean = 0 if lean == dir else dir
	G.audio.with_cat("weapons", func(): G.audio.tone(700, 0.04, 0.03, "triangle", 500))

# slide: crouch while sprinting. A short burst of speed in the direction you were running, low profile, no steering
func start_slide() -> bool:
	var hs := Vector2(vel.x, vel.z).length()
	if not G.is_playing() or slide_t > 0 or slide_cd > 0 or not on_ground or sprint_t < 0.5 or hs < 6:
		return false
	slide_t = SLIDE_T; slide_cd = 0.5; crouch = false
	slide_dir = Vector3(vel.x / hs, 0, vel.z / hs)
	G.audio.tone(170, 0.45, 0.07, "sawtooth", 60)
	return true

func double_jump() -> void:
	if G.world.arena_on and not on_ground and air_jumps > 0:
		air_jumps -= 1
		vel.y = maxf(vel.y, 11.0 if G.pw("jump") else 8.0)
		G.fx.particles(pos + Vector3(0, 0.1, 0), 0x3affe0, 12, Vector3.DOWN, 3)
		G.audio.tone(260, 0.16, 0.12, "sine", 700)

func update(dt: float) -> void:
	var W: Node = G.weapons
	var I: Node = G.inp
	var w: Dictionary = W.cur()
	var f := fwd()
	var rt := right()
	var pad: Dictionary = I.pad
	# keyboard gives full-speed input, the left stick is analog (partial tilt = walk slower)
	var wish = f * ((1.0 if I.held("fwd") else 0.0) - (1.0 if I.held("back") else 0.0) + pad.my) \
		+ rt * ((1.0 if I.held("right") else 0.0) - (1.0 if I.held("left") else 0.0) + pad.mx)
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var want_sprint: bool = (I.held("sprint") and I.held("fwd")) or (pad.sprint and pad.my > 0.35)
	if want_sprint and crouch:
		crouch = false
	var sliding := slide_t > 0
	var sprint: bool = want_sprint and not G.firing and W.ads_t < 0.3 and on_ground and W.melee_t <= 0 and not sliding
	sprint_t = clampf(sprint_t + (1.0 if sprint else -1.0) * dt * 7.0, 0, 1)
	crouch_t = clampf(crouch_t + (1.0 if crouch or sliding else -1.0) * dt * (12.0 if sliding else 7.0), 0, 1)
	slide_cd = maxf(0, slide_cd - dt); vault_cd = maxf(0, vault_cd - dt)
	var A: bool = G.world.arena_on
	var speed: float = (8.5 if sprint else 5.5) * (1.1 if A else 1.0) * (0.6 if W.ads_t > 0.5 else 1.0) * lerpf(1, 0.5, crouch_t) \
		* w.get("speed", 1.0) * (1.4 if G.pw("haste") else 1.0) * (1.12 if G.perks.has("speed") else 1.0)
	if sliding:
		# fast at first, then friction wins; leaving the ground (a jump, a ledge) ends it with the momentum intact
		slide_t -= dt
		var v := lerpf(4.5, 12, maxf(0, slide_t) / SLIDE_T) * (1.2 if G.pw("haste") else 1.0)
		if on_ground:
			vel.x = slide_dir.x * v; vel.z = slide_dir.z * v
		else:
			slide_t = 0
	elif on_ground:
		vel.x += (wish.x * speed - vel.x) * minf(1, 12 * dt)
		vel.z += (wish.z * speed - vel.z) * minf(1, 12 * dt)
		# vault: sprinting into something low (a crate, a car bonnet, a window sill) hops you onto it
		if sprint_t > 0.6 and vault_cd <= 0 and wish.length_squared() > 0.25:
			var px = pos.x + wish.x * (r + 0.35)
			var pz = pos.z + wish.z * (r + 0.35)
			var top: float = G.world.ground_at(px, pz, pos.y + 0.79, r)
			var rise := top - pos.y
			if rise > 0.45 and not G.world.column_blocked(px, pz, r, top + 0.05, top + 1.3) and not G.world.column_blocked(pos.x, pos.z, r, pos.y + 1.85, top + 1.85):
				vel.y = sqrt(40 * (rise + 0.12)); on_ground = false; vault_cd = 0.6
				land_off = 0.06; G.audio.tone(240, 0.12, 0.06, "sine", 420)
	else:
		# air control keeps momentum (jump pads, strafe jumps) and only adds speed toward the input
		var cur = vel.x * wish.x + vel.z * wish.z
		var add := minf(maxf(0, speed - cur), speed * (5.0 if A or G.pw("jump") else 2.5) * dt)
		vel.x += wish.x * add; vel.z += wish.z * add
	if (I.held("jump") or pad.jump) and on_ground:
		slide_t = 0
		if crouch:
			crouch = false
		elif G.pw("jump"):
			vel.y = 14.0 if A else 12.5; on_ground = false; G.audio.tone(320, 0.22, 0.14, "sine", 900)
		else:
			vel.y = 8.8 if A else 7.0; on_ground = false
	vel.y -= 20 * dt
	var height := lerpf(1.8, 1.25, crouch_t)

	pos.x += vel.x * dt
	pos.z += vel.z * dt
	pos = G.world.collide_circle(pos, r, pos.y, height)
	for b in G.enemies.list:
		if b.dead or absf(pos.y - b.pos.y) > 1.5:
			continue
		var dx: float = pos.x - b.pos.x
		var dz: float = pos.z - b.pos.z
		var d := sqrt(dx * dx + dz * dz)
		if d < 0.8 and d > 1e-4:
			pos.x += dx / d * (0.8 - d); pos.z += dz / d * (0.8 - d)
	var prev_feet := pos.y
	var prev_vy := vel.y
	var was_ground := on_ground
	pos.y += vel.y * dt
	if vel.y > 0:
		var c: float = G.world.ceiling_at(pos.x, pos.z, r, prev_feet + height, pos.y + height)
		if c < INF:
			pos.y = c - height - 0.01; vel.y = 0
	var g: float = G.world.ground_at(pos.x, pos.z, prev_feet, r)
	if pos.y <= g:
		pos.y = g; vel.y = 0; on_ground = true
		air_jumps = 1
		if not was_ground and prev_vy < -4:
			land_off = minf(0.12 if G.pw("jump") else 0.2, -prev_vy * 0.016)
			G.audio.tone(90, 0.08, 0.15, "sine", 50)
	else:
		on_ground = false
	G.world.try_jump_pad()

	var D: Dictionary = G.D
	if G.now - last_hit > D.regenDelay * (0.5 if G.perks.has("regen") else 1.0):
		hp = minf(100, hp + D.regen * (2.0 if G.perks.has("regen") else 1.0) * dt)

	# camera: head bob, strafe roll, landing dip, shake
	var hs := Vector2(vel.x, vel.z).length()
	if on_ground:
		bob += hs * dt * 1.55
	var bob_amt = clampf(hs / 8.5, 0, 1) * (1.0 if on_ground else 0.0) * (1.0 - W.ads_t * 0.75)
	var lat := vel.dot(rt)
	roll = lerpf(roll, -lat * 0.0035, minf(1, dt * 8))
	land_off *= exp(-dt * 9)
	shake *= exp(-dt * 7)
	var sh := shake * 0.012
	var bob_y = sin(bob * 2) * 0.035 * bob_amt
	var bob_x = cos(bob) * 0.022 * bob_amt
	# lean: shift the eye sideways (stopping short of walls) and roll the view
	if not is_aiming() or sprint_t > 0.3:
		lean = 0
	lean_t += (lean - lean_t) * minf(1, dt * 10)
	var lean_dist := 0.45 * lean_t
	if absf(lean_dist) > 0.01:
		var e0 := Vector3(pos.x, pos.y + eye_height(), pos.z)
		var side := rt * signf(lean_dist)
		var h: Dictionary = G.world.ray(e0, e0 + side * (absf(lean_dist) + 0.25))
		if not h.is_empty():
			lean_dist = signf(lean_dist) * maxf(0, minf(absf(lean_dist), e0.distance_to(h.position) - 0.25))
	lean_v = rt * lean_dist + Vector3(0, -absf(lean_t) * 0.07, 0)
	var cam: Camera3D = G.camera
	cam.position = Vector3(pos.x + rt.x * bob_x, pos.y + eye_height() + bob_y - land_off, pos.z + rt.z * bob_x) + lean_v
	var sway := (1.0 - crouch_t * 0.6) if w.get("scope", false) and W.ads_t > 0.85 else 0.0   # breathing through the scope
	cam.rotation = Vector3(pitch + W.recoil_off + G.rnd(-sh, sh) + sin(G.now * 0.8) * 0.0018 * sway,
		yaw + G.rnd(-sh, sh) + cos(G.now * 1.1) * 0.0022 * sway, roll + sin(bob) * 0.005 * bob_amt - lean_t * 0.24)

# ============================================================ damage
func damage(amount: float, from: Vector3, raw := false) -> void:
	if not G.is_playing():
		return
	if G.pw("god"):
		shake = minf(1, shake + 0.1); G.audio.tone(1400, 0.06, 0.08, "triangle", 1900)
		return
	if not raw:
		amount *= G.D.dmg
	if G.perks.has("tank"):
		amount *= 0.7
	if armor > 0:
		var absorbed := minf(armor, amount * 0.7)
		armor -= absorbed; amount -= absorbed
	hp -= amount; last_hit = G.now
	G.inp.rumble(0.7, 0.5, 0.2)
	G.hurt = minf(1, G.hurt + 0.7)
	shake = minf(1, shake + 0.5)
	G.audio.tone(200, 0.15, 0.25, "sawtooth", 90)
	var v := from - pos
	G.ui.damage_dir(yaw + PI - atan2(v.x, v.z))
	if hp <= 0:
		if G.revives > 0:
			second_life()
		else:
			G.game.game_over()

# knocked down with a life in reserve: back on your feet, briefly untouchable, and everything around you is dazed
func second_life() -> void:
	G.revives -= 1
	G.ui.render_perks()
	hp = 60; last_hit = G.now; G.hurt = 0
	G.powers.god = maxf(G.powers.god, 3.5)
	G.blind = maxf(G.blind, 0.55)
	shake = 1
	var p := pos + Vector3(0, 0.12, 0)
	G.fx.shock(p, 9, 0.5)
	G.fx.particles(p + Vector3(0, 1, 0), 0xff5c7a, 40, Vector3.UP, 8)
	for b in G.enemies.list:
		if b.dead or Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length() > 9:
			continue
		b.stun_t = maxf(b.stun_t, 0.9 if b.boss else 2.4)
	var left := "TE NE RESTA ANCORA %s" % ("UNA" if G.revives == 1 else str(G.revives)) if G.revives > 0 else "ERA L’ULTIMA · LA PROSSIMA CADUTA È LA FINE"
	G.ui.banner("SECONDA VITA", left)
	G.inp.rumble(1, 1, 0.5)
	G.audio.tone(110, 0.5, 0.3, "sine", 55)
	var i := 0
	for fq in [392, 523, 659, 784]:
		G.audio.tone(fq, 0.3, 0.1, "triangle", fq, 0.12 + i * 0.09)
		i += 1
