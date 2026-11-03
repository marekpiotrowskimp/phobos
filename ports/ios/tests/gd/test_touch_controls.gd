extends RefCounted
# AC-2 … AC-6: TouchControls standalone (context set directly, no main scene).

const VIEW := Rect2(0, 0, 1280, 720)
const MIN_BUTTON := 88.0  # 44 pt on the smallest landscape iPhone at 1280x720 "keep" scaling
const NAV_ACTIONS := ["menu_back", "menu_confirm", "menu_down", "menu_left", "menu_right", "menu_up"]


func _check_button(t, name: String, r: Rect2) -> void:
	t.ok(r.size.x >= MIN_BUTTON and r.size.y >= MIN_BUTTON, "%s is at least 88x88 (got %s)" % [name, r.size])
	t.ok(VIEW.encloses(r), "%s lies inside the 1280x720 viewport (got %s)" % [name, r])


func test_layout_buttons_size_and_bounds(t) -> void:
	var tc: Node = await t.spawn_touch("menu", true)
	if tc == null: return
	var nav: Dictionary = tc.nav_button_rects()
	var keys := nav.keys()
	keys.sort()
	t.eq(NAV_ACTIONS, keys, "navigation buttons cover exactly the six menu actions")
	for k in nav:
		_check_button(t, k, nav[k])
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			t.ok(not (nav[keys[i]] as Rect2).intersects(nav[keys[j]]), "%s and %s do not overlap" % [keys[i], keys[j]])
	var pause: Rect2 = tc.pause_button_rect()
	var mute: Rect2 = tc.mute_button_rect()
	_check_button(t, "pause", pause)
	_check_button(t, "mute", mute)
	t.ok(pause.position.x >= 640.0 and pause.end.y <= 360.0, "pause button sits in the top-right quarter (got %s)" % pause)
	t.ok(not pause.intersects(mute), "pause and mute do not overlap")


func test_left_stick_moves(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(340, 400))
	t.eq({"left": 0.0, "right": 0.5, "up": 0.0, "down": 0.0}, t.strengths("move"), "40 px right → move_right 0.5")
	await t.touch_drag(0, Vector2(300, 460))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.75}, t.strengths("move"), "60 px down → move_down 0.75")
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("aim"), "left stick never aims")
	t.eq(false, Input.is_action_pressed("shoot"), "left stick never fires")
	await t.touch_up(0, Vector2(300, 460))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "release stops movement")


func test_right_stick_aims_and_fires(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	await t.touch_down(0, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(1000, 370))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.375, "down": 0.0}, t.strengths("aim"), "30 px up → aim_up 0.375")
	t.eq(true, Input.is_action_pressed("shoot"), "deflection 0.375 ≥ 0.35 fires")
	await t.touch_drag(0, Vector2(1000, 384))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.2, "down": 0.0}, t.strengths("aim"), "16 px up → aim_up 0.2")
	t.eq(false, Input.is_action_pressed("shoot"), "deflection 0.2 < 0.35 does not fire")
	await t.touch_drag(0, Vector2(1060, 400))
	t.eq({"left": 0.0, "right": 0.75, "up": 0.0, "down": 0.0}, t.strengths("aim"), "60 px right → aim_right 0.75")
	t.eq(true, Input.is_action_pressed("shoot"), "fires again above threshold")
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "right stick never moves")
	await t.touch_up(0, Vector2(1060, 400))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("aim"), "release clears aim")
	t.eq(false, Input.is_action_pressed("shoot"), "release stops fire")


func test_two_sticks_independent(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_down(1, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(340, 400))
	await t.touch_drag(1, Vector2(1000, 440))
	t.eq({"left": 0.0, "right": 0.5, "up": 0.0, "down": 0.0}, t.strengths("move"), "finger 0 moves right")
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.5}, t.strengths("aim"), "finger 1 aims down")
	t.eq(true, Input.is_action_pressed("shoot"), "finger 1 fires")
	await t.touch_up(0, Vector2(340, 400))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "releasing finger 0 stops movement")
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.5}, t.strengths("aim"), "finger 1 keeps aiming")
	t.eq(true, Input.is_action_pressed("shoot"), "finger 1 keeps firing")


func test_sticks_inactive_outside_gameplay(t) -> void:
	var tc: Node = await t.spawn_touch("menu", true)
	if tc == null: return
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(340, 400))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "no movement in the menu")
	await t.touch_up(0, Vector2(340, 400))
	tc.screen = "game"
	tc.paused = true
	await t.frames(2)
	await t.touch_down(0, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(1060, 400))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("aim"), "no aiming while paused")
	t.eq(false, Input.is_action_pressed("shoot"), "no fire while paused")


func test_pause_button_does_not_start_stick(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	var c: Vector2 = (tc.pause_button_rect() as Rect2).get_center()
	await t.touch_down(0, c)
	await t.touch_drag(0, c + Vector2(40, 40))
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("aim"), "touch starting on the pause button does not aim")
	t.eq(false, Input.is_action_pressed("shoot"), "touch starting on the pause button does not fire")


func test_overlay_hides_on_gamepad_and_returns_on_touch(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	t.eq(true, tc.overlay_visible(), "overlay visible by default")
	await t.joy_axis(JOY_AXIS_LEFT_X, 0.2)
	t.eq(true, tc.overlay_visible(), "small stick noise (0.2) keeps the overlay")
	await t.joy_button(JOY_BUTTON_A)
	t.eq(false, tc.overlay_visible(), "gamepad button hides the overlay")
	await t.touch_down(0, Vector2(300, 400))
	t.eq(true, tc.overlay_visible(), "a touch brings the overlay back")
	await t.touch_up(0, Vector2(300, 400))
	await t.joy_axis(JOY_AXIS_RIGHT_Y, 0.8)
	t.eq(false, tc.overlay_visible(), "gamepad stick deflection 0.8 hides the overlay")


func test_release_all(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_down(1, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(340, 400))
	await t.touch_drag(1, Vector2(1060, 400))
	tc.release_all()
	await t.frames(1)
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "release_all clears movement")
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("aim"), "release_all clears aim")
	t.eq(false, Input.is_action_pressed("shoot"), "release_all stops fire")
	t.eq(false, tc.left_stick.is_active(), "left stick inactive")
	t.eq(false, tc.right_stick.is_active(), "right stick inactive")


func test_pausing_releases_sticks(t) -> void:
	var tc: Node = await t.spawn_touch("game", false)
	if tc == null: return
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(340, 400))
	t.eq(0.5, snappedf(Input.get_action_strength("move_right"), 0.0001), "moving before pause")
	tc.paused = true
	await t.frames(2)
	t.eq({"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}, t.strengths("move"), "pausing releases the held stick")
