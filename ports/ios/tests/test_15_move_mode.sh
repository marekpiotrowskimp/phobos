#!/usr/bin/env bash
# Sterowanie ruchem: „smycz” jest jedynym sterowaniem dotykowym; menu główne nie ma
# pozycji STEROWANIE (tryb "classic" zostaje tylko w API TouchControls).

test_move_default_mode_is_leash()      { run_gd test_move_mode.gd test_default_mode_is_leash; }
test_move_set_mode()                   { run_gd test_move_mode.gd test_set_move_mode; }
test_move_leash_speed_curve()          { run_gd test_move_mode.gd test_leash_speed_curve; }
test_move_leash_turns_with_thumb()     { run_gd test_move_mode.gd test_leash_turns_with_the_thumb; }
test_move_classic_turns_slower()       { run_gd test_move_mode.gd test_classic_turns_slower; }
test_move_leash_keeps_direction()      { run_gd test_move_mode.gd test_leash_keeps_direction_when_thumb_stops; }
test_move_menu_no_controls_pl()        { run_gd test_move_mode.gd test_menu_has_no_controls_item_pl; }
test_move_menu_no_controls_en()        { run_gd test_move_mode.gd test_menu_has_no_controls_item_en; }
test_move_menu_arrows_keep_leash()     { run_gd test_move_mode.gd test_menu_left_right_do_not_change_steering; }
test_move_reload_starts_with_leash()   { run_gd test_move_mode.gd test_reload_always_starts_with_leash; }
test_move_controls_texts_removed()     { run_gd test_move_mode.gd test_controls_texts_removed; }
test_move_mode_used_in_game()          { run_gd test_move_mode.gd test_mode_used_in_game; }
