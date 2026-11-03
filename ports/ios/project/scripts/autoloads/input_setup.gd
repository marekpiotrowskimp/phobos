extends Node

func _ready() -> void:
	_axis_action("move_left", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_axis_action("move_right", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_axis_action("move_up", JOY_AXIS_LEFT_Y, -1.0, [KEY_W, KEY_UP])
	_axis_action("move_down", JOY_AXIS_LEFT_Y, 1.0, [KEY_S, KEY_DOWN])
	_axis_action("aim_left", JOY_AXIS_RIGHT_X, -1.0, [])
	_axis_action("aim_right", JOY_AXIS_RIGHT_X, 1.0, [])
	_axis_action("aim_up", JOY_AXIS_RIGHT_Y, -1.0, [])
	_axis_action("aim_down", JOY_AXIS_RIGHT_Y, 1.0, [])

	_reset_action("shoot")
	_add_key("shoot", KEY_SPACE)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)
	var trig := InputEventJoypadMotion.new()
	trig.axis = JOY_AXIS_TRIGGER_RIGHT
	trig.axis_value = 1.0
	InputMap.action_add_event("shoot", trig)

	_reset_action("pause")
	_add_key("pause", KEY_ESCAPE)
	var js := InputEventJoypadButton.new()
	js.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", js)

	_reset_action("mute")
	_add_key("mute", KEY_M)

	_axis_action("menu_up", JOY_AXIS_LEFT_Y, -1.0, [KEY_W, KEY_UP])
	_axis_action("menu_down", JOY_AXIS_LEFT_Y, 1.0, [KEY_S, KEY_DOWN])
	_axis_action("menu_left", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_axis_action("menu_right", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_add_joy_button("menu_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("menu_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("menu_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("menu_right", JOY_BUTTON_DPAD_RIGHT)
	_reset_action("menu_confirm")
	_add_key("menu_confirm", KEY_ENTER)
	_add_joy_button("menu_confirm", JOY_BUTTON_A)
	_reset_action("menu_back")
	_add_key("menu_back", KEY_ESCAPE)
	_add_joy_button("menu_back", JOY_BUTTON_B)

func _axis_action(action: String, axis: int, value: float, keys: Array) -> void:
	_reset_action(action)
	for k in keys:
		_add_key(action, k)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _add_joy_button(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _reset_action(action: String, deadzone := 0.3) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, deadzone)
	InputMap.action_set_deadzone(action, deadzone)
