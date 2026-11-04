#!/usr/bin/env bash
# Poprawki celowania po audycie + większy promień zbierania kulek (ios-celowanie-i-zbieranie).
# (12 px → pełne celowanie: test_touch_right_stick_aims_and_fires w test_06_touch.sh;
#  pad bez wspomagania: test_tune_game_pad_aim_not_assisted w test_09_tuning.sh)

test_aimfix_small_aim_is_full_length()      { run_gd test_touch_controls.gd test_small_aim_is_full_length; }
test_aimfix_move_stick_keeps_graded_speed() { run_gd test_touch_controls.gd test_move_stick_keeps_graded_speed; }
test_aimfix_game_small_drag_turns_player()  { run_gd test_aim_assist.gd test_game_small_drag_turns_player; }
test_aimfix_game_player_turns_to_target()   { run_gd test_aim_assist.gd test_game_player_turns_to_assisted_target; }
test_aimfix_single_stick_radius()           { run_gd test_touch_controls.gd test_single_stick_radius; }
test_aimfix_knob_follows_finger()           { run_gd test_touch_controls.gd test_knob_follows_finger; }
test_aimfix_knob_respects_stick_radius()    { run_gd test_touch_controls.gd test_knob_respects_stick_radius; }

test_pickup_collect_radius_constant()       { run_gd test_pickups.gd test_collect_radius_constant; }
test_pickup_pool_uses_collect_radius()      { run_gd test_pickups.gd test_pool_pickups_use_collect_radius; }
test_pickup_collected_at_close_range()      { run_gd test_pickups.gd test_pickup_collected_at_close_range; }
test_pickup_collected_within_new_radius()   { run_gd test_pickups.gd test_pickup_collected_within_new_radius; }
test_pickup_heal_within_new_radius()        { run_gd test_pickups.gd test_heal_collected_within_new_radius; }
test_pickup_not_collected_beyond_radius()   { run_gd test_pickups.gd test_pickup_not_collected_beyond_radius; }
