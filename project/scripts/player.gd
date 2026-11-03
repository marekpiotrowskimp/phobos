class_name Player
extends CharacterBody3D

signal fire_hit(from: Vector3, to: Vector3, collider: Object, damage: float)
signal damaged(hp: float, max_hp: float)
signal healed(hp: float, max_hp: float)
signal died
signal overdrive_started(duration: float)
signal overdrive_ended

var hp := Balance.player_max_hp
var _aim_dir := Vector3(0, 0, -1)
var _fire_timer := 0.0
var _invuln := 0.0
var _dead := false
var _overdrive := false
var _od_left := 0.0
var _blink := 0.0

var _mesh: AnimatedSprite3D
var _shadow: Sprite3D
var _body_glow: OmniLight3D
var _muzzle_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var mouse_aim := true
var debug_invulnerable := false
var _last_aim_mouse := true

func _ready() -> void:
	collision_layer = Balance.PLAYER_LAYER
	collision_mask = Balance.WALL_LAYER
	_build_body()

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)

	_shadow = Sprite3D.new()
	_shadow.texture = load("res://assets/sprites/effects/soft_shadow.svg")
	_shadow.pixel_size = 0.008
	_shadow.position.y = 0.025
	_shadow.rotation.x = -PI / 2.0
	add_child(_shadow)

	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8.0)
	frames.set_animation_loop("default", true)
	for i in 4:
		var texture := load("res://assets/sprites/player/player_move_%d.png" % (i + 1)) as Texture2D
		frames.add_frame("default", texture)
	_mesh = AnimatedSprite3D.new()
	_mesh.sprite_frames = frames
	_mesh.animation = "default"
	_mesh.pixel_size = 0.0062
	_mesh.position.y = 0.08
	_mesh.rotation.x = -PI / 2.0
	_mesh.shaded = true
	_mesh.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_mesh.play()
	add_child(_mesh)

	_body_glow = OmniLight3D.new()
	_body_glow.light_color = Color(0.25, 0.85, 1.0)
	_body_glow.light_energy = 1.1
	_body_glow.omni_range = 7.0
	_body_glow.position.y = 1.8
	add_child(_body_glow)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.8, 0.45)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 5.0
	_muzzle_light.position = Vector3(0, 1.1, -1.0)
	add_child(_muzzle_light)

	_flash_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 0.85, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(1, 0.8, 0.4)
	fm.emission_energy_multiplier = 6.0
	sm.material = fm
	_flash_mesh.mesh = sm
	_flash_mesh.visible = false
	_flash_mesh.position = Vector3(0, 1.1, -1.0)
	add_child(_flash_mesh)

func reset() -> void:
	hp = Balance.player_max_hp
	_dead = false
	_invuln = 0.0
	_fire_timer = 0.0
	_blink = 0.0
	_overdrive = false
	_od_left = 0.0
	global_position = Vector3.ZERO
	rotation.y = 0.0
	_aim_dir = Vector3(0, 0, -1)
	visible = true
	_mesh.visible = true
	_mesh.modulate = Color.WHITE
	_mesh.frame = 0
	_body_glow.light_energy = 1.1
	set_collision_layer_value(3, true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_aim_mouse = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] and absf(motion.axis_value) > 0.35:
			_last_aim_mouse = false

func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector3.ZERO
		return
	_fire_timer -= delta
	_advance_invulnerability(delta)
	if _overdrive:
		_od_left -= delta
		if _od_left <= 0.0:
			_set_overdrive(false)

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.28)
	var dir := Vector3(mv.x, 0.0, mv.y)
	var target := dir * Balance.player_speed
	velocity = velocity.lerp(target, 1.0 - exp(-Balance.player_accel * delta))
	velocity.y = 0.0
	move_and_slide()
	if dir.length_squared() > 0.01:
		if not _mesh.is_playing():
			_mesh.play()
	else:
		_mesh.pause()
		_mesh.frame = 0

	_update_aim(delta)

	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		var rate := Balance.fire_rate * (Balance.overdrive_rate_mult if _overdrive else 1.0)
		_fire_timer = 1.0 / rate
		_fire()

	if _invuln > 0.0:
		_blink += delta
		_mesh.visible = int(_blink / 0.07) % 2 == 0
	else:
		_mesh.visible = true

func _advance_invulnerability(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)

func _update_aim(delta: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.35)
	var aim := Vector2.ZERO
	if stick.length() > 0.12:
		aim = stick
		_last_aim_mouse = false
	elif mouse_aim and _last_aim_mouse:
		var vp := get_viewport()
		var cam := vp.get_camera_3d()
		if cam:
			var ms := vp.get_mouse_position()
			var ray_origin := cam.project_ray_origin(ms)
			var ray_dir := cam.project_ray_normal(ms)
			if absf(ray_dir.y) > 0.001:
				var t := (global_position.y - ray_origin.y) / ray_dir.y
				var world_pos := ray_origin + ray_dir * t
				var to_mouse := world_pos - global_position
				aim = Vector2(to_mouse.x, to_mouse.z)
	if aim.length() > 0.12:
		var d := Vector3(aim.x, 0.0, aim.y)
		if d.length() > 1.0:
			d = d.normalized()
		_set_aim(d, delta)

func _set_aim(d: Vector3, delta: float) -> void:
	_aim_dir = _aim_dir.slerp(d, 1.0 - exp(-25.0 * delta)).normalized()
	rotation.y = atan2(-_aim_dir.x, -_aim_dir.z)

func debug_aim_at(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() > 0.05:
		_aim_dir = d.normalized()
		rotation.y = atan2(-_aim_dir.x, -_aim_dir.z)

func _fire() -> void:
	var ray_from := global_position + Vector3.UP * 0.5
	var muzzle := global_position + Vector3.UP * 0.8 + _aim_dir * 0.75
	var to := ray_from + _aim_dir * 120.0
	var q := PhysicsRayQueryParameters3D.create(ray_from, to, Balance.WALL_LAYER | Balance.ENEMY_LAYER)
	q.exclude = [self]
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if hit else to
	var dmg := Balance.weapon_damage * (Balance.overdrive_dmg_mult if _overdrive else 1.0)
	fire_hit.emit(muzzle, end, hit.get("collider") if hit else null, dmg)
	_flash_mesh.visible = true
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func(): _flash_mesh.visible = false)
	_muzzle_light.light_energy = 3.0
	create_tween().tween_property(_muzzle_light, "light_energy", 0.0, 0.06)
	AudioLib.play_sfx("shot", randf_range(0.92, 1.08), -4.0)
	AudioLib.rumble(0.12, 0.0, 0.04)

func damage(amount: float) -> bool:
	if debug_invulnerable or _dead or _invuln > 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	_invuln = Balance.invuln_time
	damaged.emit(hp, Balance.player_max_hp)
	AudioLib.play_sfx("player_damage", 1.0, -3.0)
	AudioLib.rumble(0.25, 0.45, 0.22)
	if hp <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		set_collision_layer_value(3, false)
		died.emit()
	return true

func heal(amount: float) -> void:
	if _dead:
		return
	hp = minf(hp + amount, Balance.player_max_hp)
	healed.emit(hp, Balance.player_max_hp)

func is_dead() -> bool:
	return _dead

func start_overdrive(duration: float) -> void:
	_set_overdrive(true)
	_od_left = duration
	overdrive_started.emit(duration)

func _set_overdrive(on: bool) -> void:
	if _overdrive == on:
		return
	_overdrive = on
	if on:
		_mesh.modulate = Color(0.65, 1.0, 1.0)
		_body_glow.light_energy = 2.2
	else:
		_mesh.modulate = Color.WHITE
		_body_glow.light_energy = 1.1
		overdrive_ended.emit()
