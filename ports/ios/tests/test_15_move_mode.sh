#!/usr/bin/env bash
# Sterowanie ruchem: tryb „smycz” (NOWE, domyślny) i dotychczasowy (KLASYCZNE),
# przełączane w menu głównym; wybór obowiązuje do końca sesji (bez zapisu na dysku).

test_move_default_mode_is_leash()      { run_gd test_move_mode.gd test_default_mode_is_leash; }
test_move_set_mode()                   { run_gd test_move_mode.gd test_set_move_mode; }
test_move_leash_speed_curve()          { run_gd test_move_mode.gd test_leash_speed_curve; }
test_move_leash_turns_with_thumb()     { run_gd test_move_mode.gd test_leash_turns_with_the_thumb; }
test_move_classic_turns_slower()       { run_gd test_move_mode.gd test_classic_turns_slower; }
test_move_leash_keeps_direction()      { run_gd test_move_mode.gd test_leash_keeps_direction_when_thumb_stops; }
test_move_menu_controls_pl()           { run_gd test_move_mode.gd test_menu_shows_controls_pl; }
test_move_menu_controls_en()           { run_gd test_move_mode.gd test_menu_shows_controls_en; }
test_move_menu_toggles()               { run_gd test_move_mode.gd test_menu_toggles; }
test_move_choice_survives_reload()     { run_gd test_move_mode.gd test_choice_survives_scene_reload; }
test_move_mode_used_in_game()          { run_gd test_move_mode.gd test_mode_used_in_game; }
