# Spariaps — Ondate, flusso di gioco, negozi, cambio classe, tutorial, sfide e carriera.
extends Node

const WAVE_BREAK := 60.0
var shop_kind := ""
var class_mode := "new"
var swap_from := ""
var chal_t := 1.0
var tut := { "i": -1, "t": 0.0, "okT": 0.0, "moved": 0.0, "ran": false, "jumped": false, "px": 0.0, "pz": 0.0, "text": "" }

func _ready() -> void:
	G.game = self

func word() -> Dictionary:
	return { "wave": "ORDA", "enemy": "zombie" } if G.mode == "zombie" else { "wave": "ONDATA", "enemy": "bot" }

# ============================================================ waves
func start_wave() -> void:
	G.wave += 1
	if G.diff_key == "progressive":
		G.D = G.diff_for(G.wave)
	# every 5th wave is a boss fight: the boss alone, stronger each time
	G.boss_wave = G.wave % 5 == 0
	var n := 1 if G.boss_wave else maxi(2, roundi((6 + G.wave * 3 if G.mode == "zombie" else 2 + G.wave * 2) * G.D.count))
	G.to_spawn = n; G.wave_total = n
	G.spawn_t = 2.5 if G.boss_wave else 0.5
	var W := word()
	if G.boss_wave:
		G.ui.banner("BOSS · %s %d" % [W.wave, G.wave], "%s LIVELLO %d STA ARRIVANDO" % ["L’ABOMINIO" if G.mode == "zombie" else "IL COLOSSO", G.wave / 5])
	else:
		G.ui.banner("%s %d" % [W.wave, G.wave], "%d %s IN ARRIVO" % [n, W.enemy.to_upper()] + (" · LA DIFFICOLTÀ AUMENTA" if G.diff_key == "progressive" and G.wave > 1 else ""))
	if G.mode == "zombie":
		G.audio.with_cat("enemies", func(): G.audio.groan(0.9, null))

func diff_level_text() -> String:
	if G.diff_key != "progressive":
		return ""
	var l: float = G.D.get("level", 0.0)
	return " · livello " + ("facile" if l < 0.2 else ("normale" if l < 0.45 else ("difficile" if l < 0.75 else ("incubo" if l <= 1 else "incubo+"))))

func boss_defeated(b: Object) -> void:
	var bonus := roundi(1000 * b.boss * G.D.score)
	G.items.add_cash(bonus)
	var p: Vector3 = b.pos + Vector3(0, 1.5, 0)
	G.fx.flash(p, 0xffc070, 12, 0.5); G.fx.light_burst(p, 0xffa050, 160); G.fx.blast(p, 6, 0xffa040, true)
	G.fx.particles(p, b.spark_color, 60, Vector3.UP, 10)
	for i in 8:
		G.fx.spawn_smoke(p + Vector3(G.rnd(-2, 2), G.rnd(-0.5, 2), G.rnd(-2, 2)), 0x3a3634, 3.5)
	G.audio.boom(1.2, p, 0)
	# loot: health, armour and throwables around the body
	for l in [["health", 1.6, 0.0], ["armor", -1.6, 0.0], ["equip", 0.0, 1.6], ["equip", 0.0, -1.6]]:
		G.items.temp_pickup(l[0], b.pos.x + l[1], b.pos.z + l[2])
	G.ui.toast("BOSS SCONFITTO · +%d CREDITI" % bonus, "#ffd45a")
	G.boss_kills += 1
	if G.revives < G.MAX_REVIVES:
		G.revives += 1
		G.ui.render_perks()
		get_tree().create_timer(0.9).timeout.connect(func(): G.ui.toast("+1 SECONDA VITA", "#ff5c7a"))

func update_waves(dt: float) -> void:
	if G.wave_break > 0:
		var before := ceili(G.wave_break)
		G.wave_break -= dt
		if G.wave > 0 and ceili(G.wave_break) != before and before <= 5:
			G.audio.tone(1320 if before == 1 else 880, 0.09, 0.08, "triangle")
		if G.wave_break <= 0:
			start_wave()
		return
	var max_alive := mini(18, roundi((5 + G.wave * 2) * G.D.count)) if G.mode == "zombie" else mini(9, 2 + G.wave)
	if G.to_spawn > 0 and G.enemies.alive() < max_alive:
		G.spawn_t -= dt
		if G.spawn_t <= 0:
			G.enemies.spawn_enemy()
			G.to_spawn -= 1
			G.spawn_t = G.rnd(0.25, 0.7) if G.mode == "zombie" else G.rnd(0.4, 1.2)
	if G.to_spawn == 0 and G.enemies.alive() == 0:
		G.wave_break = WAVE_BREAK; G.boss_wave = false
		var bonus := roundi(G.wave * 250 * G.D.score)
		G.score += bonus
		G.items.add_cash(bonus)
		G.ui.banner("%s SUPERATA" % word().wave, "+%d PUNTI · PROSSIMA TRA %d SECONDI · %s PER INIZIARE SUBITO" % [bonus, WAVE_BREAK, G.inp.key_label("INVIO", "back")])

# ============================================================ match flow
func clear_world() -> void:
	G.enemies.clear()
	G.fx.clear()
	G.items.clear_throwables()
	while G.items.drops.size() > 0:
		G.items.remove_drop(G.items.drops[0])
	G.ui.clear_match()

func reset_game() -> void:
	bank_match()
	G.primary = G.CLASSES[G.class_key].weapon
	G.world.set_arena(G.mode == "classic")
	G.D = G.diff_for(1)
	clear_world()
	for h in G.world.MAP.houses:
		if h.open:
			G.world.set_house(h, false)
	G.items.reset_pickups()
	G.player.reset(G.world.MAP.start, G.CLASSES[G.class_key].armor)
	G.weapons.reset(G.primary)
	G.items.reset_arsenal()
	G.wave = 0; G.to_spawn = 0; G.wave_break = 2.0; G.boss_wave = false; G.class_swaps = 0; G.wave_total = 1
	G.score = 0; G.kills = 0; G.headshots = 0; G.shots_fired = 0; G.shots_hit = 0; G.now = 0.0; G.hurt = 0.0
	G.banked = false; chal_t = 1.0
	G.world.apply_atmosphere(G.mode)
	G.items.place_box(true)
	G.ui.match_started()
	start_tutorial()

func begin_play() -> void:
	G.state = "playing"
	G.ui.hide_menus()
	G.ui.show_hud(true)
	G.main.gun_view.visible = true
	G.audio.set_music("game")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if G.inp.pad_mode() and G.inp.active_pad() else Input.MOUSE_MODE_CAPTURED

func enter_game() -> void:
	begin_play()

func start_new_game() -> void:
	reset_game()
	enter_game()

func pause() -> void:
	if G.state != "playing":
		return
	G.state = "paused"
	G.firing = false; G.aiming = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	G.audio.set_music("pause")
	G.ui.scope_on = false
	var W := word()
	G.ui.show_menu("pause", "PAUSA", "Prenditi un respiro. Puoi riprendere, ricominciare da capo o tornare al menu.",
		[[str(G.wave), W.wave, false], [str(G.kills), "Uccisioni", false], [str(G.score), "Punti", false]])

func go_main_menu() -> void:
	check_challenges(); bank_match()
	clear_world()
	G.items.clear_pickups()
	G.items.hide_box()
	G.state = "menu"
	G.ui.show_hud(false)
	G.main.gun_view.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	G.hurt = 0
	G.world.apply_atmosphere(G.mode)
	show_main_menu()

func show_main_menu() -> void:
	G.ui.show_menu("main", "SPARIAPS", G.ui.SUBTITLES[G.mode], [])
	G.audio.set_music("menu")

func game_over() -> void:
	G.state = "dead"
	G.firing = false; G.aiming = false
	G.audio.set_music("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	G.ui.show_hud(false)
	G.main.gun_view.visible = false
	G.hurt = 0.4
	var best := G.get_best()
	var record := G.score > best
	if record:
		G.sset(G.best_key(), G.score)
	var acc := roundi(float(G.shots_hit) / G.shots_fired * 100) if G.shots_fired > 0 else 0
	check_challenges(true); bank_match()
	var W := word()
	var sub := ("Nuovo record personale! " if record else "") + "Modalità %s · %s." % ["Zombie" if G.mode == "zombie" else "Classica", G.D.name.to_lower()]
	var lg: Dictionary = G.last_gain
	if not lg.is_empty():
		sub += " +%d XP." % lg.xp
		if lg.to > lg.from:
			sub += " Sei salito al livello %d!" % lg.to
			if lg.unlocked.size() > 0:
				sub += " Sbloccato: %s." % ", ".join(lg.unlocked).to_lower()
	var c: Dictionary = G.career
	var stats := [[str(G.wave), W.wave, false], [str(G.kills), "Uccisioni", false], [str(G.score), "Punti", record], ["%d%%" % acc, "Precisione", false],
		[str(G.headshots), "Headshot", false], [G.clock_str(G.now), "Tempo", false], [str(G.boss_kills), "Boss", false], [str(G.earned), "Crediti presi", false], [str(G.spent), "Crediti spesi", false]]
	var career := "CARRIERA   %d partite · %d uccisioni · %d headshot · %d boss · miglior %s %d · tempo di gioco %s" % [c.games, c.kills, c.headshots, c.bosses, W.wave.to_lower(), c.bestWave, G.clock_str(c.time)]
	G.ui.show_menu("dead", "SEI MORTO", sub, stats, career)

func quit_game() -> void:
	G.save_settings()
	G.flush()
	get_tree().quit()

# ============================================================ in-match shops (the world freezes while one is open)
func open_shop(kind: String) -> void:
	shop_kind = kind
	G.state = "shop"
	G.firing = false; G.aiming = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	G.audio.set_music("pause")
	G.ui.scope_on = false
	G.ui.open_shop(kind)

func close_shop() -> void:
	if G.state != "shop":
		return
	G.ui.close_shop()
	enter_game()

func buy_upgrade(k: String, t: String) -> void:
	var l := G.upg_lv(k, t)
	if l >= G.UPG_COST.size() or G.cash < G.UPG_COST[l]:
		return
	G.items.add_cash(-G.UPG_COST[l])
	if not G.upg.has(k):
		G.upg[k] = {}
	G.upg[k][t] = l + 1
	if t == "mag":
		G.weapons.mags[k] = G.weapons.mag_of(k)   # the bigger magazine comes full
	G.audio.with_cat("ui", func(): G.audio.tone(520, 0.1, 0.1, "triangle", 780); G.audio.tone(1040, 0.18, 0.08, "triangle", 1560, 0.08))
	G.ui.render_shop()

func buy_perk(k: String) -> void:
	var pk: Dictionary = G.PERKS[k]
	if G.perk_owned(k) or G.cash < pk.cost:
		return
	G.items.add_cash(-pk.cost)
	if k == "revive":
		G.revives += 1
	else:
		G.perks[k] = true
	var i := 0
	for m in [1.0, 1.25, 1.5, 2.0]:
		G.audio.tone(392 * m, 0.22, 0.09, "triangle", 392 * m, i * 0.07)
		i += 1
	G.ui.render_perks()
	G.ui.render_shop()

# ============================================================ map + class selection
func use_map(key: String) -> void:
	G.world.set_map(key)
	G.world.apply_atmosphere(G.mode)

func apply_class_swap() -> void:
	var old_w: String = G.CLASSES[swap_from].weapon
	var c: Dictionary = G.CLASSES[G.class_key]
	var neu: String = c.weapon
	var Wp: Node = G.weapons
	G.primary = neu
	if not G.slots.has(neu):
		var i := G.slots.find(old_w)
		if i < 0:
			i = G.slots.find(null)
		if i < 0:
			i = 0
			G.items.spawn_drop(G.slots[0], Wp.mags.get(G.slots[0], 0), G.items.drop_point())
		var was_current: bool = Wp.current == G.slots[i]
		G.slots[i] = neu
		if was_current or not G.slots.has(Wp.current):
			Wp.current = neu; Wp.switch_to = ""; Wp.switch_t = 0; Wp.reloading = false
	Wp.mags[neu] = Wp.mag_of(neu)
	G.player.armor = maxf(G.player.armor, c.armor)
	G.class_swaps += 1
	G.ui.toast("CLASSE: %s" % c.name, "#ffb36b")

# ============================================================ first-match tutorial: a few hints, each ticked off by doing what it says
func K(kb: String, btn := "") -> String:
	return "[color=#ffb36b][b]%s[/b][/color]" % G.inp.key_label(kb, btn if btn != "" else kb)

func _tut_text(i: int) -> String:
	var pad: bool = G.inp.pad_mode() and G.inp.active_pad()
	match i:
		0: return "Muoviti con lo stick sinistro e guardati intorno con il destro" if pad else "Muoviti con %s%s%s%s e guardati intorno con il mouse" % [K("W"), K("A"), K("S"), K("D")]
		1: return "Spara con %s · mira con %s" % [K("Clic SX", "RT"), K("Clic DX", "LT")]
		2: return "Ricarica con %s prima di restare a secco" % K("R", "X")
		3: return "Corri con %s · salta con %s" % [K("Shift", "L3"), K("Spazio", "A")]
		4: return "Ogni uccisione dà [b]crediti[/b]. Spendili alla [b]cassa misteriosa[/b] (quadrato giallo sulla minimappa) con %s" % K("E", "X")
		5: return "Il [b]banco armi[/b] (arancione) potenzia le tue armi · il [b]distributore di perk[/b] (viola) apre tra un’ondata e l’altra"
		6: return "Gli [b]edifici[/b] con il quadratino rosso si aprono con i crediti: dentro puoi ripararti, ma i nemici ti seguono"
	return "I [b]cuori[/b] sopra la vita sono le seconde vite: se cadi ti rialzi. Ogni 5 ondate arriva un boss. Buona fortuna!"

const TUT_N := 8

func _tut_ok(i: int) -> Variant:
	match i:
		0: return tut.moved > 4
		1: return G.shots_fired > 0
		2: return G.weapons.reloading
		3: return tut.ran and tut.jumped
	return null

func start_tutorial() -> void:
	var on := not bool(G.sget("tut-done", false))
	tut = { "i": 0 if on else -1, "t": 0.0, "okT": 0.0, "moved": 0.0, "ran": false, "jumped": false, "px": G.player.pos.x, "pz": G.player.pos.z, "text": "" }
	G.ui.tutorial("", "", false)
	if on:
		G.wave_break = 12.0   # a quiet moment to try the controls before the first wave

func update_tutorial(dt: float) -> void:
	if tut.i < 0:
		return
	var P: Node = G.player
	if tut.i == 6 and G.world.MAP.houses.is_empty():
		tut.i += 1
	if tut.i >= TUT_N:
		tut.i = -1
		G.ui.tutorial("", "", false)
		G.sset("tut-done", true)
		return
	tut.moved += Vector2(P.pos.x - tut.px, P.pos.z - tut.pz).length(); tut.px = P.pos.x; tut.pz = P.pos.z
	if P.sprint_t > 0.6: tut.ran = true
	if not P.on_ground: tut.jumped = true
	tut.t += dt
	var text := _tut_text(tut.i)
	if text != tut.text:
		tut.text = text
		G.ui.tutorial("TUTORIAL %d/%d" % [tut.i + 1, TUT_N], text, false)
	# actions get a green tick as soon as you do them; plain hints stay long enough to be read
	var ok: Variant = _tut_ok(tut.i)
	if tut.okT == 0.0 and ((ok != null and (ok or tut.t > 25)) or (ok == null and tut.t > 7)):
		tut.okT = 0.9 if ok != null else 0.01
		if ok != null and tut.t <= 25:
			G.ui.tutorial("TUTORIAL %d/%d" % [tut.i + 1, TUT_N], text, true)
			G.audio.tone(880, 0.1, 0.07, "sine", 1320)
	if tut.okT > 0.0:
		tut.okT -= dt
		if tut.okT <= 0.0:
			tut.i += 1; tut.t = 0.0; tut.okT = 0.0; tut.moved = 0.0; tut.ran = false; tut.jumped = false; tut.text = ""
			G.ui.tutorial("", "", false)

# ============================================================ career and challenges
# the running match is added to the career once: when you die, restart or go back to the menu
func bank_match() -> void:
	if G.banked:
		return
	G.banked = true
	G.last_gain = {}
	if G.now < 5 and G.kills == 0:
		return
	var c: Dictionary = G.career
	c.games += 1; c.kills += G.kills; c.headshots += G.headshots; c.bosses += G.boss_kills; c.time += G.now
	c.bestWave = maxi(c.bestWave, G.wave)
	if G.diff_key == "nightmare":
		c.nightmareWave = maxi(c.nightmareWave, G.wave)
	G.last_gain = G.add_xp(G.score)
	G.sset("career", c.duplicate())

# career totals count the match in progress, the others are the best single match so far
func _live(k: String, cur: float) -> float:
	return float(G.career[k]) + (0.0 if G.banked else cur)

func chal_val(id: String) -> float:
	var playing := not G.banked
	match id:
		"kills100", "kills1000": return _live("kills", G.kills)
		"heads100": return _live("headshots", G.headshots)
		"games25": return _live("games", 1)
		"boss1", "boss10": return _live("bosses", G.boss_kills)
		"wave10": return G.wave if playing else 0
		"night20": return G.wave if playing and G.diff_key == "nightmare" else 0
		"acc50": return roundf(float(G.shots_hit) / G.shots_fired * 100) if G.shots_fired >= 150 else 0
		"time15": return floorf(G.now / 60) if playing else 0
		"houses4":
			if not playing:
				return 0
			var n := 0
			for h in G.world.MAP.houses:
				if h.open:
					n += 1
			return n
		"perks6": return G.perks.size() if playing else 0
		"spend15k": return G.spent if playing else 0
	return 0

# `ended` is true when the match is over: only then the challenges judged on the whole match are checked
func check_challenges(ended := false) -> void:
	var dirty := false
	for c in G.CHALLENGES:
		if c.get("end", false) and not ended:
			continue
		var old: float = G.chal.get(c.id, 0)
		var v: float = minf(c.goal, chal_val(c.id))
		if v <= old:
			continue
		G.chal[c.id] = v
		dirty = true
		if v >= c.goal:
			G.add_xp(1500)
			G.sset("career", G.career.duplicate())
			G.ui.toast("SFIDA COMPLETATA · %s · +1500 XP" % c.name, "#8dffb0")
			G.audio.tone(660, 0.12, 0.1, "sine", 660); G.audio.tone(880, 0.12, 0.1, "sine", 880, 0.12); G.audio.tone(1320, 0.3, 0.1, "sine", 1320, 0.24)
	if dirty:
		G.sset("challenges", G.chal.duplicate())

# ============================================================ per-frame
func update(dt: float) -> void:
	update_waves(dt)
	G.items.update_pickups(dt)
	G.items.update_throwables(dt)
	G.world.update_arena(dt)
	G.items.update_box(dt)
	G.items.update_drops(dt)
	G.world.update_houses(dt)
	update_tutorial(dt)
	chal_t -= dt
	if chal_t <= 0:
		chal_t = 1.0
		check_challenges()
	G.items.update_interact()
