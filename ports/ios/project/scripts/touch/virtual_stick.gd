extends RefCounted
## One floating on-screen stick: it appears where a finger lands inside `zone` and reports the
## finger's offset from that point, scaled by `radius` and clamped to length 1.
## Pure logic — no rendering and no Input actions.

var zone := Rect2()
var radius := 80.0
var touch_index := -1
var origin := Vector2.ZERO
var current := Vector2.ZERO


func is_active() -> bool:
	return touch_index >= 0


## Claims the touch when the stick is free and `pos` lies inside the zone.
func press(index: int, pos: Vector2) -> bool:
	if is_active() or not zone.has_point(pos):
		return false
	touch_index = index
	origin = pos
	current = pos
	return true


func drag(index: int, pos: Vector2) -> bool:
	if index != touch_index or not is_active():
		return false
	current = pos
	return true


func release(index: int) -> bool:
	if index != touch_index or not is_active():
		return false
	reset()
	return true


func reset() -> void:
	touch_index = -1
	origin = Vector2.ZERO
	current = Vector2.ZERO


func vector() -> Vector2:
	if not is_active() or radius <= 0.0:
		return Vector2.ZERO
	return ((current - origin) / radius).limit_length(1.0)
