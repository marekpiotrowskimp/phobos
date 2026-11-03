extends RefCounted
## One floating on-screen stick: it appears where a finger lands inside `zone` and reports the
## finger's offset from that point as a vector of length 0…1.
## Response: nothing inside `deadzone` px, then linear up to full output at `full_at` × `radius`.
## If the finger goes further than `radius`, the origin follows it, so turning back reacts at once.
## Pure logic — no rendering and no Input actions.

var zone := Rect2()
var radius := 80.0
var deadzone := 8.0
var full_at := 0.6
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
	var offset := current - origin
	if offset.length() > radius:
		origin = current - offset.normalized() * radius
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
	if not is_active():
		return Vector2.ZERO
	var offset := current - origin
	var distance := offset.length()
	var full := maxf(radius * full_at, deadzone + 0.001)
	if distance <= deadzone:
		return Vector2.ZERO
	var strength := clampf((distance - deadzone) / (full - deadzone), 0.0, 1.0)
	return offset / distance * strength
