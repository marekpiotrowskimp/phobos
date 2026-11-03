extends Node

const ARENA_HALF := Vector2(20.0, 12.0)
const WALL_LAYER := 1
const ENEMY_LAYER := 2
const PLAYER_LAYER := 4

const player_max_hp := 100.0
const player_speed := 11.0
const player_accel := 12.0
const fire_rate := 9.0
const contact_damage := 18.0
const invuln_time := 0.55

const enemy_base_speed := 4.8
const enemy_speed_per_wave := 0.23
const enemy_speed_cap := 8.0
const enemy_hp := 25.0
const weapon_damage := 25.0
const enemy_contact_range := 1.15

const wave_duration_base := 35.0
const wave_duration_per := 5.0
const wave_duration_cap := 65.0
const wave_target_base := 8
const wave_target_per := 3
const wave_target_cap := 45
const spawn_group_base := 2
const spawn_group_growth_waves := 3
const spawn_group_cap := 5
const spawn_interval_base := 0.85
const spawn_interval_step := 0.04
const spawn_interval_min := 0.3
const break_time := 5.0
const first_break_time := 2.5
const min_spawn_dist := 9.0
const max_enemies := 60

const overdrive_duration := 15.0
const overdrive_dmg_mult := 2.0
const overdrive_rate_mult := 1.5
const heal_amount := 30.0
const heal_chance := 0.08
const overdrive_chance := 0.05
const heal_pity_hp := 50.0
const heal_pity_kills := 10
const pickup_lifetime := 8.0
const pickup_count := 20

const kill_points := 10
const amber_kill_points := 25
const violet_kill_points := 50
const red_spawn_chance := 0.70
const amber_spawn_chance := 0.22
const violet_spawn_chance := 0.08
const wave_bonus_per := 50

const tracer_count := 40
const explosion_count := 14
