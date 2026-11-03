#!/usr/bin/env bash
# Etap 03 — UI, safe area i proporcje. Each function runs one GDScript test (tests/gd/test_ui_layout.gd).

# characterization (green before implementation)
test_ui_arena_framing_169_unchanged()      { run_gd test_ui_layout.gd test_arena_framing_169_unchanged; }
test_ui_hud_positions_169_without_margins() { run_gd test_ui_layout.gd test_hud_positions_169_without_margins; }
test_ui_touch_buttons_169_without_margins() { run_gd test_ui_layout.gd test_touch_buttons_169_without_margins; }
test_ui_ranking_survives_reload()          { run_gd test_ui_layout.gd test_ranking_survives_reload; }
test_ui_audio_session_respects_silent_switch() { run_gd test_ui_layout.gd test_audio_session_respects_silent_switch; }

# AC-1, AC-2: aspect ratio
test_ui_stretch_aspect_expand()            { run_gd test_ui_layout.gd test_stretch_aspect_expand; }
test_ui_arena_fits_iphone()                { run_gd test_ui_layout.gd test_arena_fits_iphone; }
test_ui_arena_fits_ipad()                  { run_gd test_ui_layout.gd test_arena_fits_ipad; }
test_ui_arena_refits_after_resize()        { run_gd test_ui_layout.gd test_arena_refits_after_resize; }

# AC-3: SafeArea.margins
test_ui_safe_area_zero_rect()              { run_gd test_ui_layout.gd test_safe_area_zero_rect_means_no_margins; }
test_ui_safe_area_full_window()            { run_gd test_ui_layout.gd test_safe_area_full_window_means_no_margins; }
test_ui_safe_area_iphone()                 { run_gd test_ui_layout.gd test_safe_area_iphone_notch_and_home_bar; }
test_ui_safe_area_ipad()                   { run_gd test_ui_layout.gd test_safe_area_ipad_home_bar; }

# AC-4, AC-5: margins applied
test_ui_hud_respects_safe_margins()        { run_gd test_ui_layout.gd test_hud_respects_safe_margins; }
test_ui_touch_buttons_respect_safe_margins() { run_gd test_ui_layout.gd test_touch_buttons_respect_safe_margins; }
test_ui_main_applies_safe_area()           { run_gd test_ui_layout.gd test_main_applies_safe_area; }
test_ui_main_unknown_safe_area_keeps_edges() { run_gd test_ui_layout.gd test_main_unknown_safe_area_keeps_edges; }

# AC-6: menu screens vs touch buttons
test_ui_screen_layout_169()                { run_gd test_ui_layout.gd test_screen_layout_169; }
test_ui_screen_layout_iphone()             { run_gd test_ui_layout.gd test_screen_layout_iphone; }
test_ui_screen_layout_ipad()               { run_gd test_ui_layout.gd test_screen_layout_ipad; }

# AC-7, AC-8: hints and readability
test_ui_touch_hints()                      { run_gd test_ui_layout.gd test_touch_hints; }
test_ui_no_keyboard_hints_left()           { run_gd test_ui_layout.gd test_no_keyboard_hints_left; }
test_ui_font_sizes_readable()              { run_gd test_ui_layout.gd test_font_sizes_readable; }
