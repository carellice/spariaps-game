# Spariaps — Interfaccia: HUD, menu, impostazioni, armadietto e negozi.
# Tutto è costruito in codice con lo stesso stile "vetro" della versione browser; col controller i menu si navigano con il focus.
extends Node

const ACC := Color("#ff6b3d")
const ACC2 := Color("#ffb36b")
const GOOD := Color("#34d399")
const BAD := Color("#ff4d4d")
const ARMOR := Color("#4aa8ff")
const ARMOR2 := Color("#9ad4ff")
const TXT := Color("#eef2f7")
const MUT := Color(0.93, 0.95, 0.97, 0.6)
const LINE := Color(1, 1, 1, 0.09)

const SUBTITLES := {
	"classic": "Arena: ondate di bot armati, piattaforme sospese, trampolini e doppio salto. Muoviti veloce, prendi quota e non restare mai fermo.",
	"zombie": "È calata la notte e l’arena è infestata. Le orde crescono a ogni ondata, e gli arrampicatori dagli occhi viola scalano casse e muri: nessun posto è davvero sicuro.",
}

const ICONS := {
	"rifle": '<svg viewBox="0 0 64 22" fill="currentColor"><path d="M1 8h6l2-2h22l2-2h9v2h9V4h2v4h9v3H48l-3 2h-9l-3 8h-6l2-8H16l-2 5H5l1-5H1z"/></svg>',
	"pistol": '<svg viewBox="0 0 34 22" fill="currentColor"><path d="M2 3h28v3h2v3H14l-3 11H4l3-11H2z"/></svg>',
	"knife": '<svg viewBox="0 0 52 16" fill="currentColor"><path d="M1 6h13v4H1zM14 3h4v10h-4zM18 5h22l11 3-11 3H18z"/></svg>',
	"cross": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6v7h7v6h-7v7H9v-7H2V9h7z"/></svg>',
	"shield": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l8 3v6c0 5-3.4 9.3-8 11-4.6-1.7-8-6-8-11V5z"/></svg>',
	"shotgun": '<svg viewBox="0 0 66 18" fill="currentColor"><path d="M1 7h8l2-2h41v2h13v3H52v2H34l-2 1H19l-3 5H9l2-5H1z"/></svg>',
	"sniper": '<svg viewBox="0 0 74 22" fill="currentColor"><path d="M1 12h8l2-2h14V7h3V4h16v3h3v3h26v3H49l-2 2H35l-3 7h-6l2-7H14l-2 4H4l1-4H1z"/></svg>',
	"lmg": '<svg viewBox="0 0 66 26" fill="currentColor"><path d="M1 9h7l2-2h24V3h12v4h19v3H47v3h-4a7 7 0 0 1-14 0H16l-2 5H6l1-5H1z"/></svg>',
	"smg": '<svg viewBox="0 0 46 24" fill="currentColor"><path d="M1 6h4l1-2h22l1 2h16v3H30v3h-4l-2 10h-5l2-10h-6l-2 4H5l1-4H1z"/></svg>',
	"jump": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l7-7 7 7M5 19l7-7 7 7"/></svg>',
	"haste": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.5 1L4 14h6.5L9 23l11-14h-6.8z"/></svg>',
	"quad": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a9 9 0 0 0-9 9c0 3 1.5 5.2 3.5 6.5V21h3v-2h1v2h3v-2h1v2h3v-3.5c2-1.3 3.5-3.5 3.5-6.5a9 9 0 0 0-9-9zm-3.5 8a2 2 0 1 1 0 4 2 2 0 0 1 0-4zm7 0a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"/></svg>',
	"ammo": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"><path d="M12 12c-2-2.7-3.7-4-5.5-4a4 4 0 0 0 0 8c1.8 0 3.5-1.3 5.5-4zm0 0c2 2.7 3.7 4 5.5 4a4 4 0 0 0 0-8c-1.8 0-3.5 1.3-5.5 4z"/></svg>',
	"god": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1.5l3.1 6.6 7.2.9-5.3 5 1.4 7.1L12 17.6l-6.4 3.5L7 14l-5.3-5 7.2-.9z"/></svg>',
	"coin": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15.9V19h-2v-1.1c-1.6-.3-2.8-1.3-3-2.9h2c.2.7.9 1.2 2 1.2 1.3 0 1.8-.6 1.8-1.2 0-.7-.4-1.1-2-1.5-2-.5-3.4-1.2-3.4-3 0-1.4 1.1-2.4 2.6-2.8V6.6h2v1.1c1.5.3 2.4 1.4 2.5 2.7h-2c-.1-.7-.6-1.1-1.6-1.1-1 0-1.6.5-1.6 1.1 0 .6.5.9 2 1.3 2 .5 3.4 1.3 3.4 3.2 0 1.5-1.1 2.6-2.7 3z"/></svg>',
	"frag": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 2h5v2h-1v1.1A7 7 0 1 1 7.6 7L6.3 5.7l1.4-1.4L9 5.6a7 7 0 0 1 3-.5V4h-2zm2 6a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm-2 2h4v1.5h-4zm0 3h4v1.5h-4z"/></svg>',
	"stun": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6v2h-1v2h2a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h2V4H9zm-.5 8v2h7v-2zm0 4v2h7v-2z"/></svg>',
	"smoke": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 11h4v2h1a1 1 0 0 1 1 1v8H8v-8a1 1 0 0 1 1-1h1z"/><circle cx="9" cy="6" r="3"/><circle cx="14.5" cy="4.5" r="2.5"/><circle cx="16" cy="9" r="2"/><circle cx="6" cy="9.5" r="1.8"/></svg>',
	"tknife": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M21.5 2.5L10 11l3 3 8.5-11.5zM9.3 12.2l2.5 2.5-1.4 1.4-.7-.7-4.9 4.9a1.5 1.5 0 0 1-2.1-2.1l4.9-4.9-.7-.7z"/></svg>',
	"magnum": '<svg viewBox="0 0 44 24" fill="currentColor"><path d="M1 5h26v-2h3v2h13v4H28v1h-3v2h-4l-4 3h-3l-3 8H5l3-9H4l-1-3H1z"/></svg>',
	"raygun": '<svg viewBox="0 0 44 26" fill="currentColor"><path d="M4 7h16l3-3h4l3 2h5l3-2h4v12h-4l-3-2h-5l-3 2h-4l-3-2h-2l-3 10H8l3-10H4z"/></svg>',
	"uzi": '<svg viewBox="0 0 36 24" fill="currentColor"><path d="M2 4h26v3h6v3H22v2h-4l-1 10h-5l1-10H8l-1 3H3z"/></svg>',
	"burst": '<svg viewBox="0 0 64 22" fill="currentColor"><path d="M1 9h8l2-3h24l2-2h8v2h8V4h2v5h8v3H50l-3 2h-9l-3 7h-6l2-7H17l-3 5H6l1-5H1z"/></svg>',
	"dmr": '<svg viewBox="0 0 72 22" fill="currentColor"><path d="M1 11h8l2-2h12V6h4V3h14v3h3v3h28v3H46l-2 2H33l-3 7h-6l2-7H14l-2 4H4l1-4H1z"/></svg>',
	"minigun": '<svg viewBox="0 0 66 26" fill="currentColor"><path d="M1 8h10V4h14v4h6V6h33v3H33v2h31v3H33v2h31v3H33v-2h-4l-3 7h-8l2-7H11l-2 3H3z"/></svg>',
	"rocket": '<svg viewBox="0 0 70 22" fill="currentColor"><path d="M1 6h4l2 2h44l2-3h8l8 6-8 6h-8l-2-3H38l-2 7h-6l1-7H20l-2 5h-6l2-5H7l-2 2H1z"/></svg>',
	"pad": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M7 9l5-5 5 5M7 14l5-5 5 5"/><ellipse cx="12" cy="19" rx="9" ry="2.6"/></svg>',
	"box": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 8h18v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zm-1-4h20v3H2z"/></svg>',
	"star": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.9 6.9 7.1.6-5.4 4.7 1.7 7-6.3-3.9-6.3 3.9 1.7-7L2 9.5l7.1-.6z"/></svg>',
	"target": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><path d="M12 1v5M12 18v5M1 12h5M18 12h5"/></svg>',
	"gamepad": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7h10a5 5 0 0 1 4.9 6l-.8 4a2.4 2.4 0 0 1-4.2 1L15 16H9l-1.9 2a2.4 2.4 0 0 1-4.2-1l-.8-4A5 5 0 0 1 7 7z"/><path d="M8 10v4M6 12h4"/></svg>',
}

var font_ui: SystemFont
var font_num: SystemFont
var theme: Theme
var _icons := {}

var hud_layer: CanvasLayer
var menu_layer: CanvasLayer
var hud: Control
var overlay: Control
var scope_on := false
var hit_t := 0.0
var hit_kill := false
var dmg_dirs: Array = []
var dmg_nums: Array = []
var dmg_root: Control
var hud_lag_hp := 100.0
var h := {}                 # HUD widgets
var m := {}                 # menu widgets
var banner_t := 0.0
var mm_base: ImageTexture
var mm_ver := -1
var thumbs := {}
var tab := 0
var settings_cols: Array = []

func _ready() -> void:
	G.ui = self

# ============================================================ style helpers
func icon(key: String, px := 48) -> Texture2D:
	var k := "%s@%d" % [key, px]
	if _icons.has(k):
		return _icons[k]
	var svg: String = ICONS.get(key, ICONS.box).replace("currentColor", "#ffffff")
	var img := Image.new()
	var vb := svg.get_slice("viewBox=\"", 1).get_slice("\"", 0).split(" ")
	var vh := float(vb[3]) if vb.size() == 4 else 24.0
	img.load_svg_from_string(svg, px / vh)
	var t := ImageTexture.create_from_image(img)
	_icons[k] = t
	return t

func sb(bg: Color, radius := 16, border := LINE, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 10; s.content_margin_bottom = 10
	return s

func glass(radius := 16) -> StyleBoxFlat:
	var s := sb(Color(0.07, 0.09, 0.13, 0.62), radius)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 8
	return s

func panel(parent: Node, radius := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(p)
	return p

func label(parent: Node, text := "", size := 16, color := TXT, num := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_num if num else font_ui)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l

func rich(parent: Node, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", font_ui)
	r.add_theme_font_override("bold_font", font_num)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	r.add_theme_color_override("default_color", TXT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(r)
	return r

func hbox(parent: Node, sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(b)
	return b

func vbox(parent: Node, sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(b)
	return b

func flow(parent: Node, sep := 8) -> HFlowContainer:
	var b := HFlowContainer.new()
	b.add_theme_constant_override("h_separation", sep)
	b.add_theme_constant_override("v_separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(b)
	return b

func tex_rect(parent: Node, t: Texture2D, size: Vector2, mod := TXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.modulate = mod
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(r)
	return r

# button with hover / click sounds; `primary` is the big orange call to action
func btn(parent: Node, text: String, cb: Callable, primary := false, size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_num)
	b.add_theme_font_size_override("font_size", size)
	if primary:
		b.add_theme_stylebox_override("normal", sb(ACC, 14, Color(1, 1, 1, 0.15)))
		b.add_theme_stylebox_override("hover", sb(ACC.lightened(0.12), 14, Color(1, 1, 1, 0.3)))
		b.add_theme_stylebox_override("pressed", sb(ACC.darkened(0.1), 14))
		b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), 14, Color.WHITE, 3))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): if not b.disabled: G.audio.ui_hover())
	b.focus_entered.connect(func(): if G.inp.pad_mode(): G.audio.ui_hover())
	b.pressed.connect(func(): G.audio.ui_click(primary))
	if cb.is_valid():
		b.pressed.connect(cb)
	if parent:
		parent.add_child(b)
	return b

func _theme() -> void:
	theme = Theme.new()
	theme.default_font = font_ui
	theme.default_font_size = 16
	theme.set_stylebox("normal", "Button", sb(Color(1, 1, 1, 0.06), 12))
	theme.set_stylebox("hover", "Button", sb(Color(1, 1, 1, 0.12), 12, Color(1, 1, 1, 0.2)))
	theme.set_stylebox("pressed", "Button", sb(Color(1, 0.42, 0.24, 0.2), 12, ACC, 2))
	theme.set_stylebox("hover_pressed", "Button", sb(Color(1, 0.42, 0.24, 0.28), 12, ACC2, 2))
	theme.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), 12, ACC2, 3))
	theme.set_stylebox("disabled", "Button", sb(Color(1, 1, 1, 0.03), 12))
	theme.set_color("font_color", "Button", TXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	var grab := sb(ACC, 9)
	theme.set_stylebox("slider", "HSlider", sb(Color(1, 1, 1, 0.12), 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("grabber_area", "HSlider", sb(ACC, 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", sb(ACC2, 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("focus", "HSlider", sb(Color(0, 0, 0, 0), 6, ACC2, 2))
	var gi := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	gi.fill(Color(0, 0, 0, 0))
	for y in 18:
		for x in 18:
			if Vector2(x - 8.5, y - 8.5).length() < 8.5:
				gi.set_pixel(x, y, Color.WHITE)
	var gt := ImageTexture.create_from_image(gi)
	theme.set_icon("grabber", "HSlider", gt)
	theme.set_icon("grabber_highlight", "HSlider", gt)
	theme.set_stylebox("panel", "PanelContainer", glass())
	theme.set_stylebox("scroll", "VScrollBar", sb(Color(1, 1, 1, 0.04), 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("grabber", "VScrollBar", sb(Color(1, 1, 1, 0.2), 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(1, 1, 1, 0.35), 4, Color(0, 0, 0, 0), 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb(ACC, 4, Color(0, 0, 0, 0), 0))
	theme.set_color("font_color", "Label", TXT)

# ============================================================ build
func build() -> void:
	font_ui = SystemFont.new()
	font_ui.font_names = PackedStringArray(["Segoe UI", "Arial"])
	font_num = SystemFont.new()
	font_num.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	font_num.font_weight = 700
	_theme()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 3
	add_child(menu_layer)
	_build_hud()
	_build_menu()
	_build_overlays()
	input_changed()

# ------------------------------------------------------------ HUD
func _anchored(parent: Control, preset: int, pos: Vector2, grow_h := Control.GROW_DIRECTION_END, grow_v := Control.GROW_DIRECTION_END) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(preset)
	c.position += pos
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v
	parent.add_child(c)
	return c

func _build_hud() -> void:
	hud = Control.new()
	hud.theme = theme
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	hud_layer.add_child(hud)
	# full-screen effects: power-up glow, flashbang white-out
	h.glow = ColorRect.new()
	h.glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = Gfx.shader("edge", "shader_type canvas_item;\nuniform vec4 col : source_color;\nvoid fragment(){ vec2 d = abs(UV - 0.5) * 2.0; float e = smoothstep(0.55, 1.0, max(d.x, d.y)); COLOR = vec4(col.rgb, col.a * e); }")
	h.glow.material = gm
	hud.add_child(h.glow)
	h.blind = ColorRect.new()
	h.blind.color = Color(1, 1, 1, 0)
	h.blind.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(h.blind)
	# crosshair, hitmarker, scope, damage arrows, enemy health bars
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	hud.add_child(overlay)
	dmg_root = Control.new()
	dmg_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dmg_root)

	# top bar: score · wave · kills · credits
	var top := _anchored(hud, Control.PRESET_CENTER_TOP, Vector2(0, 18), Control.GROW_DIRECTION_BOTH)
	var tb := hbox(top, 10)
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	tb.position.x = -330
	tb.custom_minimum_size.x = 660
	h.score = _chip(tb, "star", "PUNTI", TXT)
	var wb := panel(tb)
	var wv := vbox(wb, 2)
	wv.custom_minimum_size.x = 210
	h.wave_label = label(wv, "ONDATA", 12, MUT, true, HORIZONTAL_ALIGNMENT_CENTER)
	h.wave = label(wv, "1", 38, TXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	h.wave_prog = _bar(wv, Vector2(190, 5), ACC)
	h.wave_sub = label(wv, "", 13, MUT, false, HORIZONTAL_ALIGNMENT_CENTER)
	h.brk = label(wv, "", 13, ACC2, false, HORIZONTAL_ALIGNMENT_CENTER)
	h.kills = _chip(tb, "target", "KILL", TXT)
	h.cash = _chip(tb, "coin", "CREDITI", Color("#ffd45a"))
	# boss bar
	var bt := _anchored(hud, Control.PRESET_CENTER_TOP, Vector2(-330, 168))
	h.boss = panel(bt)
	h.boss.custom_minimum_size.x = 660
	var bv := vbox(h.boss, 6)
	var bn := hbox(bv)
	h.boss_name = label(bn, "", 18, TXT, true)
	h.boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.boss_hp = label(bn, "", 18, MUT, true)
	h.boss_bar = _bar(bv, Vector2(630, 12), Color("#ff3b5c"))
	h.boss.visible = false
	# minimap
	var mmc := _anchored(hud, Control.PRESET_TOP_LEFT, Vector2(22, 22))
	h.mm = TextureRect.new()
	h.mm.custom_minimum_size = Vector2(190, 190)
	h.mm.size = Vector2(190, 190)
	var mmm := ShaderMaterial.new()
	mmm.shader = Gfx.shader("minimap", MINIMAP_SHADER)
	h.mm.material = mmm
	h.mm.texture = Gfx.tex(Gfx._img(4, 4, Color.WHITE))
	h.mm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mmc.add_child(h.mm)
	h.mm_marks = Control.new()
	h.mm_marks.size = Vector2(190, 190)
	h.mm_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mm_marks.draw.connect(_draw_minimap)
	mmc.add_child(h.mm_marks)
	# power-ups on the left
	var pc := _anchored(hud, Control.PRESET_CENTER_LEFT, Vector2(22, -60))
	h.powers = vbox(pc, 8)
	h.power_rows = {}
	# killfeed + toasts + banner + prompt + tutorial
	var kf := _anchored(hud, Control.PRESET_TOP_RIGHT, Vector2(-22, 22), Control.GROW_DIRECTION_BEGIN)
	h.killfeed = vbox(kf, 6)
	h.killfeed.alignment = BoxContainer.ALIGNMENT_END
	h.killfeed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.killfeed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var bc := _anchored(hud, Control.PRESET_CENTER, Vector2(-450, -230))
	h.banner = vbox(bc, 2)
	h.banner.custom_minimum_size.x = 900
	h.banner_big = label(h.banner, "", 64, TXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	h.banner_big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	h.banner_big.add_theme_constant_override("shadow_offset_y", 3)
	var line := ColorRect.new(); line.color = ACC; line.custom_minimum_size = Vector2(0, 3); line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.custom_minimum_size.x = 140; line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.banner.add_child(line)
	h.banner_small = label(h.banner, "", 18, TXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	h.banner_small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.banner.modulate.a = 0
	var tc := _anchored(hud, Control.PRESET_CENTER, Vector2(-300, 120))
	h.toasts = vbox(tc, 6)
	h.toasts.custom_minimum_size.x = 600
	var pr := _anchored(hud, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -220))
	h.prompt = panel(pr, 12)
	h.prompt.custom_minimum_size.x = 600
	var prh := hbox(h.prompt, 10)
	prh.alignment = BoxContainer.ALIGNMENT_CENTER
	h.prompt_key = label(prh, "E", 18, Color.BLACK, true, HORIZONTAL_ALIGNMENT_CENTER)
	var ks := sb(TXT, 6, Color(0, 0, 0, 0), 0)
	ks.content_margin_left = 8; ks.content_margin_right = 8; ks.content_margin_top = 2; ks.content_margin_bottom = 2
	h.prompt_key.add_theme_stylebox_override("normal", ks)
	h.prompt_text = label(prh, "", 17)
	h.prompt_extra = label(prh, "", 17, Color("#ffd45a"), true)
	h.prompt.visible = false
	var tt := _anchored(hud, Control.PRESET_CENTER_TOP, Vector2(-320, 244))
	h.tut = panel(tt, 12)
	h.tut.custom_minimum_size.x = 640
	var tv := vbox(h.tut, 4)
	h.tut_step = label(tv, "", 12, ACC2, true)
	h.tut_text = rich(tv, 16)
	h.tut.visible = false

	# health box bottom-left
	var hb := _anchored(hud, Control.PRESET_BOTTOM_LEFT, Vector2(22, -150))
	var hv := vbox(hb, 4)
	h.perks = hbox(hv, 6)
	h.hpbox = panel(hv)
	h.hpbox.custom_minimum_size.x = 330
	var hpv := vbox(h.hpbox, 6)
	var hr := hbox(hpv, 8)
	tex_rect(hr, icon("cross", 28), Vector2(22, 22), GOOD)
	h.hp = label(hr, "100", 36, TXT, true)
	label(hr, "/ 100", 15, MUT, true).size_flags_vertical = Control.SIZE_SHRINK_END
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hr.add_child(sp)
	h.stance = label(hr, "ACCUCCIATO", 11, ARMOR2, true)
	h.regen = label(hr, "RIGENERAZIONE", 11, GOOD, true)
	h.hp_bar = _bar(hpv, Vector2(300, 9), GOOD)
	var ar := hbox(hpv, 8)
	tex_rect(ar, icon("shield", 24), Vector2(16, 16), ARMOR)
	h.armor = label(ar, "0", 16, ARMOR2, true)
	h.armor_bar = _bar(ar, Vector2(250, 6), ARMOR)
	h.armor_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# right column: throwables, slots, weapon box
	var rc := _anchored(hud, Control.PRESET_BOTTOM_RIGHT, Vector2(-22, -22), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	var rv := vbox(rc, 8)
	rv.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rv.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rv.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var eq := hbox(rv, 6)
	eq.alignment = BoxContainer.ALIGNMENT_END
	h.equip = {}
	for k in G.EQUIP_ORDER:
		var p := panel(eq, 10)
		var e := hbox(p, 5)
		tex_rect(e, icon(k, 32), Vector2(20, 20), ACC2)
		var n := label(e, "0", 17, TXT, true)
		var kk := label(e, "", 11, MUT, true)
		h.equip[k] = { "panel": p, "n": n, "key": kk }
	var sl := hbox(rv, 6)
	sl.alignment = BoxContainer.ALIGNMENT_END
	h.slots = []
	for i in 3:
		var p2 := panel(sl, 10)
		p2.custom_minimum_size = Vector2(110, 44)
		var s := hbox(p2, 6)
		var ic := tex_rect(s, icon("knife" if i == 2 else "rifle", 48), Vector2(70, 22))
		var k2 := label(s, "V" if i == 2 else str(i + 1), 12, MUT, true)
		h.slots.append({ "panel": p2, "icon": ic, "key": k2 })
	h.wbox = panel(rv)
	h.wbox.custom_minimum_size.x = 340
	var wbv := vbox(h.wbox, 4)
	var wt := hbox(wbv)
	h.wname = label(wt, "FUCILE", 16, MUT, true)
	h.wname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.wicon = tex_rect(wt, icon("rifle", 48), Vector2(90, 26), ACC2)
	var am := hbox(wbv, 8)
	h.ammo = label(am, "30", 44, TXT, true)
	h.res = label(am, "/ ∞", 18, MUT, true)
	h.res.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.reload = label(am, "R · RICARICA", 14, BAD, true)
	h.reload.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.pips = Control.new()
	h.pips.custom_minimum_size = Vector2(310, 8)
	h.pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.pips.draw.connect(_draw_pips)
	wbv.add_child(h.pips)
	# small extras
	h.fps = label(hud, "", 14, MUT, true)
	h.fps.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	h.fps.position += Vector2(-80, -14)
	var nc := _anchored(hud, Control.PRESET_CENTER_TOP, Vector2(-220, 300))
	h.note = panel(nc, 12)
	h.note.custom_minimum_size.x = 440
	var nh := hbox(h.note)
	tex_rect(nh, icon("gamepad", 32), Vector2(22, 22), ACC2)
	h.note_text = label(nh, "", 15)
	h.note.visible = false
	h.note_t = 0.0

func _chip(parent: Node, ic: String, text: String, col: Color) -> Label:
	var p := panel(parent, 14)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var b := hbox(p, 8)
	tex_rect(b, icon(ic, 32), Vector2(18, 18), col)
	var v := label(b, "0", 24, TXT, true)
	label(b, text, 11, MUT, true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return v

# progress bar drawn by hand: background, white "lag" part, coloured fill
func _bar(parent: Node, size: Vector2, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("fill", 1.0); c.set_meta("lag", 1.0); c.set_meta("col", col)
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var rad := minf(c.size.y / 2.0, 6.0)
		c.draw_style_box(sb(Color(1, 1, 1, 0.1), int(rad), Color(0, 0, 0, 0), 0), r)
		var lg: float = c.get_meta("lag")
		var f: float = c.get_meta("fill")
		if lg > f + 0.002:
			c.draw_style_box(sb(Color(1, 1, 1, 0.75), int(rad), Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, Vector2(c.size.x * lg, c.size.y)))
		if f > 0.002:
			c.draw_style_box(sb(c.get_meta("col"), int(rad), Color(0, 0, 0, 0), 0), Rect2(Vector2.ZERO, Vector2(maxf(c.size.y, c.size.x * f), c.size.y))))
	if parent:
		parent.add_child(c)
	return c

func _set_bar(c: Control, fill: float, lag := -1.0, col: Variant = null) -> void:
	c.set_meta("fill", clampf(fill, 0, 1))
	c.set_meta("lag", clampf(lag if lag >= 0 else fill, 0, 1))
	if col is Color:
		c.set_meta("col", col)
	c.queue_redraw()

const MINIMAP_SHADER := """
shader_type canvas_item;
uniform sampler2D base : filter_linear;
uniform vec2 ppos = vec2(0.0);
uniform float yaw = 0.0;
uniform float range = 32.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	if (r > 1.0) discard;
	vec2 s = d * range;
	float cy = cos(yaw), sy = sin(yaw);
	vec2 w = ppos + vec2(cy * s.x + sy * s.y, -sy * s.x + cy * s.y);
	vec2 uv = (w + 40.0) / 80.0;
	vec4 c = vec4(0.03, 0.05, 0.08, 0.45);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 b = texture(base, uv);
		c.rgb = mix(c.rgb, b.rgb, b.a);
		c.a = max(c.a, b.a * 0.9);
	}
	float ring = 1.0 - smoothstep(0.0, 0.012, abs(r - 0.5));
	c.rgb += ring * 0.08;
	float rim = smoothstep(0.96, 1.0, r);
	c.rgb = mix(c.rgb, vec3(1.0), rim * 0.25);
	COLOR = c;
}
"""

func _minimap_base() -> void:
	var Wd: Node = G.world
	var MAP: Dictionary = Wd.MAP
	var im := Gfx._img(400, 400, Color(1, 1, 1, 0.05))
	if MAP.key == "arena":
		for a in 120:
			var t := a / 120.0 * TAU
			Gfx._rect(im, 200 + cos(t) * 46, 200 + sin(t) * 46, 2, 2, Color(1, 0.77, 0.47, 0.35))
	if MAP.has("roads"):
		for r in MAP.roads:
			Gfx._rect(im, (r[0] + 40) * 5, (r[1] + 40) * 5, (r[2] - r[0]) * 5, (r[3] - r[1]) * 5, Color(0, 0, 0, 0.28))
	for b in Wd.colliders:
		if b.end.y < 0.5 or b == G.items.box.collider:
			continue
		var skip := false
		for s in MAP.layer.solids:
			if s.box == b:
				skip = true
		if skip:
			continue
		Gfx._rect(im, (b.position.x + 40) * 5, (b.position.z + 40) * 5, b.size.x * 5, b.size.z * 5, Color(0.82, 0.86, 0.92, 0.42))
	mm_base = Gfx.tex(im)
	(h.mm.material as ShaderMaterial).set_shader_parameter("base", mm_base)
	mm_ver = Wd.map_version

# ------------------------------------------------------------ main menu
func _build_menu() -> void:
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)
	m.root = root
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgm := ShaderMaterial.new()
	bgm.shader = Gfx.shader("menubg", "shader_type canvas_item;\nvoid fragment(){ float a = mix(0.82, 0.25, smoothstep(0.0, 0.75, UV.x)); COLOR = vec4(0.03, 0.04, 0.07, a + (1.0 - UV.y) * 0.05); }")
	bg.material = bgm
	root.add_child(bg)
	m.menu = Control.new()
	m.menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(m.menu)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56 if side in ["left", "right"] else 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.menu.add_child(margin)
	var row := hbox(margin, 40)
	var left := vbox(row, 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	m.tag = _tag(left, "ARENA FPS")
	m.title = label(left, "SPARIAPS", 104, TXT, true)
	m.title.add_theme_color_override("font_shadow_color", Color(1, 0.42, 0.24, 0.35))
	m.title.add_theme_constant_override("shadow_offset_y", 4)
	m.sub = label(left, "", 18, MUT)
	m.sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.sub.custom_minimum_size.x = 640
	m.stats = flow(left, 10)
	m.career = label(left, "", 14, MUT)
	m.career.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.career.custom_minimum_size.x = 640
	m.pickers = vbox(left, 8)
	label(m.pickers, "MODALITÀ", 13, MUT, true)
	var mr := hbox(m.pickers, 10)
	m.mode_btns = {}
	for k in ["classic", "zombie"]:
		var b := btn(mr, "", _set_mode.bind(k))
		b.custom_minimum_size = Vector2(300, 74)
		b.toggle_mode = true
		var bv := vbox(b, 2)
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 16; bv.offset_top = 10
		label(bv, "CLASSICA" if k == "classic" else "ZOMBIE", 20, TXT, true)
		label(bv, "Arena con piattaforme, trampolini e bot armati" if k == "classic" else "Orde notturne corpo a corpo", 13, MUT)
		m.mode_btns[k] = b
	label(m.pickers, "DIFFICOLTÀ", 13, MUT, true)
	var dr := hbox(m.pickers, 8)
	m.diff_btns = {}
	for k in G.DIFF_ORDER:
		var b2 := btn(dr, G.DIFFS[k].name if G.DIFFS.has(k) else "PROGRESSIVA", _set_diff.bind(k), false, 15)
		b2.toggle_mode = true
		b2.custom_minimum_size = Vector2(118, 44)
		m.diff_btns[k] = b2
	m.diff_desc = label(m.pickers, "", 14, MUT)
	var acts := flow(left, 10)
	m.play = btn(acts, "GIOCA  →", _on_play, true, 22)
	m.play.custom_minimum_size = Vector2(200, 56)
	m.restart = btn(acts, "RICOMINCIA", func(): G.game.start_new_game())
	m.swap = btn(acts, "CLASSE", func(): if G.class_swaps < G.MAX_SWAPS: show_class_menu(true))
	m.mainmenu = btn(acts, "MENU", func(): G.game.go_main_menu())
	m.locker = btn(acts, "ARMADIETTO", func(): open_locker())
	m.settings = btn(acts, "IMPOSTAZIONI", func(): open_settings())
	m.quit = btn(acts, "ESCI", func(): _show(m.quit_dlg, true))
	for b3 in [m.restart, m.swap, m.mainmenu, m.locker, m.settings, m.quit]:
		b3.custom_minimum_size.y = 56
	m.best = label(acts, "", 16, MUT, true)
	m.best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lv := hbox(left, 10)
	m.lvl = label(lv, "LIV 1", 18, ACC2, true)
	m.lvl_bar = _bar(lv, Vector2(240, 8), ACC)
	m.lvl_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.lvl_txt = label(lv, "", 14, MUT, true)
	# legend card on the right
	var card := panel(row)
	card.custom_minimum_size = Vector2(470, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cv := vbox(card, 10)
	var tabs := hbox(cv, 6)
	m.tabs = []
	var names := ["TASTIERA", "CONTROLLER", "EQUIP", "BONUS", "SFIDE"]
	for i in names.size():
		var tb := btn(tabs, names[i], _set_tab.bind(i), false, 13)
		tb.toggle_mode = true
		m.tabs.append(tb)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(440, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(sc)
	m.legend_scroll = sc
	m.legend = vbox(sc, 6)
	m.legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _tag(parent: Node, text: String) -> Label:
	var p := PanelContainer.new()
	var s := sb(Color(1, 0.42, 0.24, 0.12), 20, Color(1, 0.42, 0.24, 0.35))
	s.content_margin_top = 4; s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return label(p, "●  " + text, 13, ACC2, true)

func _row(parent: Node, a: String, b: String) -> void:
	var r := hbox(parent, 8)
	var l := label(r, a, 15, TXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var k := label(r, b, 15, ACC2, true, HORIZONTAL_ALIGNMENT_RIGHT)
	k.custom_minimum_size.x = 150

func _set_tab(i: int) -> void:
	tab = i
	for j in m.tabs.size():
		m.tabs[j].button_pressed = j == i
	for c in m.legend.get_children():
		c.queue_free()
	var L: Control = m.legend
	var kn := func(id: String) -> String: return G.key_name(G.bind_of(id))
	match i:
		0:
			_row(L, "Muoviti", "%s %s %s %s" % [kn.call("fwd"), kn.call("left"), kn.call("back"), kn.call("right")])
			_row(L, "Spara / Mira", "Clic SX · Clic DX")
			_row(L, "Corri / Salta", "%s · %s" % [kn.call("sprint"), kn.call("jump")])
			_row(L, "Doppio salto (arena)", "%s ×2" % kn.call("jump"))
			_row(L, "Accucciati · scivola (mentre corri)", kn.call("crouch"))
			_row(L, "Sporgiti (mentre miri)", "%s · %s" % [kn.call("swap"), kn.call("interact")])
			_row(L, "Cambia arma", "1 · 2 · Rotella · %s" % kn.call("swap"))
			_row(L, "Coltellata", "%s · F" % kn.call("melee"))
			_row(L, "Ricarica", kn.call("reload"))
			_row(L, "Usa cassa / raccogli arma", kn.call("interact"))
			_row(L, "Getta arma", kn.call("drop"))
			_row(L, "Avvia subito l’ondata successiva", kn.call("skip"))
			_row(L, "Audio on/off", "M")
			_row(L, "Pausa", "%s · Esc" % kn.call("pause"))
		1:
			var p := func(b: String) -> String: return G.inp.pad_label(b)
			_row(L, "Muoviti / Guarda", "%s · %s" % [p.call("ls"), p.call("rs")])
			_row(L, "Spara / Mira", "%s · %s" % [p.call("RT"), p.call("LT")])
			_row(L, "Salta (×2 in arena)", p.call("A"))
			_row(L, "Corri", p.call("L3"))
			_row(L, "Accucciati · scivola (mentre corri)", p.call("B"))
			_row(L, "Ricarica · usa cassa / raccogli", p.call("X"))
			_row(L, "Cambia arma", p.call("Y"))
			_row(L, "Coltellata", "%s · %s" % [p.call("RB"), p.call("R3")])
			_row(L, "Sporgiti a sinistra / destra (mentre miri)", "%s · %s" % [p.call("L3"), p.call("R3")])
			_row(L, "Granata a frammentazione", p.call("LB"))
			_row(L, "Stordente · Fumogeno", "%s · %s" % [p.call("up"), p.call("down")])
			_row(L, "Coltello da lancio · Getta arma", "%s · %s" % [p.call("left"), p.call("right")])
			_row(L, "Avvia subito l’ondata", p.call("back"))
			_row(L, "Pausa", p.call("start"))
			var n := label(L, "Nei menu: croce direzionale o stick sinistro per spostarti, %s per confermare, %s per tornare indietro. Collegando un controller il gioco passa da solo a questa modalità." % [p.call("A"), p.call("B")], 13, MUT)
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		2:
			_row(L, "Granata a frammentazione", kn.call("frag"))
			_row(L, "Granata stordente", kn.call("stun"))
			_row(L, "Fumogeno", kn.call("smoke"))
			_row(L, "Coltello da lancio", kn.call("tknife"))
			var n2 := label(L, "Si parte senza: trovali nei pacchetti arancioni sparsi per la mappa o raccoglili dai nemici eliminati. Uccidere nemici ti dà anche crediti da spendere nella cassa misteriosa.", 13, MUT)
			n2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		3:
			for k in G.POWERUPS:
				var d: Dictionary = G.POWERUPS[k]
				_bonus_row(L, k, d.name, Color.html(d.css), "%s · %ds" % [d.hint, int(d.dur)])
			_bonus_row(L, "box", "CASSA MISTERIOSA", Color("#9fd0ff"), "Arma casuale per %d crediti, poi si sposta" % G.BOX_COST)
			_bonus_row(L, "pad", "TRAMPOLINO", Color("#7cfff0"), "Solo in modalità classica: ti lancia sulle piattaforme")
		4:
			var done := 0
			for c in G.CHALLENGES:
				if G.chal.get(c.id, 0) >= c.goal:
					done += 1
			label(L, "%d / %d COMPLETATE" % [done, G.CHALLENGES.size()], 14, ACC2, true)
			for c in G.CHALLENGES:
				var v: float = G.chal.get(c.id, 0)
				var ok: bool = v >= c.goal
				var cp := panel(L, 10)
				var cv := vbox(cp, 3)
				var top := hbox(cv)
				var nm := label(top, ("✓ " if ok else "") + c.name, 15, GOOD if ok else TXT, true)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var unit: String = c.get("unit", "")
				label(top, "%d%s / %d%s" % [v, unit, c.goal, unit], 13, MUT, true)
				label(cv, c.desc, 12, MUT)
				_set_bar(_bar(cv, Vector2(400, 4), GOOD if ok else ACC), v / c.goal)

func _bonus_row(parent: Node, ic: String, name: String, col: Color, text: String) -> void:
	var r := hbox(parent, 10)
	tex_rect(r, icon(ic, 32), Vector2(24, 24), col)
	var v := vbox(r, 0)
	label(v, name, 15, col, true)
	var t := label(v, text, 13, MUT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 360

func _set_mode(k: String) -> void:
	G.mode = k
	G.sset("mode", k)
	G.world.apply_atmosphere(k)
	_refresh_pickers()
	if G.audio.music_want == "menu":
		G.audio.set_music("menu")

func _set_diff(k: String) -> void:
	G.diff_key = k
	G.D = G.diff_for(1)
	G.sset("diff", k)
	_refresh_pickers()

func _refresh_pickers() -> void:
	for k in m.mode_btns:
		m.mode_btns[k].button_pressed = k == G.mode
	for k in m.diff_btns:
		m.diff_btns[k].button_pressed = k == G.diff_key
	m.diff_desc.text = G.diff_for(1).desc
	m.best.text = "RECORD  %d" % G.get_best()
	if G.menu_type == "main":
		m.sub.text = SUBTITLES[G.mode]
		m.tag.text = "●  " + ("MODALITÀ ZOMBIE" if G.mode == "zombie" else "MODALITÀ CLASSICA")

func _on_play() -> void:
	if G.menu_type == "pause":
		G.game.enter_game()
	else:
		show_map_menu()

func _render_level() -> void:
	var l: Dictionary = G.level_of()
	m.lvl.text = "LIV %d" % l.lvl
	_set_bar(m.lvl_bar, float(l.cur) / l.need)
	m.lvl_txt.text = "%d / %d XP" % [l.cur, l.need] if l.lvl < G.MAX_LEVEL else "LIVELLO MASSIMO"

# menu for the title screen, the pause and the end of a match
func show_menu(type: String, title: String, sub: String, stats: Array, career := "") -> void:
	G.menu_type = type
	m.title.text = title
	m.sub.text = sub
	for c in m.stats.get_children():
		c.queue_free()
	for s in stats:
		var p := panel(m.stats, 12)
		p.custom_minimum_size.x = 120
		var v := vbox(p, 0)
		label(v, s[0], 28, ACC2 if s[2] else TXT, true)
		label(v, s[1], 12, MUT, true)
	m.career.text = career
	m.career.visible = career != ""
	m.pickers.visible = type == "main"
	m.play.text = "RIPRENDI  →" if type == "pause" else ("RIGIOCA  →" if type == "dead" else "GIOCA  →")
	m.restart.visible = type == "pause"
	m.swap.visible = type == "pause"
	m.swap.disabled = G.class_swaps >= G.MAX_SWAPS
	m.swap.text = "CLASSE  %d/%d" % [G.MAX_SWAPS - G.class_swaps, G.MAX_SWAPS]
	m.mainmenu.visible = type != "main"
	m.best.visible = type != "pause"
	m.locker.visible = type == "main"
	m.tag.text = "●  %s · %s" % ["ZOMBIE" if G.mode == "zombie" else "CLASSICA", G.D.name]
	_render_level()
	_refresh_pickers()
	_set_tab(tab)
	m.root.visible = true
	m.menu.visible = true
	_focus(m.play)

func hide_menus() -> void:
	m.root.visible = false
	for k in ["map_menu", "class_menu", "settings_menu", "locker_menu", "shop", "quit_dlg"]:
		m[k].visible = false

func show_hud(on: bool) -> void:
	hud.visible = on
	if on:
		hud_lag_hp = 100

func _focus(c: Control) -> void:
	if G.inp.pad_mode() and c and c.is_visible_in_tree():
		c.call_deferred("grab_focus")

# ------------------------------------------------------------ overlays: map, class, settings, locker, shop, quit
func _overlay(title: String, tag: String) -> Dictionary:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	m.root.add_child(o)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(sc)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 36)
	center.add_child(mc)
	var v := vbox(mc, 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tg := _tag(v, tag)
	var t := label(v, title, 52, TXT, true)
	var s := label(v, "", 16, MUT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 900
	return { "root": o, "body": v, "tag": tg, "title": t, "sub": s, "scroll": sc }

func _show(o: Dictionary, on: bool) -> void:
	o.root.visible = on

func _build_overlays() -> void:
	# map
	var mp := _overlay("SCEGLI LA MAPPA", "")
	mp.sub.text = "Dove vuoi combattere? La scelta resta salvata per le prossime partite."
	m.map_menu = mp.root; m.map = mp
	mp.cards = hbox(mp.body, 18)
	var ma := hbox(mp.body, 10)
	mp.next = btn(ma, "AVANTI  →", func(): _show(mp, false); show_class_menu(false), true, 20)
	mp.next.custom_minimum_size = Vector2(200, 52)
	btn(ma, "←  INDIETRO", func(): _show(mp, false); G.game.show_main_menu()).custom_minimum_size.y = 52
	# class
	var cl := _overlay("SCEGLI LA CLASSE", "")
	m.class_menu = cl.root; m.cls = cl
	cl.cards = flow(cl.body, 12)
	cl.cards.custom_minimum_size.x = 1100
	var ca := hbox(cl.body, 10)
	cl.start = btn(ca, "INIZIA  →", _class_start, true, 20)
	cl.start.custom_minimum_size = Vector2(200, 52)
	btn(ca, "←  INDIETRO", _class_back).custom_minimum_size.y = 52
	# settings
	var st := _overlay("IMPOSTAZIONI", "OPZIONI")
	m.settings_menu = st.root; m.set = st
	st.sub.text = "Le impostazioni si salvano automaticamente · Esc (o B sul controller) o FATTO per tornare indietro"
	var sa := hbox(st.body, 10)
	btn(sa, "FATTO  ✓", func(): _show(st, false); _focus(m.settings), true, 18).custom_minimum_size = Vector2(160, 48)
	btn(sa, "RIPRISTINA", _reset_settings).custom_minimum_size.y = 48
	st.grid = GridContainer.new()
	st.grid.columns = 3
	st.grid.add_theme_constant_override("h_separation", 14)
	st.grid.add_theme_constant_override("v_separation", 14)
	st.body.add_child(st.grid)
	# locker
	var lk := _overlay("ARMADIETTO", "")
	lk.sub.text = "Mimetiche, guanti e finiture delle armi si sbloccano salendo di livello. L’esperienza arriva dai punti di ogni partita e dalle sfide completate."
	m.locker_menu = lk.root; m.lock = lk
	lk.list = vbox(lk.body, 10)
	btn(lk.body, "FATTO  ✓", func(): _show(lk, false); _focus(m.locker), true, 18).custom_minimum_size = Vector2(160, 48)
	# shop
	var sh := _overlay("", "")
	m.shop = sh.root; m.sh = sh
	var cash := panel(sh.body, 12)
	cash.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ch := hbox(cash)
	tex_rect(ch, icon("coin", 32), Vector2(22, 22), Color("#ffd45a"))
	sh.cash = label(ch, "0", 26, TXT, true)
	label(ch, "CREDITI", 12, MUT, true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.grid = flow(sh.body, 12)
	sh.grid.custom_minimum_size.x = 1100
	sh.close = btn(sh.body, "TORNA IN PARTITA  →", func(): G.game.close_shop(), true, 18)
	sh.close.custom_minimum_size = Vector2(240, 50)
	sh.close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# quit
	var q := _overlay("VUOI USCIRE DAL GIOCO?", "ESCI")
	q.sub.text = "La partita in corso andrà persa. Il record e le impostazioni restano salvati."
	m.quit_dlg = q.root; m.q = q
	var qa := hbox(q.body, 10)
	var yes := btn(qa, "ESCI DAL GIOCO", func(): G.game.quit_game(), true, 18)
	yes.add_theme_stylebox_override("normal", sb(BAD, 14))
	yes.custom_minimum_size = Vector2(220, 50)
	q.no = btn(qa, "ANNULLA", func(): _show(q, false); _focus(m.quit))
	q.no.custom_minimum_size.y = 50

func overlay_open() -> bool:
	for k in ["map_menu", "class_menu", "settings_menu", "locker_menu", "shop", "quit_dlg"]:
		if m[k].visible:
			return true
	return false

# Esc / B: close the topmost layer, pause or resume
func escape() -> void:
	if m.quit_dlg.visible:
		_show(m.q, false); _focus(m.quit)
	elif m.settings_menu.visible:
		if not G.inp.bind_wait.is_empty():
			G.inp.bind_wait = {}; render_binds()
		else:
			_show(m.set, false); _focus(m.settings)
	elif m.locker_menu.visible:
		_show(m.lock, false); _focus(m.locker)
	elif m.class_menu.visible:
		_class_back()
	elif m.map_menu.visible:
		_show(m.map, false); G.game.show_main_menu()
	elif m.shop.visible:
		G.game.close_shop()
	elif G.is_playing():
		G.game.pause()
	elif G.state == "paused":
		G.game.enter_game()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton) and event.pressed and event.button_index == JOY_BUTTON_B and not G.is_playing():
		escape()

func pad_start() -> void:
	if G.state == "paused" and not overlay_open():
		G.game.enter_game()
	elif G.state == "menu" and not overlay_open() and G.menu_type == "main":
		_on_play()

func pad_bumper(dir: int) -> void:
	if m.menu.visible and not overlay_open():
		_set_tab(posmod(tab + dir, 5))

func pad_scroll(px: float) -> void:
	for o in [m.set, m.lock, m.cls, m.map, m.sh]:
		if o.root.visible:
			o.scroll.scroll_vertical += int(px)
			return
	if m.menu.visible:
		m.legend_scroll.scroll_vertical += int(px)

# ---------------------------------------------------------------- map selection with live previews
func show_map_menu() -> void:
	if G.state == "dead":
		G.game.go_main_menu()   # clear the finished match so the previews show clean maps
	m.menu.visible = false
	m.map.tag.text = "●  %s · %s" % ["ZOMBIE" if G.mode == "zombie" else "CLASSICA", G.diff_for(1).name]
	_show(m.map, true)
	_render_maps()
	_make_thumbs()

func _render_maps() -> void:
	for c in m.map.cards.get_children():
		c.queue_free()
	var first: Button = null
	for k in ["city", "arena"]:
		var M: Dictionary = G.world.MAPS[k]
		var b := btn(m.map.cards, "", _pick_map.bind(k))
		b.toggle_mode = true
		b.button_pressed = G.world.MAP.key == k
		b.custom_minimum_size = Vector2(500, 430)
		var v := vbox(b, 6)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 12; v.offset_top = 12; v.offset_right = -12
		var tr := tex_rect(v, thumbs.get(k + "-" + G.mode), Vector2(476, 268), Color.WHITE)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		label(v, M.tag, 12, ACC2, true)
		label(v, M.name, 30, TXT, true)
		var d := label(v, M.desc, 14, MUT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if b.button_pressed or first == null:
			first = b
	_focus(first)

func _pick_map(k: String) -> void:
	if k != G.world.MAP.key:
		G.game.use_map(k)
		G.sset("map", k)
	_render_maps()

# one frame of each map from above, in the lighting of the selected mode
func _make_thumbs() -> void:
	var need: Array = []
	for k in ["city", "arena"]:
		if not thumbs.has(k + "-" + G.mode):
			need.append(k)
	if need.is_empty():
		return
	var prev: String = G.world.MAP.key
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.world_3d = G.scene_root.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 48
	vp.add_child(cam)
	add_child(vp)
	for k in need:
		G.game.use_map(k)
		var shot: Array = G.world.MAPS[k].shot
		cam.position = shot[0]
		cam.look_at_from_position(shot[0], shot[1])
		cam.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		thumbs[k + "-" + G.mode] = ImageTexture.create_from_image(img)
	vp.queue_free()
	G.game.use_map(prev)
	if m.map_menu.visible:
		_render_maps()

# ---------------------------------------------------------------- class selection (also the mid-match class swap)
func show_class_menu(swap: bool) -> void:
	var gm: Node = G.game
	gm.class_mode = "swap" if swap else "new"
	gm.swap_from = G.class_key
	m.cls.tag.text = "●  CAMBIO CLASSE · %d DISPONIBILI" % (G.MAX_SWAPS - G.class_swaps) if swap else "●  %s · %s" % ["ZOMBIE" if G.mode == "zombie" else "CLASSICA", G.diff_for(1).name]
	m.cls.sub.text = "La nuova arma principale sostituisce quella della classe attuale; se lo scudo della nuova classe è più alto, lo ricevi subito." if swap else "Ogni classe ha un’arma principale diversa. Pistola e coltello sono sempre con te."
	m.cls.start.text = "CONFERMA  ✓" if swap else "INIZIA  →"
	m.menu.visible = false
	_show(m.cls, true)
	_render_classes()

const STAT_NAMES := ["DANNO", "CADENZA", "PRECISIONE", "MOBILITÀ"]

func _render_classes() -> void:
	for c in m.cls.cards.get_children():
		c.queue_free()
	var sel: Button = null
	for k in G.CLASS_ORDER:
		var c: Dictionary = G.CLASSES[k]
		var b := btn(m.cls.cards, "", _pick_class.bind(k))
		b.toggle_mode = true
		b.button_pressed = k == G.class_key
		b.custom_minimum_size = Vector2(210, 340)
		var v := vbox(b, 6)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14; v.offset_top = 14; v.offset_right = -14
		tex_rect(v, icon(c.weapon, 48), Vector2(170, 40), ACC2)
		label(v, c.name, 20, TXT, true)
		label(v, G.weapons.W[c.weapon].name, 12, MUT, true)
		var d := label(v, c.desc, 13, MUT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.y = 72
		for i in 4:
			label(v, STAT_NAMES[i], 10, MUT, true)
			_set_bar(_bar(v, Vector2(180, 5), ACC), c.stats[i] / 5.0)
		label(v, c.perk, 12, GOOD, true)
		if b.button_pressed:
			sel = b
	_focus(sel if sel else m.cls.start)

func _pick_class(k: String) -> void:
	G.class_key = k
	G.sset("class", k)
	_render_classes()

func _class_start() -> void:
	_show(m.cls, false)
	var gm: Node = G.game
	if gm.class_mode == "new":
		G.game.start_new_game()
		return
	if G.class_key != gm.swap_from:
		gm.apply_class_swap()
	G.game.enter_game()

func _class_back() -> void:
	var gm: Node = G.game
	if gm.class_mode == "swap":
		G.class_key = gm.swap_from
		G.sset("class", G.class_key)
	_show(m.cls, false)
	if gm.class_mode == "new":
		_show(m.map, true)
		_render_maps()
	else:
		m.menu.visible = true
		_focus(m.swap)

# ---------------------------------------------------------------- settings
func open_settings() -> void:
	_show(m.set, true)
	_render_settings()

func _section(title: String) -> VBoxContainer:
	var p := panel(m.set.grid)
	p.custom_minimum_size.x = 380
	p.size_flags_vertical = Control.SIZE_FILL
	var v := vbox(p, 10)
	label(v, title, 14, ACC2, true)
	return v

func _slider(parent: Node, name: String, hint: String, key: String, lo: float, hi: float, after: Callable) -> void:
	var v := vbox(parent, 2)
	var r := hbox(v)
	var t := vbox(r, 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(t, name, 15)
	if hint != "":
		label(t, hint, 12, MUT)
	var val := label(r, "%d%%" % roundi(G.settings[key] * 100), 15, ACC2, true)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = 5
	s.value = roundf(G.settings[key] * 100)
	s.custom_minimum_size = Vector2(340, 22)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(x: float):
		G.settings[key] = x / 100.0
		val.text = "%d%%" % roundi(x)
		G.save_settings()
		after.call())
	v.add_child(s)

func _opt(parent: Node, name: String, hint: String, options: Array, current: Variant, cb: Callable) -> void:
	var v := vbox(parent, 4)
	label(v, name, 15)
	if hint != "":
		var hl := label(v, hint, 12, MUT)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size.x = 340
	var r := hbox(v, 6)
	for o in options:
		var b := btn(r, o[1], func(): cb.call(o[0]); _render_settings(), false, 13)
		b.toggle_mode = true
		b.button_pressed = o[0] == current
		b.custom_minimum_size.y = 36

func _render_settings() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var fpath := ""
	if focused and m.set.grid.is_ancestor_of(focused):
		fpath = str(m.set.grid.get_path_to(focused))
	for c in m.set.grid.get_children():
		c.queue_free()
	var S: Dictionary = G.settings
	var atmo := func(): G.world.apply_atmosphere(G.mode)
	var v1 := _section("VISUALE E CONTROLLI")
	_slider(v1, "Intensità luci", "Neon, insegne, torcia e bagliore", "lights", 0, 150, atmo)
	_slider(v1, "Luminosità generale", "Esposizione dell’intera scena", "bright", 60, 140, atmo)
	_slider(v1, "Sensibilità mouse", "Velocità della visuale", "sens", 30, 250, func(): pass)
	_opt(v1, "Mira col tasto destro / grilletto sinistro", "“Clic singolo” attiva e disattiva la mira", [[true, "TIENI PREMUTO"], [false, "CLIC SINGOLO"]], S.adsHold, func(v): S.adsHold = v; G.aiming = false; G.save_settings())
	_opt(v1, "Mira semplificata", "Sparando col tasto sinistro miri in automatico", [[false, "DISATTIVA"], [true, "ATTIVA"]], S.autoAds, func(v): S.autoAds = v; G.save_settings())
	var tb := btn(v1, "RIVEDI IL TUTORIAL ALLA PROSSIMA PARTITA", func(): G.sset("tut-done", false); toast("TUTORIAL ATTIVO ALLA PROSSIMA PARTITA", "#8dffb0"), false, 13)
	tb.custom_minimum_size.y = 36
	var v2 := _section("CONTROLLER")
	var status := "Collegato: %s" % G.inp.pad_name() if G.inp.active_pad() else "Nessun controller rilevato: collegalo e premi un tasto qualsiasi"
	_opt(v2, "Dispositivo di gioco", status, [["kbm", "MOUSE E TASTIERA"], ["pad", "CONTROLLER"]], S.input, func(v): G.inp.set_input(v))
	_slider(v2, "Sensibilità controller", "Velocità della visuale con lo stick destro", "padSens", 30, 250, func(): pass)
	_opt(v2, "Inverti asse verticale", "Stick destro in su = guarda in basso", [[false, "NO"], [true, "SÌ"]], S.invertY, func(v): S.invertY = v; G.save_settings())
	_opt(v2, "Aiuto alla mira", "Col controller la visuale rallenta sopra un nemico", [[false, "DISATTIVA"], [true, "ATTIVA"]], S.aimAssist, func(v): S.aimAssist = v; G.save_settings())
	var v3 := _section("GRAFICA E SCHERMO")
	_opt(v3, "Qualità grafica", G.QUALITY[S.quality].hint, [["low", "BASSA"], ["medium", "MEDIA"], ["high", "ALTA"]], S.quality, func(v): S.quality = v; G.save_settings(); G.main.apply_quality(); G.items.atmosphere_changed())
	_opt(v3, "Contatore FPS", "Fotogrammi al secondo in basso a destra", [[false, "NASCONDI"], [true, "MOSTRA"]], S.fps, func(v): S.fps = v; G.save_settings(); h.fps.text = "")
	_opt(v3, "Schermo intero", "Gioca a tutto schermo oppure in finestra", [[true, "SCHERMO INTERO"], [false, "FINESTRA"]], S.fullscreen, func(v): S.fullscreen = v; G.save_settings(); G.main.apply_fullscreen())
	var v4 := _section("AUDIO")
	var vols := func(): G.audio.apply_volumes()
	for a in [["Generale", "volMaster"], ["Musica", "volMusic"], ["Armi", "volWeapons"], ["Nemici", "volEnemies"], ["Effetti e ambiente", "volFx"], ["Interfaccia", "volUi"]]:
		_slider(v4, a[0], "", a[1], 0, 100, vols)
	var v5 := _section("COMANDI")
	var hint := label(v5, "Scegli un comando e premi il nuovo tasto o pulsante. Se è già usato, i due comandi si scambiano. Esc annulla. Mouse, 1, 2, F, M ed Esc restano fissi.", 12, MUT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 340
	m.set.binds = vbox(v5, 4)
	render_binds()
	btn(v5, "RIPRISTINA I COMANDI", func(): S.binds = {}; S.padBinds = {}; G.inp.binds_changed(), false, 13).custom_minimum_size.y = 36
	if fpath != "":
		await get_tree().process_frame
		var n = m.set.grid.get_node_or_null(fpath)
		if n is Control:
			n.grab_focus()
	elif G.inp.pad_mode():
		await get_tree().process_frame
		var first = m.set.grid.find_children("*", "Button", true, false)
		if first.size() > 0:
			first[0].grab_focus()

func render_binds() -> void:
	if not m.has("set") or not m.set.has("binds") or not is_instance_valid(m.set.binds):
		return
	var list: VBoxContainer = m.set.binds
	for c in list.get_children():
		c.queue_free()
	var W: Dictionary = G.inp.bind_wait
	for a in G.ACTIONS:
		var r := hbox(list, 6)
		var nl := label(r, a[1], 13)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 140
		if a[2] != 0:
			var waiting: bool = W.get("id", "") == a[0] and W.get("dev", "") == "key"
			var b := btn(r, "PREMI…" if waiting else G.key_name(G.bind_of(a[0])), _wait_bind.bind(a[0], "key"), false, 12)
			b.custom_minimum_size = Vector2(90, 30)
		else:
			label(r, "mouse" if a[0] in ["fire", "aim"] else "—", 12, MUT).custom_minimum_size.x = 90
		if a[3] >= 0:
			var waitp: bool = W.get("id", "") == a[0] and W.get("dev", "") == "pad"
			var pb := btn(r, "PREMI…" if waitp else G.PAD_LABELS[G.inp.pad_style][G.PAD_NAMES[G.pad_of(a[3])]], _wait_bind.bind(a[0], "pad"), false, 12)
			pb.custom_minimum_size = Vector2(90, 30)
		else:
			label(r, "come ricarica" if a[0] == "interact" else "stick", 12, MUT).custom_minimum_size.x = 90

func _wait_bind(id: String, dev: String) -> void:
	var W: Dictionary = G.inp.bind_wait
	G.inp.bind_wait = {} if W.get("id", "") == id and W.get("dev", "") == dev else { "id": id, "dev": dev }
	render_binds()

func _reset_settings() -> void:
	var keep := { "input": G.settings.input, "binds": G.settings.binds, "padBinds": G.settings.padBinds }
	G.settings = G.SETTINGS_DEFAULT.duplicate(true)
	for k in keep:
		G.settings[k] = keep[k]
	G.save_settings()
	G.world.apply_atmosphere(G.mode)
	G.main.apply_quality()
	G.main.apply_fullscreen()
	G.audio.apply_volumes()
	_render_settings()

# ---------------------------------------------------------------- locker
func open_locker() -> void:
	_show(m.lock, true)
	_render_locker()

func _render_locker() -> void:
	var lvl: int = G.level_of().lvl
	m.lock.tag.text = "●  LIVELLO %d" % lvl
	for c in m.lock.list.get_children():
		c.queue_free()
	var first: Button = null
	for k in G.LOOK_ORDER:
		var g: Dictionary = G.LOOKS[k]
		label(m.lock.list, g.name, 15, ACC2, true)
		var r := flow(m.lock.list, 10)
		r.custom_minimum_size.x = 1000
		for it in g.items:
			var open: bool = lvl >= it.lvl
			var sel: bool = G.loadout[k] == it.id
			var b := btn(r, "", _pick_look.bind(k, it.id), false)
			b.toggle_mode = true
			b.button_pressed = sel
			b.disabled = not open
			b.custom_minimum_size = Vector2(150, 120)
			var v := vbox(b, 4)
			v.set_anchors_preset(Control.PRESET_FULL_RECT)
			v.offset_left = 10; v.offset_top = 10; v.offset_right = -10
			var sw := hbox(v, 0)
			var cols: Array = it.get("pal", [it.get("metal", it.get("base", "#888888")), it.get("poly", it.get("base", "#888888"))])
			for c in cols:
				var cr := ColorRect.new()
				cr.color = Color.html(c)
				cr.custom_minimum_size = Vector2(128.0 / cols.size(), 40)
				cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sw.add_child(cr)
			label(v, it.name, 15, TXT, true)
			label(v, "IN USO" if sel else ("Sbloccata" if open else "Livello %d" % it.lvl), 12, GOOD if sel else MUT)
			if first == null and open:
				first = b
	_focus(first)

func _pick_look(k: String, id: String) -> void:
	G.loadout[k] = id
	G.sset("loadout", G.loadout.duplicate())
	G.weapons.apply_loadout()
	_render_locker()

# ---------------------------------------------------------------- shops
func open_shop(kind: String) -> void:
	var sh: Dictionary = m.sh
	m.root.visible = true
	m.menu.visible = false
	sh.tag.text = "●  %s %d" % [G.game.word().wave, G.wave]
	sh.title.text = "DISTRIBUTORE DI PERK" if kind == "perks" else "BANCO ARMI"
	sh.sub.text = "Abilità permanenti per tutta la partita, una per tipo. Il distributore apre solo tra un’ondata e l’altra: il conto alla rovescia è fermo finché resti qui." if kind == "perks" \
		else "Spendi i crediti per potenziare le armi che hai con te. I potenziamenti restano su quell’arma per tutta la partita, anche se la lasci a terra e la riprendi."
	_show(sh, true)
	render_shop()

func close_shop() -> void:
	_show(m.sh, false)
	m.root.visible = false

func render_shop() -> void:
	var sh: Dictionary = m.sh
	sh.cash.text = str(G.cash)
	for c in sh.grid.get_children():
		c.queue_free()
	var first: Button = null
	if G.game.shop_kind == "perks":
		for k in G.PERK_ORDER:
			var pk: Dictionary = G.PERKS[k]
			var own: bool = G.perk_owned(k)
			var b := btn(sh.grid, "", G.game.buy_perk.bind(k))
			b.disabled = own or G.cash < pk.cost
			b.custom_minimum_size = Vector2(520, 84)
			var r := hbox(b, 12)
			r.set_anchors_preset(Control.PRESET_FULL_RECT)
			r.offset_left = 14; r.offset_right = -14
			var t := label(r, pk.tag, 26, Color.html(pk.css), true)
			t.custom_minimum_size.x = 50
			var v := vbox(r, 2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			label(v, pk.name + (" · %d/%d" % [G.revives, G.MAX_REVIVES] if k == "revive" else ""), 17, TXT, true)
			var d := label(v, pk.desc, 13, MUT)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label(r, ("AL MASSIMO" if k == "revive" else "ATTIVO") if own else str(pk.cost), 18, GOOD if own else Color("#ffd45a"), true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if first == null and not b.disabled:
				first = b
	else:
		for k in G.slots:
			if k == null:
				continue
			var col := panel(sh.grid)
			col.custom_minimum_size.x = 360
			var v2 := vbox(col, 8)
			var hd := hbox(v2, 10)
			tex_rect(hd, icon(k, 48), Vector2(90, 30), ACC2)
			var hv := vbox(hd, 0)
			label(hv, G.weapons.W[k].name, 17, TXT, true)
			label(hv, "IN MANO" if k == G.weapons.current else "DI RISERVA", 11, MUT, true)
			for t2 in ["dmg", "mag", "rel"]:
				var u: Dictionary = G.UPGRADES[t2]
				var l := G.upg_lv(k, t2)
				var mx := l >= G.UPG_COST.size()
				var b2 := btn(v2, "", G.game.buy_upgrade.bind(k, t2))
				b2.disabled = mx or G.cash < G.UPG_COST[mini(l, 2)]
				b2.custom_minimum_size = Vector2(330, 62)
				var r2 := hbox(b2, 8)
				r2.set_anchors_preset(Control.PRESET_FULL_RECT)
				r2.offset_left = 12; r2.offset_right = -12
				var tv := vbox(r2, 0)
				tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				tv.alignment = BoxContainer.ALIGNMENT_CENTER
				label(tv, u.name, 15, TXT, true)
				label(tv, ((u.fmt % (l * u.step)) if l else "di serie") + ("" if mx else "  →  " + (u.fmt % ((l + 1) * u.step))), 12, MUT)
				var pips := hbox(r2, 3)
				pips.alignment = BoxContainer.ALIGNMENT_CENTER
				for i in 3:
					var pr := ColorRect.new()
					pr.color = ACC if i < l else Color(1, 1, 1, 0.15)
					pr.custom_minimum_size = Vector2(10, 10)
					pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
					pips.add_child(pr)
				label(r2, "MAX" if mx else str(G.UPG_COST[l]), 16, GOOD if mx else Color("#ffd45a"), true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
				if first == null and not b2.disabled:
					first = b2
	_focus(first if first else sh.close)

# ============================================================ HUD updates
func match_started() -> void:
	for c in h.killfeed.get_children(): c.queue_free()
	for c in h.toasts.get_children(): c.queue_free()
	h.wave_label.text = G.game.word().wave
	scope_on = false
	clear_powers()
	render_perks()
	hud_lag_hp = 100

func clear_match() -> void:
	for d in dmg_nums:
		d.l.queue_free()
	dmg_nums.clear()
	dmg_dirs.clear()
	set_prompt("", "", "", "")
	h.tut.visible = false

func update_hud(dt: float) -> void:
	var P: Node = G.player
	var Wp: Node = G.weapons
	var hp := maxi(0, ceili(P.hp))
	var ar := ceili(P.armor)
	hud_lag_hp = maxf(hp, hud_lag_hp - 40 * dt)
	h.hp.text = str(hp)
	_set_bar(h.hp_bar, hp / 100.0, hud_lag_hp / 100.0, BAD if hp < 35 else GOOD)
	h.hp.add_theme_color_override("font_color", BAD if hp < 35 else TXT)
	h.regen.visible = hp < 100 and G.now - P.last_hit > G.D.regenDelay * (0.5 if G.perks.has("regen") else 1.0)
	h.stance.visible = P.crouch
	h.armor.text = str(ar)
	_set_bar(h.armor_bar, ar / 100.0)
	var w: Dictionary = Wp.cur()
	var mag: int = Wp.mags.get(Wp.current, 0)
	var mx: int = Wp.mag_of(Wp.current)
	h.wname.text = w.name
	h.wicon.texture = icon(Wp.current, 48)
	var inf := G.pw("ammo")
	var low := mag <= ceili(mx / 6.0)
	h.ammo.text = "∞" if inf else str(mag)
	h.ammo.add_theme_color_override("font_color", BAD if low and not inf else TXT)
	h.reload.visible = low and not Wp.reloading and not inf and fmod(G.now, 1.0) < 0.7
	h.reload.text = "%s · RICARICA" % G.inp.key_label("R", "X")
	h.pips.set_meta("n", mx); h.pips.set_meta("m", mag)
	h.pips.queue_redraw()
	var act: String = "knife" if Wp.melee_t > 0 else Wp.current
	for i in 3:
		var s: Dictionary = h.slots[i]
		var k: String = "knife" if i == 2 else (G.slots[i] if G.slots[i] else "")
		s.icon.texture = icon(k, 48) if k != "" else null
		s.panel.add_theme_stylebox_override("panel", sb(Color(1, 0.42, 0.24, 0.22), 10, ACC) if k == act and k != "" else glass(10))
	for k in G.EQUIP_ORDER:
		var e: Dictionary = h.equip[k]
		e.n.text = str(G.equip[k])
		e.panel.modulate.a = 1.0 if G.equip[k] > 0 else 0.45
	# boss bar
	var boss: Object = G.enemies.boss()
	h.boss.visible = boss != null
	if boss:
		if boss.bar_lag < 0:
			boss.bar_lag = boss.max_hp
		boss.bar_lag = maxf(boss.hp, boss.bar_lag - boss.max_hp * 0.25 * dt)
		h.boss_name.text = boss.name + (" · FASE %d" % boss.phase if boss.phase > 1 else "")
		h.boss_hp.text = str(ceili(boss.hp))
		_set_bar(h.boss_bar, boss.hp / boss.max_hp, boss.bar_lag / boss.max_hp)
	h.wave.text = str(G.wave)
	var brk: bool = G.wave > 0 and G.wave_break > 0
	h.brk.visible = brk
	if brk:
		h.brk.text = "prossima tra %ds" % ceili(G.wave_break) + (" · %s per iniziare" % G.inp.key_label("INVIO", "back") if G.wave_break > 3 else "")
	var left: int = G.enemies.alive() + G.to_spawn
	h.wave_sub.text = "%d %s rimasti%s" % [left, G.game.word().enemy, G.game.diff_level_text()]
	_set_bar(h.wave_prog, 1.0 if G.wave_break > 0 else 1.0 - float(left) / maxf(1, G.wave_total))
	h.score.text = str(G.score)
	h.kills.text = str(G.kills)
	h.cash.text = str(G.cash)
	h.blind.color.a = minf(1, G.blind)
	# power-ups: rows with a countdown bar, and a coloured glow around the screen
	var glow_col: Variant = null
	for k in G.POWERUPS:
		var left_t: float = G.powers[k]
		var def: Dictionary = G.POWERUPS[k]
		if left_t > 0:
			if not h.power_rows.has(k):
				var p := panel(h.powers, 12)
				var r := hbox(p, 8)
				tex_rect(r, icon(k, 32), Vector2(22, 22), Color.html(def.css))
				var v := vbox(r, 2)
				label(v, def.name, 13, Color.html(def.css), true)
				var bar := _bar(v, Vector2(140, 4), Color.html(def.css))
				var t := label(r, "", 18, TXT, true)
				h.power_rows[k] = { "p": p, "bar": bar, "t": t }
			var row: Dictionary = h.power_rows[k]
			_set_bar(row.bar, left_t / def.dur)
			row.t.text = str(ceili(left_t))
			row.p.modulate.a = (0.5 + 0.5 * sin(G.now * 12)) if left_t < 3 else 1.0
			glow_col = Color.html(def.css)
		elif h.power_rows.has(k):
			h.power_rows[k].p.queue_free()
			h.power_rows.erase(k)
	var gm: ShaderMaterial = h.glow.material
	gm.set_shader_parameter("col", Color(glow_col.r, glow_col.g, glow_col.b, 0.33) if glow_col is Color else Color(0, 0, 0, 0))
	# banner, toasts, note
	if banner_t > 0:
		banner_t -= dt
		h.banner.modulate.a = clampf(banner_t / 0.4, 0, 1) * clampf((2.6 - banner_t) / 0.25 + 0.0, 0, 1) if banner_t < 2.6 else 1.0
	else:
		h.banner.modulate.a = 0
	if h.note_t > 0:
		h.note_t -= dt
		h.note.visible = h.note_t > 0
	hit_t = maxf(0, hit_t - dt)
	for i in range(dmg_dirs.size() - 1, -1, -1):
		dmg_dirs[i].t -= dt
		if dmg_dirs[i].t <= 0:
			dmg_dirs.remove_at(i)
	_update_damage_numbers(dt)
	if mm_ver != G.world.map_version or mm_base == null:
		_minimap_base()
	var mmm: ShaderMaterial = h.mm.material
	mmm.set_shader_parameter("ppos", Vector2(P.pos.x, P.pos.z))
	mmm.set_shader_parameter("yaw", P.yaw)
	h.mm_marks.queue_redraw()
	overlay.queue_redraw()

func _draw_pips() -> void:
	var c: Control = h.pips
	var n: int = c.get_meta("n", 30)
	var mg: int = c.get_meta("m", 30)
	if n <= 0:
		return
	var w := c.size.x
	var gap := 1.0 if n > 40 else 2.0
	var pw := (w - gap * (n - 1)) / n
	for i in n:
		c.draw_rect(Rect2(i * (pw + gap), 0, maxf(1, pw), c.size.y), ACC2 if i < mg else Color(1, 1, 1, 0.12))

func _draw_overlay() -> void:
	var c := overlay
	var sz := c.size
	var ctr := sz / 2
	var Wp: Node = G.weapons
	var P: Node = G.player
	var w: Dictionary = Wp.cur()
	# enemy health bars over their heads
	var cam: Camera3D = G.camera
	var focal: float = sz.y / (2.0 * tan(deg_to_rad(cam.fov) / 2.0))
	for e in G.enemies.list:
		if e.dead or not e.hb_visible:
			continue
		var top: Vector3 = e.pos + Vector3(0, e.bar_y + (e.hips.position.y - 0.88), 0)
		if cam.is_position_behind(top):
			continue
		var dist := cam.global_position.distance_to(top)
		if dist > 60:
			continue
		var p2 := cam.unproject_position(top)
		var s := clampf(dist / 14, 1, 2.4) * 0.85
		var bw := clampf(focal * s / dist, 26, 120)
		var bh := maxf(4, bw * 0.12)
		var f: float = e.hp / e.max_hp
		var r := Rect2(p2 - Vector2(bw / 2, bh / 2), Vector2(bw, bh))
		c.draw_rect(r.grow(1), Color(0.04, 0.05, 0.07, 0.7))
		c.draw_rect(Rect2(r.position, Vector2(bw * e.lag_hp / e.max_hp, bh)), Color(1, 1, 1, 0.85))
		c.draw_rect(Rect2(r.position, Vector2(bw * f, bh)), Color.from_hsv(f * 0.36, 0.75, 0.95) if e.hurt_t <= 0 else Color.WHITE)
	# scope: black outside a circle, thin reticle
	if scope_on:
		var rad := sz.y * 0.46
		var pts := PackedVector2Array()
		for i in 65:
			var a := i / 64.0 * TAU
			pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
		var outer := [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]
		c.draw_rect(Rect2(0, 0, ctr.x - rad + 1, sz.y), Color.BLACK)
		c.draw_rect(Rect2(ctr.x + rad - 1, 0, sz.x - ctr.x - rad + 1, sz.y), Color.BLACK)
		for i in 64:
			var a0 := i / 64.0 * TAU
			var a1 := (i + 1) / 64.0 * TAU
			var p0 := ctr + Vector2(cos(a0), sin(a0)) * rad
			var p1 := ctr + Vector2(cos(a1), sin(a1)) * rad
			var e0 := Vector2(p0.x, 0.0 if p0.y < ctr.y else sz.y)
			var e1 := Vector2(p1.x, 0.0 if p1.y < ctr.y else sz.y)
			if (p0.y < ctr.y) == (p1.y < ctr.y):
				c.draw_colored_polygon(PackedVector2Array([p0, p1, e1, e0]), Color.BLACK)
		c.draw_arc(ctr, rad, 0, TAU, 96, Color(0, 0, 0, 1), 6)
		c.draw_line(Vector2(ctr.x - rad, ctr.y), Vector2(ctr.x + rad, ctr.y), Color(0, 0, 0, 0.85), 1.5)
		c.draw_line(Vector2(ctr.x, ctr.y - rad), Vector2(ctr.x, ctr.y + rad), Color(0, 0, 0, 0.85), 1.5)
		c.draw_line(Vector2(ctr.x - rad, ctr.y), Vector2(ctr.x - 40, ctr.y), Color.BLACK, 4)
		c.draw_line(Vector2(ctr.x + 40, ctr.y), Vector2(ctr.x + rad, ctr.y), Color.BLACK, 4)
		c.draw_line(Vector2(ctr.x, ctr.y + 40), Vector2(ctr.x, ctr.y + rad), Color.BLACK, 4)
		c.draw_circle(ctr, 2, Color(1, 0.2, 0.15))
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.1, 0.2, 0.1, 0.06))
		outer.clear()
	else:
		# crosshair: four ticks pushed out by the spread, a dot, and the reload ring
		var a = (1 - Wp.ads_t) * (1 - P.sprint_t * 0.8)
		if a > 0.02:
			var g = 5 + (Wp.current_spread() + (w.pelletSpread if w.has("pellets") else 0.0)) * 420
			var col := Color(1, 1, 1, a)
			var sh := Color(0, 0, 0, a * 0.5)
			for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				c.draw_line(ctr + d * g + Vector2(1, 1), ctr + d * (g + 8) + Vector2(1, 1), sh, 2)
				c.draw_line(ctr + d * g, ctr + d * (g + 8), col, 2)
			c.draw_circle(ctr, 2, col)
		if Wp.reloading:
			c.draw_arc(ctr, 20, -PI / 2, -PI / 2 + TAU, 48, Color(1, 1, 1, 0.15), 3)
			c.draw_arc(ctr, 20, -PI / 2, -PI / 2 + TAU * (1 - Wp.reload_t / Wp.reload_of()), 48, ACC2, 3)
	# hitmarker
	if hit_t > 0:
		var k := hit_t / (0.45 if hit_kill else 0.22)
		var s2 := 1 + k * 0.35
		var col2 := Color(1, 0.3, 0.25, k) if hit_kill else Color(1, 1, 1, k)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			c.draw_line(ctr + d * 6 * s2, ctr + d * 14 * s2, col2, 2.5)
	# damage direction arcs
	for dd in dmg_dirs:
		var al: float = dd.t / 1.2
		var rot: float = dd.rot - P.yaw
		var ang := -PI / 2 - rot
		c.draw_arc(ctr, 140, ang - 0.35, ang + 0.35, 24, Color(1, 0.2, 0.15, al * 0.85), 7)

func _draw_minimap() -> void:
	var c: Control = h.mm_marks
	var P: Node = G.player
	var R := 95.0
	var S := R / 32.0
	var cy := cos(P.yaw)
	var sy := sin(P.yaw)
	var MAP: Dictionary = G.world.MAP
	var to_map := func(x: float, z: float) -> Vector2:
		var dx = x - P.pos.x
		var dz = z - P.pos.z
		return Vector2(R + (dx * cy - dz * sy) * S, R + (dx * sy + dz * cy) * S)
	var inside := func(p: Vector2) -> bool: return p.distance_to(Vector2(R, R)) < R - 3
	if G.world.arena_on:
		for pd in MAP.layer.pads:
			var pp: Vector2 = to_map.call(pd.pos.x, pd.pos.z)
			if inside.call(pp): c.draw_circle(pp, 0.8 * S, Color(0.23, 1, 0.88, 0.8))
	var box: Dictionary = G.items.box
	if box.group.visible:
		var bp: Vector2 = to_map.call(box.group.position.x, box.group.position.z)
		if inside.call(bp): c.draw_rect(Rect2(bp - Vector2(S, S), Vector2(2 * S, 2 * S)), Color("#ffd45a"))
	for hs in MAP.houses:
		for d in hs.doors:
			var dp: Vector2 = to_map.call(d.x, d.y)
			if inside.call(dp): c.draw_rect(Rect2(dp - Vector2(0.7, 0.7) * S, Vector2(1.4, 1.4) * S), Color("#8dffb0") if hs.open else Color("#ff6a5a"))
	if MAP.has("bench"):
		var b1: Vector2 = to_map.call(MAP.bench.x, MAP.bench.z)
		if inside.call(b1): c.draw_circle(b1, 1.1 * S, Color("#ff9d5c"))
	if MAP.has("perks"):
		var b2: Vector2 = to_map.call(MAP.perks.x, MAP.perks.z)
		if inside.call(b2): c.draw_circle(b2, 1.1 * S, Color(0.79, 0.55, 1, 1.0 if G.wave_break > 0 else 0.45))
	# enemies: far ones clamp to the rim so you always know where they come from
	for e in G.enemies.list:
		if e.dead:
			continue
		var ep: Vector2 = to_map.call(e.pos.x, e.pos.z) - Vector2(R, R)
		var d2 := ep.length()
		var edge := d2 > R - 6
		if edge:
			ep *= (R - 6) / d2
		var col := Color("#ffd45a") if e.boss else (Color("#b98cff") if e.climber else (Color("#ff6a3d") if G.mode == "zombie" else Color("#ff4d4d")))
		col.a = 0.55 if edge else 1.0
		c.draw_circle(Vector2(R, R) + ep, (2.5 if edge else 3.6) * (1.9 if e.boss else 1.0), col)
		if not edge and e.pos.y - P.pos.y > 1.5:
			c.draw_rect(Rect2(Vector2(R, R) + ep + Vector2(-1, -8), Vector2(2, 3)), col)
	# you
	var arrow := PackedVector2Array([Vector2(R, R - 7), Vector2(R + 5, R + 5), Vector2(R, R + 2.5), Vector2(R - 5, R + 5)])
	c.draw_colored_polygon(arrow, Color.WHITE)

func _update_damage_numbers(dt: float) -> void:
	var cam: Camera3D = G.camera
	for i in range(dmg_nums.size() - 1, -1, -1):
		var d: Dictionary = dmg_nums[i]
		d.t += dt
		var p: Vector3 = d.pos + Vector3(d.dx * d.t, 0.4 + d.t * 0.9, 0)
		var l: Label = d.l
		if cam.is_position_behind(p):
			l.visible = false
		else:
			l.visible = true
			var sp := cam.unproject_position(p)
			var pop = 1 + (0.12 - d.t) * 4 if d.t < 0.12 else 1.0
			l.scale = Vector2.ONE * pop
			l.position = sp - l.size * 0.5 * pop
			l.modulate.a = minf(1, (0.9 - d.t) * 3)
		if d.t > 0.9:
			l.queue_free()
			dmg_nums.remove_at(i)

# ============================================================ events from the game
func damage_number(pos: Vector3, amount: float, head: bool, kill: bool) -> void:
	var l := label(dmg_root, str(roundi(amount)), 26 if kill else (22 if head else 18), Color("#ff4d4d") if kill else (Color("#ffd45a") if head else TXT), true)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	dmg_nums.append({ "l": l, "pos": pos, "t": 0.0, "dx": G.rnd(-0.3, 0.3) })

func hitmarker(kill: bool) -> void:
	hit_kill = kill
	hit_t = 0.45 if kill else 0.22

func damage_dir(rot: float) -> void:
	dmg_dirs.append({ "rot": rot + G.player.yaw, "t": 1.2 })

func banner(big: String, small: String) -> void:
	h.banner_big.text = big
	h.banner_small.text = small
	banner_t = 2.85

func toast(text: String, color := "#ffb36b") -> void:
	var p := panel(h.toasts, 12)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var s := glass(12)
	s.border_color = Color.html(color)
	s.border_color.a = 0.6
	p.add_theme_stylebox_override("panel", s)
	label(p, text, 16, Color.html(color), true)
	var tw := p.create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)
	while h.toasts.get_child_count() > 5:
		h.toasts.get_child(0).queue_free()
		break

func killfeed(name: String, head: bool, weapon_key: String) -> void:
	var p := panel(null, 10)
	h.killfeed.add_child(p)
	h.killfeed.move_child(p, 0)
	var r := hbox(p, 8)
	label(r, "TU", 14, ACC2, true)
	tex_rect(r, icon(weapon_key if ICONS.has(weapon_key) else "knife", 32), Vector2(44, 16))
	label(r, name, 14)
	if head:
		label(r, "HEADSHOT", 12, Color("#ffd45a"), true)
	var tw := p.create_tween()
	tw.tween_interval(4.1)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	while h.killfeed.get_child_count() > 5:
		var last = h.killfeed.get_child(h.killfeed.get_child_count() - 1)
		h.killfeed.remove_child(last)
		last.queue_free()

func set_prompt(key: String, text: String, extra: String, extra_kind: String) -> void:
	h.prompt.visible = text != ""
	if text == "":
		return
	h.prompt_key.visible = key != ""
	h.prompt_key.text = key
	h.prompt_text.text = text
	h.prompt_extra.text = extra
	h.prompt_extra.visible = extra != ""
	if extra_kind == "no":
		h.prompt_extra.add_theme_color_override("font_color", BAD)
	elif extra_kind == "price" or extra_kind == "":
		h.prompt_extra.add_theme_color_override("font_color", Color("#ffd45a"))
	else:
		h.prompt_extra.add_theme_color_override("font_color", Color.html(extra_kind))

func tutorial(step: String, text: String, ok: bool) -> void:
	h.tut.visible = text != ""
	h.tut_step.text = step + ("   ✓" if ok else "")
	h.tut_step.add_theme_color_override("font_color", GOOD if ok else ACC2)
	h.tut_text.text = text

func render_perks() -> void:
	for c in h.perks.get_children():
		c.queue_free()
	for i in G.revives:
		label(h.perks, "♥", 22, Color.html(G.PERKS.revive.css), true)
	for k in G.PERK_ORDER:
		if G.perks.has(k):
			var p := panel(h.perks, 8)
			label(p, G.PERKS[k].tag, 13, Color.html(G.PERKS[k].css), true)

func clear_powers() -> void:
	for k in h.power_rows:
		h.power_rows[k].p.queue_free()
	h.power_rows.clear()

func flash_cash() -> void:
	var l: Label = h.cash
	l.add_theme_color_override("font_color", Color("#ffd45a"))
	var tw := l.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func(): l.add_theme_color_override("font_color", TXT))

func shake_equip(kind: String) -> void:
	var p: Control = h.equip[kind].panel
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", p.position.x - 4, 0.05)
	tw.tween_property(p, "position:x", p.position.x + 4, 0.06)
	tw.tween_property(p, "position:x", p.position.x, 0.05)

func bump_equip(kind: String) -> void:
	var p: Control = h.equip[kind].panel
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", p.position.y - 4, 0.08)
	tw.tween_property(p, "position:y", p.position.y, 0.15)

func pad_note(text: String) -> void:
	h.note_text.text = text
	h.note.visible = true
	h.note_t = 3.2
	if not hud.visible:
		toast_menu(text)

func toast_menu(text: String) -> void:
	if not m.root.visible:
		return
	var l := label(m.root, text, 15, ACC2, true)
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.position += Vector2(-200, -60)
	var tw := l.create_tween()
	tw.tween_interval(2.8)
	tw.tween_callback(l.queue_free)

func set_fps(n: int) -> void:
	h.fps.text = "%d FPS" % n

func sound_changed() -> void:
	var t := "AUDIO DISATTIVATO" if G.muted else "AUDIO ATTIVO"
	if hud.visible:
		toast(t, "#9ad4ff")
	else:
		toast_menu(t)

# refresh every on-screen key hint for the current input device
func input_changed() -> void:
	var on: bool = G.inp.pad_mode() and G.inp.active_pad()
	var eq_keys := { "frag": ["frag", "LB"], "stun": ["stun", "up"], "smoke": ["smoke", "down"], "tknife": ["tknife", "left"] }
	for k in h.equip:
		var e: Array = eq_keys[k]
		h.equip[k].key.text = G.inp.pad_label(e[1]) if on else G.key_name(G.bind_of(e[0]))
	h.slots[2].key.text = G.inp.pad_label("RB") if on else G.key_name(G.bind_of("melee"))
	if m.has("set") and m.set.root.visible:
		_render_settings()
	if m.has("menu") and m.menu.visible:
		_set_tab(tab)
