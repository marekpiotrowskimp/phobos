extends RefCounted
# AC-3, AC-4: aim assist for touch — the right stick's direction snaps to the enemy closest in
# angle, if it lies within ±15° of where the thumb points. Pad and keyboard are not assisted.

const PATH := "res://scripts/touch/aim_assist.gd"
const PLAYER_AIM_DEADZONE := 0.35


func _aim() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", PLAYER_AIM_DEADZONE)


func _deg(a: Vector2, b: Vector2) -> float:
	return absf(rad_to_deg(a.angle_to(b)))


func _assist(t) -> Script:
	return t.require_script(PATH)


# ------------------------------------------------------------ AimAssist.pick (pure)

func test_pick_without_targets_keeps_direction(t) -> void:
	var a := _assist(t)
	if a == null: return
	t.approx_v(Vector2(0.6, 0.8), a.pick(Vector2.ZERO, Vector2(3, 4), [], 15.0), "no enemies → thumb direction (normalised)")


func test_pick_snaps_within_cone(t) -> void:
	var a := _assist(t)
	if a == null: return
	var target := Vector2(10, 10 * tan(deg_to_rad(10.0)))
	t.approx_v(target.normalized(), a.pick(Vector2.ZERO, Vector2.RIGHT, [target], 15.0), "enemy 10° off → aim straight at it")


func test_pick_ignores_target_outside_cone(t) -> void:
	var a := _assist(t)
	if a == null: return
	var target := Vector2(10, 10 * tan(deg_to_rad(20.0)))
	t.approx_v(Vector2.RIGHT, a.pick(Vector2.ZERO, Vector2.RIGHT, [target], 15.0), "enemy 20° off → thumb direction")
	t.approx_v(Vector2.RIGHT, a.pick(Vector2.ZERO, Vector2.RIGHT, [Vector2(-10, 0)], 15.0), "enemy behind → thumb direction")


func test_pick_prefers_smallest_angle(t) -> void:
	var a := _assist(t)
	if a == null: return
	var near_12 := Vector2(5, 5 * tan(deg_to_rad(12.0)))
	var far_5 := Vector2(15, -15 * tan(deg_to_rad(5.0)))
	t.approx_v(far_5.normalized(), a.pick(Vector2.ZERO, Vector2.RIGHT, [near_12, far_5], 15.0), "of 12° and 5° picks the 5° enemy")


func test_pick_relative_to_origin(t) -> void:
	var a := _assist(t)
	if a == null: return
	var origin := Vector2(4, -3)
	var target := origin + Vector2(0, 10)
	t.approx_v(Vector2.DOWN, a.pick(origin, Vector2(0.1, 1.0), [target], 15.0), "angles measured from the player position")


func test_pick_zero_direction(t) -> void:
	var a := _assist(t)
	if a == null: return
	t.approx_v(Vector2.ZERO, a.pick(Vector2.ZERO, Vector2.ZERO, [Vector2(5, 0)], 15.0), "no thumb direction → no aim")


func test_assist_cone_constant(t) -> void:
	var script: Script = t.require_script("res://scripts/touch/touch_controls.gd")
	if script == null: return
	t.approx(15.0, float(script.get_script_constant_map().get("AIM_ASSIST_DEG", -1.0)), "assist cone ±15°")


# ------------------------------------------------------------ in the game (main scene)

func _arena_with_enemy(t, deg: float) -> Node:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	main.player.global_position = Vector3.ZERO
	var e: Node = main.enemy_pool[0]
	e.spawn(Vector3(10.0, 0.0, 10.0 * tan(deg_to_rad(deg))), 0.0, 0.0)
	await t.frames(2)
	return main


func test_game_aim_snaps_to_enemy(t) -> void:
	var main: Node = await _arena_with_enemy(t, 10.0)
	await t.touch_down(0, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(1048, 400))
	var to_enemy := Vector2(10.0, 10.0 * tan(deg_to_rad(10.0)))
	t.ok(_aim().length() > 0.9, "full aim (got %s)" % _aim())
	t.ok(_deg(_aim(), to_enemy) < 1.0, "thumb points right, enemy 10° below → player aims at the enemy (off by %.1f°)" % _deg(_aim(), to_enemy))
	t.eq(true, Input.is_action_pressed("shoot"), "firing")


func test_game_aim_free_when_enemy_outside_cone(t) -> void:
	var main: Node = await _arena_with_enemy(t, 25.0)
	await t.touch_down(0, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(1048, 400))
	t.ok(_deg(_aim(), Vector2.RIGHT) < 1.0, "enemy 25° off → player aims where the thumb points (off by %.1f°)" % _deg(_aim(), Vector2.RIGHT))


func test_game_aim_tracks_moving_enemy(t) -> void:
	var main: Node = await _arena_with_enemy(t, 10.0)
	await t.touch_down(0, Vector2(1000, 400))
	await t.touch_drag(0, Vector2(1048, 400))
	var e: Node = main.enemy_pool[0]
	e.global_position = Vector3(10.0, 0.0, -10.0 * tan(deg_to_rad(5.0)))
	await t.frames(3)
	var to_enemy := Vector2(10.0, -10.0 * tan(deg_to_rad(5.0)))
	t.ok(_deg(_aim(), to_enemy) < 1.0, "finger still, enemy moved to 5° above → aim follows it (off by %.1f°)" % _deg(_aim(), to_enemy))


func test_game_pad_aim_not_assisted(t) -> void:
	var main: Node = await _arena_with_enemy(t, 10.0)
	Input.action_press("aim_right", 1.0)
	await t.frames(3)
	t.ok(_deg(_aim(), Vector2.RIGHT) < 0.5, "pad / keyboard aim right stays exactly right (off by %.1f°)" % _deg(_aim(), Vector2.RIGHT))
	Input.action_release("aim_right")
