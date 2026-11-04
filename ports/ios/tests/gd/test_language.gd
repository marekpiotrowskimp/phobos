extends RefCounted
# Wersja angielska i poprawki UI.
# Język interfejsu wybiera scripts/ui/localization.gd: polski, gdy język urządzenia to polski,
# w pozostałych przypadkach angielski. I18n.override_language wymusza język (runner: "pl").
# Fonty gry (Oxanium, Tektur) nie mają ▲▼◀▶♪, więc teksty ich nie używają, a przyciski
# dotykowe rysują strzałki, pauzę i dźwięk jako kształty (button_icon).

const I18N := "res://scripts/ui/localization.gd"
const HUD := "res://scripts/hud.gd"
const OXANIUM := "res://assets/fonts/Oxanium-Variable.ttf"
const ARROWS := {"menu_up": "arrow_up", "menu_down": "arrow_down", "menu_left": "arrow_left", "menu_right": "arrow_right"}


func _i18n(t) -> Script:
	return t.require_script(I18N)


func _en(t) -> Node:
	t.set_language("en")
	var main: Node = await t.spawn_main()
	return main


# ------------------------------------------------------------ I18n

func test_detect_language(t) -> void:
	var i := _i18n(t)
	if i == null: return
	for locale in ["pl", "pl_PL", "pl-PL"]:
		t.eq("pl", i.detect(locale), "%s → pl" % locale)
	for locale in ["en", "en_US", "en_GB", "de_DE", "fr", "uk_UA", ""]:
		t.eq("en", i.detect(locale), "%s → en (English is the default)" % locale)


func test_override_language(t) -> void:
	var i := _i18n(t)
	if i == null: return
	i.set("override_language", "en")
	t.eq("en", i.current(), "override en")
	i.set("override_language", "pl")
	t.eq("pl", i.current(), "override pl")
	i.set("override_language", "")
	t.eq(i.detect(OS.get_locale()), i.current(), "no override → device locale")


func test_both_languages_have_the_same_keys(t) -> void:
	var i := _i18n(t)
	if i == null: return
	var pl: Array = i.keys("pl")
	var en: Array = i.keys("en")
	pl.sort()
	en.sort()
	t.ok(pl.size() >= 30, "at least 30 UI strings (got %d)" % pl.size())
	t.eq(pl, en, "Polish and English define the same keys")
	for lang in ["pl", "en"]:
		for key in i.keys(lang):
			t.ok(str(i.text(key, lang)).strip_edges() != "", "%s/%s is not empty" % [lang, key])


# ------------------------------------------------------------ polski bez zmian (charakteryzacja)

func test_polish_texts_unchanged(t) -> void:
	var main: Node = await t.spawn_main()
	var hud: Node = main.hud
	t.ok(hud._screen_body.text.contains(">  GRAJ  <") and hud._screen_body.text.contains("TRUDNOŚĆ: < NORMALNY >"), "menu PL")
	t.ok(hud._screen_body.text.contains("WYNIKI") and hud._screen_body.text.contains("LICENCJE"), "menu PL items")
	hud.show_results([], "WSZYSTKIE", {"score": 100, "difficulty_label": "NORMALNY", "wave": 2, "time": 65.0}, true)
	var body: String = hud._screen_body.text
	t.ok(body.contains("OSTATNI WYNIK: 100  •  NORMALNY  •  FALA 2  •  01:05"), "results summary PL")
	t.ok(body.contains("TOP 10  •  < WSZYSTKIE >"), "results filter PL")
	t.ok(body.contains("LP   GRACZ    WYNIK      POZIOM       FALA   CZAS"), "results header PL")
	t.ok(body.contains("BRAK ZAPISANYCH WYNIKÓW"), "empty ranking PL")
	main.run_difficulty = "normal"
	main._pending_result = {"score": 100, "wave": 2, "kills": 5, "time": 30.0, "difficulty": "normal"}
	main._show_initials()
	t.eq("WPISZ INICJAŁY", hud._screen_title.text, "initials title PL")
	t.ok(hud._screen_body.text.begins_with("NOWY WYNIK: 100\nPOZIOM: NORMALNY  •  FALA: 2  •  ZABICIA: 5"), "initials body PL")
	hud.show_game_over(100, 200, 3, 7, 65.0)
	t.eq("PRZEGRANA", hud._go_title.text, "game over title PL")
	t.eq("WYNIK: 100", hud._go_score.text, "score PL")
	t.eq("REKORD: 200", hud._go_best.text, "best PL")
	t.eq("Fala 3  |  Zabicia: 7  |  Czas: 01:05", hud._go_stats.text, "stats PL")
	main._start_run()
	await t.frames(2)
	main._begin_wave()  # the round starts with a break; the banner comes with the first wave
	t.eq("POZIOM: NORMALNY", hud.difficulty_label.text, "level PL")
	t.eq("Zabicia: 0", hud.kills_label.text, "kills PL")
	t.eq("FALA 1", hud.banner.text, "wave banner PL")
	hud.set_wave_cleanup(2)
	t.eq("FALA 2  ·  OCZYŚĆ ARENĘ", hud.wave_label.text, "cleanup PL")
	hud.set_wave_time(2, 9)
	t.eq("FALA 2  ·  09 s", hud.wave_label.text, "wave timer PL")
	main._on_wave_cleared()
	t.ok(str(hud.banner.text).begins_with("FALA 1 UDANA  +"), "wave cleared banner PL (got %s)" % hud.banner.text)


# ------------------------------------------------------------ angielski

func test_en_menu(t) -> void:
	var main: Node = await _en(t)
	var hud: Node = main.hud
	t.eq("PHOBOS", hud._screen_title.text, "title")
	var body: String = hud._screen_body.text
	t.ok(body.contains(">  PLAY  <"), "PLAY selected (got %s)" % body)
	t.ok(body.contains("DIFFICULTY: < NORMAL >"), "difficulty")
	t.ok(body.contains("SCORES") and body.contains("LICENSES"), "scores + licenses")
	t.ok(not body.contains("GRAJ") and not body.contains("WYNIKI"), "no Polish left in the menu")
	t.eq("UP/DOWN SELECT  •  OK", hud._screen_hint.text, "hint")
	main._menu_index = 1
	main._cycle_difficulty(1)
	main._show_main_menu()
	t.ok(hud._screen_body.text.contains("DIFFICULTY: < HARD >"), "difficulty names in English (got %s)" % hud._screen_body.text)


func test_en_results(t) -> void:
	var main: Node = await _en(t)
	var hud: Node = main.hud
	main._results_filter_index = 0
	main._show_results(false)
	t.eq("SCORES", hud._screen_title.text, "title")
	var body: String = hud._screen_body.text
	t.ok(body.contains("TOP 10  •  < ALL >"), "filter ALL (got %s)" % body)
	t.ok(body.contains("NO SCORES YET"), "empty ranking")
	for word in ["PLAYER", "SCORE", "LEVEL", "WAVE", "TIME"]:
		t.ok(body.contains(word), "header has %s" % word)
	t.eq("‹ › FILTER  •  OK / BACK MENU", hud._screen_hint.text, "hint from the menu")
	hud.show_results([], "ALL", {"score": 100, "difficulty_label": "NORMAL", "wave": 2, "time": 65.0}, true)
	t.ok(hud._screen_body.text.contains("LAST SCORE: 100  •  NORMAL  •  WAVE 2  •  01:05"), "last score line")
	t.eq("‹ › FILTER  •  OK PLAY AGAIN  •  BACK MENU", hud._screen_hint.text, "hint after a run")


func test_en_initials(t) -> void:
	var main: Node = await _en(t)
	var hud: Node = main.hud
	main.run_difficulty = "normal"
	main._pending_result = {"score": 100, "wave": 2, "kills": 5, "time": 30.0, "difficulty": "normal"}
	main._show_initials()
	t.eq("YOUR INITIALS", hud._screen_title.text, "title")
	t.ok(hud._screen_body.text.begins_with("NEW SCORE: 100\nLEVEL: NORMAL  •  WAVE: 2  •  KILLS: 5"), "body (got %s)" % hud._screen_body.text)
	t.eq("UP/DOWN LETTER  •  ‹ › POSITION  •  OK", hud._screen_hint.text, "hint")


func test_en_credits(t) -> void:
	var main: Node = await _en(t)
	main._show_credits()
	t.eq("LICENSES", main.hud._screen_title.text, "title")
	t.eq("UP/DOWN SCROLL  •  OK / BACK MENU", main.hud._screen_hint.text, "hint")


func test_en_gameplay_hud(t) -> void:
	var main: Node = await _en(t)
	var hud: Node = main.hud
	main._start_run()
	await t.frames(2)
	main._begin_wave()
	t.eq("LEVEL: NORMAL", hud.difficulty_label.text, "level")
	t.eq("Kills: 0", hud.kills_label.text, "kills")
	t.eq("WAVE 1", hud.banner.text, "wave banner")
	hud.set_wave_time(2, 9)
	t.eq("WAVE 2  ·  09 s", hud.wave_label.text, "wave timer")
	hud.set_wave_cleanup(2)
	t.eq("WAVE 2  ·  CLEAR THE ARENA", hud.wave_label.text, "cleanup")
	t.eq("PAUSED\nII — RESUME", hud._pause_label.text, "pause")
	main._on_wave_cleared()
	t.ok(str(hud.banner.text).begins_with("WAVE 1 CLEARED  +"), "wave cleared banner (got %s)" % hud.banner.text)


func test_en_game_over(t) -> void:
	var main: Node = await _en(t)
	var hud: Node = main.hud
	hud.show_game_over(100, 200, 3, 7, 65.0)
	t.eq("GAME OVER", hud._go_title.text, "title")
	t.eq("SCORE: 100", hud._go_score.text, "score")
	t.eq("BEST: 200", hud._go_best.text, "best")
	t.eq("Wave 3  |  Kills: 7  |  Time: 01:05", hud._go_stats.text, "stats")
	t.eq("OK — PLAY AGAIN", hud._go_hint.text, "hint")


# ------------------------------------------------------------ fonty: tylko znaki, które mają

## Every character of every HUD label (except the licence text) exists in the label's font.
func _check_glyphs(t, hud: Node, tag: String) -> void:
	for node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label == hud.get("_credits_label"):
			continue
		var font: Font = label.get_theme_font("font")
		var missing := ""
		for c in label.text:
			if c.strip_edges() == "":
				continue
			if not font.has_char(c.unicode_at(0)):
				missing += c
		t.eq("", missing, "%s: label %s '%s' uses glyphs its font lacks" % [tag, label.name, label.text.left(30)])


func _glyph_tour(t, lang: String) -> void:
	t.set_language(lang)
	var main: Node = await t.spawn_main()
	var hud: Node = main.hud
	_check_glyphs(t, hud, lang + " menu")
	main.run_difficulty = "normal"
	main._pending_result = {"score": 100, "wave": 2, "kills": 5, "time": 30.0, "difficulty": "normal"}
	main._show_initials()
	_check_glyphs(t, hud, lang + " initials")
	hud.show_results([{"initials": "ABC", "score": 10, "difficulty_label": "X", "wave": 1, "time": 5.0}], "X", {"score": 1, "difficulty_label": "X", "wave": 1, "time": 1.0}, true)
	_check_glyphs(t, hud, lang + " results")
	main._show_credits()
	_check_glyphs(t, hud, lang + " credits")
	hud.show_game_over(100, 200, 3, 7, 65.0)
	_check_glyphs(t, hud, lang + " game over")
	main._start_run()
	await t.frames(2)
	hud.set_wave_cleanup(2)
	_check_glyphs(t, hud, lang + " gameplay")


func test_glyphs_pl(t) -> void:
	await _glyph_tour(t, "pl")


func test_glyphs_en(t) -> void:
	await _glyph_tour(t, "en")


# ------------------------------------------------------------ przyciski dotykowe

func _touch_labels(t, lang: String, back: String) -> void:
	t.set_language(lang)
	var tc: Node = await t.spawn_touch("menu", true)
	if tc == null: return
	t.eq(back, tc.button_label("menu_back"), "%s: back button" % lang)
	t.eq("OK", tc.button_label("menu_confirm"), "%s: OK button" % lang)
	for action in ARROWS:
		t.eq("", tc.button_label(action), "%s: %s has no text (drawn arrow)" % [lang, action])
	var font: Font = tc.button_font()
	t.ok(font != null, "button font set")
	if font == null: return
	for action in ["menu_back", "menu_confirm"]:
		var label: String = tc.button_label(action)
		var size: int = tc.button_font_size(action)
		t.ok(size >= 20, "%s %s: font %d px ≥ 20" % [lang, action, size])
		for c in label:
			t.ok(font.has_char(c.unicode_at(0)), "%s %s: font has '%s'" % [lang, action, c])
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		t.ok(width <= tc.BUTTON_SIZE - 8.0, "%s '%s' fits the button: %.0f ≤ %.0f px" % [lang, label, width, tc.BUTTON_SIZE - 8.0])


func test_touch_labels_pl(t) -> void:
	await _touch_labels(t, "pl", "WSTECZ")


func test_touch_labels_en(t) -> void:
	await _touch_labels(t, "en", "BACK")


func test_touch_icons(t) -> void:
	var tc: Node = await t.spawn_touch("menu", true)
	if tc == null: return
	for action in ARROWS:
		t.eq(ARROWS[action], tc.button_icon(action), "%s is a drawn arrow" % action)
	t.eq("", tc.button_icon("menu_confirm"), "OK is text")
	t.eq("", tc.button_icon("menu_back"), "BACK is text")
	t.eq("pause", tc.button_icon("pause"), "pause is drawn (two bars)")
	t.eq("", tc.button_label("pause"), "pause has no text")
	AudioServer.set_bus_mute(0, false)
	t.eq("sound_on", tc.button_icon("mute"), "mute button shows sound on")
	AudioServer.set_bus_mute(0, true)
	t.eq("sound_off", tc.button_icon("mute"), "muted → sound off icon")
	AudioServer.set_bus_mute(0, false)
	t.eq("", tc.button_label("mute"), "mute has no text")


# ------------------------------------------------------------ licznik FPS

func test_should_show_fps(t) -> void:
	var hud: Script = load(HUD)
	t.eq(false, hud.should_show_fps(false, PackedStringArray()), "release build → no FPS counter")
	t.eq(true, hud.should_show_fps(true, PackedStringArray()), "debug build → FPS counter")
	t.eq(true, hud.should_show_fps(false, PackedStringArray(["--show-fps"])), "--show-fps → FPS counter")


func test_fps_label_follows_show_fps(t) -> void:
	var main: Node = await t.spawn_main()
	var hud: Node = main.hud
	hud.show_fps = false
	main._start_run()
	await t.frames(2)
	t.eq(false, hud.fps_label.visible, "show_fps off → hidden during gameplay")
	hud.show_fps = true
	hud.show_gameplay("NORMALNY")
	t.eq(true, hud.fps_label.visible, "show_fps on → visible during gameplay")
	hud.set_gameplay_visible(false)
	t.eq(false, hud.fps_label.visible, "hidden with the rest of the HUD")


# ------------------------------------------------------------ Centrum sterowania / utrata fokusu

func test_focus_out_pauses_game(t) -> void:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	await t.touch_down(0, Vector2(300, 400))
	await t.touch_drag(0, Vector2(340, 400))
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await t.frames(1)
	t.eq(true, t.paused, "Control Center / notification banner (focus out) pauses the round")
	t.eq(true, main.hud.pause_panel.visible, "pause panel shown")
	t.eq(false, main.touch_controls.left_stick.is_active(), "held touch released")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await t.frames(1)
	t.eq(true, t.paused, "second focus out keeps the pause (no toggle)")


func test_focus_out_in_menu_changes_nothing(t) -> void:
	var main: Node = await t.spawn_main()
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await t.frames(1)
	t.eq("menu", main.screen, "still in the menu")
	t.eq(false, main.hud.pause_panel.visible, "no pause panel over the menu")
