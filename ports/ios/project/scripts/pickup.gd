class_name Pickup
extends Area3D

signal collected(pickup: Pickup)

var kind := "heal"
var _t := 0.0
var _life := 8.0
var _sprite: Sprite3D
var _shadow: Sprite3D
var _glow: OmniLight3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PLAYER_LAYER
	body_entered.connect(_on_body)
	_build()

func _build() -> void:
	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.45
	shape.shape = sp
	shape.position.y = 0.4
	add_child(shape)

	_shadow = Sprite3D.new()
	_shadow.texture = load("res://assets/sprites/effects/soft_shadow.svg")
	_shadow.pixel_size = 0.005
	_shadow.position.y = 0.02
	_shadow.rotation.x = -PI / 2.0
	add_child(_shadow)

	_sprite = Sprite3D.new()
	_sprite.pixel_size = 0.0055
	_sprite.position.y = 0.45
	_sprite.rotation.x = -PI / 2.0
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	add_child(_sprite)

	_glow = OmniLight3D.new()
	_glow.position.y = 0.7
	_glow.omni_range = 3.5
	_glow.light_energy = 0.8
	add_child(_glow)

func setup(k: String, pos: Vector3) -> void:
	kind = k
	global_position = pos
	_t = 0.0
	_life = Balance.pickup_lifetime
	var col := Color(0.2, 1.0, 0.4) if kind == "heal" else Color(0.3, 0.7, 1.0)
	_sprite.texture = load("res://assets/sprites/pickups/heal_nanocapsule.svg" if kind == "heal" else "res://assets/sprites/pickups/overdrive_reactor.svg")
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector3.ONE
	_glow.light_color = col
	_glow.light_energy = 0.8
	rotation.y = 0.0
	visible = true
	set_process(true)
	set_deferred("monitoring", true)

func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	_sprite.position.y = 0.45 + sin(_t * 3.0) * 0.1
	var pulse := 1.0 + sin(_t * 5.0) * 0.08
	_sprite.scale = Vector3.ONE * pulse
	_glow.light_energy = 0.65 + sin(_t * 5.0) * 0.2
	rotation.y += delta * 2.0
	if _life <= 0.0:
		hide_pickup()

func hide_pickup() -> void:
	visible = false
	set_process(false)
	set_deferred("monitoring", false)

func _on_body(body: Node) -> void:
	if body is Player:
		collected.emit(self)
		hide_pickup()
