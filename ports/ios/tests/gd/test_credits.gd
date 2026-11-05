extends RefCounted
# Etap 04: ekran „LICENCJE” (Credits) w menu gry iOS.
# Treść składa scripts/ui/credits.gd (Credits.text()); HUD pokazuje ją w przewijanym panelu,
# a ▲▼ (klawisze, pad albo przyciski dotykowe) przewijają, OK / WSTECZ wracają do menu.

const CREDITS := "res://scripts/ui/credits.gd"
const FONT_LICENSES := ["res://assets/fonts/OFL-Oxanium.txt", "res://assets/fonts/OFL-Tektur.txt"]
const CREDITS_HINT := "GÓRA/DÓŁ PRZEWIŃ  •  OK / WSTECZ MENU"


func _text(t) -> String:
	var script: Script = t.require_script(CREDITS)
	if script == null:
		return ""
	return str(script.text())


func _press(t, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await t.frames(2)


## Main menu → LICENCJE (5th item) → OK.
func _open_credits(t) -> Node:
	var main: Node = await t.spawn_main()
	for i in 4:
		await _press(t, "menu_down")
	await _press(t, "menu_confirm")
	await t.frames(2)
	return main


# ------------------------------------------------------------ treść (Credits.text)

func test_credits_game_licence(t) -> void:
	var s := _text(t)
	t.ok(s.contains("PHOBOS"), "names the game")
	t.ok(s.contains("© 2026 Marek Piotrowski"), "game copyright line")
	t.ok(s.contains("MIT"), "game licence MIT")


func test_credits_contains_full_font_licences(t) -> void:
	var s := _text(t)
	for path in FONT_LICENSES:
		var licence := FileAccess.get_file_as_string(path).strip_edges()
		t.ok(licence.length() > 1000, "%s readable from the exported project (%d chars)" % [path, licence.length()])
		t.ok(s.contains(licence), "credits contain the full text of %s" % path)
	t.ok(s.contains("Oxanium") and s.contains("Tektur"), "font names listed")
	t.ok(s.contains("SIL Open Font License"), "OFL named")


func test_credits_contains_godot_licence(t) -> void:
	var s := _text(t)
	t.ok(s.contains("Godot Engine"), "engine named")
	t.ok(s.contains(Engine.get_license_text().strip_edges()), "full Godot MIT licence text (Engine.get_license_text)")


func test_credits_contains_third_party_notices(t) -> void:
	var s := _text(t)
	var missing := []
	for component in Engine.get_copyright_info():
		var name: String = component["name"]
		if not s.contains(name):
			missing.append(name)
		for part in component["parts"]:
			for line in part["copyright"]:
				if not s.contains(str(line)):
					missing.append("%s: © %s" % [name, line])
	t.eq([], missing, "every third-party component and copyright line from Engine.get_copyright_info()")
	var info := Engine.get_license_info()
	var missing_texts := []
	for licence in info:
		if not s.contains(str(info[licence]).strip_edges()):
			missing_texts.append(licence)
	t.eq([], missing_texts, "full text of every licence from Engine.get_license_info()")


func test_credits_ai_graphics_note(t) -> void:
	var s := _text(t)
	t.ok(s.contains("AI") and s.contains("Claude"), "graphics marked as AI-generated (Claude)")


# ------------------------------------------------------------ menu i ekran

func test_menu_shows_licences_item(t) -> void:
	var main: Node = await t.spawn_main()
	for i in 4:
		await _press(t, "menu_down")
	t.eq(4, main._menu_index, "LICENCJE is the 5th menu item")
	t.ok(main.hud._screen_body.text.contains(">  LICENCJE  <"), "LICENCJE highlighted (got %s)" % main.hud._screen_body.text)


func test_open_credits_from_menu(t) -> void:
	var main: Node = await _open_credits(t)
	t.eq("credits", main.screen, "OK on LICENCJE opens the credits screen")
	t.eq("LICENCJE", main.hud._screen_title.text, "title")
	t.eq(CREDITS_HINT, main.hud._screen_hint.text, "hint")
	var script: Script = t.require_script(CREDITS)
	if script == null: return
	t.eq(str(script.text()), main.hud.credits_text(), "the panel shows Credits.text()")
	t.eq(true, t.paused, "game stays paused on the credits screen")


func test_credits_scroll_by_actions(t) -> void:
	var main: Node = await _open_credits(t)
	var hud: Node = main.hud
	t.approx(0.0, hud.credits_scroll(), "starts at the top")
	await _press(t, "menu_down")
	var one: float = hud.credits_scroll()
	t.ok(one > 0.0, "▼ scrolls down (got %.1f)" % one)
	await _press(t, "menu_up")
	t.approx(0.0, hud.credits_scroll(), "▲ scrolls back to the top")
	await _press(t, "menu_up")
	t.approx(0.0, hud.credits_scroll(), "▲ at the top stays at the top")
	var last := -1.0
	for i in 2000:
		hud.scroll_credits(1)
		await t.frames(1)
		if is_equal_approx(hud.credits_scroll(), last):
			break
		last = hud.credits_scroll()
	t.ok(last > one, "long text can be scrolled far down (%.0f px)" % last)
	await _press(t, "menu_down")
	t.approx(last, hud.credits_scroll(), "▼ at the end stays at the end")


func test_credits_back_returns_to_menu(t) -> void:
	var main: Node = await _open_credits(t)
	await _press(t, "menu_back")
	t.eq("menu", main.screen, "WSTECZ returns to the menu")
	t.eq(4, main._menu_index, "LICENCJE stays selected")
	t.ok(main.hud._screen_body.text.contains(">  LICENCJE  <"), "menu shown again")
	await _press(t, "menu_confirm")
	t.eq("credits", main.screen, "can open the credits again")
	await _press(t, "menu_confirm")
	t.eq("menu", main.screen, "OK also returns to the menu")


func test_credits_by_touch(t) -> void:
	var main: Node = await t.spawn_main()
	var tc: Node = main.touch_controls
	var nav: Dictionary = tc.nav_button_rects()
	await t.tap(nav["menu_up"])  # wraps from GRAJ to LICENCJE
	await t.tap(nav["menu_confirm"])
	t.eq("credits", main.screen, "tap ▲ (wrap) + OK opens the credits")
	await t.tap(nav["menu_down"])
	t.ok(main.hud.credits_scroll() > 0.0, "tap ▼ scrolls")
	await t.tap(nav["menu_back"])
	t.eq("menu", main.screen, "tap WSTECZ returns to the menu")
