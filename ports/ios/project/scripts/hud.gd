class_name Hud
extends CanvasLayer

class Bar:
	extends Control

	var value := 1.0
	var max_value := 1.0
	var fill := Color(0.2, 0.9, 0.3)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.05, 0.09, 0.9))
		var ratio := clampf(value / max_value, 0.0, 1.0)
		draw_rect(Rect2(2, 2, (w - 4.0) * ratio, h - 4.0), fill)
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.22), false, 1.5)

	func set_value(v: float, mx: float) -> void:
		value = v
		max_value = mx
		queue_redraw()

var wave_label: Label
var score_label: Label
var kills_label: Label
var fps_label: Label
var difficulty_label: Label
var hp_bar: Bar
var od_bar: Bar
var banner: Label
var vignette: ColorRect
var flash: ColorRect
var game_over_panel: Control
var pause_panel: Control
var screen_panel: ColorRect
var od_tween: Tween
var _banner_tween: Tween
var _fps_t := 0.0
var _go_title: Label
var _go_score: Label
var _go_best: Label
var _go_stats: Label
var _go_hint: Label
var _screen_title: Label
var _screen_body: Label
var _screen_hint: Label
var _credits_scroll: ScrollContainer
var _credits_label: Label
var _pause_label: Label
var _display_font: FontVariation
var _ui_font: FontVariation
var _ui_font_bold: FontVariation
## Gameplay HUD controls and their offsets without safe-area margins.
var _safe_controls: Array[Control] = []
var _base_offsets := {}

## Width of the menu-screen text column: wide enough for the longest ranking line (≈ 610 px at
## 22 px) and narrow enough to stay between the touch d-pad and the OK/BACK buttons.
const SCREEN_COLUMN_WIDTH := 640.0
## Same column as the other menu screens, so the licence text never runs under the touch d-pad.
const CREDITS_WIDTH := SCREEN_COLUMN_WIDTH
## Pixels scrolled by one ▲ / ▼ press on the credits screen.
const CREDITS_SCROLL_STEP := 240

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fonts()
	_go_title = Label.new()
	_go_score = Label.new()
	_go_best = Label.new()
	_go_stats = Label.new()
	_go_hint = Label.new()
	_build_hud()
	_build_panels()
	_apply_fonts()
	reset()

func _setup_fonts() -> void:
	_display_font = _make_font("res://assets/fonts/Tektur-Variable.ttf", 760.0, 88.0)
	_display_font.spacing_glyph = 1
	_ui_font = _make_font("res://assets/fonts/Oxanium-Variable.ttf", 500.0)
	_ui_font_bold = _make_font("res://assets/fonts/Oxanium-Variable.ttf", 700.0)

func _make_font(path: String, weight: float, width := -1.0) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = load(path)
	var text_server := TextServerManager.get_primary_interface()
	var axes := {text_server.name_to_tag("wght"): weight}
	if width > 0.0:
		axes[text_server.name_to_tag("wdth")] = width
	variation.variation_opentype = axes
	return variation

func _apply_fonts() -> void:
	var display_labels := [wave_label, banner, _pause_label, _go_title, _screen_title]
	var bold_labels := [score_label, difficulty_label, _go_score, _go_best]
	var ui_labels := [kills_label, fps_label, _go_stats, _go_hint, _screen_body, _screen_hint]
	for label in display_labels:
		label.add_theme_font_override("font", _display_font)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.025, 0.045, 0.95))
	for label in bold_labels:
		label.add_theme_font_override("font", _ui_font_bold)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.035, 0.9))
	for label in ui_labels:
		label.add_theme_font_override("font", _ui_font)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.035, 0.9))
	# ~90 KB of licence text on an opaque panel: no outline (it would double the glyphs drawn).
	_credits_label.add_theme_font_override("font", _ui_font)

func _build_hud() -> void:
	wave_label = Label.new()
	wave_label.text = ""
	wave_label.add_theme_font_size_override("font_size", 46)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.position = Vector2(-250, 22)
	wave_label.size = Vector2(500, 60)
	add_child(wave_label)

	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-250, 78)
	score_label.size = Vector2(500, 40)
	add_child(score_label)

	kills_label = Label.new()
	kills_label.add_theme_font_size_override("font_size", 22)
	kills_label.text = "Zabicia: 0"
	kills_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kills_label.position = Vector2(-300, 22)
	kills_label.size = Vector2(280, 30)
	add_child(kills_label)

	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-300, 50)
	fps_label.size = Vector2(280, 24)
	add_child(fps_label)

	difficulty_label = Label.new()
	difficulty_label.add_theme_font_size_override("font_size", 22)
	difficulty_label.position = Vector2(24, 22)
	difficulty_label.size = Vector2(300, 28)
	add_child(difficulty_label)

	hp_bar = Bar.new()
	hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bar.position = Vector2(24, -36)
	hp_bar.size = Vector2(260, 18)
	hp_bar.fill = Color(0.2, 0.9, 0.3)
	add_child(hp_bar)

	od_bar = Bar.new()
	od_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	od_bar.position = Vector2(-284, -26)
	od_bar.size = Vector2(260, 10)
	od_bar.fill = Color(0.3, 0.7, 1.0)
	od_bar.visible = false
	add_child(od_bar)

	banner = Label.new()
	banner.text = ""
	banner.add_theme_font_size_override("font_size", 64)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.size = Vector2(760, 90)
	banner.position = Vector2(-380, -140)
	banner.modulate.a = 0.0
	add_child(banner)

	var vmat := ShaderMaterial.new()
	vmat.shader = load("res://shaders/vignette.gdshader")
	vignette = ColorRect.new()
	vignette.material = vmat
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	set_danger(false)

	flash = ColorRect.new()
	flash.color = Color(1, 0.08, 0.08, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	_safe_controls = [wave_label, score_label, kills_label, fps_label, difficulty_label, hp_bar, od_bar]
	for control in _safe_controls:
		_base_offsets[control] = [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]

func _build_panels() -> void:
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0, 0, 0, 0.6)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	add_child(pause_panel)
	_pause_label = Label.new()
	_pause_label.text = "PAUZA\nII — WZNÓW"
	_pause_label.add_theme_font_size_override("font_size", 48)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(_pause_label)

	game_over_panel = Control.new()
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_panel.visible = false
	add_child(game_over_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_panel.add_child(bg)
	_go_title.text = "PRZEGRANA"
	_go_title.add_theme_font_size_override("font_size", 72)
	_go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_title.set_anchors_preset(Control.PRESET_CENTER)
	_go_title.position = Vector2(-400, -220)
	_go_title.size = Vector2(800, 100)
	_go_title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_panel.add_child(_go_title)
	_go_score.add_theme_font_size_override("font_size", 40)
	_go_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_score.set_anchors_preset(Control.PRESET_CENTER)
	_go_score.position = Vector2(-400, -80)
	_go_score.size = Vector2(800, 50)
	game_over_panel.add_child(_go_score)
	_go_best.add_theme_font_size_override("font_size", 28)
	_go_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_best.set_anchors_preset(Control.PRESET_CENTER)
	_go_best.position = Vector2(-400, -20)
	_go_best.size = Vector2(800, 40)
	game_over_panel.add_child(_go_best)
	_go_stats.add_theme_font_size_override("font_size", 24)
	_go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_stats.set_anchors_preset(Control.PRESET_CENTER)
	_go_stats.position = Vector2(-400, 40)
	_go_stats.size = Vector2(800, 40)
	game_over_panel.add_child(_go_stats)
	_go_hint.text = "OK — GRAJ PONOWNIE"
	_go_hint.add_theme_font_size_override("font_size", 26)
	_go_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_hint.set_anchors_preset(Control.PRESET_CENTER)
	_go_hint.position = Vector2(-400, 140)
	_go_hint.size = Vector2(800, 40)
	_go_hint.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	game_over_panel.add_child(_go_hint)

	screen_panel = ColorRect.new()
	screen_panel.color = Color(0.008, 0.012, 0.025, 0.94)
	screen_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_panel.visible = false
	add_child(screen_panel)
	_screen_title = Label.new()
	_screen_title.add_theme_font_size_override("font_size", 64)
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_in_screen(_screen_title, -315.0, 90.0)
	_screen_title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	screen_panel.add_child(_screen_title)
	_screen_body = Label.new()
	_screen_body.add_theme_font_size_override("font_size", 22)
	_screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_in_screen(_screen_body, -225.0, 440.0)
	_screen_body.add_theme_color_override("font_color", Color(0.84, 0.9, 0.94))
	screen_panel.add_child(_screen_body)
	_screen_hint = Label.new()
	_screen_hint.add_theme_font_size_override("font_size", 22)
	_screen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_in_screen(_screen_hint, 265.0, 38.0)
	_screen_hint.add_theme_color_override("font_color", Color(0.42, 0.72, 0.82))
	screen_panel.add_child(_screen_hint)
	_build_credits()

## Anchors a menu-screen label to the screen centre: SCREEN_COLUMN_WIDTH wide, `height` tall,
## its top edge `top` px from the vertical centre (the 1280x720 layout kept, but centred).
func _center_in_screen(label: Label, top: float, height: float) -> void:
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -SCREEN_COLUMN_WIDTH / 2.0
	label.offset_right = SCREEN_COLUMN_WIDTH / 2.0
	label.offset_top = top
	label.offset_bottom = top + height

## Moves the gameplay HUD inside the safe area: controls anchored to an edge keep their inset
## from that edge of the safe area. margins = {left, top, right, bottom} in canvas pixels.
func apply_safe_margins(margins: Dictionary) -> void:
	for control in _safe_controls:
		var base: Array = _base_offsets[control]
		var dx := 0.0
		if control.anchor_left == 0.0 and control.anchor_right == 0.0:
			dx = float(margins.get("left", 0.0))
		elif control.anchor_left == 1.0 and control.anchor_right == 1.0:
			dx = -float(margins.get("right", 0.0))
		var dy := 0.0
		if control.anchor_top == 0.0 and control.anchor_bottom == 0.0:
			dy = float(margins.get("top", 0.0))
		elif control.anchor_top == 1.0 and control.anchor_bottom == 1.0:
			dy = -float(margins.get("bottom", 0.0))
		control.offset_left = base[0] + dx
		control.offset_top = base[1] + dy
		control.offset_right = base[2] + dx
		control.offset_bottom = base[3] + dy

func reset() -> void:
	set_hp(Balance.player_max_hp, Balance.player_max_hp)
	score_label.text = "0"
	kills_label.text = "Zabicia: 0"
	wave_label.text = ""
	banner.modulate.a = 0.0
	od_bar.visible = false
	if od_tween:
		od_tween.kill()
	game_over_panel.visible = false
	pause_panel.visible = false
	screen_panel.visible = false
	set_gameplay_visible(true)
	set_danger(false)

func _process(delta: float) -> void:
	if od_bar.visible:
		od_bar.queue_redraw()
	_fps_t += delta
	if _fps_t >= 0.5:
		_fps_t = 0.0
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func set_hp(v: float, mx: float) -> void:
	hp_bar.set_value(v, mx)
	set_danger(v / mx < 0.3)

func flash_damage() -> void:
	flash.color = Color(1, 0.08, 0.08, 0.32)
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)

func set_danger(on: bool) -> void:
	(vignette.material as ShaderMaterial).set_shader_parameter("danger", 1.0 if on else 0.0)

func set_wave(w: int) -> void:
	wave_label.text = "FALA %d" % w

func show_gameplay(difficulty: String) -> void:
	screen_panel.visible = false
	game_over_panel.visible = false
	pause_panel.visible = false
	difficulty_label.text = "POZIOM: %s" % difficulty
	set_gameplay_visible(true)

func show_main_menu(selected: int, difficulty: String) -> void:
	var entries := ["GRAJ", "TRUDNOŚĆ: < %s >" % difficulty, "WYNIKI", "LICENCJE"]
	var lines := PackedStringArray()
	for i in entries.size():
		lines.append((">  %s  <" if i == selected else "   %s   ") % entries[i])
	_show_screen("PHOBOS", "\n".join(lines), "▲▼ WYBÓR  •  OK")

func show_initials(chars: PackedStringArray, cursor: int, result: Dictionary, difficulty: String) -> void:
	var displayed := PackedStringArray()
	for i in 3:
		displayed.append("[%s]" % chars[i] if i == cursor else " %s " % chars[i])
	var body := "NOWY WYNIK: %d\nPOZIOM: %s  •  FALA: %d  •  ZABICIA: %d\n\n%s" % [
		int(result.get("score", 0)), difficulty, int(result.get("wave", 0)),
		int(result.get("kills", 0)), "   ".join(displayed)
	]
	_show_screen("WPISZ INICJAŁY", body, "▲▼ LITERA  •  ◀▶ POZYCJA  •  OK")

func show_results(entries: Array, filter_label: String, summary: Dictionary, from_run: bool) -> void:
	var lines := PackedStringArray()
	if not summary.is_empty():
		lines.append("OSTATNI WYNIK: %d  •  %s  •  FALA %d  •  %02d:%02d" % [
			int(summary.get("score", 0)), str(summary.get("difficulty_label", "")),
			int(summary.get("wave", 0)), int(summary.get("time", 0.0)) / 60,
			int(summary.get("time", 0.0)) % 60
		])
		lines.append("")
	lines.append("TOP 10  •  < %s >" % filter_label)
	lines.append("LP   GRACZ    WYNIK      POZIOM       FALA   CZAS")
	var count := mini(entries.size(), 10)
	for i in count:
		var entry: Dictionary = entries[i]
		var seconds := int(entry.get("time", 0.0))
		lines.append("%2d   %s      %7d    %-9s    %2d    %02d:%02d" % [
			i + 1, str(entry.get("initials", "---")), int(entry.get("score", 0)),
			str(entry.get("difficulty_label", "")), int(entry.get("wave", 0)),
			seconds / 60, seconds % 60
		])
	if count == 0:
		lines.append("\nBRAK ZAPISANYCH WYNIKÓW")
	var hint := "◀▶ FILTR  •  OK JESZCZE RAZ  •  WSTECZ MENU" if from_run else "◀▶ FILTR  •  OK / WSTECZ MENU"
	_show_screen("WYNIKI", "\n".join(lines), hint)

func set_gameplay_visible(on: bool) -> void:
	for control in [wave_label, score_label, kills_label, fps_label, difficulty_label, hp_bar, banner, vignette, flash]:
		control.visible = on
	if not on:
		od_bar.visible = false

func _show_screen(title: String, body: String, hint: String) -> void:
	set_gameplay_visible(false)
	game_over_panel.visible = false
	pause_panel.visible = false
	screen_panel.visible = true
	_credits_scroll.visible = false
	_screen_title.text = title
	_screen_body.text = body
	_screen_hint.text = hint

func set_wave_time(w: int, seconds: int) -> void:
	wave_label.text = "FALA %d  ·  %02d s" % [w, seconds]

func set_wave_cleanup(w: int) -> void:
	wave_label.text = "FALA %d  ·  OCZYŚĆ ARENĘ" % w

func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.1)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.7)

func hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 0.0

func add_score(v: int) -> void:
	score_label.text = str(v)

func add_kills(k: int) -> void:
	kills_label.text = "Zabicia: %d" % k

func start_od_bar(duration: float) -> void:
	od_bar.visible = true
	od_bar.set_value(1.0, 1.0)
	if od_tween:
		od_tween.kill()
	od_tween = create_tween()
	od_tween.tween_property(od_bar, "value", 0.0, duration)

func end_od_bar() -> void:
	if od_tween:
		od_tween.kill()
	od_bar.visible = false

func show_game_over(score: int, best: int, w: int, kills: int, survived: float) -> void:
	_go_score.text = "WYNIK: %d" % score
	_go_best.text = "REKORD: %d" % best
	var minutes := int(survived) / 60
	var seconds := int(survived) % 60
	_go_stats.text = "Fala %d  |  Zabicia: %d  |  Czas: %02d:%02d" % [w, kills, minutes, seconds]
	game_over_panel.visible = true

func toggle_pause(on: bool) -> void:
	pause_panel.visible = on


# ------------------------------------------------------------ credits (LICENCJE)

## Scrollable licence text in the place of the screen body (same vertical band, wider column).
func _build_credits() -> void:
	_credits_scroll = ScrollContainer.new()
	_credits_scroll.anchor_left = 0.5
	_credits_scroll.anchor_right = 0.5
	_credits_scroll.anchor_top = 0.5
	_credits_scroll.anchor_bottom = 0.5
	_credits_scroll.offset_left = -CREDITS_WIDTH * 0.5
	_credits_scroll.offset_right = CREDITS_WIDTH * 0.5
	_credits_scroll.offset_top = -225.0
	_credits_scroll.offset_bottom = 215.0
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.visible = false
	screen_panel.add_child(_credits_scroll)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 22)
	_credits_label.add_theme_color_override("font_color", Color(0.84, 0.9, 0.94))
	_credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_scroll.add_child(_credits_label)


func show_credits(text: String) -> void:
	_show_screen("LICENCJE", "", "▲▼ PRZEWIŃ  •  OK / WSTECZ MENU")
	_credits_label.text = text
	_credits_scroll.visible = true
	_credits_scroll.scroll_vertical = 0


## Scrolls by `step` presses (negative = up); the container clamps to the text's ends.
func scroll_credits(step: int) -> void:
	_credits_scroll.scroll_vertical += step * CREDITS_SCROLL_STEP


func credits_scroll() -> float:
	return float(_credits_scroll.scroll_vertical)


func credits_text() -> String:
	return _credits_label.text
