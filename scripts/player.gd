extends CharacterBody2D

@export var max_oxygen: float = 100.0
@export var depletion_rate: float = 2.0

var speed: float = 120.0
var friction: float = 0.15

@export var oxygen: float = 100.0
@export var camera_zoom: Vector2 = Vector2(1.7, 1.7)
@export var horizontal_boundary: float = 300.0
var is_dead: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D

func _enter_tree() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	oxygen = max_oxygen
	if is_multiplayer_authority():
		camera.enabled = true
		camera.top_level = true
		camera.zoom = camera_zoom
		camera.global_position = Vector2(0, global_position.y)
		sprite.self_modulate = Color(0.2, 0.6, 1.0)
	else:
		camera.enabled = false
		sprite.self_modulate = Color(0.2, 0.9, 0.6)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_multiplayer_authority():
		move_and_slide()
		position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
		return

	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x = -1
	if Input.is_action_pressed("right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x = 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y = -1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y = 1
		
	input_dir = input_dir.normalized()
	
	if input_dir != Vector2.ZERO:
		velocity = velocity.lerp(input_dir * speed, 0.1)
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
		
	move_and_slide()
	position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)

	if is_multiplayer_authority() and oxygen > 0:
		oxygen -= depletion_rate * delta
		if oxygen <= 0:
			oxygen = 0
			die()

func recharge_oxygen() -> void:
	if not is_dead:
		oxygen = max_oxygen

func die() -> void:
	if is_multiplayer_authority() or multiplayer.is_server():
		_die_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _die_rpc() -> void:
	if is_dead:
		return
	is_dead = true
	oxygen = 0
	collision_layer = 0
	collision_mask = 0
	sprite.visible = false
	
	print(name, " has died!")
	var game_node = get_parent()
	if game_node.has_method("player_died"):
		game_node.player_died(name.to_int())

func respawn(pos: Vector2) -> void:
	is_dead = false
	position = pos
	oxygen = max_oxygen
	collision_layer = 2
	collision_mask = 1
	sprite.visible = true
	velocity = Vector2.ZERO
	if is_multiplayer_authority():
		camera.global_position = Vector2(0, pos.y)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if not is_dead:
			camera.global_position = Vector2(0, global_position.y)
		else:
			var survivor = get_survivor()
			if survivor:
				camera.global_position.x = 0
				camera.global_position.y = lerp(camera.global_position.y, survivor.global_position.y, 5.0 * delta)

func get_survivor() -> CharacterBody2D:
	var parent = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is CharacterBody2D and child != self and "is_dead" in child and not child.is_dead:
			return child
	return null
