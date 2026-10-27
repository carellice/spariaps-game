# Spariaps — Comandi: tastiera e mouse, controller (Xbox / PlayStation), rimappatura, vibrazione e aiuto alla mira.
extends Node

var pad := { "mx": 0.0, "my": 0.0, "jump": false, "sprint": false }
var device := -1
var pad_style := "xbox"
var pad_prev: Array = []
var phys2act := {}         # physical keycode -> action id
var bind_wait: Dictionary = {}   # { id, dev: "key" | "pad" } while the settings wait for a new key or button
var wheel_t := 0.0

func _ready() -> void:
	G.inp = self
	pad_prev.resize(16)
	pad_prev.fill(false)
	Input.joy_connection_changed.connect(_on_joy)
	rebuild_binds()
	_pick_device()

func pad_mode() -> bool:
	return G.settings.input == "pad"

func active_pad() -> bool:
	return device >= 0

func _pick_device() -> void:
	var pads := Input.get_connected_joypads()
	device = pads[0] if pads.size() > 0 else -1
	if device >= 0:
		var n := Input.get_joy_name(device).to_lower()
		pad_style = "ps" if (n.contains("ps") or n.contains("dualsense") or n.contains("dualshock") or n.contains("sony") or n.contains("wireless controller")) and not n.contains("xbox") else "xbox"

func pad_name() -> String:
	return Input.get_joy_name(device) if device >= 0 else ""

func _on_joy(_dev: int, connected: bool) -> void:
	_pick_device()
	if connected:
		set_input("pad", "Controller rilevato · modalità controller attiva")
	elif device < 0 and pad_mode():
		if G.is_playing():
			G.game.pause()
		set_input("kbm", "Controller scollegato · torno a mouse e tastiera")
	else:
		G.ui.input_changed()

func set_input(v: String, why := "") -> void:
	if G.settings.input != v:
		G.settings.input = v
		G.save_settings()
		G.firing = false; G.aiming = false
	if v == "kbm" and G.is_playing():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if v == "pad" and G.is_playing():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if v == "kbm":
		pad.mx = 0.0; pad.my = 0.0; pad.jump = false; pad.sprint = false
	G.ui.input_changed()
	if why != "":
		G.ui.pad_note(why)

func rumble(strong: float, weak: float, sec: float) -> void:
	if not pad_mode() or not G.is_playing() or device < 0:
		return
	Input.start_joy_vibration(device, clampf(weak, 0, 1), clampf(strong, 0, 1), sec)

# ============================================================ bindings
func rebuild_binds() -> void:
	phys2act = {}
	for a in G.ACTIONS:
		if a[2] != 0:
			phys2act[G.bind_of(a[0])] = a[0]

func held(id: String) -> bool:
	if not G.is_playing():
		return false
	var k := G.bind_of(id)
	return k != 0 and Input.is_physical_key_pressed(k)

func set_key_bind(id: String, code: int) -> void:
	var old := G.bind_of(id)
	for a in G.ACTIONS:
		if a[2] != 0 and a[0] != id and G.bind_of(a[0]) == code:
			G.settings.binds[a[0]] = old
	G.settings.binds[id] = code
	for a in G.ACTIONS:
		if G.settings.binds.has(a[0]) and int(G.settings.binds[a[0]]) == int(a[2]):
			G.settings.binds.erase(a[0])

func set_pad_bind(logical: int, phys: int) -> void:
	var old := G.pad_of(logical)
	for i in G.PAD_NAMES.size():
		if i != logical and G.pad_of(i) == phys:
			G.settings.padBinds[str(i)] = old
	G.settings.padBinds[str(logical)] = phys
	for k in G.settings.padBinds.keys():
		if int(G.settings.padBinds[k]) == int(k):
			G.settings.padBinds.erase(k)

func binds_changed() -> void:
	bind_wait = {}
	rebuild_binds()
	G.save_settings()
	G.ui.render_binds()

func pad_label(btn: String) -> String:
	var i := G.PAD_NAMES.find(btn)
	var L: Dictionary = G.PAD_LABELS[pad_style]
	return L[btn] if i < 0 else L[G.PAD_NAMES[G.pad_of(i)]]

const LABEL_ACT := { "E": "interact", "R": "reload", "INVIO": "skip", "W": "fwd", "A": "left", "S": "back", "D": "right", "Shift": "sprint", "Spazio": "jump", "C": "crouch" }

# prompts are written with the default key and button: show whatever they are bound to now
func key_label(kb: String, btn: String) -> String:
	if pad_mode() and active_pad():
		return pad_label(btn)
	var a: String = LABEL_ACT.get(kb, "")
	return G.key_name(G.bind_of(a)) if a != "" and G.settings.binds.has(a) else kb

# ============================================================ standard-mapping pad buttons on Godot's joypad API
# 0 A · 1 B · 2 X · 3 Y · 4 LB · 5 RB · 6 LT · 7 RT · 8 View · 9 Menu · 10 L3 · 11 R3 · 12-15 d-pad ↑↓←→
const JOY := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, -1, -2,
	JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]

func _phys(i: int) -> bool:
	var j: int = JOY[i]
	if j == -1:
		return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.4
	if j == -2:
		return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	return Input.is_joy_button_pressed(device, j)

static func dz(x: float, y: float, d: float) -> Vector2:
	# radial dead zone, rescaled so the stick still reaches 1
	var m := sqrt(x * x + y * y)
	if m < d:
		return Vector2.ZERO
	var k := minf(1, (m - d) / (1 - d)) / m
	return Vector2(x * k, y * k)

func assist_friction() -> float:
	if not G.settings.aimAssist:
		return 1.0
	var cam: Camera3D = G.camera
	var eye := cam.global_position
	var f := -cam.global_basis.z
	var fr := 1.0
	for b in G.enemies.list:
		if b.dead:
			continue
		var t: Vector3 = b.pos + Vector3(0, 1.2, 0) - eye
		var d := t.length()
		if d < 1 or d > 70:
			continue
		# angular window scales with distance so it matches the body width on screen
		var ang := acos(clampf(t.dot(f) / d, -1, 1))
		if ang < atan(0.9 / d) + 0.02:
			fr = minf(fr, 0.4 if G.weapons.ads_t > 0.5 else 0.6)
	return fr

func poll(dt: float) -> void:
	if device < 0:
		return
	var cur: Array = []
	for i in 16:
		cur.append(_phys(i))
	var down := func(i: int) -> bool: return cur[G.pad_of(i)] and not pad_prev[G.pad_of(i)]
	var up := func(i: int) -> bool: return not cur[G.pad_of(i)] and pad_prev[G.pad_of(i)]
	var ax := [Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)]
	# any input from the pad while the mouse is selected switches back to the controller
	if not pad_mode():
		var fresh := false
		for i in 16:
			if cur[i] and not pad_prev[i]:
				fresh = true
		for a in ax:
			if absf(a) > 0.6:
				fresh = true
		if fresh:
			set_input("pad", "Controller rilevato · modalità controller attiva")
		pad_prev = cur
		return
	# settings waiting for a new button: the first one pressed is taken and does nothing else
	if bind_wait.get("dev", "") == "pad":
		for i in 16:
			if cur[i] and not pad_prev[i]:
				var a: Array = G.action_def(bind_wait.id)
				set_pad_bind(a[3], i)
				binds_changed()
				break
		pad_prev = cur
		return
	var P: Node = G.player
	var Wp: Node = G.weapons
	if G.is_playing() and not G.ui.overlay_open():
		var m := dz(ax[0], ax[1], 0.16)
		pad.mx = m.x; pad.my = -m.y
		var r := dz(ax[2], ax[3], 0.12)
		var mag := r.length()
		if mag > 0:
			r *= pow(mag, 1.7) / mag   # response curve: fine aim near the center
		var ads := (0.3 if Wp.cur().get("scope", false) else 0.6) if Wp.ads_t > 0.5 else 1.0
		var rate: float = 3.3 * G.settings.padSens * ads * (assist_friction() if mag > 0 else 1.0)
		var dyaw := r.x * rate * dt
		var dpitch := r.y * rate * 0.7 * dt * (-1.0 if G.settings.invertY else 1.0)
		P.yaw -= dyaw
		P.pitch = clampf(P.pitch - dpitch, -1.5, 1.5)
		G.sway += Vector2(dyaw, dpitch) * 0.068
		pad.jump = cur[G.pad_of(0)]
		if down.call(0): game_action("jump")
		if down.call(1): game_action("crouch")
		if down.call(2):
			if not G.items.interact_target().is_empty(): G.items.interact()
			else: Wp.start_reload()
		if down.call(3): Wp.switch_weapon(Wp.other_slot())
		if down.call(4): G.items.throw_item("frag")
		if down.call(5): Wp.start_melee()
		# Rainbow Six Siege on console: L3/R3 lean while aiming, otherwise sprint / melee
		if down.call(10):
			if P.is_aiming(): P.toggle_lean(-1)
			else: pad.sprint = not pad.sprint
		if down.call(11):
			if P.is_aiming(): P.toggle_lean(1)
			else: Wp.start_melee()
		if pad.my < 0.2:
			pad.sprint = false
		if down.call(12): G.items.throw_item("stun")
		if down.call(13): G.items.throw_item("smoke")
		if down.call(14): G.items.throw_item("tknife")
		if down.call(15): G.items.drop_current_weapon()
		if down.call(8): game_action("skip")
		if down.call(7):
			G.firing = true; G.trigger_queued = true; G.trigger_t = G.now
		if up.call(7):
			G.firing = false
		if G.settings.adsHold:
			if down.call(6): G.aiming = true
			if up.call(6): G.aiming = false
		elif down.call(6):
			G.aiming = not G.aiming
		if down.call(9):
			G.game.pause()
	else:
		pad.mx = 0.0; pad.my = 0.0; pad.jump = false
		# menus: Godot's own focus navigation reads the d-pad / stick (ui_* actions); here only the extras
		if cur[9] and not pad_prev[9]:
			G.ui.pad_start()
		if (cur[4] and not pad_prev[4]) or (cur[5] and not pad_prev[5]):
			G.ui.pad_bumper(1 if cur[5] else -1)
		var sc := dz(ax[2], ax[3], 0.2)
		if sc.y != 0:
			G.ui.pad_scroll(sc.y * absf(sc.y) * 1400 * dt)
	pad_prev = cur

# ============================================================ keyboard + mouse
func _input(event: InputEvent) -> void:
	# while waiting for a key nothing else must react to it
	if bind_wait.get("dev", "") == "key" and event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		get_viewport().set_input_as_handled()
		if code == KEY_ESCAPE or code in G.FIXED_KEYS:
			bind_wait = {}
			G.ui.render_binds()
			return
		set_key_bind(bind_wait.id, code)
		binds_changed()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var e: InputEventKey = event
		var code: int = e.physical_keycode
		if e.pressed and not e.echo and code == KEY_M:
			G.audio.set_muted(not G.muted)
			G.ui.sound_changed()
			return
		if e.pressed and not e.echo and code == KEY_ESCAPE:
			G.ui.escape()
			return
		if not e.pressed:
			return
		var act: String = phys2act.get(code, "")
		if act == "pause" and not e.echo:
			if G.is_playing():
				G.game.pause()
			elif G.state == "paused" and not G.ui.overlay_open():
				G.game.enter_game()
			return
		if G.state == "shop" and not e.echo and act == "interact":
			G.game.close_shop()
			return
		if not G.is_playing():
			return
		if code == KEY_1 and not e.echo: G.weapons.switch_weapon(_slot(0))
		elif code == KEY_2 and not e.echo: G.weapons.switch_weapon(_slot(1))
		elif code == KEY_F and not e.echo: G.weapons.start_melee()
		if act != "" and act not in ["fwd", "back", "left", "right", "sprint"]:
			game_action(act, e.echo)
	elif G.is_playing() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var mm: InputEventMouseMotion = event
			var Wp: Node = G.weapons
			var s: float = 0.0022 * G.settings.sens * ((0.28 if Wp.cur().get("scope", false) else 0.6) if Wp.ads_t > 0.5 else 1.0)
			G.player.yaw -= mm.relative.x * s
			G.player.pitch = clampf(G.player.pitch - mm.relative.y * s, -1.5, 1.5)
			G.sway += Vector2(mm.relative.x, mm.relative.y) * 0.00015
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				G.firing = mb.pressed
				if mb.pressed:
					G.trigger_queued = true; G.trigger_t = G.now
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				if G.settings.adsHold:
					G.aiming = mb.pressed
				elif mb.pressed:
					G.aiming = not G.aiming
			elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				var t := Time.get_ticks_msec() / 1000.0
				if t - wheel_t > 0.25:
					wheel_t = t
					G.weapons.switch_weapon(G.weapons.other_slot())

func _slot(i: int) -> String:
	var s: Variant = G.slots[i]
	return s if s else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		G.firing = false; G.aiming = false

# gameplay actions shared by the keyboard and the controller
func game_action(act: String, echo := false) -> void:
	var P: Node = G.player
	var Wp: Node = G.weapons
	match act:
		"jump":
			if not echo:
				P.double_jump()
		"skip":
			if G.wave > 0 and G.wave_break > 3:
				G.wave_break = 3
		"reload":
			Wp.start_reload()
		"swap":
			# Rainbow Six style lean: while aiming Q/E toggle leaning left/right instead of their usual action
			if P.is_aiming():
				if not echo: P.toggle_lean(-1)
			else:
				Wp.switch_weapon(Wp.other_slot())
		"interact":
			if P.is_aiming():
				if not echo: P.toggle_lean(1)
			elif not echo:
				G.items.interact()
		"melee":
			Wp.start_melee()
		"crouch":
			if not echo and not P.start_slide():
				P.crouch = not P.crouch
		"drop":
			if not echo: G.items.drop_current_weapon()
		"frag", "stun", "smoke", "tknife":
			G.items.throw_item(act)
