extends RefCounted
# AC-7 … AC-11 and characterization: the main scene of the iOS project driven by touch.

const ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"shoot", "pause", "mute",
	"menu_up", "menu_down", "menu_left", "menu_right", "menu_confirm", "menu_back",
]


func _action(name: String) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	Input.parse_input_event(ev)


func _tc(t, main: Node) -> Node:
	var tc: Variant = main.get("touch_controls")
	if not t.ok(tc is Node, "main.touch_controls exists"):
		return null
	return tc


# ------------------------------------------------------------ characterization

func test_input_actions_unchanged(t) -> void:
	for a in ACTIONS:
		t.ok(InputMap.has_action(a), "action %s exists" % a)
	t.ok(InputMap.action_get_events("move_left").any(func(e): return e is InputEventJoypadMotion), "move_left keeps its gamepad axis")
	t.ok(InputMap.action_get_events("shoot").any(func(e): return e is InputEventJoypadMotion), "shoot keeps the R2 trigger")


func test_menu_navigation_by_actions(t) -> void:
	var main: Node = await t.spawn_main()
	t.eq("menu", main.screen, "boots into the main menu")
	_action("menu_down")
	await t.frames(2)
	t.eq(1, main._menu_index, "menu_down action selects the second item")
	_action("menu_up")
	await t.frames(2)
	t.eq(0, main._menu_index, "menu_up action goes back")


func test_pause_action_toggles(t) -> void:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	_action("pause")
	await t.frames(2)
	t.eq(true, t.paused, "pause action pauses the game")
	t.eq(true, main.hud.pause_panel.visible, "pause panel visible")


# ------------------------------------------------------------ new behaviour

func test_mouse_emulation_from_touch_disabled(t) -> void:
	t.eq(false, ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "touch must not emulate the mouse (mouse aim would follow fingers)")


func test_menu_has_no_quit(t) -> void:
	var main: Node = await t.spawn_main()
	t.eq(["play", "difficulty", "controls", "results", "credits"], main.MENU_ITEMS, "iOS menu items: + STEROWANIE, + LICENCJE (etap 04), no quit — Apple forbids quitting apps")
	var body: String = main.hud._screen_body.text
	t.ok(body.contains("GRAJ") and body.contains("WYNIKI") and body.contains("LICENCJE"), "menu shows GRAJ, WYNIKI and LICENCJE")
	t.ok(not body.contains("WYJŚCIE"), "menu does not show WYJŚCIE")


func test_main_owns_touch_controls(t) -> void:
	var main: Node = await t.spawn_main()
	var tc := _tc(t, main)
	if tc == null: return
	t.eq("res://scripts/touch/touch_controls.gd", tc.get_script().resource_path, "touch_controls is a TouchControls")
	t.eq("menu", tc.screen, "touch context follows the menu screen")
	t.eq(true, tc.paused, "touch context sees the paused tree in the menu")
	main._start_run()
	await t.frames(2)
	t.eq("game", tc.screen, "touch context follows the game screen")
	t.eq(false, tc.paused, "touch context sees the running game")


func test_menu_navigation_by_touch(t) -> void:
	var main: Node = await t.spawn_main()
	var tc := _tc(t, main)
	if tc == null: return
	var nav: Dictionary = tc.nav_button_rects()
	await t.tap(nav["menu_down"])
	t.eq(1, main._menu_index, "tap ▼ selects DIFFICULTY")
	await t.tap(nav["menu_up"])
	t.eq(0, main._menu_index, "tap ▲ selects PLAY")
	await t.tap(nav["menu_up"])
	t.eq(4, main._menu_index, "tap ▲ on PLAY wraps to LICENCJE (5 items)")
	await t.tap(nav["menu_down"])
	await t.tap(nav["menu_confirm"])
	t.eq("game", main.screen, "tap OK on PLAY starts a run")
	t.eq(false, t.paused, "game is running")


func test_pause_button_toggles_pause(t) -> void:
	var main: Node = await t.spawn_main()
	var tc := _tc(t, main)
	if tc == null: return
	main._start_run()
	await t.frames(2)
	await t.tap(tc.pause_button_rect())
	t.eq(true, t.paused, "tap pause pauses")
	t.eq(true, main.hud.pause_panel.visible, "pause panel shown")
	await t.tap(tc.pause_button_rect())
	t.eq(false, t.paused, "second tap resumes")
	t.eq(false, main.hud.pause_panel.visible, "pause panel hidden")


func test_mute_button_only_in_pause(t) -> void:
	var main: Node = await t.spawn_main()
	var tc := _tc(t, main)
	if tc == null: return
	AudioServer.set_bus_mute(0, false)
	main._start_run()
	await t.frames(2)
	await t.tap(tc.mute_button_rect())
	t.eq(false, AudioServer.is_bus_mute(0), "mute button inactive during gameplay")
	await t.tap(tc.pause_button_rect())
	await t.tap(tc.mute_button_rect())
	t.eq(true, AudioServer.is_bus_mute(0), "tap mute in pause mutes")
	await t.tap(tc.mute_button_rect())
	t.eq(false, AudioServer.is_bus_mute(0), "second tap unmutes")
	t.eq(true, t.paused, "mute does not leave the pause")


func test_initials_by_touch(t) -> void:
	var main: Node = await t.spawn_main()
	var tc := _tc(t, main)
	if tc == null: return
	main.run_difficulty = "normal"
	main._pending_result = {"score": 100, "wave": 2, "kills": 5, "time": 30.0, "difficulty": "normal"}
	main._show_initials()
	main._initials = PackedStringArray(["A", "A", "A"])
	main._initials_cursor = 0
	await t.frames(2)
	var nav: Dictionary = tc.nav_button_rects()
	await t.tap(nav["menu_up"])
	t.eq("B", main._initials[0], "tap ▲ changes the first letter A→B")
	await t.tap(nav["menu_right"])
	t.eq(1, main._initials_cursor, "tap ▶ moves to the second letter")
	await t.tap(nav["menu_down"])
	t.eq("Z", main._initials[1], "tap ▼ changes the second letter A→Z")


func test_auto_pause_when_app_goes_to_background(t) -> void:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await t.frames(1)
	t.eq(true, t.paused, "game pauses when the app is backgrounded")
	t.eq(true, main.hud.pause_panel.visible, "pause panel shown")
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await t.frames(1)
	t.eq(true, t.paused, "a second background event keeps the pause (no toggle)")


func test_background_in_menu_changes_nothing(t) -> void:
	var main: Node = await t.spawn_main()
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await t.frames(1)
	t.eq("menu", main.screen, "still in the menu")
	t.eq(false, main.hud.pause_panel.visible, "no pause panel over the menu")


func test_background_releases_touch(t) -> void:
	var main: Node = await t.spawn_main()
	if _tc(t, main) == null: return
	main.touch_controls.set_move_mode("classic")  # classic curve: 40 px → 0.8
	main._start_run()
	await t.frames(2)
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(340, 400))
	t.approx_v(Vector2(0.8, 0.0), Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.28), "moving by touch (40 px → 0.8 as player.gd reads it)", 0.01)
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await t.frames(2)
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "backgrounding releases held touch input")
