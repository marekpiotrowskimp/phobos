extends RefCounted
# Sterowanie ruchem: dwa tryby lewego drążka, przełączane w menu głównym.
#   "leash"   (NOWE, domyślne) — krótka smycz: środek drążka idzie za kciukiem 40 px z tyłu,
#             pełna prędkość przy 30 px, martwa strefa 8 px; kierunek ≈ ostatni ruch kciuka.
#   "classic" (KLASYCZNE) — dotychczasowe: środek zostaje, dopóki kciuk nie odjedzie 80 px,
#             pełna prędkość przy 48 px.
# Prawy drążek (celowanie) jest w obu trybach taki sam. Wybór obowiązuje do końca sesji
# (także po przeładowaniu sceny, np. „GRAJ PONOWNIE”), nie jest zapisywany na dysku.

const SETTINGS_FILE := "user://ios_settings.cfg"
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


# ------------------------------------------------------------ menu główne

func test_menu_shows_controls_pl(t) -> void:
	var main: Node = await t.spawn_main()
	t.eq("controls", main.MENU_ITEMS[2], "3rd menu item")
	t.eq("leash", main.touch_controls.move_mode, "game starts with the leash mode")
	t.ok(main.hud._screen_body.text.contains("STEROWANIE: < NOWE >"), "menu PL (got %s)" % main.hud._screen_body.text)


func test_menu_shows_controls_en(t) -> void:
	t.set_language("en")
	var main: Node = await t.spawn_main()
	t.ok(main.hud._screen_body.text.contains("CONTROLS: < NEW >"), "menu EN (got %s)" % main.hud._screen_body.text)
	main._menu_index = 2
	await _press(t, "menu_right")
	t.ok(main.hud._screen_body.text.contains("CONTROLS: < CLASSIC >"), "EN classic label")


func test_menu_toggles(t) -> void:
	var main: Node = await t.spawn_main()
	await _press(t, "menu_down")
	await _press(t, "menu_down")
	t.eq(2, main._menu_index, "STEROWANIE selected")
	t.ok(main.hud._screen_body.text.contains(">  STEROWANIE: < NOWE >  <"), "highlighted (got %s)" % main.hud._screen_body.text)
	await _press(t, "menu_right")
	t.eq("classic", main.touch_controls.move_mode, "▶ switches to classic")
	t.ok(main.hud._screen_body.text.contains("STEROWANIE: < KLASYCZNE >"), "label KLASYCZNE")
	await _press(t, "menu_left")
	t.eq("leash", main.touch_controls.move_mode, "◀ switches back")
	await _press(t, "menu_confirm")
	t.eq("classic", main.touch_controls.move_mode, "OK also toggles")
	t.eq("menu", main.screen, "OK on STEROWANIE stays in the menu")
	t.eq(false, FileAccess.file_exists(SETTINGS_FILE), "session only: nothing is written to disk")
	t.eq(false, FileAccess.get_file_as_string("user://phobos.cfg").contains("classic"), "GameState save untouched")


func test_choice_survives_scene_reload(t) -> void:
	var first: Node = await t.spawn_main()
	first._menu_index = 2
	await _press(t, "menu_right")
	t.eq("classic", first.touch_controls.move_mode, "classic chosen")
	first.queue_free()
	await t.frames(2)
	var second: Node = await t.spawn_main()  # same app run, scene loaded again (e.g. GRAJ PONOWNIE)
	t.eq("classic", second.touch_controls.move_mode, "choice kept for the rest of the session")
	t.ok(second.hud._screen_body.text.contains("STEROWANIE: < KLASYCZNE >"), "menu shows the session choice")


func test_mode_used_in_game(t) -> void:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(319, 400))
	t.approx_v(Vector2(0.5, 0.0), _move(), "in game the default leash curve applies (19 px → half speed)", 0.01)
