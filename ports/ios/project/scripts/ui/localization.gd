extends RefCounted
## UI texts in Polish and English. The language follows the device: Polish for a Polish
## locale, English otherwise. `override_language` forces one (tests, a future settings option).
## Only characters present in the game fonts (Oxanium, Tektur) are used: no ▲▼◀▶♪.

const DEFAULT_LANGUAGE := "en"

const STRINGS := {
	"pl": {
		"menu_play": "GRAJ",
		"menu_difficulty": "TRUDNOŚĆ: < %s >",
		"menu_controls": "STEROWANIE: < %s >",
		"controls_leash": "NOWE",
		"controls_classic": "KLASYCZNE",
		"menu_results": "WYNIKI",
		"menu_credits": "LICENCJE",
		"hint_menu": "GÓRA/DÓŁ WYBÓR  •  OK",
		"initials_title": "WPISZ INICJAŁY",
		"initials_body": "NOWY WYNIK: %d\nPOZIOM: %s  •  FALA: %d  •  ZABICIA: %d\n\n%s",
		"hint_initials": "GÓRA/DÓŁ LITERA  •  ‹ › POZYCJA  •  OK",
		"results_title": "WYNIKI",
		"results_last": "OSTATNI WYNIK: %d  •  %s  •  FALA %d  •  %02d:%02d",
		"results_top": "TOP 10  •  < %s >",
		"results_header": "LP   GRACZ    WYNIK      POZIOM       FALA   CZAS",
		"results_empty": "BRAK ZAPISANYCH WYNIKÓW",
		"hint_results_run": "‹ › FILTR  •  OK JESZCZE RAZ  •  WSTECZ MENU",
		"hint_results_menu": "‹ › FILTR  •  OK / WSTECZ MENU",
		"credits_title": "LICENCJE",
		"hint_credits": "GÓRA/DÓŁ PRZEWIŃ  •  OK / WSTECZ MENU",
		"pause": "PAUZA\nII — WZNÓW",
		"go_title": "PRZEGRANA",
		"go_hint": "OK — GRAJ PONOWNIE",
		"go_score": "WYNIK: %d",
		"go_best": "REKORD: %d",
		"go_stats": "Fala %d  |  Zabicia: %d  |  Czas: %02d:%02d",
		"hud_kills": "Zabicia: %d",
		"hud_level": "POZIOM: %s",
		"hud_wave": "FALA %d",
		"hud_wave_time": "FALA %d  ·  %02d s",
		"hud_wave_cleanup": "FALA %d  ·  OCZYŚĆ ARENĘ",
		"banner_wave_cleared": "FALA %d UDANA  +%d",
		"difficulty_easy": "ŁATWY",
		"difficulty_normal": "NORMALNY",
		"difficulty_hard": "TRUDNY",
		"difficulty_all": "WSZYSTKIE",
		"button_back": "WSTECZ",
		"button_ok": "OK",
	},
	"en": {
		"menu_play": "PLAY",
		"menu_difficulty": "DIFFICULTY: < %s >",
		"menu_controls": "CONTROLS: < %s >",
		"controls_leash": "NEW",
		"controls_classic": "CLASSIC",
		"menu_results": "SCORES",
		"menu_credits": "LICENSES",
		"hint_menu": "UP/DOWN SELECT  •  OK",
		"initials_title": "YOUR INITIALS",
		"initials_body": "NEW SCORE: %d\nLEVEL: %s  •  WAVE: %d  •  KILLS: %d\n\n%s",
		"hint_initials": "UP/DOWN LETTER  •  ‹ › POSITION  •  OK",
		"results_title": "SCORES",
		"results_last": "LAST SCORE: %d  •  %s  •  WAVE %d  •  %02d:%02d",
		"results_top": "TOP 10  •  < %s >",
		"results_header": "#    PLAYER   SCORE      LEVEL        WAVE   TIME",
		"results_empty": "NO SCORES YET",
		"hint_results_run": "‹ › FILTER  •  OK PLAY AGAIN  •  BACK MENU",
		"hint_results_menu": "‹ › FILTER  •  OK / BACK MENU",
		"credits_title": "LICENSES",
		"hint_credits": "UP/DOWN SCROLL  •  OK / BACK MENU",
		"pause": "PAUSED\nII — RESUME",
		"go_title": "GAME OVER",
		"go_hint": "OK — PLAY AGAIN",
		"go_score": "SCORE: %d",
		"go_best": "BEST: %d",
		"go_stats": "Wave %d  |  Kills: %d  |  Time: %02d:%02d",
		"hud_kills": "Kills: %d",
		"hud_level": "LEVEL: %s",
		"hud_wave": "WAVE %d",
		"hud_wave_time": "WAVE %d  ·  %02d s",
		"hud_wave_cleanup": "WAVE %d  ·  CLEAR THE ARENA",
		"banner_wave_cleared": "WAVE %d CLEARED  +%d",
		"difficulty_easy": "EASY",
		"difficulty_normal": "NORMAL",
		"difficulty_hard": "HARD",
		"difficulty_all": "ALL",
		"button_back": "BACK",
		"button_ok": "OK",
	},
}

static var override_language := ""


## "pl" for a Polish locale (pl, pl_PL, pl-PL), English for everything else.
static func detect(locale: String) -> String:
	var language := locale.to_lower().replace("-", "_").get_slice("_", 0)
	return "pl" if language == "pl" else DEFAULT_LANGUAGE


static func current() -> String:
	if STRINGS.has(override_language):
		return override_language
	return detect(OS.get_locale())


static func text(key: String, lang: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS[DEFAULT_LANGUAGE])
	return str(table.get(key, key))


## Text in the current language.
static func t(key: String) -> String:
	return text(key, current())


static func keys(lang: String) -> Array:
	var table: Dictionary = STRINGS.get(lang, {})
	return table.keys()
