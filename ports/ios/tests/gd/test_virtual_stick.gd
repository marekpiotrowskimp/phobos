extends RefCounted
# AC-1 (etap 02, strojenie): VirtualStick — pure logic of one floating stick.
# Response curve: radius 80 px, dead zone 8 px, full output at 60 % of the radius (48 px):
#   output = clamp((distance − 8) / (48 − 8), 0, 1) in the finger's direction.
# When the finger goes beyond the radius the origin follows it (stays 80 px behind).

const PATH := "res://scripts/touch/virtual_stick.gd"


func _stick(t) -> Object:
	var script: Script = t.require_script(PATH)
	if script == null:
		return null
	var s: Object = script.new()
	s.zone = Rect2(0, 0, 640, 720)
	return s


func test_defaults(t) -> void:
	var s := _stick(t)
	if s == null: return
	t.approx(80.0, s.radius, "radius 80 px")
	t.approx(8.0, s.deadzone, "dead zone 8 px")
	t.approx(0.6, s.full_at, "full output at 60 % of the radius")


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


func test_dead_zone(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(206, 300))
	t.approx_v(Vector2.ZERO, s.vector(), "6 px is inside the 8 px dead zone")
	s.drag(0, Vector2(208, 300))
	t.approx_v(Vector2.ZERO, s.vector(), "exactly 8 px still gives 0")


func test_response_curve(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	t.eq(true, s.drag(0, Vector2(228, 300)), "drag of own finger is consumed")
	t.approx_v(Vector2(0.5, 0.0), s.vector(), "28 px → half output")
	s.drag(0, Vector2(240, 300))
	t.approx_v(Vector2(0.8, 0.0), s.vector(), "40 px → 0.8")
	s.drag(0, Vector2(200, 252))
	t.approx_v(Vector2(0.0, -1.0), s.vector(), "48 px up → full output")
	s.drag(0, Vector2(200 + 33.941, 300 + 33.941))
	t.approx_v(Vector2(0.7071, 0.7071), s.vector(), "48 px diagonal → full output, direction kept")


func test_origin_follows_finger(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(400, 300))
	t.approx_v(Vector2(1.0, 0.0), s.vector(), "far drag → full output")
	t.approx_v(Vector2(320, 300), s.origin, "origin follows to 80 px behind the finger")
	s.drag(0, Vector2(300, 300))
	t.approx_v(Vector2(-0.3, 0.0), s.vector(), "coming back 20 px left of the moved origin → 0.3 left at once")
	s.drag(0, Vector2(260, 380))
	t.approx_v(Vector2(-0.6, 0.8), s.vector(), "100 px diagonal from the origin → full output, direction kept")


func test_second_finger_ignored(t) -> void:
	var s := _stick(t)
	if s == null: return
	s.press(0, Vector2(200, 300))
	s.drag(0, Vector2(240, 300))
	t.eq(false, s.press(1, Vector2(100, 100)), "second finger is not claimed while active")
	t.eq(false, s.drag(1, Vector2(500, 500)), "drag of a foreign finger is ignored")
	t.approx_v(Vector2(0.8, 0.0), s.vector(), "vector unchanged by the foreign finger")


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
