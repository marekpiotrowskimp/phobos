extends RefCounted
## Touch aim assist: snaps the thumb's aim direction to the target closest in angle, if that
## target lies within ±max_deg of where the thumb points.


## origin  — player position (arena x/z as a Vector2)
## dir     — aim direction from the stick (any length; zero means "not aiming")
## targets — positions (Vector2) of the enemies that may be aimed at
## Returns a unit direction, or Vector2.ZERO when `dir` is zero.
static func pick(origin: Vector2, dir: Vector2, targets: Array, max_deg: float) -> Vector2:
	if dir.length_squared() < 0.000001:
		return Vector2.ZERO
	var aim := dir.normalized()
	var best := aim
	var best_angle := deg_to_rad(max_deg)
	for target in targets:
		var to_target: Vector2 = target - origin
		if to_target.length_squared() < 0.000001:
			continue
		var angle := absf(aim.angle_to(to_target))
		if angle <= best_angle:
			best_angle = angle
			best = to_target.normalized()
	return best
