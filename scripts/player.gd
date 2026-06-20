extends CharacterBody2D

@export var max_oxygen: float = 100.0
@export var depletion_rate: float = 2.0

var speed: float = 120.0
var friction: float = 0.15

@export var oxygen: float = 100.0

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
		sprite.self_modulate = Color(0.2, 0.6, 1.0)
	else:
		camera.enabled = false
		sprite.self_modulate = Color(0.2, 0.9, 0.6)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		move_and_slide()
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

	if oxygen > 0:
		oxygen -= depletion_rate * delta
		if oxygen <= 0:
			oxygen = 0
			_on_die()

func _on_die() -> void:
	print(name, " has run out of oxygen!")
	var game_node = get_parent()
	if game_node.has_method("player_died"):
		game_node.player_died(name.to_int())
