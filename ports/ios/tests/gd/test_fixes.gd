extends RefCounted
# Poprawki po audycie etapu 03: safe area tylko na iOS, dopasowanie tekstów menu i inicjałów.

const R169 := Vector2i(1280, 720)
const IPHONE := Vector2i(2532, 1170)
const IPAD := Vector2i(2048, 1536)
const IPHONE_SAFE := Rect2i(141, 0, 2250, 1107)
const IPAD_SAFE := Rect2i(0, 0, 2048, 1496)
## What macOS returns from get_display_safe_area(): the screen's usable rect in screen
## coordinates (menu bar 38 px, Dock), here for a 1512x982 MacBook screen.
const MAC_USABLE := Rect2i(0, 38, 1512, 906)
## Same on a second monitor placed right of the built-in one.
const MAC_SECOND_SCREEN := Rect2i(1512, 25, 2560, 1415)

const SAFE_AREA_PATH := "res://scripts/ui/safe_area.gd"


func _resize(t, size: Vector2i) -> void:
	t.root.size = size
	await t.frames(3)


# ------------------------------------------------------------ AC-1: safe area only on iOS

func test_effective_safe_area_ignored_off_ios(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	if not t.ok(sa.has_method("effective"), "SafeArea.effective exists"): return
	t.eq(Rect2i(), sa.effective(MAC_USABLE, false), "macOS usable screen rect is not a safe area")
	t.eq(Rect2i(), sa.effective(MAC_SECOND_SCREEN, false), "second-monitor rect is not a safe area")


func test_effective_safe_area_used_on_ios(t) -> void:
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null: return
	if not t.ok(sa.has_method("effective"), "SafeArea.effective exists"): return
	t.eq(IPHONE_SAFE, sa.effective(IPHONE_SAFE, true), "iPhone safe area passed through on iOS")
	t.eq(IPAD_SAFE, sa.effective(IPAD_SAFE, true), "iPad safe area passed through on iOS")


func test_main_desktop_safe_area_is_empty(t) -> void:
	var main: Node = await t.spawn_main()
	if not t.ok(main.has_method("_device_safe_area"), "main._device_safe_area exists"): return
	t.eq(false, OS.has_feature("ios"), "tests run on a non-iOS platform")
	t.eq(Rect2i(), main._device_safe_area(), "off iOS main uses no safe area (zero margins)")


func test_mac_rect_does_not_shift_hud(t) -> void:
	await _resize(t, R169)
	var main: Node = await t.spawn_main()
	var sa: Script = t.require_script(SAFE_AREA_PATH)
	if sa == null or not t.ok(sa.has_method("effective"), "SafeArea.effective exists"): return
	main.apply_safe_area(sa.effective(MAC_SECOND_SCREEN, false), R169)
	main._start_run()
	await t.frames(2)
	t.approx_v(Vector2(24, 684), main.hud.hp_bar.global_position, "hp bar stays at its desktop position", 0.5)
	t.eq(Rect2(1160, 24, 96, 96), main.touch_controls.pause_button_rect(), "pause stays at its desktop position")


# ------------------------------------------------------------ AC-2: menu and initials text fits

func _check_texts(t, main: Node, tag: String) -> void:
	var nav: Dictionary = main.touch_controls.nav_button_rects()
	var v: Vector2 = t.root.get_visible_rect().size
	for label_name in ["_screen_title", "_screen_body", "_screen_hint"]:
		var label: Label = main.hud.get(label_name)
		var r := label.get_global_rect()
		var need := label.get_minimum_size()
		var name := "%s %s" % [tag, label_name]
		t.ok(Rect2(Vector2.ZERO, v).grow(0.5).encloses(r), "%s on screen (%s)" % [name, r])
		t.ok(need.x <= r.size.x + 0.5 and need.y <= r.size.y + 0.5, "%s: text %s fits its box %s" % [name, need, r.size])
		for k in nav:
			t.ok(not r.intersects(nav[k]), "%s does not overlap button %s" % [name, k])


func _check_menu_and_initials(t, size: Vector2i, safe: Rect2i) -> void:
	await _resize(t, size)
	var main: Node = await t.spawn_main()
	if safe != Rect2i():
		main.apply_safe_area(safe, size)
	main._show_main_menu()
	await t.frames(2)
	_check_texts(t, main, "menu @%s" % size)
	main.run_difficulty = "normal"
	main._pending_result = {"score": 9999999, "wave": 99, "kills": 9999, "time": 3599.0, "difficulty": "normal"}
	main._show_initials()
	main._initials = PackedStringArray(["W", "W", "W"])
	main._initials_cursor = 1
	main._refresh_initials()
	await t.frames(2)
	_check_texts(t, main, "initials @%s" % size)


func test_menu_and_initials_fit_169(t) -> void:
	await _check_menu_and_initials(t, R169, Rect2i())


func test_menu_and_initials_fit_iphone(t) -> void:
	await _check_menu_and_initials(t, IPHONE, IPHONE_SAFE)


func test_menu_and_initials_fit_ipad(t) -> void:
	await _check_menu_and_initials(t, IPAD, IPAD_SAFE)
