extends RefCounted
# Sterowanie ruchem lewym kciukiem: „smycz” — jedyne sterowanie dotykowe w grze.
#   środek drążka idzie za kciukiem 40 px z tyłu, pełna prędkość przy 30 px, martwa strefa 8 px;
#   kierunek ≈ ostatni ruch kciuka.
# Menu główne nie ma już pozycji STEROWANIE (decyzja po testach na iPhonie). Tryb "classic"
# zostaje tylko w TouchControls (API set_move_mode), bez dostępu z interfejsu gry.
# Prawy drążek (celowanie) bez zmian.

const PLAYER_MOVE_DEADZONE := 0.28


func _move() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down", PLAYER_MOVE_DEADZONE)


func _deg(a: Vector2, b: Vector2) -> float:
	return absf(rad_to_deg(a.angle_to(b)))


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


## Thumb: press at (300,400), go 100 px right, then 80 px down in 4 steps. Returns the move
## direction at the end — the player wants to go down now.
func _turn_down(t, tc: Node) -> Vector2:
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(400, 400))
	for y in [420, 440, 460, 480]:
		await t.touch_drag(0, Vector2(400, y))
	return _move()


# ------------------------------------------------------------ TouchControls: tryby

func test_default_mode_is_leash(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	t.eq("leash", tc.move_mode, "new touch controls start in the leash mode")
	t.approx(40.0, tc.left_stick.radius, "leash: left stick radius 40 px")
	t.approx(0.75, tc.left_stick.full_at, "leash: full speed at 75 % of 40 px = 30 px")
	t.approx(8.0, tc.left_stick.deadzone, "leash: dead zone 8 px")
	t.approx(80.0, tc.right_stick.radius, "aim stick unchanged: 80 px")
	t.approx(0.6, tc.right_stick.full_at, "aim stick unchanged: full at 60 %")


func test_set_move_mode(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	tc.set_move_mode("classic")
	t.eq("classic", tc.move_mode, "classic selected")
	t.approx(80.0, tc.left_stick.radius, "classic: 80 px")
	t.approx(0.6, tc.left_stick.full_at, "classic: full at 48 px")
	tc.set_move_mode("nonsense")
	t.eq("classic", tc.move_mode, "unknown mode ignored")
	t.approx(80.0, tc.left_stick.radius, "unknown mode leaves the stick alone")
	tc.set_move_mode("leash")
	t.eq("leash", tc.move_mode, "back to leash")
	t.approx(40.0, tc.left_stick.radius, "leash: 40 px")
	t.eq(["classic", "leash"], tc.move_modes(), "available modes")


func test_leash_speed_curve(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	tc.set_move_mode("leash")
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(306, 400))
	t.approx_v(Vector2.ZERO, _move(), "6 px: dead zone", 0.01)
	await t.touch_drag(0, Vector2(319, 400))
	t.approx_v(Vector2(0.5, 0.0), _move(), "19 px: half speed ((19-8)/(30-8))", 0.01)
	await t.touch_drag(0, Vector2(330, 400))
	t.approx_v(Vector2(1.0, 0.0), _move(), "30 px: full speed", 0.01)


func test_leash_turns_with_the_thumb(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	tc.set_move_mode("leash")
	var dir := await _turn_down(t, tc)
	t.ok(dir.length() > 0.95, "full speed after the turn (got %s)" % dir)
	t.ok(_deg(dir, Vector2.DOWN) < 30.0, "leash: after 80 px down the player goes (almost) down — %.1f° off" % _deg(dir, Vector2.DOWN))


func test_classic_turns_slower(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	tc.set_move_mode("classic")
	var dir := await _turn_down(t, tc)
	t.ok(_deg(dir, Vector2.DOWN) > 40.0, "classic: the same thumb path still goes diagonally — %.1f° off down" % _deg(dir, Vector2.DOWN))


func test_leash_keeps_direction_when_thumb_stops(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	tc.set_move_mode("leash")
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(360, 400))
	await t.frames(10)
	t.approx_v(Vector2(1.0, 0.0), _move(), "thumb resting 60 px right → keeps running right", 0.01)
	await t.touch_up(0, Vector2(360, 400))
	t.approx_v(Vector2.ZERO, _move(), "lifting the thumb stops", 0.001)


# ------------------------------------------------------------ menu główne: bez przełącznika

const REMOVED_KEYS := ["menu_controls", "controls_leash", "controls_classic"]


func test_menu_has_no_controls_item_pl(t) -> void:
	var main: Node = await t.spawn_main()
	t.eq(["play", "difficulty", "results", "credits"], main.MENU_ITEMS, "4 menu items, no controls")
	var body: String = main.hud._screen_body.text
	t.eq(4, body.split("\n").size(), "menu shows 4 lines (got %s)" % body)
	t.ok(not body.contains("STEROWANIE") and not body.contains("NOWE") and not body.contains("KLASYCZNE"), "no STEROWANIE line (got %s)" % body)
	t.eq("leash", main.touch_controls.move_mode, "game starts with the leash steering")


func test_menu_has_no_controls_item_en(t) -> void:
	t.set_language("en")
	var main: Node = await t.spawn_main()
	var body: String = main.hud._screen_body.text
	t.eq(4, body.split("\n").size(), "menu shows 4 lines (got %s)" % body)
	t.ok(not body.contains("CONTROLS") and not body.contains("NEW") and not body.contains("CLASSIC"), "no CONTROLS line (got %s)" % body)


func test_menu_left_right_do_not_change_steering(t) -> void:
	var main: Node = await t.spawn_main()
	for i in main.MENU_ITEMS.size():
		main._menu_index = i
		if main.MENU_ITEMS[i] in ["play", "credits", "results"]:
			for action in ["menu_left", "menu_right"]:
				await _press(t, action)
				t.eq("leash", main.touch_controls.move_mode, "%s on %s keeps the leash" % [action, main.MENU_ITEMS[i]])
				t.eq("menu", main.screen, "%s on %s stays in the menu" % [action, main.MENU_ITEMS[i]])
	main._menu_index = 2
	await _press(t, "menu_right")
	t.eq("leash", main.touch_controls.move_mode, "3rd item (WYNIKI) ▶ does not switch steering")


func test_reload_always_starts_with_leash(t) -> void:
	var first: Node = await t.spawn_main()
	first._menu_index = 2
	await _press(t, "menu_right")  # was: STEROWANIE ▶ → classic for the session
	first.queue_free()
	await t.frames(2)
	var second: Node = await t.spawn_main()  # same app run, scene loaded again (e.g. GRAJ PONOWNIE)
	t.eq("leash", second.touch_controls.move_mode, "after a reload the steering is still the leash")
	t.eq(false, "session_move_mode" in second, "no session steering override in main")


func test_controls_texts_removed(t) -> void:
	for lang in ["pl", "en"]:
		var keys: Array = _keys(lang)
		for key in REMOVED_KEYS:
			t.ok(not keys.has(key), "%s: text '%s' removed" % [lang, key])


func _keys(lang: String) -> Array:
	var script: Script = load("res://scripts/ui/localization.gd")
	return script.keys(lang)


func test_mode_used_in_game(t) -> void:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(319, 400))
	t.approx_v(Vector2(0.5, 0.0), _move(), "in game the default leash curve applies (19 px → half speed)", 0.01)
