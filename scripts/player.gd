extends CharacterBody2D

@export var max_oxygen: float = 100.0
@export var depletion_rate: float = 2.0

var speed: float = 120.0
var friction: float = 0.15

@export var oxygen: float = 100.0
@export var camera_zoom: Vector2 = Vector2(1.7, 1.7)
@export var horizontal_boundary: float = 300.0
var is_dead: bool = false

var is_suffocating: bool = false
var suffocate_time_left: float = 5.0
var original_color: Color = Color.WHITE

var is_stunned: bool = false
var stun_time_left: float = 0.0
@export var stun_oxygen_depletion_multiplier: float = 3.0

@export var dash_speed: float = 380.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.6
@export var dash_oxygen_cost: float = 12.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var was_shift_pressed: bool = false
var was_e_pressed: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D

var shake_amount: float = 0.0
var shake_decay: float = 0.0

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
		original_color = Color(0.2, 0.6, 1.0)
	else:
		camera.enabled = false
		original_color = Color(0.2, 0.9, 0.6)
	sprite.self_modulate = original_color

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_multiplayer_authority():
		return

	if is_suffocating:
		suffocate_time_left -= delta
		if suffocate_time_left <= 0.0:
			is_suffocating = false
			die()
			return

	if is_stunned:
		stun_time_left -= delta
		if stun_time_left <= 0.0:
			is_stunned = false

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			velocity = dash_dir * speed
		else:
			velocity = dash_dir * dash_speed
			move_and_slide()
			position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
			return

	var input_dir = Vector2.ZERO
	
	if not is_stunned:
		if Input.is_action_pressed("left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x = -1
		if Input.is_action_pressed("right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x = 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y = -1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y = 1
			
		input_dir = input_dir.normalized()

	var is_shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	var just_pressed_shift = is_shift_pressed and not was_shift_pressed
	was_shift_pressed = is_shift_pressed
	
	if just_pressed_shift and dash_cooldown_timer <= 0.0 and not is_stunned:
		var d_dir = input_dir
		if d_dir == Vector2.ZERO:
			d_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		
		if oxygen > 0.0:
			oxygen = max(0.0, oxygen - dash_oxygen_cost)
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			dash_dir = d_dir
			velocity = dash_dir * dash_speed
			
			move_and_slide()
			position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
			
			if oxygen <= 0.0:
				oxygen = 0.0
				start_suffocating()
			return
	
	var current_speed = speed * 0.3 if is_suffocating else speed
	if input_dir != Vector2.ZERO:
		velocity = velocity.lerp(input_dir * current_speed, 0.1)
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
		
	move_and_slide()
	position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)

	var is_e_pressed = Input.is_key_pressed(KEY_E)
	var just_pressed_e = is_e_pressed and not was_e_pressed
	was_e_pressed = is_e_pressed
	
	if just_pressed_e and not is_suffocating and oxygen > 40.0:
		var teammate = get_survivor()
		if teammate and teammate.is_suffocating:
			var dist = global_position.distance_to(teammate.global_position)
			if dist < 50.0:
				var other_peer_id = teammate.name.to_int()
				if other_peer_id > 0:
					teammate.receive_shared_oxygen.rpc_id(other_peer_id, 30.0, multiplayer.get_unique_id())

	if is_multiplayer_authority() and oxygen > 0:
		var current_depletion = depletion_rate
		if is_stunned:
			current_depletion *= stun_oxygen_depletion_multiplier
		oxygen -= current_depletion * delta
		if oxygen <= 0:
			oxygen = 0
			start_suffocating()

func recharge_oxygen() -> void:
	if not is_dead:
		oxygen = max_oxygen
		if is_suffocating:
			stop_suffocating()

func die() -> void:
	if is_multiplayer_authority() or multiplayer.is_server():
		_die_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _die_rpc() -> void:
	if is_dead:
		return
	is_dead = true
	oxygen = 0
	is_suffocating = false
	is_dashing = false
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
	is_suffocating = false
	is_dashing = false
	is_stunned = false
	stun_time_left = 0.0
	suffocate_time_left = 5.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	collision_layer = 2
	collision_mask = 1
	sprite.visible = true
	velocity = Vector2.ZERO
	if is_multiplayer_authority():
		camera.global_position = Vector2(0, pos.y)

func shake_camera(intensity: float, duration: float) -> void:
	if is_multiplayer_authority():
		shake_amount = intensity
		shake_decay = intensity / duration

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if not is_dead:
			camera.global_position = Vector2(0, global_position.y)
		else:
			var survivor = get_survivor()
			if survivor:
				camera.global_position.x = 0
				camera.global_position.y = lerp(camera.global_position.y, survivor.global_position.y, 5.0 * delta)
		
		# Camera shake logic
		if shake_amount > 0.0:
			shake_amount = max(0.0, shake_amount - shake_decay * delta)
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
		else:
			camera.offset = Vector2.ZERO
				
	if velocity.length() > speed * 1.3 and not is_dead:
		if abs(velocity.x) > abs(velocity.y):
			sprite.scale = Vector2(26.0, 15.0)
		else:
			sprite.scale = Vector2(15.0, 26.0)
	else:
		sprite.scale = Vector2(20.0, 20.0)

	if is_suffocating and not is_dead:
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		sprite.self_modulate = original_color.lerp(Color(0.9, 0.1, 0.1), pulse)
	elif is_stunned and not is_dead:
		var pulse = (sin(Time.get_ticks_msec() * 0.04) + 1.0) * 0.5
		sprite.self_modulate = original_color.lerp(Color(1.0, 1.0, 0.2), pulse)
	else:
		sprite.self_modulate = original_color

func get_survivor() -> CharacterBody2D:
	var parent = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is CharacterBody2D and child != self and "is_dead" in child and not child.is_dead:
			return child
	return null

func start_suffocating() -> void:
	if is_suffocating or is_dead:
		return
	is_suffocating = true
	suffocate_time_left = 5.0
	print(name, " started suffocating!")

func stop_suffocating() -> void:
	if not is_suffocating:
		return
	is_suffocating = false
	print(name, " stopped suffocating!")



@rpc("any_peer", "call_local", "reliable")
func receive_shared_oxygen(amount: float, giver_id: int) -> void:
	if is_multiplayer_authority():
		if is_dead:
			return
		oxygen = min(max_oxygen, oxygen + amount)
		if is_suffocating:
			stop_suffocating()
		var giver_node = get_parent().get_node_or_null(str(giver_id))
		if giver_node and giver_node.has_method("deduct_oxygen"):
			giver_node.deduct_oxygen.rpc_id(giver_id, amount)

@rpc("any_peer", "call_local", "reliable")
func deduct_oxygen(amount: float) -> void:
	if is_multiplayer_authority():
		oxygen = max(0.0, oxygen - amount)

@rpc("any_peer", "call_local", "reliable")
func shock(duration: float) -> void:
	if is_dead:
		return
	is_stunned = true
	stun_time_left = max(stun_time_left, duration)
	is_dashing = false
	velocity = Vector2.ZERO
	print(name, " was shocked!")
