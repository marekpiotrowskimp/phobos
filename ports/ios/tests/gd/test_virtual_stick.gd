extends RefCounted
# AC-1: VirtualStick — pure logic of one floating stick (no rendering, no Input).

const PATH := "res://scripts/touch/virtual_stick.gd"


func _stick(t) -> Object:
	var script: Script = t.require_script(PATH)
	if script == null:
		return null
	var s: Object = script.new()
	s.zone = Rect2(0, 0, 640, 720)
	s.radius = 80.0
	return s


func test_press_in_zone_activates(t) -> void:
	var s := _stick(t)
	if s == null: return
	t.eq(true, s.press(0, Vector2(200, 300)), "press inside zone is claimed")
	t.eq(true, s.is_active(), "stick active after press")
	t.approx_v(Vector2.ZERO, s.vector(), "no deflection right after press")


func test_press_outside_zone_ignored(t) -> void:
	var s := _stick(t)
	if s == null: return
	t.eq(false, s.press(0, Vector2(700, 300)), "press outside zone is not claimed")
	t.eq(false, s.is_active(), "stick stays inactive")
	t.approx_v(Vector2.ZERO, s.vector(), "inactive stick has zero vector")


func test_drag_gives_scaled_vector(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	t.eq(true, s.drag(0, Vector2(240, 300)), "drag of own finger is consumed")
	t.approx_v(Vector2(0.5, 0.0), s.vector(), "40 px right of origin with radius 80")
	s.drag(0, Vector2(200, 240))
	t.approx_v(Vector2(0.0, -0.75), s.vector(), "60 px up of origin with radius 80")


func test_vector_clamped_to_unit_length(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(400, 300))
	t.approx_v(Vector2(1.0, 0.0), s.vector(), "200 px right is clamped to length 1")
	s.drag(0, Vector2(260, 380))
	t.approx_v(Vector2(0.6, 0.8), s.vector(), "100 px diagonal keeps direction, length 1")


func test_second_finger_ignored(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(240, 300))
	t.eq(false, s.press(1, Vector2(100, 100)), "second finger is not claimed while active")
	t.eq(false, s.drag(1, Vector2(500, 500)), "drag of a foreign finger is ignored")
	t.approx_v(Vector2(0.5, 0.0), s.vector(), "vector unchanged by the foreign finger")


func test_release_resets(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(240, 300))
	t.eq(false, s.release(1), "release of a foreign finger is ignored")
	t.eq(true, s.is_active(), "still active after foreign release")
	t.eq(true, s.release(0), "release of own finger is consumed")
	t.eq(false, s.is_active(), "inactive after release")
	t.approx_v(Vector2.ZERO, s.vector(), "zero vector after release")
	t.eq(true, s.press(2, Vector2(300, 300)), "a new finger can take over after release")
