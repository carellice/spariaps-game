# Spariaps — Materiali, shader e texture procedurali, costruzione delle mesh.
# Tutta la scenografia statica passa da Batch: una sola mesh per materiale, così la GPU fa poche chiamate di disegno.
class_name Gfx
extends RefCounted

static var _shaders := {}
static var _noise: NoiseTexture2D
static var _noise_n: NoiseTexture2D
static var _radial := {}

# ============================================================ materials
static func mat(color: Variant, rough := 0.8, metal := 0.0, extra := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color if color is Color else G.col(int(color))
	m.roughness = rough
	m.metallic = metal
	for k in extra:
		m.set(k, extra[k])
	return m

# glowing surface: black body, light from the emission only (picked up by the bloom)
static func glow(color: Variant, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.emission_enabled = true
	m.emission = color if color is Color else G.col(int(color))
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	return m

# flat additive glow (beams, discs, flashes): no lighting, no depth writes
static func additive(color: Variant, alpha := 1.0, tex: Texture2D = null, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var c: Color = color if color is Color else G.col(int(color))
	m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy, alpha)
	if tex:
		m.albedo_texture = tex
	m.disable_receive_shadows = true
	return m

static func transparent(color: Variant, alpha: float, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := mat(color, rough, metal)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = alpha
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func noise_tex() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 256; _noise.height = 256
		_noise.seamless = true
		_noise.noise = n
	return _noise

static func noise_normal() -> NoiseTexture2D:
	if _noise_n == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.06
		_noise_n = NoiseTexture2D.new()
		_noise_n.width = 256; _noise_n.height = 256
		_noise_n.seamless = true
		_noise_n.as_normal_map = true
		_noise_n.bump_strength = 3.0
		_noise_n.noise = n
	return _noise_n

static func shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]

# plaster, concrete, paving, asphalt: colour noise + seams on a world grid (every face tiles on its own plane)
const SURFACE_SHADER := """
shader_type spatial;
uniform vec4 base : source_color;
uniform vec4 seam : source_color;
uniform float cells = 1.0;
uniform float tile = 4.0;
uniform float blotch = 0.1;
uniform float dirt = 0.0;
uniform float rough = 0.8;
uniform float metal = 0.0;
uniform float bump = 0.5;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D nmap : hint_normal, repeat_enable, filter_linear_mipmap;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = abs(wnrm);
	vec2 p = n.x >= n.y && n.x >= n.z ? wpos.zy : (n.y >= n.z ? wpos.xz : wpos.xy);
	vec2 uv = p / tile;
	float big = texture(noise, uv * 0.35).r;
	float fine = texture(noise, uv * 7.0).r;
	vec3 c = base.rgb * (1.0 + (big - 0.5) * blotch * 4.0) * (0.92 + fine * 0.16);
	vec2 g = fract(uv * cells);
	vec2 e = min(g, 1.0 - g);
	float s = 1.0 - smoothstep(0.0, 0.006 * cells, min(e.x, e.y));
	c = mix(c, seam.rgb, s * 0.85);
	c *= 1.0 - dirt * (1.0 - smoothstep(0.0, 1.6, wpos.y)) * step(n.y, 0.5);
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = texture(nmap, uv * 1.5).rgb;
	NORMAL_MAP_DEPTH = bump;
}
"""

static func surface(base: String, seam: String, cells := 1.0, tile := 4.0, blotch := 0.1, rough := 0.8, dirt := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("surface", SURFACE_SHADER)
	m.set_shader_parameter("base", Color.html(base))
	m.set_shader_parameter("seam", Color.html(seam))
	m.set_shader_parameter("cells", cells)
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("blotch", blotch)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("dirt", dirt)
	m.set_shader_parameter("noise", noise_tex())
	m.set_shader_parameter("nmap", noise_normal())
	return m

# soft vertical light beam (jump pads, power-ups, mystery box), additive
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color;
uniform float k = 0.5;
uniform float up = 1.0;
void fragment() {
	float v = up > 0.5 ? 1.0 - UV.y : UV.y;
	float a = pow(clamp(1.0 - v, 0.0, 1.0), 1.5) * k * (0.6 + 0.4 * sin(UV.x * 6.2832 * 3.0));
	ALBEDO = color.rgb * a * 1.6;
	ALPHA = a;
}
"""

static func beam(color: Variant, k := 0.55, up := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("beam", BEAM_SHADER)
	m.set_shader_parameter("color", color if color is Color else G.col(int(color)))
	m.set_shader_parameter("k", k)
	m.set_shader_parameter("up", 1.0 if up else 0.0)
	return m

# radial gradient texture (glows, flashes, smoke puffs, holes)
static func radial(key: String, stops: Array) -> GradientTexture2D:
	if _radial.has(key):
		return _radial[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128; t.height = 128
	_radial[key] = t
	return t

static func glow_tex() -> GradientTexture2D:
	return radial("glow", [[0.0, Color(1, 1, 1, 0.9)], [0.35, Color(1, 1, 1, 0.35)], [1.0, Color(1, 1, 1, 0)]])

static func flash_tex() -> GradientTexture2D:
	return radial("flash", [[0.0, Color(1, 1, 0.94, 1)], [0.25, Color(1, 0.86, 0.47, 0.9)], [0.6, Color(1, 0.55, 0.16, 0.35)], [1.0, Color(1, 0.4, 0, 0)]])

static func smoke_tex() -> GradientTexture2D:
	return radial("smoke", [[0.0, Color(1, 1, 1, 0.55)], [0.5, Color(1, 1, 1, 0.2)], [1.0, Color(1, 1, 1, 0)]])

static func cloud_tex() -> GradientTexture2D:
	return radial("cloud", [[0.0, Color(1, 1, 1, 0.95)], [0.45, Color(1, 1, 1, 0.6)], [0.8, Color(1, 1, 1, 0.18)], [1.0, Color(1, 1, 1, 0)]])

static func hole_tex() -> GradientTexture2D:
	return radial("hole", [[0.0, Color(0.04, 0.04, 0.04, 1)], [0.35, Color(0.08, 0.08, 0.08, 0.9)], [0.6, Color(0.16, 0.16, 0.16, 0.4)], [1.0, Color(0, 0, 0, 0)]])

static func fire_tex() -> GradientTexture2D:
	return radial("fire", [[0.0, Color(1, 0.98, 0.86, 0.9)], [0.35, Color(1, 0.75, 0.35, 0.6)], [0.7, Color(0.9, 0.31, 0.08, 0.25)], [1.0, Color(0.47, 0.08, 0, 0)]])

# ============================================================ procedural images
static func _img(w: int, h: int, c: Color) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(c)
	return im

static func _rect(im: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	var r := Rect2i(int(x), int(y), maxi(1, int(w)), maxi(1, int(h))).intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if c.a >= 0.999:
		im.fill_rect(r, c)
	else:
		var src := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		src.fill(c)
		im.blend_rect(src, Rect2i(Vector2i.ZERO, r.size), r.position)

static func tex(im: Image) -> ImageTexture:
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# plastered facade, 4 bays x 4 floors per tile; a second image lights some windows at night
static func facade_tex(wall: String, shutter: String, frame := "#e9e2d2") -> Array:
	var S := 512
	var n := 4
	var cs := S / n
	var w0 := Color.html(wall)
	var sh := Color.html(shutter)
	var fr := Color.html(frame)
	var im := _img(S, S, w0)
	var em := _img(S, S, Color.BLACK)
	for i in 26:
		var x := randf() * S
		var y := randf() * S
		var r := G.rnd(30, 90)
		_rect(im, x - r, y - r * 0.6, r * 2, r * 1.2, Color(0, 0, 0, 0.035) if randf() < 0.6 else Color(1, 1, 1, 0.03))
	for j in n:
		_rect(im, 0, j * cs, S, 5, Color(1, 1, 1, 0.18))
		_rect(im, 0, j * cs + 5, S, 2, Color(0, 0, 0, 0.22))
		for i in n:
			var x := i * cs + cs * 0.31
			var w := cs * 0.38
			var y := j * cs + cs * 0.2
			var h := cs * 0.56
			var sw := w * 0.42
			_rect(im, x - 2, y + h, w + 4, 30, Color(0.12, 0.09, 0.05, 0.2))
			_rect(im, x - 5, y - 5, w + 10, h + 10, fr)
			var closed := randf() < 0.3
			var lit := not closed and randf() < 0.45
			if closed:
				_rect(im, x, y, w, h, sh)
				var k := y + 3
				while k < y + h:
					_rect(im, x, k, w, 1.5, Color(0, 0, 0, 0.28))
					k += 5
				_rect(im, x + w / 2 - 1, y, 2, h, Color(0, 0, 0, 0.28))
			else:
				_rect(im, x, y, w, h, Color.html("#16202b"))
				_rect(im, x, y, w * 0.3, h, Color(0.92, 0.88, 0.8, 0.22))
				_rect(im, x + w / 2 - 1.5, y, 3, h, fr)
				_rect(im, x, y + h * 0.36, w, 3, fr)
				_rect(im, x - 5 - sw, y - 2, sw, h + 4, sh)
				_rect(im, x + w + 5, y - 2, sw, h + 4, sh)
				var k2 := y + 2
				while k2 < y + h:
					_rect(im, x - 5 - sw, k2, sw, 1.5, Color(0, 0, 0, 0.25))
					_rect(im, x + w + 5, k2, sw, 1.5, Color(0, 0, 0, 0.25))
					k2 += 5
				if lit:
					_rect(em, x, y, w, h, Color(1, G.rnd(0.76, 0.94), G.rnd(0.5, 0.78)) * G.rnd(0.5, 1))
					_rect(em, x + w / 2 - 1.5, y, 3, h, Color.BLACK)
					_rect(em, x, y + h * 0.36, w, 3, Color.BLACK)
			_rect(im, x - 8, y + h + 6, w + 16, 4, Color(0, 0, 0, 0.35))
			_rect(im, x - 8, y + h + 2, w + 16, 5, fr)
	return [tex(im), tex(em)]

static func crate_tex() -> ImageTexture:
	var s := 256
	var im := _img(s, s, Color.html("#8f6f46"))
	for i in 16:
		_rect(im, 0, i * 16 + G.rnd(0, 6), s, 2, Color(0, 0, 0, randf() * 0.12))
	var c := Color.html("#5e4429")
	_rect(im, 0, 0, s, 20, c); _rect(im, 0, s - 20, s, 20, c); _rect(im, 0, 0, 20, s, c); _rect(im, s - 20, 0, 20, s, c)
	for k in range(16, s - 16, 4):
		_rect(im, k - 8, k - 8, 16, 16, c)
	return tex(im)

static func barrel_tex(color: String) -> ImageTexture:
	var s := 128
	var im := _img(s, s, Color.html(color))
	for y in [0.18, 0.5, 0.82]:
		_rect(im, 0, y * s - 3, s, 6, Color(0, 0, 0, 0.3))
		_rect(im, 0, y * s - 5, s, 2, Color(1, 1, 1, 0.14))
	for i in 300:
		_rect(im, randf() * s, randf() * s, 2, 2, Color(0.16, 0.08, 0.04, randf() * 0.2))
	return tex(im)

# lit window grid for the far skyline
static func windows_tex() -> ImageTexture:
	var im := _img(256, 256, Color.BLACK)
	for y in range(6, 256, 16):
		for x in range(6, 256, 12):
			if randf() < 0.42:
				_rect(im, x, y, 7, 9, Color(1, G.rnd(0.75, 0.95), G.rnd(0.47, 0.78)) * G.rnd(0.35, 1))
	return tex(im)

# shop windows: warm interior with shelf silhouettes
static func shopwin_tex() -> ImageTexture:
	var im := _img(128, 128, Color.html("#c9a36a"))
	for y in 128:
		_rect(im, 0, y, 128, 1, Color.html("#fff3d6").lerp(Color.html("#8a6a3c"), y / 128.0))
	var y2 := 30
	while y2 < 128:
		_rect(im, 0, y2, 128, 3, Color(0.08, 0.05, 0.03, 0.75))
		var x := 3.0
		while x < 125:
			var h := G.rnd(7, 20)
			_rect(im, x, y2 - h, G.rnd(4, 9), h, Color(G.rnd(0.08, 0.47), G.rnd(0.08, 0.35), G.rnd(0.04, 0.27), 0.8))
			x += G.rnd(7, 15)
		y2 += 31
	return tex(im)

# noise-based fabric / skin / camo: per-pixel, small images only (startup cost stays low)
static func blotch_tex(base: String, pal: Array, size := 128, freq := 0.035, kind := "camo") -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = randi()
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var b := Color.html(base)
	var cols: Array = pal.map(func(p): return Color.html(p))
	for y in size:
		for x in size:
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			var c := b
			if kind == "camo" and cols.size() >= 4:
				c = cols[clampi(int(v * 4.0), 0, 3)]
				if (x % 3) == 0:
					c = c.darkened(0.08)
			elif kind == "skin":
				c = b.lerp(Color(0.15, 0.08, 0.17) if v < 0.35 else Color(0.5, 0.52, 0.2), absf(v - 0.5) * 0.7)
				if randf() < 0.004:
					c = Color(0.37, 0.02, 0.02)
			else:
				c = b.darkened((1.0 - v) * 0.25 + randf() * 0.05)
				if v > 0.78:
					c = c.lerp(Color(0.3, 0.02, 0.02), 0.6)
			im.set_pixel(x, y, c)
	return tex(im)

# armour plates: panel lines, rivets and a hazard stripe
static func armor_tex(base: String, accent: String) -> ImageTexture:
	var s := 128
	var im := _img(s, s, Color.html(base))
	for i in 400:
		_rect(im, randf() * s, randf() * s, 2, 2, Color(0, 0, 0, randf() * 0.08) if randf() < 0.5 else Color(1, 1, 1, randf() * 0.06))
	for i in 5:
		var v := G.rnd(6, 122)
		if randf() < 0.5:
			_rect(im, 0, v, s, 1, Color(0, 0, 0, 0.5)); _rect(im, 0, v + 1, s, 1, Color(1, 1, 1, 0.12))
		else:
			_rect(im, v, 0, 1, s, Color(0, 0, 0, 0.5)); _rect(im, v + 1, 0, 1, s, Color(1, 1, 1, 0.12))
	for i in 20:
		var x := randf() * s
		var y := randf() * s
		_rect(im, x, y, 2, 2, Color(0, 0, 0, 0.45))
	if accent != "":
		_rect(im, 0, 95, s, 15, Color.html("#111111"))
		var ac := Color.html(accent)
		for k in range(-20, s + 20, 13):
			for t in 15:
				_rect(im, k + t, 95 + t, 6, 1, ac)
	for i in 40:
		_rect(im, randf() * s, randf() * s, G.rnd(2, 8), 1, Color(0.9, 0.9, 0.9, G.rnd(0.15, 0.4)))
	return tex(im)

# ============================================================ meshes
static var _boxes := {}

# box with softly rounded edges: keeps the blocky style, but edges catch the light like a modern low-poly model.
# Each face is a 4x4 grid; points are pulled onto a rounded box (inner box + radius), normals follow the rounding.
static func box(w: float, h: float, d: float) -> Mesh:
	var r := clampf(minf(w, minf(h, d)) * 0.12, 0.0015, 0.05)
	var key := "%.3f|%.3f|%.3f" % [w, h, d]
	if _boxes.has(key):
		return _boxes[key]
	var half := Vector3(w, h, d) * 0.5
	var inner := half - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# face normal, u axis, v axis
	var faces := [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hu := absf(half.dot(u))
		var hv := absf(half.dot(v))
		var hn := absf(half.dot(n))
		var us := [-hu, -hu + r, hu - r, hu]
		var vs := [-hv, -hv + r, hv - r, hv]
		var pts: Array = []
		var nrm: Array = []
		var uvs: Array = []
		for j in 4:
			for i in 4:
				var q: Vector3 = n * hn + u * us[i] + v * vs[j]
				var c := q.clamp(-inner, inner)
				var dn := q - c
				var nn := dn.normalized() if dn.length_squared() > 1e-12 else n
				pts.append(c + nn * r)
				nrm.append(nn)
				uvs.append(Vector2(us[i] / (2.0 * hu) + 0.5, 0.5 - vs[j] / (2.0 * hv)))
		for j in 3:
			for i in 3:
				var a := i + j * 4
				for k in [a, a + 1, a + 5, a, a + 5, a + 4]:
					st.set_normal(nrm[k])
					st.set_uv(uvs[k])
					st.add_vertex(pts[k])
	st.generate_tangents()
	var m := st.commit()
	_boxes[key] = m
	return m

# plain sharp box (tracers and other things that get stretched)
static func sharp_box(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m

static func cyl(rt: float, rb: float, h: float, seg := 16, open := false) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt; m.bottom_radius = rb; m.height = h
	m.radial_segments = seg; m.rings = 1
	m.cap_top = not open; m.cap_bottom = not open
	return m

static func sphere(r: float, seg := 16, rings := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r; m.height = r * 2.0
	m.radial_segments = seg; m.rings = rings
	return m

static func capsule(r: float, h: float, seg := 12) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r; m.height = maxf(h, r * 2.0 + 0.001)
	m.radial_segments = seg; m.rings = 4
	return m

static func torus(r: float, tube: float, seg := 32) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - tube; m.outer_radius = r + tube
	m.rings = seg; m.ring_segments = 8
	return m

static func plane(w: float, h: float) -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2(w, h)
	return m

# box whose side faces show a whole number of window bays and floors (facade texture is 4x4 bays); the roof samples plain wall
static func facade_box(w: float, h: float, d: float) -> ArrayMesh:
	var nf := maxf(1, roundf(h / 3.2))
	var nx := maxf(1, roundf(w / 3.2))
	var nz := maxf(1, roundf(d / 3.2))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2.0
	var hh := h / 2.0
	var hd := d / 2.0
	# each face: normal, u axis, v axis (up), extents, bays
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), hw, hd, nx],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), hw, hd, nx],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), hd, hw, nz],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), hd, hw, nz],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var ext: float = f[2]
		var off: float = f[3]
		var bays: float = f[4]
		var c := nrm * off
		var p := [c - u * ext - Vector3.UP * hh, c + u * ext - Vector3.UP * hh, c + u * ext + Vector3.UP * hh, c - u * ext + Vector3.UP * hh]
		var uv := [Vector2(0, nf / 4.0), Vector2(bays / 4.0, nf / 4.0), Vector2(bays / 4.0, 0), Vector2(0, 0)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nrm)
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
	# roof: plain wall colour
	var r := [Vector3(-hw, hh, -hd), Vector3(hw, hh, -hd), Vector3(hw, hh, hd), Vector3(-hw, hh, hd)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.004, 0.004))
		st.add_vertex(r[idx])
	st.generate_tangents()
	return st.commit()

# ============================================================ static batching: one mesh per material
class Batch:
	var groups := {}   # material -> [SurfaceTool, cast_shadow]
	func add(mesh: Mesh, m: Material, xf: Transform3D, shadow := true) -> void:
		var k := str(m.get_instance_id()) + ("s" if shadow else "n")
		if not groups.has(k):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[k] = [st, m, shadow]
		var st2: SurfaceTool = groups[k][0]
		for s in mesh.get_surface_count():
			st2.append_from(mesh, s, xf)
	func at(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, shadow := true) -> void:
		add(mesh, m, Transform3D(Basis.from_euler(rot), pos), shadow)
	func commit(parent: Node3D) -> Array:
		var out: Array = []
		for k in groups:
			var st: SurfaceTool = groups[k][0]
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = groups[k][1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if groups[k][2] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			out.append(mi)
		groups.clear()
		return out

static func mesh_node(mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if parent:
		parent.add_child(mi)
	return mi
