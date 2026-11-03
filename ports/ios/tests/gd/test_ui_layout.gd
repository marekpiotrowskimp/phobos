extends RefCounted
# Etap 03 — UI, safe area i proporcje ekranu. Window sizes are real device pixel sizes:
#   16:9    1280x720  (design size)
#   iPhone  2532x1170 (19.5:9, iPhone 12–14)
#   iPad    2048x1536 (4:3, iPad 10.2")

const R169 := Vector2i(1280, 720)
const IPHONE := Vector2i(2532, 1170)
const IPAD := Vector2i(2048, 1536)

## Arena as projected at the 16:9 design size (camera size 27.5, ARENA_HALF 20x12).
const ARENA_TL_169 := Vector2(116.364, 45.818)
const ARENA_BR_169 := Vector2(1163.636, 674.182)
const ARENA_SIZE := ARENA_BR_169 - ARENA_TL_169

## Real iPhone landscape safe area (47 pt sides, 21 pt home indicator, @3x) and iPad home bar.
const IPHONE_SAFE := Rect2i(141, 0, 2250, 1107)
const IPAD_SAFE := Rect2i(0, 0, 2048, 1496)
const IPHONE_MARGINS := {"left": 86.769, "top": 0.0, "right": 86.769, "bottom": 38.769}

const SAFE_AREA_PATH := "res://scripts/ui/safe_area.gd"


func _resize(t, size: Vector2i) -> void:
	t.root.size = size
	await t.frames(3)


func _visible(t) -> Vector2:
	return t.root.get_visible_rect().size


func _arena_rect(main: Node) -> Rect2:
	var h := Vector2(20.0, 12.0)
	var a: Vector2 = main.camera.unproject_position(Vector3(-h.x, 0.0, -h.y))
	var b: Vector2 = main.camera.unproject_position(Vector3(h.x, 0.0, h.y))
	return Rect2(a, b - a)


func _has(t, obj: Object, method: String) -> bool:
	return t.ok(obj != null and obj.has_method(method), "missing method %s" % method)


func _safe_rect(t, m: Dictionary) -> Rect2:
	var v := _visible(t)
	return Rect2(m["left"], m["top"], v.x - m["left"] - m["right"], v.y - m["top"] - m["bottom"])


func _inside(t, outer: Rect2, inner: Rect2, msg: String) -> void:
	t.ok(outer.grow(0.5).encloses(inner), "%s — %s not inside %s" % [msg, inner, outer])


func _approx_margins(t, expected: Dictionary, actual: Variant, msg: String) -> void:
	if not t.ok(actual is Dictionary, msg + " returns a Dictionary"):
		return
	for k in ["left", "top", "right", "bottom"]:
		t.approx(float(expected[k]), float(actual.get(k, -999.0)), "%s %s" % [msg, k], 0.01)


func _hud_gameplay_controls(hud: Node) -> Dictionary:
	return {
		"wave_label": hud.wave_label, "score_label": hud.score_label, "kills_label": hud.kills_label,
		"difficulty_label": hud.difficulty_label, "hp_bar": hud.hp_bar, "od_bar": hud.od_bar,
	}


# ------------------------------------------------------------ characterization

func test_arena_framing_169_unchanged(t) -> void:
	await _resize(t, R169)
	var main: Node = await t.spawn_main()
	var r := _arena_rect(main)
	t.approx_v(ARENA_TL_169, r.position, "arena top-left at 16:9", 0.5)
	t.approx_v(ARENA_BR_169, r.end, "arena bottom-right at 16:9", 0.5)


func test_hud_positions_169_without_margins(t) -> void:
	await _resize(t, R169)
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	var hud: Node = main.hud
	t.approx_v(Vector2(24, 684), hud.hp_bar.global_position, "hp bar bottom-left", 0.5)
	t.approx_v(Vector2(980, 22), hud.kills_label.global_position, "kills top-right", 0.5)
	t.approx_v(Vector2(24, 22), hud.difficulty_label.global_position, "difficulty top-left", 0.5)
	t.approx_v(Vector2(390, 22), hud.wave_label.global_position, "wave top-centre", 0.5)
	t.approx_v(Vector2(996, 694), hud.od_bar.global_position, "overdrive bar bottom-right", 0.5)


func test_touch_buttons_169_without_margins(t) -> void:
	await _resize(t, R169)
	var main: Node = await t.spawn_main()
	var tc: Node = main.touch_controls
	t.eq(Rect2(1160, 24, 96, 96), tc.pause_button_rect(), "pause button at 16:9 (etap 02 layout)")
	t.eq(Rect2(1160, 600, 96, 96), tc.nav_button_rects()["menu_confirm"], "OK button at 16:9 (etap 02 layout)")


func test_ranking_survives_reload(t) -> void:
	var gs: Node = t.root.get_node("GameState")
	t.eq(true, gs.submit_score("QAZ", 4321, 3, 17, 75.0, "normal"), "score accepted")
	var fresh: Node = load("res://scripts/autoloads/game_state.gd").new()
	t.root.add_child(fresh)
	await t.frames(1)
	var board: Array = fresh.get_leaderboard("normal")
	t.ok(board.any(func(e): return e["initials"] == "QAZ" and int(e["score"]) == 4321), "entry read back from user:// after reload")


func test_audio_session_respects_silent_switch(t) -> void:
	t.eq(0, ProjectSettings.get_setting("audio/general/ios/session_category"), "AVAudioSession category Ambient (honours the silent switch)")


# ------------------------------------------------------------ AC-1, AC-2: aspect ratio

func test_stretch_aspect_expand(t) -> void:
	t.eq("expand", ProjectSettings.get_setting("display/window/stretch/aspect"), "no black bars: canvas expands to the screen ratio")


func test_arena_fits_iphone(t) -> void:
	await _resize(t, IPHONE)
	var main: Node = await t.spawn_main()
	var v := _visible(t)
	t.ok(v.x > 1500.0, "iPhone canvas is wider than 16:9 (got %s)" % v)
	var r := _arena_rect(main)
	t.approx_v(ARENA_SIZE, r.size, "arena keeps its 16:9 on-screen size on iPhone", 0.5)
	t.approx_v(v / 2.0, r.get_center(), "arena centred on iPhone", 0.5)


func test_arena_fits_ipad(t) -> void:
	await _resize(t, IPAD)
	var main: Node = await t.spawn_main()
	var v := _visible(t)
	t.ok(v.y > 900.0, "iPad canvas is taller than 16:9 (got %s)" % v)
	var r := _arena_rect(main)
	t.approx_v(ARENA_SIZE, r.size, "arena keeps its 16:9 on-screen size on iPad (no clipping at 4:3)", 0.5)
	t.approx_v(v / 2.0, r.get_center(), "arena centred on iPad", 0.5)
	_inside(t, Rect2(Vector2.ZERO, v), r, "whole arena visible on iPad")


func test_arena_refits_after_resize(t) -> void:
	await _resize(t, R169)
	var main: Node = await t.spawn_main()
	await _resize(t, IPAD)
	t.ok(_visible(t).y > 900.0, "canvas follows the window after resize (got %s)" % _visible(t))
	var r := _arena_rect(main)
	t.approx_v(ARENA_SIZE, r.size, "arena size after switching 16:9 → 4:3 at runtime", 0.5)
	t.approx_v(_visible(t) / 2.0, r.get_center(), "arena centred after resize", 0.5)


# ------------------------------------------------------------ AC-3: SafeArea.margins

func test_safe_area_zero_rect_means_no_margins(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	_approx_margins(t, {"left": 0, "top": 0, "right": 0, "bottom": 0},
		sa.margins(Rect2i(), IPHONE, Vector2(1558.154, 720)), "unknown safe area (headless/desktop)")


func test_safe_area_full_window_means_no_margins(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	_approx_margins(t, {"left": 0, "top": 0, "right": 0, "bottom": 0},
		sa.margins(Rect2i(Vector2i.ZERO, R169), R169, Vector2(1280, 720)), "safe area = whole window")


func test_safe_area_iphone_notch_and_home_bar(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	_approx_margins(t, IPHONE_MARGINS, sa.margins(IPHONE_SAFE, IPHONE, Vector2(1558.154, 720)), "iPhone 2532x1170")


func test_safe_area_ipad_home_bar(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	_approx_margins(t, {"left": 0, "top": 0, "right": 0, "bottom": 25.0},
		sa.margins(IPAD_SAFE, IPAD, Vector2(1280, 960)), "iPad 2048x1536")


# ------------------------------------------------------------ AC-4, AC-5: margins applied

func test_hud_respects_safe_margins(t) -> void:
	await _resize(t, IPHONE)
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	var hud: Node = main.hud
	if not _has(t, hud, "apply_safe_margins"): return
	hud.apply_safe_margins(IPHONE_MARGINS)
	hud.od_bar.visible = true
	await t.frames(2)
	var safe := _safe_rect(t, IPHONE_MARGINS)
	var controls := _hud_gameplay_controls(hud)
	for name in controls:
		_inside(t, safe, (controls[name] as Control).get_global_rect(), name)
	var v := _visible(t)
	t.approx_v(Vector2(24 + 86.769, v.y - 36 - 38.769), hud.hp_bar.global_position, "hp bar keeps its 24/36 px inset from the safe edges", 0.5)
	t.approx(v.x - 20 - 86.769, hud.kills_label.get_global_rect().end.x, "kills keeps its 20 px inset from the safe right edge", 0.5)


func test_touch_buttons_respect_safe_margins(t) -> void:
	await _resize(t, IPHONE)
	var main: Node = await t.spawn_main()
	var tc: Node = main.touch_controls
	if not _has(t, tc, "set_safe_margins"): return
	tc.set_safe_margins(IPHONE_MARGINS)
	await t.frames(1)
	var safe := _safe_rect(t, IPHONE_MARGINS)
	var v := _visible(t)
	t.approx_v(Vector2(v.x - 86.769 - 24 - 96, 24), tc.pause_button_rect().position, "pause inset 24 px from the safe top-right corner", 0.5)
	_inside(t, safe, tc.pause_button_rect(), "pause")
	_inside(t, safe, tc.mute_button_rect(), "mute")
	var nav: Dictionary = tc.nav_button_rects()
	for k in nav:
		_inside(t, safe, nav[k], k)


func test_main_applies_safe_area(t) -> void:
	await _resize(t, IPHONE)
	var main: Node = await t.spawn_main()
	if not _has(t, main, "apply_safe_area"): return
	main.apply_safe_area(IPHONE_SAFE, IPHONE)
	main._start_run()
	await t.frames(2)
	var v := _visible(t)
	t.approx_v(Vector2(24 + 86.769, v.y - 36 - 38.769), main.hud.hp_bar.global_position, "main passes margins to the HUD", 0.5)
	t.approx(v.x - 86.769 - 24, main.touch_controls.pause_button_rect().end.x, "main passes margins to the touch overlay", 0.5)


func test_main_unknown_safe_area_keeps_edges(t) -> void:
	await _resize(t, IPHONE)
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	var v := _visible(t)
	t.ok(v.x > 1500.0, "iPhone canvas is wider than 16:9 (got %s)" % v)
	t.approx_v(Vector2(24, v.y - 36), main.hud.hp_bar.global_position, "headless (no safe area): hp bar at the plain bottom-left inset", 0.5)
	t.approx(v.x - 24, main.touch_controls.pause_button_rect().end.x, "headless: pause at the plain right inset", 0.5)


# ------------------------------------------------------------ AC-6: menu screens vs buttons

func _check_screen_layout(t, size: Vector2i, margins_safe: Rect2i) -> void:
	await _resize(t, size)
	var main: Node = await t.spawn_main()
	if margins_safe != Rect2i() and _has(t, main, "apply_safe_area"):
		main.apply_safe_area(margins_safe, size)
	var entries := []
	for i in 10:
		entries.append({"initials": "WWW", "score": 9999999, "difficulty_label": "NORMALNY", "wave": 99, "time": 3599.0})
	main.hud.show_results(entries, "WSZYSTKIE", {"score": 9999999, "difficulty_label": "NORMALNY", "wave": 99, "time": 3599.0}, true)
	await t.frames(2)
	var v := _visible(t)
	var nav: Dictionary = main.touch_controls.nav_button_rects()
	for label_name in ["_screen_title", "_screen_body", "_screen_hint"]:
		var label: Label = main.hud.get(label_name)
		var r := label.get_global_rect()
		var tag := "%s @%s" % [label_name, size]
		_inside(t, Rect2(Vector2.ZERO, v), r, tag + " on screen")
		t.approx(v.x / 2.0, r.get_center().x, tag + " horizontally centred", 1.0)
		var need := label.get_minimum_size()
		t.ok(need.x <= r.size.x + 0.5 and need.y <= r.size.y + 0.5, "%s: worst-case text %s fits its box %s" % [tag, need, r.size])
		for k in nav:
			t.ok(not r.intersects(nav[k]), "%s does not overlap button %s" % [tag, k])


func test_screen_layout_169(t) -> void:
	await _check_screen_layout(t, R169, Rect2i())


func test_screen_layout_iphone(t) -> void:
	await _check_screen_layout(t, IPHONE, IPHONE_SAFE)


func test_screen_layout_ipad(t) -> void:
	await _check_screen_layout(t, IPAD, IPAD_SAFE)


# ------------------------------------------------------------ AC-7: touch hints, AC-8: font size

func test_touch_hints(t) -> void:
	var main: Node = await t.spawn_main()
	var hud: Node = main.hud
	t.eq("▲▼ WYBÓR  •  OK", hud._screen_hint.text, "menu hint")
	main.run_difficulty = "normal"
	main._pending_result = {"score": 100, "wave": 2, "kills": 5, "time": 30.0, "difficulty": "normal"}
	main._show_initials()
	t.eq("▲▼ LITERA  •  ◀▶ POZYCJA  •  OK", hud._screen_hint.text, "initials hint")
	hud.show_results([], "WSZYSTKIE", {}, true)
	t.eq("◀▶ FILTR  •  OK JESZCZE RAZ  •  WSTECZ MENU", hud._screen_hint.text, "results hint after a run")
	hud.show_results([], "WSZYSTKIE", {}, false)
	t.eq("◀▶ FILTR  •  OK / WSTECZ MENU", hud._screen_hint.text, "results hint from the menu")
	t.eq("PAUZA\nII — WZNÓW", hud._pause_label.text, "pause label")
	t.eq("OK — GRAJ PONOWNIE", hud._go_hint.text, "game over hint")


func test_no_keyboard_hints_left(t) -> void:
	var main: Node = await t.spawn_main()
	for label in main.hud.find_children("*", "Label", true, false):
		var text: String = (label as Label).text
		for word in ["ESC", "ENTER", "PAD A", "PAD B", "STRZAŁKI", "GAŁKA", "SPACJA"]:
			t.ok(not text.contains(word), "label %s still mentions %s: %s" % [label.name, word, text])


func test_font_sizes_readable(t) -> void:
	var main: Node = await t.spawn_main()
	for label in main.hud.find_children("*", "Label", true, false):
		if label == main.hud.fps_label:
			continue
		var size: int = (label as Label).get_theme_font_size("font_size")
		t.ok(size >= 22, "label %s (%s) font %d px < 22 px (≈ 11 pt on iPhone SE)" % [label.name, (label as Label).text.left(20), size])
