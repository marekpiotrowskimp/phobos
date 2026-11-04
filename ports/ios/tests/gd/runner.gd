extends SceneTree
# Headless GDScript test runner for the iOS project.
# Usage: godot --headless --path ports/ios/project -s <this file> -- <suite.gd> <test_name>
# Prints GD_PASS / GD_ASSERT lines; exit code 0 = pass, 1 = fail.

const VIEWPORT := Vector2(1280, 720)

var failures: PackedStringArray = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("GD_ASSERT usage: -- <suite.gd> <test_name>")
		quit(1)
		return
	# Headless has a 0x0 window, so the root viewport is 64x64 and the canvas_items stretch would
	# scale touch positions ×20. Give it the real design size so event coords = viewport coords.
	root.size = Vector2i(VIEWPORT)
	# The UI language follows the device; the suites assert Polish texts unless they switch to
	# English themselves (set_language), so pin Polish regardless of the machine's locale.
	set_language("pl")
	await process_frame  # autoloads ready
	var script: Script = load(args[0])
	if script == null:
		print("GD_ASSERT cannot load suite ", args[0])
		quit(1)
		return
	var suite: Object = script.new()
	if not suite.has_method(args[1]):
		print("GD_ASSERT no test ", args[1])
		quit(1)
		return
	await suite.call(args[1], self)
	if failures.is_empty():
		print("GD_PASS ", args[1])
		quit(0)
	else:
		for f in failures:
			print("GD_ASSERT ", f)
		quit(1)


# ------------------------------------------------------------------ assertions

func fail(msg: String) -> void:
	failures.append(msg)


func ok(cond: bool, msg: String) -> bool:
	if not cond:
		fail(msg)
	return cond


func eq(expected: Variant, actual: Variant, msg: String) -> bool:
	if typeof(expected) != typeof(actual) or expected != actual:
		fail("%s — expected: %s, actual: %s" % [msg, var_to_str(expected), var_to_str(actual)])
		return false
	return true


func approx(expected: float, actual: float, msg: String, eps := 0.001) -> bool:
	if absf(expected - actual) > eps:
		fail("%s — expected: %.4f, actual: %.4f" % [msg, expected, actual])
		return false
	return true


func approx_v(expected: Vector2, actual: Vector2, msg: String, eps := 0.001) -> bool:
	if expected.distance_to(actual) > eps:
		fail("%s — expected: %s, actual: %s" % [msg, expected, actual])
		return false
	return true


# ------------------------------------------------------------------ helpers

## Loads a production script; records a failure (not a crash) when it does not exist yet.
func require_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		fail("missing production script " + path)
		return null
	return load(path)


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func touch_down(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)


func touch_drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)
	await frames(2)


func touch_up(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(2)


## Press + release in the centre of a rect (a tap).
func tap(rect: Rect2, index := 0) -> void:
	await touch_down(index, rect.get_center())
	await touch_up(index, rect.get_center())


func joy_button(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(2)


func joy_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	await frames(2)


## Forces the UI language (Localization.override_language) for everything created afterwards.
func set_language(lang: String) -> void:
	var i18n: Script = load("res://scripts/ui/localization.gd")
	if i18n != null:
		i18n.set("override_language", lang)


## Instantiates scenes/main.tscn and waits until it shows the main menu.
func spawn_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(3)
	return main


## Adds a standalone TouchControls with the given context (no main scene).
func spawn_touch(screen: String, is_paused: bool) -> Node:
	var script := require_script("res://scripts/touch/touch_controls.gd")
	if script == null:
		return null
	var tc: Node = script.new()
	tc.screen = screen
	tc.paused = is_paused
	root.add_child(tc)
	await frames(2)
	return tc


func strengths(prefix: String) -> Dictionary:
	var out := {}
	for dir in ["left", "right", "up", "down"]:
		out[dir] = snappedf(Input.get_action_strength("%s_%s" % [prefix, dir]), 0.0001)
	return out
