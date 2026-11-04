extends CanvasLayer
## Touch overlay for iPhone / iPad. Translates touches into the existing input actions, so the
## game logic does not know whether a pad, a keyboard or a finger is used:
##   gameplay    — floating left stick → move_*, right stick → aim_* (+ shoot above threshold),
##                 pause button (and mute button while paused)
##   menu screens — ▲ ▼ ◀ ▶ OK BACK buttons → menu_* actions
## The context comes from `source` (the main scene: its `screen` + the tree pause state) or is
## set directly through `screen` / `paused`.

const VirtualStick := preload("res://scripts/touch/virtual_stick.gd")

## Aim assist: the thumb's direction snaps to an enemy within ±AIM_ASSIST_DEG (touch only).
const AIM_ASSIST_DEG := 15.0
## Dead zones player.gd applies when it reads move_* / aim_* (Input.get_vector). The touch layer
## pre-compensates them so the player sees exactly the stick's output, while pad input that
## goes straight to player.gd keeps its own dead zones.
const PLAYER_MOVE_DEADZONE := 0.28
const PLAYER_AIM_DEADZONE := 0.35
const BUTTON_SIZE := 96.0  # ≥ 88 px = 44 pt on the smallest landscape iPhone
const MARGIN := 24.0
const GAMEPAD_AXIS_THRESHOLD := 0.5
const GAMEPLAY_SCREEN := "game"
const Localization := preload("res://scripts/ui/localization.gd")
## Text buttons and their Localization keys; every other button is a drawn icon (button_icon),
## because the game fonts have no ▲▼◀▶♪ glyphs.
const TEXT_BUTTONS := {"menu_confirm": "button_ok", "menu_back": "button_back"}
const ICON_BUTTONS := {
	"menu_up": "arrow_up", "menu_down": "arrow_down", "menu_left": "arrow_left",
	"menu_right": "arrow_right", "pause": "pause",
}
const BUTTON_FONT_FILE := preload("res://assets/fonts/Oxanium-Variable.ttf")
const BUTTON_FONT_WEIGHT := 600.0
const BUTTON_FONT_SIZE := 28
const BUTTON_FONT_MIN_SIZE := 20
## Horizontal room for a label inside a button (4 px padding on each side).
const BUTTON_TEXT_ROOM := BUTTON_SIZE - 8.0
const COLOR_BASE := Color(1, 1, 1, 0.12)
const COLOR_KNOB := Color(1, 1, 1, 0.35)
const COLOR_BUTTON := Color(1, 1, 1, 0.16)
const COLOR_TEXT := Color(1, 1, 1, 0.8)

var screen := "menu"
var paused := true
var source: Node = null
## Optional: Callable(dir: Vector2) -> Vector2 that bends the aim towards a target (set by main).
var aim_assist := Callable()

var left_stick := VirtualStick.new()
var right_stick := VirtualStick.new()

var _overlay_visible := true
## Safe-area margins in canvas pixels; buttons are laid out inside them.
var _safe := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
var _owned_actions := {}
var _canvas: Control
var _button_font: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)
	_update_zones()


func _process(_delta: float) -> void:
	if source != null and is_instance_valid(source):
		screen = str(source.get("screen"))
		paused = get_tree().paused
	if not _sticks_enabled() and (left_stick.is_active() or right_stick.is_active()):
		release_all()
	elif right_stick.is_active():
		_apply_sticks()  # targets move even when the thumb does not — keep the assisted aim fresh
	_canvas.visible = _overlay_visible
	_canvas.queue_redraw()


# ------------------------------------------------------------------ layout

func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _update_zones() -> void:
	var size := _view_size()
	left_stick.zone = Rect2(0, 0, size.x * 0.5, size.y)
	right_stick.zone = Rect2(size.x * 0.5, 0, size.x * 0.5, size.y)


## The part of the canvas not covered by the notch / home indicator.
func _safe_rect() -> Rect2:
	var size := _view_size()
	var l := float(_safe["left"])
	var t := float(_safe["top"])
	return Rect2(l, t, size.x - l - float(_safe["right"]), size.y - t - float(_safe["bottom"]))


func set_safe_margins(margins: Dictionary) -> void:
	for k in _safe:
		_safe[k] = maxf(float(margins.get(k, 0.0)), 0.0)


func pause_button_rect() -> Rect2:
	var safe := _safe_rect()
	return Rect2(safe.end.x - MARGIN - BUTTON_SIZE, safe.position.y + MARGIN, BUTTON_SIZE, BUTTON_SIZE)


func mute_button_rect() -> Rect2:
	var safe := _safe_rect()
	return Rect2(safe.end.x - 2.0 * (MARGIN + BUTTON_SIZE), safe.position.y + MARGIN, BUTTON_SIZE, BUTTON_SIZE)


func nav_button_rects() -> Dictionary:
	var safe := _safe_rect()
	var b := BUTTON_SIZE
	var center := Vector2(safe.position.x + MARGIN + 1.5 * b, safe.end.y - MARGIN - 1.5 * b)
	return {
		"menu_up": Rect2(center + Vector2(-0.5 * b, -1.5 * b), Vector2(b, b)),
		"menu_down": Rect2(center + Vector2(-0.5 * b, 0.5 * b), Vector2(b, b)),
		"menu_left": Rect2(center + Vector2(-1.5 * b, -0.5 * b), Vector2(b, b)),
		"menu_right": Rect2(center + Vector2(0.5 * b, -0.5 * b), Vector2(b, b)),
		"menu_confirm": Rect2(safe.end.x - MARGIN - b, safe.end.y - MARGIN - b, b, b),
		"menu_back": Rect2(safe.end.x - 2.0 * (MARGIN + b), safe.end.y - MARGIN - b, b, b),
	}


func overlay_visible() -> bool:
	return _overlay_visible


# ------------------------------------------------------------------ context

func _in_gameplay() -> bool:
	return screen == GAMEPLAY_SCREEN


func _sticks_enabled() -> bool:
	return _in_gameplay() and not paused


## Buttons active in the current context, as {action: rect}.
func _active_buttons() -> Dictionary:
	if _in_gameplay():
		var buttons := {"pause": pause_button_rect()}
		if paused:
			buttons["mute"] = mute_button_rect()
		return buttons
	return nav_button_rects()


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_overlay_visible = false
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= GAMEPAD_AXIS_THRESHOLD:
			_overlay_visible = false


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_overlay_visible = true
		var buttons := _active_buttons()
		for action in buttons:
			if (buttons[action] as Rect2).has_point(event.position):
				_emit_action(action)
				get_viewport().set_input_as_handled()
				return
		if _sticks_enabled():
			_update_zones()
			if left_stick.press(event.index, event.position) or right_stick.press(event.index, event.position):
				_apply_sticks()
				get_viewport().set_input_as_handled()
	else:
		if left_stick.release(event.index) or right_stick.release(event.index):
			_apply_sticks()
			get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _sticks_enabled():
		return
	if left_stick.drag(event.index, event.position) or right_stick.drag(event.index, event.position):
		_apply_sticks()
		get_viewport().set_input_as_handled()


func _emit_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


# ------------------------------------------------------------------ actions

func _apply_sticks() -> void:
	_set_axis("move", _compensate(left_stick.vector(), PLAYER_MOVE_DEADZONE))
	# The right stick carries direction only: once the thumb leaves the dead zone the aim has full
	# length, so player.gd (which ignores aim shorter than 0.12) turns as soon as the gun fires.
	var aim := right_stick.vector()
	var aiming := aim.length_squared() > 0.0
	if aiming:
		aim = aim.normalized()
		if aim_assist.is_valid():
			var assisted: Vector2 = aim_assist.call(aim)
			if assisted.length_squared() > 0.0:
				aim = assisted.normalized()
	_set_axis("aim", _compensate(aim, PLAYER_AIM_DEADZONE))
	_set_action("shoot", 1.0 if aiming else 0.0)


## Scales a 0…1 stick vector so that after `deadzone` is removed again (Input.get_vector) the
## reader gets the original length back.
func _compensate(v: Vector2, deadzone: float) -> Vector2:
	var length := v.length()
	if length <= 0.0:
		return Vector2.ZERO
	return v / length * (deadzone + length * (1.0 - deadzone))


func _set_axis(prefix: String, v: Vector2) -> void:
	_set_action(prefix + "_right", maxf(v.x, 0.0))
	_set_action(prefix + "_left", maxf(-v.x, 0.0))
	_set_action(prefix + "_down", maxf(v.y, 0.0))
	_set_action(prefix + "_up", maxf(-v.y, 0.0))


## Presses an action with `strength`, or releases it — but only if the touch layer pressed it,
## so a key or pad button held at the same time is never released by touch.
func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_owned_actions[action] = true
	elif _owned_actions.has(action):
		Input.action_release(action)
		_owned_actions.erase(action)


func release_all() -> void:
	left_stick.reset()
	right_stick.reset()
	for action in _owned_actions.keys():
		Input.action_release(action)
	_owned_actions.clear()


# ------------------------------------------------------------------ drawing

func _draw_overlay() -> void:
	var font := button_font()
	var buttons := _active_buttons()
	for action in buttons:
		var r: Rect2 = buttons[action]
		_canvas.draw_rect(r, COLOR_BUTTON)
		var icon := button_icon(action)
		if icon != "":
			_draw_icon(icon, r)
			continue
		var size := button_font_size(action)
		var baseline := r.get_center().y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
		_canvas.draw_string(font, Vector2(r.position.x, baseline), button_label(action),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, COLOR_TEXT)
	for stick in [left_stick, right_stick]:
		if stick.is_active():
			_canvas.draw_circle(stick.origin, stick.radius, COLOR_BASE)
			_canvas.draw_circle(knob_position(stick), stick.radius * 0.4, COLOR_KNOB)


## Where the knob of `stick` is drawn (canvas px); ZERO when the stick is not held.
func knob_position(stick) -> Vector2:
	if not stick.is_active():
		return Vector2.ZERO
	return stick.origin + (stick.current - stick.origin).limit_length(stick.radius)


# ------------------------------------------------------------ button content

## Text shown on a button in the current language; "" for icon buttons.
func button_label(action: String) -> String:
	if TEXT_BUTTONS.has(action):
		return Localization.t(TEXT_BUTTONS[action])
	return ""


## Drawn icon of a button: arrow_up/down/left/right, pause, sound_on/sound_off; "" for text.
func button_icon(action: String) -> String:
	if action == "mute":
		return "sound_off" if AudioServer.is_bus_mute(0) else "sound_on"
	return str(ICON_BUTTONS.get(action, ""))


## The game UI font (Oxanium, semi-bold) — the variable font would otherwise render its thinnest weight.
func button_font() -> Font:
	if _button_font == null:
		_button_font = FontVariation.new()
		_button_font.base_font = BUTTON_FONT_FILE
		var text_server := TextServerManager.get_primary_interface()
		_button_font.variation_opentype = {text_server.name_to_tag("wght"): BUTTON_FONT_WEIGHT}
	return _button_font


## BUTTON_FONT_SIZE, reduced (down to BUTTON_FONT_MIN_SIZE) until the label fits the button.
func button_font_size(action: String) -> int:
	var label := button_label(action)
	var font := button_font()
	var size := BUTTON_FONT_SIZE
	while size > BUTTON_FONT_MIN_SIZE and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > BUTTON_TEXT_ROOM:
		size -= 1
	return size


func _draw_icon(icon: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x * 0.18
	match icon:
		"arrow_up":
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.7), c + Vector2(-s, s * 0.7)]), COLOR_TEXT)
		"arrow_down":
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s * 0.7), c + Vector2(s, -s * 0.7)]), COLOR_TEXT)
		"arrow_left":
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.7, -s), c + Vector2(s * 0.7, s)]), COLOR_TEXT)
		"arrow_right":
			_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, s), c + Vector2(-s * 0.7, -s)]), COLOR_TEXT)
		"pause":
			var bar := Vector2(s * 0.45, s * 2.0)
			_canvas.draw_rect(Rect2(c + Vector2(-s * 0.75, -s), bar), COLOR_TEXT)
			_canvas.draw_rect(Rect2(c + Vector2(s * 0.3, -s), bar), COLOR_TEXT)
		"sound_on", "sound_off":
			# speaker: box + cone, then waves (on) or a cross (off)
			var left := c.x - s * 1.1
			_canvas.draw_rect(Rect2(Vector2(left, c.y - s * 0.35), Vector2(s * 0.5, s * 0.7)), COLOR_TEXT)
			_canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(left + s * 0.5, c.y - s * 0.35), Vector2(left + s * 1.1, c.y - s * 0.9),
				Vector2(left + s * 1.1, c.y + s * 0.9), Vector2(left + s * 0.5, c.y + s * 0.35)]), COLOR_TEXT)
			var x := c.x + s * 0.35
			if icon == "sound_on":
				_canvas.draw_arc(Vector2(x - s * 0.3, c.y), s * 0.45, -PI / 3.0, PI / 3.0, 12, COLOR_TEXT, 3.0)
				_canvas.draw_arc(Vector2(x - s * 0.3, c.y), s * 0.85, -PI / 3.0, PI / 3.0, 12, COLOR_TEXT, 3.0)
			else:
				_canvas.draw_line(Vector2(x, c.y - s * 0.45), Vector2(x + s * 0.8, c.y + s * 0.45), COLOR_TEXT, 3.0)
				_canvas.draw_line(Vector2(x, c.y + s * 0.45), Vector2(x + s * 0.8, c.y - s * 0.45), COLOR_TEXT, 3.0)
