#!/usr/bin/env bash
# Strojenie sterowania dotykowego: krzywa drążka i wspomaganie celowania.
# (Pozostałe testy drążków są w test_06_touch.sh — zaktualizowane do nowej krzywej.)

test_tune_stick_defaults()             { run_gd test_virtual_stick.gd test_defaults; }
test_tune_stick_dead_zone()            { run_gd test_virtual_stick.gd test_dead_zone; }
test_tune_stick_response_curve()       { run_gd test_virtual_stick.gd test_response_curve; }
test_tune_stick_origin_follows_finger() { run_gd test_virtual_stick.gd test_origin_follows_finger; }

test_tune_pick_without_targets()       { run_gd test_aim_assist.gd test_pick_without_targets_keeps_direction; }
test_tune_pick_snaps_within_cone()     { run_gd test_aim_assist.gd test_pick_snaps_within_cone; }
test_tune_pick_ignores_outside_cone()  { run_gd test_aim_assist.gd test_pick_ignores_target_outside_cone; }
test_tune_pick_prefers_smallest_angle() { run_gd test_aim_assist.gd test_pick_prefers_smallest_angle; }
test_tune_pick_relative_to_origin()    { run_gd test_aim_assist.gd test_pick_relative_to_origin; }
test_tune_pick_zero_direction()        { run_gd test_aim_assist.gd test_pick_zero_direction; }
test_tune_assist_cone_constant()       { run_gd test_aim_assist.gd test_assist_cone_constant; }

test_tune_game_aim_snaps_to_enemy()    { run_gd test_aim_assist.gd test_game_aim_snaps_to_enemy; }
test_tune_game_aim_free_outside_cone() { run_gd test_aim_assist.gd test_game_aim_free_when_enemy_outside_cone; }
test_tune_game_aim_tracks_moving_enemy() { run_gd test_aim_assist.gd test_game_aim_tracks_moving_enemy; }
test_tune_game_pad_aim_not_assisted()  { run_gd test_aim_assist.gd test_game_pad_aim_not_assisted; }
