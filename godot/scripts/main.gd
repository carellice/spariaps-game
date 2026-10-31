# Spariaps — Avvio: scena 3D, luci, ambiente, vista delle armi, post-processing e ciclo principale.
extends Node

const World_ := preload("res://scripts/world.gd")
const Audio_ := preload("res://scripts/audio.gd")
const Fx_ := preload("res://scripts/fx.gd")
const Player_ := preload("res://scripts/player.gd")
const Weapons_ := preload("res://scripts/weapons.gd")
const Enemies_ := preload("res://scripts/enemies.gd")
const Items_ := preload("res://scripts/items.gd")
const Game_ := preload("res://scripts/game.gd")
const Inp_ := preload("res://scripts/inp.gd")
const Ui_ := preload("res://scripts/ui.gd")

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var torch: SpotLight3D
var muzzle_light: OmniLight3D
var gun_view: SubViewportContainer
var gun_vp: SubViewport
var gun_light: DirectionalLight3D
var gun_env: Environment
var grade: ColorRect
var grade_tint := Color(1, 1, 1)
var menu_t := 0.0
var fps_n := 0
var fps_t := 0.0
var autotest := false
var auto_t := 0.0
var booting := true
var boot := {}

const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float hurt = 0.0;
uniform float aberr = 0.0015;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = dot(d, d);
	vec2 off = d * aberr * (0.4 + r * 4.0);
	vec3 c = vec3(texture(screen, uv + off).r, texture(screen, uv).g, texture(screen, uv - off).b);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, 1.12) * tint;
	c = (c - 0.5) * 1.05 + 0.5;
	c *= 1.0 - r * 0.75;
	c = mix(c, c * vec3(1.35, 0.45, 0.4) + vec3(0.12, 0.0, 0.0), hurt * smoothstep(0.04, 0.32, r));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

func _ready() -> void:
	G.main = self
	randomize()
	G.load_all()
	autotest = OS.get_cmdline_user_args().has("--autotest")
	get_tree().auto_accept_quit = false
	get_window().title = "Spariaps"
	_boot_screen()
	await _boot_step(0.04, "Preparo la scena")
	_scene()
	# the game nodes stay frozen until everything is built, so nothing reacts to input half-way through
	var parts: Array[Node] = []
	for s in [World_, Audio_, Fx_, Player_, Weapons_, Enemies_, Items_, Game_, Inp_, Ui_]:
		var n := Node.new()
		n.set_script(s)
		n.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(n)
		parts.append(n)
	G.fx.setup()
	await _boot_step(0.15, "Costruisco le mappe")
	if autotest:
		_snap("loading")
	G.world.build()
	await _boot_step(0.5, "Preparo armi e nemici")
	_gun_view()
	G.enemies.setup()
	G.items.setup()
	_grade()
	await _boot_step(0.68, "Carico l’interfaccia")
	G.ui.build()
	G.world.set_map(str(G.sget("map", "city")))
	G.world.apply_atmosphere(G.mode)
	apply_quality()
	apply_fullscreen()
	await _boot_step(0.82, "Compilo gli shader")
	for n in parts:
		n.process_mode = Node.PROCESS_MODE_INHERIT
	booting = false
	G.game.show_main_menu()
	# a few frames of the real scene behind the loading screen: shaders get compiled before it fades away
	for i in 8:
		boot.bar.value = lerpf(0.82, 1.0, (i + 1) / 8.0)
		await get_tree().process_frame
	boot.status.text = "Pronto"
	var tw := create_tween()
	tw.tween_property(boot.root, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(boot.layer.queue_free)

# ============================================================ loading screen shown while the game builds itself
func _boot_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var root := ColorRect.new()
	root.color = Color(0.043, 0.059, 0.086)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	gt.gradient = Gradient.new()
	gt.gradient.colors = PackedColorArray([Color(1, 0.42, 0.24, 0.16), Color(1, 0.42, 0.24, 0.0)])
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(glow)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(120, 120)
	v.add_child(logo)
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	bold.font_weight = 700
	var title := Label.new()
	title.text = "SPARIAPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", bold)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#eef2f7"))
	v.add_child(title)
	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 1.0; bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 8)
	for k in [["background", Color(1, 1, 1, 0.08)], ["fill", Color("#ff6b3d")]]:
		var st := StyleBoxFlat.new()
		st.bg_color = k[1]
		st.set_corner_radius_all(4)
		bar.add_theme_stylebox_override(k[0], st)
	v.add_child(bar)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_override("font", bold)
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 0.6))
	v.add_child(status)
	boot = { "layer": layer, "root": root, "bar": bar, "status": status }

# shows the next phase and waits one frame so it is actually drawn before the heavy work starts
func _boot_step(p: float, text: String) -> void:
	boot.bar.value = p
	boot.status.text = text.to_upper()
	await get_tree().process_frame

func _scene() -> void:
	var root := Node3D.new()
	root.name = "Scene"
	add_child(root)
	G.scene_root = root
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 30
	sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# filmic look: AgX keeps bright colours from clipping, a touch of contrast and saturation on top
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 0.6); env.set_glow_level(2, 0.8); env.set_glow_level(3, 0.35); env.set_glow_level(4, 0.0)
	# contact shadows in corners and under props, bounced light, reflections on glossy floors
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.15
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.55, 0.5, 0.65)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-deg_to_rad(52), deg_to_rad(56), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 1.4
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 75
	cam.near = 0.05
	cam.far = 400
	cam.rotation_order = EULER_ORDER_YXZ
	root.add_child(cam)
	cam.current = true
	G.camera = cam
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = G.col(0xffb060)
	muzzle_light.omni_range = 14
	muzzle_light.position = Vector3(0.2, -0.1, -1)
	muzzle_light.light_energy = 0
	cam.add_child(muzzle_light)
	# weapon torch, only switched on at night (zombie mode)
	torch = SpotLight3D.new()
	torch.light_color = Color(1, 0.95, 0.84)
	torch.spot_range = 40
	torch.spot_angle = 24
	torch.spot_attenuation = 1.4
	torch.position = Vector3(0.25, -0.2, 0)
	torch.rotation.x = -0.04
	torch.shadow_enabled = false
	torch.visible = false
	cam.add_child(torch)

# the weapon in your hands: its own small 3D world, rendered on top of the scene
func _gun_view() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	gun_view = SubViewportContainer.new()
	gun_view.stretch = true
	gun_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	gun_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun_view.visible = false
	layer.add_child(gun_view)
	gun_vp = SubViewport.new()
	gun_vp.own_world_3d = true
	gun_vp.transparent_bg = true
	gun_vp.world_3d = World3D.new()
	gun_view.add_child(gun_vp)
	var groot := Node3D.new()
	gun_vp.add_child(groot)
	var genv := Environment.new()
	# same sky as the world for reflections, so metal parts shine instead of looking painted
	genv.background_mode = Environment.BG_CLEAR_COLOR
	genv.sky = env.sky
	genv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	genv.ambient_light_color = Color(0.75, 0.8, 0.9)
	genv.ambient_light_energy = 0.45
	genv.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	genv.tonemap_mode = Environment.TONE_MAPPER_AGX
	genv.tonemap_exposure = 1.05
	genv.adjustment_enabled = true
	genv.adjustment_contrast = 1.08
	genv.adjustment_saturation = 1.15
	gun_env = genv
	var gwe := WorldEnvironment.new()
	gwe.environment = genv
	groot.add_child(gwe)
	var gcam := Camera3D.new()
	gcam.fov = 60
	gcam.near = 0.01
	gcam.far = 10
	groot.add_child(gcam)
	gcam.current = true
	gun_light = DirectionalLight3D.new()
	gun_light.light_color = G.col(0xfff2e0)
	gun_light.light_energy = 2.2
	gun_light.rotation = Vector3(-0.9, 0.6, 0)
	groot.add_child(gun_light)
	var rim := DirectionalLight3D.new()
	rim.light_color = G.col(0x9ecbff)
	rim.light_energy = 1.0
	rim.rotation = Vector3(-0.2, PI + 1.1, 0)
	groot.add_child(rim)
	G.weapons.setup(groot, gcam)

func _grade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	grade = ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader("grade", GRADE_SHADER)
	grade.material = m
	layer.add_child(grade)

# graphics presets: resolution scale, shadows, bloom and MSAA
func apply_quality() -> void:
	var Q: Dictionary = G.QUALITY.get(G.settings.quality, G.QUALITY.high)
	var vp := get_viewport()
	vp.scaling_3d_scale = Q.scale
	var msaa: int = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][Q.msaa]
	vp.msaa_3d = msaa
	gun_vp.msaa_3d = msaa
	sun.shadow_enabled = Q.shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if G.settings.quality == "high" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(4096 if G.settings.quality == "high" else 2048, true)
	env.glow_enabled = Q.glow
	env.ssao_enabled = G.settings.quality != "low"
	env.ssil_enabled = G.settings.quality == "high"
	env.ssr_enabled = G.settings.quality == "high"
	sun.light_angular_distance = 0.6 if G.settings.quality == "high" else 0.0
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if G.settings.quality != "low" else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = true
	G.world.ambient.visible = G.settings.quality != "low"
	G.world.apply_atmosphere(G.mode)

func apply_fullscreen() -> void:
	var w := get_window()
	if autotest:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1600, 900)
		return
	if G.settings.fullscreen:
		w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	elif w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or w.mode == Window.MODE_FULLSCREEN:
		w.mode = Window.MODE_MAXIMIZED

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if booting:
			get_tree().quit()
		else:
			G.game.quit_game()

# ============================================================ main loop
func _process(delta: float) -> void:
	if booting:
		return
	var dt := minf(delta, 0.05)
	if G.settings.fps:
		fps_n += 1; fps_t += delta
		if fps_t >= 0.5:
			G.ui.set_fps(roundi(fps_n / fps_t)); fps_n = 0; fps_t = 0
	G.inp.poll(dt)
	if G.state == "playing":
		G.now += dt
		G.player.update(dt)
		G.audio.with_cat("weapons", func(): G.weapons.update(dt))
		G.audio.cat = "enemies"
		G.enemies.update(dt)
		G.audio.cat = "fx"
		if G.state == "playing":
			G.game.update(dt)
		G.fx.update(dt)
		if G.state == "playing":
			G.ui.update_hud(dt)
	elif G.state == "menu":
		menu_t += dt * 0.08
		var o: Vector2 = G.world.MAP.orbit
		G.camera.position = Vector3(sin(menu_t) * o.x, o.y, cos(menu_t) * o.x)
		G.camera.look_at(Vector3(0, 2, 0))
		G.fx.update(dt)
	G.world.update_ambient()
	# post-processing: hurt vignette, chromatic aberration, colour grade
	G.hurt = maxf(0.0, G.hurt - dt * 1.6) if G.state == "playing" else G.hurt
	var hp: float = G.player.hp
	var low := (35 - hp) / 35 * (0.55 + 0.25 * sin(G.now * 7)) if hp < 35 and G.state == "playing" else 0.0
	var h := maxf(G.hurt, low)
	var gm: ShaderMaterial = grade.material
	gm.set_shader_parameter("hurt", h)
	gm.set_shader_parameter("aberr", 0.0015 + h * 0.012)
	gm.set_shader_parameter("tint", Vector3(grade_tint.r, grade_tint.g, grade_tint.b))
	gun_light.light_energy = 1.2 if G.mode == "zombie" else 2.2
	if autotest:
		_autotest(dt)


# ============================================================ automatic smoke test (godot -- --autotest [--shots=DIR]): plays each mode for a while and quits
var auto_step := 0
var shot_dir := ""
var shot_n := 0

func _snap(name: String) -> void:
	if shot_dir == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				shot_dir = a.substr(8)
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	shot_n += 1
	var n := shot_n
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("%s/%02d-%s.jpg" % [shot_dir, n, name], 0.85)

const Enemies_s := preload("res://scripts/enemies.gd")
var plan: Array = []
var plan_i := 0

func _aim_nearest(dt: float) -> void:
	var P: Node = G.player
	var best: Object = null
	var bd := 999.0
	for e in G.enemies.list:
		if not e.dead and e.pos.distance_to(P.pos) < bd:
			best = e; bd = e.pos.distance_to(P.pos)
	if best:
		var to: Vector3 = best.pos + Vector3(0, 1.2 * best.scale_k, 0) - P.eye()
		P.yaw = atan2(-to.x, -to.z)
		P.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	else:
		P.yaw += dt * 0.6

func _start(map: String, md: String) -> void:
	if G.state != "menu":
		G.game.go_main_menu()
	G.game.use_map(map); G.mode = md
	G.game.start_new_game()
	G.wave_break = 0.5
	G.cash = 30000

func _spawn(kind: String) -> void:
	var P: Node = G.player
	var x: float = clampf(P.pos.x + 8, -36, 36)
	var z: float = clampf(P.pos.z + 3, -36, 36)
	var e: Object = Enemies_s.Zombie.new(x, z, 6, 0, kind) if G.mode == "zombie" else Enemies_s.Bot.new(x, z, 6, 0, kind)
	G.enemies.list.append(e)

func _boss() -> void:
	G.enemies.clear()
	G.wave = 4; G.wave_break = 0.01; G.to_spawn = 0

func _hurt_boss() -> void:
	var b: Object = G.enemies.boss()
	if b:
		b.damage(b.max_hp * 0.36, false, "rifle")

func _build_plan() -> void:
	var t := [0.0]
	var at := func(dt_: float, f: Callable) -> void:
		t[0] += dt_
		plan.append([t[0], f])
	at.call(2.0, func(): _snap("menu"))
	at.call(0.3, func(): G.ui.open_settings())
	at.call(0.8, func(): _snap("settings"); G.ui.escape())
	at.call(0.3, func(): G.ui.open_locker())
	at.call(0.5, func(): G.ui._pick_look("camo", "bosco"); _snap("locker"); G.ui.escape())
	at.call(0.3, func(): G.ui.m.quit.pressed.emit())
	at.call(0.4, func(): assert(G.ui.m.quit_dlg.visible); _snap("quit"))
	at.call(0.3, func(): G.ui.escape())
	at.call(0.3, func(): G.ui.show_map_menu())
	at.call(1.5, func(): _snap("maps"); G.ui._pick_map("city"))
	at.call(0.3, func(): G.ui._show(G.ui.m.map, false); G.ui.show_class_menu(false))
	at.call(0.5, func(): G.ui._pick_class("assault"); _snap("classes"); G.ui._class_back(); G.ui._show(G.ui.m.map, false))
	# zombie city: buildings, box, shops, every weapon, throwables, special zombies
	at.call(0.3, func(): _start("city", "zombie"))
	at.call(2.0, func(): _snap("zombie"))
	at.call(0.2, func(): G.world.set_house(G.world.MAP.houses[0], true))
	at.call(0.5, func(): G.items.open_box())
	at.call(3.6, func(): G.items.take_box_weapon())
	at.call(0.5, func(): G.game.open_shop("bench"))
	at.call(0.5, func(): G.game.buy_upgrade(G.weapons.current, "mag"); G.game.buy_upgrade(G.weapons.current, "dmg"); _snap("bench"); G.game.close_shop())
	at.call(0.3, func(): G.wave_break = 30.0; G.game.open_shop("perks"))
	at.call(0.5, func(): G.game.buy_perk("tank"); G.game.buy_perk("revive"); _snap("perks"); G.game.close_shop(); G.wave_break = 0.5)
	for k in ["shotgun", "sniper", "lmg", "smg", "magnum", "uzi", "burst", "dmr", "minigun", "rocket", "raygun"]:
		at.call(1.6, func(): G.items.give_weapon(k))
	at.call(0.5, func(): G.aiming = true)
	at.call(0.6, func(): _snap("scope"); G.aiming = false)
	for k in ["frag", "stun", "smoke", "tknife"]:
		at.call(0.7, func(): G.equip[k] = 2; G.items.throw_item(k))
	for k in ["bomber", "spitter", "armored"]:
		at.call(0.4, func(): _spawn(k))
	at.call(3.0, func(): _snap("specials"))
	at.call(0.5, func(): G.items.drop_current_weapon())
	at.call(0.5, func(): G.items.spawn_drop("rifle", 10, G.player.pos); G.items.interact())
	at.call(0.5, func(): _boss())
	at.call(4.0, func(): _snap("boss-zombie"); _hurt_boss())
	at.call(2.5, func(): _hurt_boss())
	at.call(4.0, func(): _snap("boss-phase3"); _hurt_boss())
	at.call(2.0, func(): G.game.pause())
	at.call(0.5, func(): _snap("pause"); G.ui.show_class_menu(true))
	at.call(0.4, func(): G.ui._pick_class("gunner"); G.ui._class_start())
	# classic arena: sniper, Colosso and its barrage, then death
	at.call(1.0, func(): _start("arena", "classic"))
	at.call(2.5, func(): _spawn("sniper"))
	at.call(3.0, func(): _snap("classic"))
	at.call(0.3, func(): _boss())
	at.call(4.0, func(): _snap("boss-classic"); _hurt_boss())
	at.call(3.0, func(): _hurt_boss())
	at.call(4.0, func(): _snap("barrage"))
	at.call(0.5, func(): G.revives = 0; G.powers.god = 0; G.player.armor = 0; G.player.damage(500, G.player.pos, true))
	at.call(1.0, func(): _snap("dead"))
	at.call(0.5, func(): G.game.go_main_menu())
	at.call(1.0, func(): print("AUTOTEST DONE · kills %d · fps %d" % [G.career.kills, Engine.get_frames_per_second()]); get_tree().quit())

func _autotest(dt: float) -> void:
	if plan.is_empty():
		_build_plan()
	auto_t += dt
	while plan_i < plan.size() and auto_t >= plan[plan_i][0]:
		plan[plan_i][1].call()
		plan_i += 1
	if G.is_playing():
		_aim_nearest(dt)
		G.firing = fmod(auto_t, 1.2) < 0.8
		G.trigger_queued = true; G.trigger_t = G.now
		G.player.hp = maxf(G.player.hp, 40) if plan_i < plan.size() - 4 else G.player.hp
