extends Node3D

# iOS: no "quit" item — apps must not terminate themselves (App Store guidelines).
const MENU_ITEMS := ["play", "difficulty", "results", "credits"]
const TouchControlsScript := preload("res://scripts/touch/touch_controls.gd")
const SafeArea := preload("res://scripts/ui/safe_area.gd")
const AimAssist := preload("res://scripts/touch/aim_assist.gd")
const Credits := preload("res://scripts/ui/credits.gd")
## Orthographic camera height at the 16:9 design size; on narrower screens (iPad 4:3) the
## same horizontal extent is kept instead, so the whole arena always stays on screen.
const CAMERA_HEIGHT := 27.5
const DESIGN_ASPECT := 1280.0 / 720.0
## iOS: pickups are collected from a little further away (pickup.gd builds them with 0.45),
## so a thumb-steered player does not have to hit the orb dead-on.
const PICKUP_COLLECT_RADIUS := 0.9
const RESULT_FILTERS := ["all", "easy", "normal", "hard"]

var player: Player
var hud: Hud
var touch_controls: Node
var camera: Camera3D
var world_environment: Environment

var enemy_pool: Array[Enemy] = []
var tracer_pool: Array[MeshInstance3D] = []
var explosion_pool: Array[GPUParticles3D] = []
var pickup_pool: Array[Pickup] = []
var _expl_idx := 0

var state := "break"
var screen := "menu"
var wave := 0
var alive := 0
var wave_time_left := 0.0
var target_alive := 0
var spawn_group_size := 0
var spawn_timer := 0.0
var _refill_remaining := 0
var _refill_burst_timer := 0.0
var _refill_first_side := 0
var _refill_group_index := 0
var break_timer := 0.0
var shake_time := 0.0
var run_time := 0.0
var _rng := RandomNumberGenerator.new()
var _autotest := false
var _stress_test := false
var _at_t := 0.0
var _wave_warned := false
var _last_wave_second := -1
var _wave_started_at := 0.0
var _last_wave_duration := 0.0
var _completed_waves := 0
var _first_wave_peak := 0
var _first_wave_groups := 0
var _max_alive_seen := 0
var _director_violation := false
var _kills_since_heal_drop := 0
var _credits_text := ""
var _heal_drops := 0
var _overdrive_drops := 0
var _forced_heals := 0
var _balance_self_test_passed := false
var run_difficulty := "normal"
var _run_profile: Dictionary = {}
var _menu_index := 0
var _results_filter_index := 0
var _results_from_run := false
var _pending_result: Dictionary = {}
var _initials := PackedStringArray(["A", "A", "A"])
var _initials_cursor := 0
var _stress_min_fps := 9999.0
var _stress_fps_sum := 0.0
var _stress_fps_samples := 0
var _stress_window_time := 0.0
var _stress_window_frames := 0
var _stress_next_active_sample := 6.0
var _stress_full_target_samples := 0
var _stress_min_active := 9999

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_stress_test = "--stress-test" in OS.get_cmdline_user_args()
	if _stress_test and DisplayServer.get_name() == "headless":
		printerr("STRESS_TEST: requires a graphical display server")
		set_process(false)
		set_physics_process(false)
		_finish_autotest(2)
		return
	if _autotest or _stress_test:
		_rng.seed = 31337
	else:
		_rng.randomize()
	_build_arena()
	_build_camera()
	hud = Hud.new()
	add_child(hud)
	touch_controls = TouchControlsScript.new()
	touch_controls.source = self
	touch_controls.aim_assist = _touch_aim_assist
	add_child(touch_controls)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	if _autotest or _stress_test:
		player.mouse_aim = false
		player.debug_invulnerable = true
	player.fire_hit.connect(_on_fire_hit)
	player.damaged.connect(func(hp: float, mx: float):
		hud.set_hp(hp, mx)
		hud.flash_damage()
		AudioLib.duck_music(hp / mx < 0.3))
	player.healed.connect(func(hp: float, mx: float):
		hud.set_hp(hp, mx)
		AudioLib.duck_music(hp / mx < 0.3))
	player.died.connect(_on_player_died)
	player.overdrive_started.connect(_on_overdrive_started)
	player.overdrive_ended.connect(_on_overdrive_ended)
	_build_pools()
	if _autotest:
		_run_profile = GameState.get_difficulty_profile("normal")
		_balance_self_test_passed = _run_balance_self_test()
		if not _balance_self_test_passed:
			printerr("AUTOTEST: balance self-test failed")
			_finish_autotest(2)
			return
	if _autotest or _stress_test or GameState.consume_boot_mode() == "play":
		_start_run()
	else:
		_show_main_menu()

func _start_run() -> void:
	get_tree().paused = false
	GameState.reset()
	run_difficulty = "normal" if _autotest or _stress_test else GameState.run_difficulty
	_run_profile = GameState.get_difficulty_profile(run_difficulty)
	screen = "game"
	player.reset()
	wave = 0
	alive = 0
	wave_time_left = 0.0
	target_alive = 0
	_refill_remaining = 0
	_completed_waves = 0
	_last_wave_duration = 0.0
	_first_wave_peak = 0
	_first_wave_groups = 0
	_max_alive_seen = 0
	_director_violation = false
	_kills_since_heal_drop = 0
	_heal_drops = 0
	_overdrive_drops = 0
	_forced_heals = 0
	run_time = 0.0
	AudioLib.duck_music(false)
	hud.reset()
	hud.show_gameplay(_difficulty_label(run_difficulty))
	_begin_break(Balance.first_break_time)

func _begin_break(dur: float) -> void:
	state = "break"
	break_timer = dur
	_wave_warned = false
	AudioLib.set_music_intensity(0)

func _begin_wave() -> void:
	wave += 1
	state = "wave"
	wave_time_left = minf(Balance.wave_duration_base + (wave - 1) * Balance.wave_duration_per, Balance.wave_duration_cap)
	target_alive = mini(Balance.wave_target_base + (wave - 1) * Balance.wave_target_per, Balance.wave_target_cap)
	spawn_group_size = mini(Balance.spawn_group_base + int((wave - 1) / float(Balance.spawn_group_growth_waves)), Balance.spawn_group_cap)
	if _stress_test:
		wave_time_left = 60.0
		target_alive = Balance.max_enemies
		spawn_group_size = Balance.spawn_group_cap
	spawn_timer = 0.4
	_refill_remaining = 0
	_last_wave_second = ceili(wave_time_left)
	_wave_started_at = run_time
	hud.set_wave_time(wave, _last_wave_second)
	hud.show_banner("FALA %d" % wave)
	hud.add_score(GameState.score)
	if not _wave_warned:
		AudioLib.play_sfx("wave_start", 1.0, -2.0)
	AudioLib.set_music_intensity(clampi(1 + (wave - 1) / 2, 1, 2))
	AudioLib.rumble(0.3, 0.2, 0.3)

func _process(delta: float) -> void:
	if not _stress_test or _at_t < 6.0 or _at_t > 20.0:
		return
	_stress_window_time += delta
	_stress_window_frames += 1
	if _stress_window_time >= 1.0:
		var fps := float(_stress_window_frames) / _stress_window_time
		_stress_min_fps = minf(_stress_min_fps, fps)
		_stress_fps_sum += fps
		_stress_fps_samples += 1
		_stress_window_time = 0.0
		_stress_window_frames = 0

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if state != "over":
		run_time += delta
	if state == "break":
		break_timer -= delta
		if wave >= 4 and not _wave_warned and break_timer <= 3.0:
			AudioLib.play_sfx("wave_start", 1.0, -2.0)
			_wave_warned = true
		if break_timer <= 0.0:
			_begin_wave()
	elif state == "wave":
		wave_time_left = maxf(wave_time_left - delta, 0.0)
		var wave_second := ceili(wave_time_left)
		if wave_second != _last_wave_second:
			_last_wave_second = wave_second
			if wave_second > 0:
				hud.set_wave_time(wave, wave_second)
			else:
				hud.set_wave_cleanup(wave)
		if wave_time_left > 0.0:
			if _refill_remaining > 0:
				_refill_burst_timer -= delta
				if _refill_burst_timer <= 0.0:
					_spawn_refill_group()
			spawn_timer -= delta
			if _refill_remaining == 0 and alive < target_alive and spawn_timer <= 0.0:
				_start_refill()
				var interval := maxf(Balance.spawn_interval_base - (wave - 1) * Balance.spawn_interval_step, Balance.spawn_interval_min)
				spawn_timer = interval
		else:
			_refill_remaining = 0
			if alive == 0:
				_on_wave_cleared()
	if _autotest or _stress_test:
		_debug_tick(delta)
	_update_shake(delta)

func _on_wave_cleared() -> void:
	state = "cleared"
	_last_wave_duration = run_time - _wave_started_at
	_completed_waves += 1
	var bonus := wave * Balance.wave_bonus_per
	GameState.add_score(bonus)
	hud.add_score(GameState.score)
	hud.show_banner("FALA %d UDANA  +%d" % [wave, bonus])
	AudioLib.play_sfx("wave_clear")
	AudioLib.set_music_intensity(0)
	_begin_break(Balance.break_time)

func _start_refill() -> void:
	_refill_remaining = target_alive - alive
	_refill_first_side = _rng.randi_range(0, 3)
	_refill_group_index = 0
	_spawn_refill_group()

func _spawn_refill_group() -> void:
	var count := mini(spawn_group_size, _refill_remaining)
	var spawned := _spawn_group(count, (_refill_first_side + _refill_group_index) % 4)
	_refill_remaining = maxi(_refill_remaining - spawned, 0)
	_refill_group_index += 1
	_refill_burst_timer = 0.12

func _spawn_group(count: int, first_side: int) -> int:
	var spawned := 0
	for i in count:
		if _spawn_enemy((first_side + i) % 4):
			spawned += 1
	if spawned > 0:
		if wave == 1:
			_first_wave_groups += 1
	return spawned

func _spawn_enemy(side: int) -> bool:
	var e: Enemy = null
	for c in enemy_pool:
		if not c.active:
			e = c
			break
	if e == null:
		return false
	var pos := _random_edge_pos(side)
	var spd := minf(Balance.enemy_base_speed + (wave - 1) * Balance.enemy_speed_per_wave, Balance.enemy_speed_cap)
	var variant := _select_enemy_variant(_rng.randf())
	e.spawn(pos, spd, _rng.randf_range(0.0, TAU), variant["id"], variant["points"])
	alive += 1
	_max_alive_seen = maxi(_max_alive_seen, alive)
	if wave == 1:
		_first_wave_peak = maxi(_first_wave_peak, alive)
	if alive > target_alive or alive > Balance.max_enemies:
		_director_violation = true
	return true

func _random_edge_pos(forced_side := -1) -> Vector3:
	var inset := 1.1
	var xr := Balance.ARENA_HALF.x - inset
	var yr := Balance.ARENA_HALF.y - inset
	var best_pos := Vector3.ZERO
	var best_dist := -1.0
	for i in 8:
		var side: int = forced_side if forced_side >= 0 else _rng.randi_range(0, 3)
		var pos := Vector3.ZERO
		match side:
			0:
				pos = Vector3(-xr, 0, _rng.randf_range(-yr, yr))
			1:
				pos = Vector3(xr, 0, _rng.randf_range(-yr, yr))
			2:
				pos = Vector3(_rng.randf_range(-xr, xr), 0, -yr)
			3:
				pos = Vector3(_rng.randf_range(-xr, xr), 0, yr)
		var dist := pos.distance_to(player.global_position)
		if dist >= Balance.min_spawn_dist:
			return pos
		if dist > best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos

func _on_fire_hit(from: Vector3, to: Vector3, collider: Object, damage: float) -> void:
	_spawn_tracer(from, to)
	shake_time = maxf(shake_time, 0.025)
	if collider is Enemy:
		var e := collider as Enemy
		if e.active:
			AudioLib.play_sfx("hit", randf_range(0.9, 1.1), -7.0)
			e.damage(damage)
	elif collider is Area3D and collider.get_parent() is Enemy:
		var e := collider.get_parent() as Enemy
		if e.active:
			AudioLib.play_sfx("hit", randf_range(0.9, 1.1), -7.0)
			e.damage(damage)

func _on_enemy_died(e: Enemy, by_contact: bool) -> void:
	alive = maxi(alive - 1, 0)
	if state == "wave" and wave_time_left > 0.0 and alive < target_alive:
		if _refill_remaining > 0:
			_refill_remaining = target_alive - alive
		else:
			spawn_timer = minf(spawn_timer, 0.12)
	_spawn_explosion(e.global_position)
	if by_contact:
		AudioLib.play_sfx("enemy_die", 0.8, -6.0)
		return
	var pts := wave * e.point_value
	GameState.add_score(pts)
	GameState.add_kill()
	_kills_since_heal_drop += 1
	hud.add_score(GameState.score)
	hud.add_kills(GameState.kills)
	AudioLib.play_sfx("enemy_die", randf_range(0.85, 1.15), -2.0)
	AudioLib.rumble(0.1, 0.05, 0.05)
	shake_time = maxf(shake_time, 0.12)
	_try_drop(e.global_position)

func _try_drop(pos: Vector3) -> void:
	var kind := ""
	var forced_heal := _should_force_heal(player.hp, _kills_since_heal_drop)
	if forced_heal:
		kind = "heal"
	else:
		kind = _select_drop_kind(_rng.randf())
	if kind == "":
		return
	var p: Pickup = null
	for c in pickup_pool:
		if not c.visible:
			p = c
			break
	if p == null:
		return
	p.setup(kind, pos)
	if kind == "heal":
		_kills_since_heal_drop = 0
		_heal_drops += 1
		if forced_heal:
			_forced_heals += 1
	else:
		_overdrive_drops += 1

func _select_enemy_variant(roll: float) -> Dictionary:
	if roll < Balance.red_spawn_chance:
		return {"id": "red", "points": Balance.kill_points}
	if roll < Balance.red_spawn_chance + Balance.amber_spawn_chance:
		return {"id": "amber", "points": Balance.amber_kill_points}
	return {"id": "violet", "points": Balance.violet_kill_points}

func _drop_distributions_valid() -> bool:
	for index in GameState.DIFFICULTY_IDS.size():
		var profile := GameState.get_difficulty_profile(GameState.DIFFICULTY_IDS[index])
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = 8505 + index
		var heal_count := 0
		var overdrive_count := 0
		for i in 10000:
			match _select_drop_kind(sample_rng.randf(), profile):
				"heal":
					heal_count += 1
				"overdrive":
					overdrive_count += 1
		if absf(float(heal_count) / 10000.0 - float(profile["heal_chance"])) >= 0.01:
			return false
		if absf(float(overdrive_count) / 10000.0 - float(profile["overdrive_chance"])) >= 0.01:
			return false
		var pity_kills := int(profile["heal_pity_kills"])
		if not _should_force_heal(Balance.heal_pity_hp, pity_kills, profile):
			return false
		if _should_force_heal(Balance.heal_pity_hp, pity_kills - 1, profile):
			return false
	return true

func _enemy_variants_valid() -> bool:
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 9505
	var counts := {"red": 0, "amber": 0, "violet": 0}
	for i in 10000:
		var variant := _select_enemy_variant(sample_rng.randf())
		counts[variant["id"]] += 1
	if absf(float(counts["red"]) / 10000.0 - Balance.red_spawn_chance) >= 0.01:
		return false
	if absf(float(counts["amber"]) / 10000.0 - Balance.amber_spawn_chance) >= 0.01:
		return false
	if absf(float(counts["violet"]) / 10000.0 - Balance.violet_spawn_chance) >= 0.01:
		return false
	return (
		_select_enemy_variant(0.0)["points"] == Balance.kill_points
		and _select_enemy_variant(Balance.red_spawn_chance)["points"] == Balance.amber_kill_points
		and _select_enemy_variant(Balance.red_spawn_chance + Balance.amber_spawn_chance)["points"] == Balance.violet_kill_points
	)

func _should_force_heal(hp: float, kills_without_heal: int, profile: Dictionary = {}) -> bool:
	var selected := _run_profile if profile.is_empty() else profile
	return hp <= Balance.heal_pity_hp and kills_without_heal >= int(selected.get("heal_pity_kills", Balance.heal_pity_kills))

func _select_drop_kind(roll: float, profile: Dictionary = {}) -> String:
	var selected := _run_profile if profile.is_empty() else profile
	var overdrive_chance := float(selected.get("overdrive_chance", Balance.overdrive_chance))
	var heal_chance := float(selected.get("heal_chance", Balance.heal_chance))
	if roll < overdrive_chance:
		return "overdrive"
	if roll < overdrive_chance + heal_chance:
		return "heal"
	return ""

func _run_balance_self_test() -> bool:
	var test_player := Player.new()
	test_player.process_mode = Node.PROCESS_MODE_DISABLED
	test_player.mouse_aim = false
	add_child(test_player)
	var death_state := [false]
	test_player.died.connect(func(): death_state[0] = true)
	var first_hit := test_player.damage(Balance.contact_damage)
	var first_hp_valid := is_equal_approx(test_player.hp, Balance.player_max_hp - Balance.contact_damage)
	var iframe_valid := not test_player.damage(Balance.contact_damage) and is_equal_approx(test_player.hp, Balance.player_max_hp - Balance.contact_damage)
	test_player._advance_invulnerability(Balance.invuln_time - 0.01)
	var iframe_duration_valid := not test_player.damage(Balance.contact_damage)
	test_player._advance_invulnerability(0.02)
	var expiry_valid := test_player.damage(Balance.contact_damage) and is_equal_approx(test_player.hp, Balance.player_max_hp - Balance.contact_damage * 2.0)
	for i in 4:
		test_player._advance_invulnerability(Balance.invuln_time + 0.01)
		test_player.damage(Balance.contact_damage)
	test_player._invuln = 0.0
	var death_valid: bool = is_zero_approx(test_player.hp) and test_player.is_dead() and bool(death_state[0]) and not test_player.damage(Balance.contact_damage)
	test_player.free()

	var normal_profile := GameState.get_difficulty_profile("normal")
	var drop_distributions_valid := _drop_distributions_valid()
	var enemy_variants_valid := _enemy_variants_valid()

	player.hp = Balance.heal_pity_hp
	_kills_since_heal_drop = int(normal_profile["heal_pity_kills"])
	var heal_before := _heal_drops
	var forced_before := _forced_heals
	_try_drop(Vector3.ZERO)
	var pity_spawn_valid := _heal_drops == heal_before + 1 and _forced_heals == forced_before + 1 and _kills_since_heal_drop == 0
	for pickup in pickup_pool:
		pickup.hide_pickup()
		pickup.setup("overdrive", Vector3.ZERO)
	_kills_since_heal_drop = int(normal_profile["heal_pity_kills"])
	heal_before = _heal_drops
	forced_before = _forced_heals
	_try_drop(Vector3.ZERO)
	var full_pool_valid := _heal_drops == heal_before and _forced_heals == forced_before and _kills_since_heal_drop == int(normal_profile["heal_pity_kills"])
	for pickup in pickup_pool:
		pickup.hide_pickup()
	return first_hit and first_hp_valid and iframe_valid and iframe_duration_valid and expiry_valid and death_valid and drop_distributions_valid and enemy_variants_valid and pity_spawn_valid and full_pool_valid and GameState.run_self_test()

func _on_pickup_collected(p: Pickup) -> void:
	if state == "over":
		return
	if p.kind == "heal":
		player.heal(Balance.heal_amount)
		AudioLib.play_sfx("pickup_heal", 1.0, -2.0)
	else:
		player.start_overdrive(Balance.overdrive_duration)
		hud.start_od_bar(Balance.overdrive_duration)

func _on_overdrive_started(duration: float) -> void:
	AudioLib.set_music_intensity(3)
	world_environment.glow_intensity = 1.2
	world_environment.ambient_light_color = Color(0.16, 0.25, 0.4)
	AudioLib.rumble(0.35, 0.5, 0.4)
	AudioLib.play_sfx("pickup_overdrive", 1.0, -2.0)

func _on_overdrive_ended() -> void:
	AudioLib.play_sfx("overdrive_off", 1.0, -4.0)
	hud.end_od_bar()
	world_environment.glow_intensity = 0.85
	world_environment.ambient_light_color = Color(0.12, 0.14, 0.2)
	if state == "wave":
		AudioLib.set_music_intensity(clampi(1 + (wave - 1) / 2, 1, 2))
	else:
		AudioLib.set_music_intensity(0)

func _on_player_died() -> void:
	state = "over"
	world_environment.glow_intensity = 0.85
	world_environment.ambient_light_color = Color(0.12, 0.14, 0.2)
	for e in enemy_pool:
		if e.active:
			e.velocity = Vector3.ZERO
			e.set_physics_process(false)
	for p in pickup_pool:
		p.hide_pickup()
	AudioLib.play_sfx("game_over")
	AudioLib.set_music_intensity(0)
	AudioLib.rumble(0.6, 0.9, 0.5)
	shake_time = 0.5
	_pending_result = {
		"score": GameState.score,
		"wave": wave,
		"kills": GameState.kills,
		"time": run_time,
		"difficulty": run_difficulty,
		"difficulty_label": _difficulty_label(run_difficulty),
	}
	get_tree().paused = true
	if GameState.qualifies(GameState.score, run_difficulty, wave, GameState.kills, run_time):
		_show_initials()
	else:
		_show_results(true)

## Touch aim assist: bends the stick direction (arena x/z) towards the nearest-in-angle enemy.
func _widen_pickup(pickup: Pickup) -> void:
	for child in pickup.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is SphereShape3D:
			((child as CollisionShape3D).shape as SphereShape3D).radius = PICKUP_COLLECT_RADIUS


func _touch_aim_assist(dir: Vector2) -> Vector2:
	var targets: Array = []
	for enemy in enemy_pool:
		if enemy.active:
			targets.append(Vector2(enemy.global_position.x, enemy.global_position.z))
	var origin := Vector2(player.global_position.x, player.global_position.z)
	return AimAssist.pick(origin, dir, targets, TouchControlsScript.AIM_ASSIST_DEG)

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED:
		return
	# iOS: the app went to the background — drop held touches and pause a running round.
	if touch_controls != null:
		touch_controls.release_all()
	if screen == "game" and state != "over" and not get_tree().paused:
		get_tree().paused = true
		hud.toggle_pause(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		return
	if event is InputEventKey and event.echo:
		return
	match screen:
		"menu":
			_handle_menu_input(event)
		"initials":
			_handle_initials_input(event)
		"results":
			_handle_results_input(event)
		"credits":
			_handle_credits_input(event)
		"game":
			if event.is_action_pressed("pause") and state != "over":
				get_tree().paused = not get_tree().paused
				hud.toggle_pause(get_tree().paused)

func _show_main_menu() -> void:
	screen = "menu"
	state = "over"
	_menu_index = clampi(_menu_index, 0, MENU_ITEMS.size() - 1)
	get_tree().paused = true
	hud.show_main_menu(_menu_index, _difficulty_label(GameState.selected_difficulty))

func _handle_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_up"):
		_menu_index = posmod(_menu_index - 1, MENU_ITEMS.size())
	elif event.is_action_pressed("menu_down"):
		_menu_index = posmod(_menu_index + 1, MENU_ITEMS.size())
	elif event.is_action_pressed("menu_left") and MENU_ITEMS[_menu_index] == "difficulty":
		_cycle_difficulty(-1)
	elif event.is_action_pressed("menu_right") and MENU_ITEMS[_menu_index] == "difficulty":
		_cycle_difficulty(1)
	elif event.is_action_pressed("menu_confirm"):
		match MENU_ITEMS[_menu_index]:
			"play":
				_start_run()
			"difficulty":
				_cycle_difficulty(1)
			"results":
				_results_filter_index = 0
				_show_results(false)
			"credits":
				_show_credits()
		return
	hud.show_main_menu(_menu_index, _difficulty_label(GameState.selected_difficulty))

func _cycle_difficulty(direction: int) -> void:
	var index := GameState.DIFFICULTY_IDS.find(GameState.selected_difficulty)
	var difficulty: String = GameState.DIFFICULTY_IDS[posmod(index + direction, GameState.DIFFICULTY_IDS.size())]
	GameState.set_selected_difficulty(difficulty)

func _show_initials() -> void:
	screen = "initials"
	_initials_cursor = 0
	var remembered: String = GameState.last_initials
	_initials = PackedStringArray([remembered.substr(0, 1), remembered.substr(1, 1), remembered.substr(2, 1)])
	hud.show_initials(_initials, _initials_cursor, _pending_result, _difficulty_label(run_difficulty))

func _handle_initials_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		var code := int(key.physical_keycode)
		if code >= KEY_A and code <= KEY_Z:
			_initials[_initials_cursor] = String.chr(code)
			_initials_cursor = mini(_initials_cursor + 1, 2)
			_refresh_initials()
			return
	if event.is_action_pressed("menu_left"):
		_initials_cursor = posmod(_initials_cursor - 1, 3)
	elif event.is_action_pressed("menu_right"):
		_initials_cursor = posmod(_initials_cursor + 1, 3)
	elif event.is_action_pressed("menu_up"):
		_shift_initial(1)
	elif event.is_action_pressed("menu_down"):
		_shift_initial(-1)
	elif event.is_action_pressed("menu_confirm"):
		if _initials_cursor < 2:
			_initials_cursor += 1
		else:
			_submit_result()
			return
	else:
		return
	_refresh_initials()

func _shift_initial(direction: int) -> void:
	var code := _initials[_initials_cursor].unicode_at(0)
	_initials[_initials_cursor] = String.chr(65 + posmod(code - 65 + direction, 26))

func _refresh_initials() -> void:
	hud.show_initials(_initials, _initials_cursor, _pending_result, _difficulty_label(run_difficulty))

func _submit_result() -> void:
	GameState.submit_score(
		"".join(_initials), int(_pending_result["score"]), int(_pending_result["wave"]),
		int(_pending_result["kills"]), float(_pending_result["time"]), str(_pending_result["difficulty"])
	)
	_results_filter_index = RESULT_FILTERS.find(run_difficulty)
	_show_results(true)

func _show_results(from_run: bool) -> void:
	screen = "results"
	_results_from_run = from_run
	get_tree().paused = true
	var filter: String = RESULT_FILTERS[_results_filter_index]
	var entries := GameState.get_leaderboard(filter)
	for entry in entries:
		entry["difficulty_label"] = _difficulty_label(str(entry["difficulty"]))
	var summary: Dictionary = _pending_result if from_run else {}
	hud.show_results(entries, _difficulty_label(filter), summary, from_run)

func _handle_results_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_left"):
		_results_filter_index = posmod(_results_filter_index - 1, RESULT_FILTERS.size())
		_show_results(_results_from_run)
	elif event.is_action_pressed("menu_right"):
		_results_filter_index = posmod(_results_filter_index + 1, RESULT_FILTERS.size())
		_show_results(_results_from_run)
	elif event.is_action_pressed("menu_confirm"):
		if _results_from_run:
			_reload_to("play")
		else:
			_show_main_menu()
	elif event.is_action_pressed("menu_back"):
		if _results_from_run:
			_reload_to("menu")
		else:
			_show_main_menu()

func _show_credits() -> void:
	screen = "credits"
	get_tree().paused = true
	if _credits_text.is_empty():
		_credits_text = Credits.text()  # built once: reads the licence files, ~90 KB
	hud.show_credits(_credits_text)

func _handle_credits_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_up"):
		hud.scroll_credits(-1)
	elif event.is_action_pressed("menu_down"):
		hud.scroll_credits(1)
	elif event.is_action_pressed("menu_confirm") or event.is_action_pressed("menu_back"):
		_show_main_menu()

func _reload_to(mode: String) -> void:
	GameState.request_boot_mode(mode)
	get_tree().paused = false
	get_tree().reload_current_scene()

func _difficulty_label(difficulty: String) -> String:
	if difficulty == GameState.ALL_DIFFICULTIES:
		return "WSZYSTKIE"
	return str(GameState.DIFFICULTY_LABELS.get(difficulty, difficulty.to_upper()))

func _debug_tick(delta: float) -> void:
	_at_t += delta
	if _stress_test:
		_stress_tick()
		_debug_control()
		return
	if state == "over":
		print("AUTOTEST: died at wave %d, score %d, kills %d after %.1fs" % [wave, GameState.score, GameState.kills, _at_t])
		_finish_autotest(1)
		return
	if _at_t > 50.0:
		var active_count := 0
		for enemy in enemy_pool:
			if enemy.active:
				active_count += 1
		var expected_first_groups := ceili(float(Balance.wave_target_base) / float(Balance.spawn_group_base))
		var duration_valid := _last_wave_duration >= Balance.wave_duration_base - 0.2 and _last_wave_duration <= Balance.wave_duration_base + 5.0
		var runtime_drop_valid := _heal_drops > 0 and _overdrive_drops > 0 and _heal_drops + _overdrive_drops <= GameState.kills
		var pity_logic_valid := _should_force_heal(Balance.heal_pity_hp, Balance.heal_pity_kills) and not _should_force_heal(Balance.heal_pity_hp + 1.0, Balance.heal_pity_kills) and not _should_force_heal(Balance.heal_pity_hp, Balance.heal_pity_kills - 1)
		if wave < 2 or _completed_waves < 1 or not duration_valid or _first_wave_peak != Balance.wave_target_base or _first_wave_groups < expected_first_groups or _director_violation or not _balance_self_test_passed or not runtime_drop_valid or not pity_logic_valid or GameState.kills == 0 or alive != active_count or alive > target_alive:
			print("AUTOTEST: invalid balance at 50s, wave %d, completed %d, duration %.1f, peak %d, groups %d, max %d, alive %d/%d, target %d, kills %d, drops %d/%d, pity %d" % [wave, _completed_waves, _last_wave_duration, _first_wave_peak, _first_wave_groups, _max_alive_seen, alive, active_count, target_alive, GameState.kills, _heal_drops, _overdrive_drops, _forced_heals])
			_finish_autotest(2)
			return
		print("AUTOTEST: balance passed 50s, wave %d, duration %.1f, peak %d, max %d, alive %d/%d, score %d, kills %d, heal %d, overdrive %d, pity %d" % [wave, _last_wave_duration, _first_wave_peak, _max_alive_seen, alive, target_alive, GameState.score, GameState.kills, _heal_drops, _overdrive_drops, _forced_heals])
		_finish_autotest(0)
		return
	_debug_control()

func _stress_tick() -> void:
	if _at_t >= _stress_next_active_sample:
		if alive == Balance.max_enemies:
			_stress_full_target_samples += 1
		if _at_t >= 8.0:
			_stress_min_active = mini(_stress_min_active, alive)
		_stress_next_active_sample += 0.5
	if _at_t <= 20.0:
		return
	var active_count := 0
	for enemy in enemy_pool:
		if enemy.active:
			active_count += 1
	var average_fps := _stress_fps_sum / maxi(_stress_fps_samples, 1)
	var active_floor := Balance.max_enemies - Balance.spawn_group_cap * 2
	var valid := _stress_fps_samples >= 10 and _stress_min_fps >= 60.0 and _max_alive_seen == Balance.max_enemies and _stress_full_target_samples >= 3 and _stress_min_active >= active_floor and alive == active_count and alive <= Balance.max_enemies and not _director_violation
	print("STRESS_TEST: %s, min FPS %.1f, avg FPS %.1f, peak %d, full samples %d, min active %d, alive %d/%d, kills %d" % ["PASS" if valid else "FAIL", _stress_min_fps, average_fps, _max_alive_seen, _stress_full_target_samples, _stress_min_active, alive, active_count, GameState.kills])
	_finish_autotest(0 if valid else 2)

func _debug_control() -> void:
	var phase := int(_at_t / 3.0) % 4
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	match phase:
		0:
			Input.action_press("move_right")
		1:
			Input.action_press("move_up")
		2:
			Input.action_press("move_left")
		3:
			Input.action_press("move_down")
	var target: Enemy = null
	for e in enemy_pool:
		if e.active:
			target = e
			break
	if target and (not _stress_test or _at_t >= 8.0):
		player.debug_aim_at(target.global_position)
		Input.action_press("shoot")
	else:
		Input.action_release("shoot")

func _finish_autotest(exit_code: int) -> void:
	get_tree().quit(exit_code)

func _build_pools() -> void:
	for i in Balance.max_enemies:
		var e := Enemy.new()
		e.player = player
		e.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(e)
		e.died.connect(_on_enemy_died)
		e.visible = false
		e.set_physics_process(false)
		e.set_collision_layer_value(2, false)
		enemy_pool.append(e)
	for i in Balance.pickup_count:
		var pickup := Pickup.new()
		pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(pickup)
		pickup.collected.connect(_on_pickup_collected)
		_widen_pickup(pickup)
		pickup.hide_pickup()
		pickup_pool.append(pickup)
	_build_tracer_pool(Balance.tracer_count)
	for i in Balance.explosion_count:
		var p := _make_explosion()
		add_child(p)
		explosion_pool.append(p)

func _build_tracer_pool(n: int) -> void:
	for i in n:
		var root := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 1.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.4, 0.95, 1.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 1.0)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		cyl.material = mat
		root.mesh = cyl
		root.rotation.x = -PI / 2.0
		root.visible = false
		add_child(root)
		tracer_pool.append(root)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tr: MeshInstance3D = null
	for t in tracer_pool:
		if not t.visible:
			tr = t
			break
	if tr == null:
		return
	var dir := to - from
	var len := dir.length()
	if len <= 0.001:
		return
	tr.mesh.height = len
	tr.global_position = from + dir * 0.5
	tr.quaternion = Quaternion(Vector3.UP, dir / len)
	tr.visible = true
	var mat := tr.mesh.material as StandardMaterial3D
	mat.albedo_color.a = 1.0
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(func(): tr.visible = false)

func _make_explosion() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.3
	pm.color = Color(1, 0.35, 0.1, 1)
	p.process_material = pm
	p.one_shot = true
	p.emitting = false
	p.lifetime = 0.6
	p.amount = 24
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.3, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0.1)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	p.draw_pass_1 = m
	return p

func _spawn_explosion(pos: Vector3) -> void:
	var p := explosion_pool[_expl_idx]
	_expl_idx = (_expl_idx + 1) % explosion_pool.size()
	p.global_position = pos + Vector3(0, 0.5, 0)
	p.restart()
	p.emitting = true

func _update_shake(delta: float) -> void:
	shake_time = maxf(shake_time - delta, 0.0)
	var k := shake_time * 2.0
	camera.position.x = _rng.randf_range(-1.0, 1.0) * k
	camera.position.y = 34.0
	camera.position.z = _rng.randf_range(-1.0, 1.0) * k

func _fit_camera() -> void:
	var visible := get_viewport().get_visible_rect().size
	if visible.y <= 0.0 or visible.x / visible.y >= DESIGN_ASPECT:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = CAMERA_HEIGHT
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = CAMERA_HEIGHT * DESIGN_ASPECT

func _on_viewport_resized() -> void:
	_fit_camera()
	apply_safe_area(_device_safe_area(), DisplayServer.window_get_size())

func _device_safe_area() -> Rect2i:
	return SafeArea.effective(DisplayServer.get_display_safe_area(), OS.has_feature("ios"))

## Lays HUD and touch controls out inside the device safe area (notch, home indicator).
func apply_safe_area(safe_rect: Rect2i, window_size: Vector2i) -> void:
	var margins := SafeArea.margins(safe_rect, window_size, get_viewport().get_visible_rect().size)
	hud.apply_safe_margins(margins)
	touch_controls.set_safe_margins(margins)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_HEIGHT
	camera.position = Vector3(0, 34, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.near = 1.0
	camera.far = 120.0
	add_child(camera)
	camera.current = true

func _build_arena() -> void:
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Balance.ARENA_HALF.x * 2.0, Balance.ARENA_HALF.y * 2.0)
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://shaders/floor.gdshader")
	fmat.set_shader_parameter("floor_texture", load("res://assets/sprites/arena/arena_floor.svg"))
	pm.material = fmat
	floor.mesh = pm
	add_child(floor)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.05, 0.08, 0.15)
	wall_mat.emission_enabled = true
	wall_mat.emission = Color(0.05, 0.15, 0.3)
	wall_mat.emission_energy_multiplier = 0.8
	var hw := Balance.ARENA_HALF.x
	var hh := Balance.ARENA_HALF.y
	var walls := [
		[Vector3(0, 1.0, -hh), Vector3(hw * 2.0, 2.0, 1.0)],
		[Vector3(0, 1.0, hh), Vector3(hw * 2.0, 2.0, 1.0)],
		[Vector3(-hw, 1.0, 0), Vector3(1.0, 2.0, hh * 2.0)],
		[Vector3(hw, 1.0, 0), Vector3(1.0, 2.0, hh * 2.0)],
	]
	for w in walls:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = w[1]
		bm.material = wall_mat
		box.mesh = bm
		box.position = w[0]
		add_child(box)
		var col := StaticBody3D.new()
		col.collision_layer = Balance.WALL_LAYER
		col.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		cs.shape = bs
		col.add_child(cs)
		col.position = w[0]
		add_child(col)

	var env := WorldEnvironment.new()
	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color(0.015, 0.015, 0.035)
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color(0.12, 0.14, 0.2)
	world_environment.ambient_light_energy = 0.6
	world_environment.glow_enabled = true
	world_environment.glow_intensity = 0.85
	world_environment.glow_bloom = 0.05
	world_environment.glow_hdr_threshold = 1.0
	env.environment = world_environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.35
	sun.light_color = Color(0.6, 0.7, 1.0)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

	var corner_colors := [Color(1.0, 0.15, 0.2), Color(0.2, 0.4, 1.0), Color(1.0, 0.6, 0.1), Color(0.4, 1.0, 0.5)]
	var corner_pos := [Vector3(-hw, 3, -hh), Vector3(hw, 3, -hh), Vector3(-hw, 3, hh), Vector3(hw, 3, hh)]
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = corner_colors[i]
		l.light_energy = 0.9
		l.omni_range = 14.0
		l.position = corner_pos[i]
		add_child(l)
