extends RefCounted
## Converts the display safe area (notch, Dynamic Island, home indicator) into margins in
## canvas units — the coordinates HUD and touch controls are laid out in.


## safe_rect   — DisplayServer.get_display_safe_area() in window pixels (empty = unknown)
## window_size — DisplayServer.window_get_size() in pixels
## visible     — the canvas size (Viewport.get_visible_rect().size)
## Returns {left, top, right, bottom}; all 0 when the safe area is unknown.
static func margins(safe_rect: Rect2i, window_size: Vector2i, visible: Vector2) -> Dictionary:
	var result := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return result
	var scale := Vector2(visible.x / window_size.x, visible.y / window_size.y)
	result["left"] = maxf(safe_rect.position.x, 0.0) * scale.x
	result["top"] = maxf(safe_rect.position.y, 0.0) * scale.y
	result["right"] = maxf(window_size.x - safe_rect.end.x, 0.0) * scale.x
	result["bottom"] = maxf(window_size.y - safe_rect.end.y, 0.0) * scale.y
	return result
