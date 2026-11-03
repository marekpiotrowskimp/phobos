class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy, by_contact: bool)

static var _frames_cache: Dictionary = {}

var player: Player
var active := false
var speed := 0.0
var hp := 0.0
var variant := "red"
var point_value := Balance.kill_points
var _spawn_t := 0.0
var _bob := 0.0
var _sprite: AnimatedSprite3D
var _shadow: Sprite3D
var _telegraph: Sprite3D
var _hit_area: Area3D
var _armor_mark: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.WALL_LAYER
	_build()

func _build() -> void:
	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5
	shape.shape = sp
	shape.position.y = 0.5
	add_child(shape)

	_hit_area = Area3D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 0
	var hit_shape := CollisionShape3D.new()
	var hit_sphere := SphereShape3D.new()
	hit_sphere.radius = 0.72
	hit_shape.shape = hit_sphere
	hit_shape.position.y = 0.5
	_hit_area.add_child(hit_shape)
	add_child(_hit_area)

	_mesh_setup()

func _mesh_setup() -> void:
	_shadow = Sprite3D.new()
	_shadow.texture = load("res://assets/sprites/effects/soft_shadow.svg")
	_shadow.pixel_size = 0.0065
	_shadow.position.y = 0.02
	_shadow.rotation.x = -PI / 2.0
	add_child(_shadow)

	_telegraph = Sprite3D.new()
	_telegraph.texture = load("res://assets/sprites/effects/spawn_telegraph.svg")
	_telegraph.pixel_size = 0.008
	_telegraph.position.y = 0.025
	_telegraph.rotation.x = -PI / 2.0
	_telegraph.visible = false
	add_child(_telegraph)

	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = _frames_for_variant("red")
	_sprite.animation = "default"
	_sprite.pixel_size = 0.0045
	_sprite.position.y = 0.07
	_sprite.rotation.x = -PI / 2.0
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	add_child(_sprite)

	_armor_mark = Label3D.new()
	_armor_mark.text = "I"
	_armor_mark.font = load("res://assets/fonts/Tektur-Variable.ttf")
	_armor_mark.font_size = 42
	_armor_mark.outline_size = 9
	_armor_mark.pixel_size = 0.006
	_armor_mark.position = Vector3(0.0, 0.12, 0.25)
	_armor_mark.rotation.x = -PI / 2.0
	_armor_mark.no_depth_test = true
	add_child(_armor_mark)

func _frames_for_variant(variant_id: String) -> SpriteFrames:
	if _frames_cache.has(variant_id):
		return _frames_cache[variant_id]
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 10.0)
	frames.set_animation_loop("default", true)
	var prefix := "scorpion_crawl" if variant_id == "red" else "scorpion_%s" % variant_id
	for i in 4:
		var texture := load("res://assets/sprites/enemy/%s_%d.png" % [prefix, i + 1]) as Texture2D
		frames.add_frame("default", texture)
	_frames_cache[variant_id] = frames
	return frames

func spawn(pos: Vector3, spd: float, bob: float, variant_id := "red", points := 10) -> void:
	global_position = pos
	speed = spd
	hp = Balance.enemy_hp
	variant = variant_id
	point_value = points
	_bob = bob
	_spawn_t = 0.55
	_sprite.sprite_frames = _frames_for_variant(variant)
	_sprite.frame = int(bob / TAU * 4.0) % 4
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector3.ONE * 0.05
	_sprite.play()
	_shadow.scale = Vector3.ONE * 0.2
	_telegraph.scale = Vector3.ONE
	_telegraph.modulate = Color.WHITE
	_telegraph.visible = true
	_armor_mark.text = {"red": "I", "amber": "II", "violet": "III"}.get(variant, "I")
	_armor_mark.modulate = {"red": Color(1.0, 0.25, 0.2), "amber": Color(1.0, 0.72, 0.08), "violet": Color(0.75, 0.22, 1.0)}.get(variant, Color.WHITE)
	var initial_direction := player.global_position - pos
	if initial_direction.length_squared() > 0.001:
		rotation.y = atan2(-initial_direction.x, -initial_direction.z)
	scale = Vector3.ONE
	active = true
	visible = true
	set_physics_process(true)
	_hit_area.collision_layer = 0

func die(by_contact := false) -> void:
	if not active:
		return
	active = false
	visible = false
	_sprite.stop()
	_telegraph.visible = false
	set_physics_process(false)
	_hit_area.collision_layer = 0
	died.emit(self, by_contact)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if _spawn_t > 0.0:
		_spawn_t -= delta
		var k := clampf(1.0 - _spawn_t / 0.55, 0.0, 1.0)
		var s := 0.05 + 0.95 * (k * k)
		_sprite.scale = Vector3.ONE * s
		_shadow.scale = Vector3.ONE * (0.2 + 0.8 * k)
		_telegraph.rotation.z += delta * 3.5
		_telegraph.modulate.a = 0.35 + sin(k * PI) * 0.65
		if _spawn_t <= 0.0:
			_sprite.scale = Vector3.ONE
			_shadow.scale = Vector3.ONE
			_telegraph.visible = false
			_hit_area.collision_layer = Balance.ENEMY_LAYER
		return
	if not is_instance_valid(player):
		return
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var d := to_p.length()
	velocity = to_p / d * speed if d > 0.001 else Vector3.ZERO
	velocity.y = 0.0
	if d > 0.001:
		var target_rotation := atan2(-to_p.x, -to_p.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 1.0 - exp(-12.0 * delta))
	var previous := global_position
	move_and_slide()
	var segment := global_position - previous
	var closest := previous
	if segment.length_squared() > 0.000001:
		var t := clampf((player.global_position - previous).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest += segment * t
	if closest.distance_to(player.global_position) < Balance.enemy_contact_range:
		if player.damage(Balance.contact_damage):
			die(true)
			return
	var pulse := 0.98 + sin(Time.get_ticks_msec() * 0.015 + _bob) * 0.02
	_sprite.modulate = Color(pulse, pulse, pulse)

func damage(amount: float) -> void:
	if not active:
		return
	hp -= amount
	if hp <= 0.0:
		die()
		return
	_sprite.modulate = Color.WHITE
