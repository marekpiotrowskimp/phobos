#!/usr/bin/env bash
# Etap 02 — sterowanie dotykowe. Each function runs one GDScript test (tests/gd/*.gd) headless.

# VirtualStick (AC-1) — response curve and origin following: test_09_tuning.sh
test_stick_press_in_zone_activates()        { run_gd test_virtual_stick.gd test_press_in_zone_activates; }
test_stick_press_outside_zone_ignored()     { run_gd test_virtual_stick.gd test_press_outside_zone_ignored; }
test_stick_second_finger_ignored()          { run_gd test_virtual_stick.gd test_second_finger_ignored; }
test_stick_release_resets()                 { run_gd test_virtual_stick.gd test_release_resets; }

# TouchControls standalone (AC-2 … AC-6)
test_touch_layout_buttons_size_and_bounds() { run_gd test_touch_controls.gd test_layout_buttons_size_and_bounds; }
test_touch_left_stick_moves()               { run_gd test_touch_controls.gd test_left_stick_moves; }
test_touch_right_stick_aims_and_fires()     { run_gd test_touch_controls.gd test_right_stick_aims_and_fires; }
test_touch_two_sticks_independent()         { run_gd test_touch_controls.gd test_two_sticks_independent; }
test_touch_sticks_inactive_outside_gameplay() { run_gd test_touch_controls.gd test_sticks_inactive_outside_gameplay; }
test_touch_pause_button_does_not_start_stick() { run_gd test_touch_controls.gd test_pause_button_does_not_start_stick; }
test_touch_overlay_hides_on_gamepad()       { run_gd test_touch_controls.gd test_overlay_hides_on_gamepad_and_returns_on_touch; }
test_touch_release_all()                    { run_gd test_touch_controls.gd test_release_all; }
test_touch_pausing_releases_sticks()        { run_gd test_touch_controls.gd test_pausing_releases_sticks; }

# Main scene — characterization (green before implementation)
test_main_input_actions_unchanged()         { run_gd test_main_touch.gd test_input_actions_unchanged; }
test_main_menu_navigation_by_actions()      { run_gd test_main_touch.gd test_menu_navigation_by_actions; }
test_main_pause_action_toggles()            { run_gd test_main_touch.gd test_pause_action_toggles; }

# Main scene — new behaviour (AC-7 … AC-11)
test_main_mouse_emulation_disabled()        { run_gd test_main_touch.gd test_mouse_emulation_from_touch_disabled; }
test_main_menu_has_no_quit()                { run_gd test_main_touch.gd test_menu_has_no_quit; }
test_main_owns_touch_controls()             { run_gd test_main_touch.gd test_main_owns_touch_controls; }
test_main_menu_navigation_by_touch()        { run_gd test_main_touch.gd test_menu_navigation_by_touch; }
test_main_pause_button_toggles_pause()      { run_gd test_main_touch.gd test_pause_button_toggles_pause; }
test_main_mute_button_only_in_pause()       { run_gd test_main_touch.gd test_mute_button_only_in_pause; }
test_main_initials_by_touch()               { run_gd test_main_touch.gd test_initials_by_touch; }
test_main_auto_pause_on_background()        { run_gd test_main_touch.gd test_auto_pause_when_app_goes_to_background; }
test_main_background_in_menu_changes_nothing() { run_gd test_main_touch.gd test_background_in_menu_changes_nothing; }
test_main_background_releases_touch()       { run_gd test_main_touch.gd test_background_releases_touch; }
