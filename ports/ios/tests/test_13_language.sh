#!/usr/bin/env bash
# Wersja angielska gry (język z urządzenia: pl → polski, inne → angielski) i poprawki UI:
# znaki dostępne w fontach gry, rysowane ikony przycisków, napis WSTECZ mieści się w przycisku,
# licznik FPS tylko w buildzie debug, pauza przy utracie fokusu (Centrum sterowania).

RELEASE="$IOS_DIR/release"

# ------------------------------------------------------------ I18n (gd)
test_lang_detect()                 { run_gd test_language.gd test_detect_language; }
test_lang_override()               { run_gd test_language.gd test_override_language; }
test_lang_same_keys()              { run_gd test_language.gd test_both_languages_have_the_same_keys; }
test_lang_polish_unchanged()       { run_gd test_language.gd test_polish_texts_unchanged; }
test_lang_en_menu()                { run_gd test_language.gd test_en_menu; }
test_lang_en_results()             { run_gd test_language.gd test_en_results; }
test_lang_en_initials()            { run_gd test_language.gd test_en_initials; }
test_lang_en_credits()             { run_gd test_language.gd test_en_credits; }
test_lang_en_gameplay_hud()        { run_gd test_language.gd test_en_gameplay_hud; }
test_lang_en_game_over()           { run_gd test_language.gd test_en_game_over; }
test_lang_glyphs_pl()              { run_gd test_language.gd test_glyphs_pl; }
test_lang_glyphs_en()              { run_gd test_language.gd test_glyphs_en; }
test_lang_layout_iphone_en()       { run_gd test_ui_layout.gd test_screen_layout_iphone_en; }
test_lang_layout_ipad_en()         { run_gd test_ui_layout.gd test_screen_layout_ipad_en; }

# ------------------------------------------------------------ przyciski, FPS, fokus (gd)
test_ui_touch_labels_pl()          { run_gd test_language.gd test_touch_labels_pl; }
test_ui_touch_labels_en()          { run_gd test_language.gd test_touch_labels_en; }
test_ui_touch_icons()              { run_gd test_language.gd test_touch_icons; }
test_ui_should_show_fps()          { run_gd test_language.gd test_should_show_fps; }
test_ui_fps_label_follows_flag()   { run_gd test_language.gd test_fps_label_follows_show_fps; }
test_ui_focus_out_pauses()         { run_gd test_language.gd test_focus_out_pauses_game; }
test_ui_focus_out_in_menu()        { run_gd test_language.gd test_focus_out_in_menu_changes_nothing; }

# ------------------------------------------------------------ kod: teksty tylko w i18n.gd

test_lang_no_polish_literals_in_code() {
	local f hits=""
	for f in scripts/hud.gd scripts/main.gd scripts/touch/touch_controls.gd; do
		hits+=$(grep -nE '"[^"]*(GRAJ|WYNIK|FALA|Fala|Zabicia|ZABICIA|POZIOM|PAUZA|WZNÓW|WSTECZ|LICENCJE|PRZEGRANA|REKORD|TRUDNOŚĆ|INICJAŁY|WSZYSTKIE|OCZYŚĆ|UDANA|PRZEWIŃ|BRAK ZAPISANYCH|LITERA|POZYCJA|FILTR|WYBÓR|JESZCZE RAZ|Czas)[^"]*"' "$IOS_PROJECT/$f" | sed "s#^#$f:#")
	done
	assert_eq "" "$hits" "UI texts live only in scripts/ui/localization.gd (Polish literal left in code)"
}

# ------------------------------------------------------------ Info.plist: języki aplikacji

test_lang_presets_declare_localizations() {
	local p v
	for p in "iOS" "iOS Xcode"; do
		v=$(preset_value "$IOS_PRESETS" "$p" application/additional_plist_content)
		assert_contains "$v" "CFBundleLocalizations" "$p: declares the app languages" || return 1
		assert_contains "$v" "GCSupportsControllerUserInteraction" "$p: controller keys kept" || return 1
	done
}

test_lang_info_plist_localizations() {
	rm -rf "$XCODE_EXPORT"
	local log rc
	log=$("$ROOT/build.sh" ios-xcode 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	local plist="$XCODE_EXPORT/PHOBOS/PHOBOS-Info.plist"
	plutil -lint "$plist" >/dev/null || fail "Info.plist is not valid" || return 1
	assert_eq '["en","pl"]' "$(plutil -extract CFBundleLocalizations json -o - "$plist" 2>&1)" "CFBundleLocalizations = en, pl" || return 1
	assert_eq "true" "$(plutil -extract GCSupportsControllerUserInteraction raw -o - "$plist")" "controller key still present"
}

# ------------------------------------------------------------ materiały sklepu

test_lang_store_texts_mention_languages() {
	local notes; notes=$(cat "$RELEASE/review-notes.md")
	assert_contains "$notes" "Polish and English" "review notes: UI in Polish and English" || return 1
	assert_not_contains "$notes" "The user interface is in Polish;" "review notes: no 'Polish only' statement" || return 1
	assert_contains "$(cat "$RELEASE/metadata-en.md")" "English" "EN description mentions the English UI" || return 1
	assert_contains "$(cat "$RELEASE/metadata-pl.md")" "angielsk" "PL description mentions the English version"
}
