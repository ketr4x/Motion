extends CharacterBody2D

@export var max_oxygen: float = 100.0
@export var depletion_rate: float = 2.0

@export var base_speed: float = 240.0
@export var acceleration: float = 1600.0
@export var water_friction: float = 700.0

@export var oxygen: float = 100.0
@export var camera_zoom: Vector2 = Vector2(3.33333, 3.33333)
@export var horizontal_boundary: float = 288.0
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
var last_look_dir: Vector2 = Vector2(0, 1)
var coop_speed_bonus: float = 0.0

var is_launched: bool = false
var launch_timer: float = 0.0
var launch_duration_total: float = 0.4
var launch_direction: Vector2 = Vector2.ZERO

@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var bubble_particles: CPUParticles2D = %BubbleParticles
@onready var wind_particles: CPUParticles2D = %WindParticles

var anim_time: float = 0.0
var spawn_intro_timer: float = 1.0

var shake_amount: float = 0.0
var shake_decay: float = 0.0
var flash_timer: float = 0.0

func _enter_tree() -> void:
	var peer_id = name.to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	add_to_group("players")
	oxygen = max_oxygen
	if is_local_authority():
		camera.enabled = true
		camera.make_current()
		camera.top_level = true
		camera.zoom = camera_zoom
		camera.global_position = Vector2(0, global_position.y)
	else:
		camera.enabled = false
		
	var peer_id = name.to_int()
	if peer_id == 1:
		sprite.texture = preload("res://assets/kaczka1.png")
	else:
		sprite.texture = preload("res://assets/kaczka2.png")
		
	original_color = Color.WHITE
	sprite.self_modulate = original_color

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_local_authority():
		return

	if spawn_intro_timer > 0.0:
		velocity = Vector2(0, 150.0)
		move_and_slide()
		position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
		return

	if is_launched:
		launch_timer -= delta
		if launch_timer <= 0.0:
			is_launched = false
		else:
			velocity = launch_direction * (dash_speed * 1.5) * (launch_timer / launch_duration_total + 0.5)
			move_and_slide()
			position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
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
		last_look_dir = input_dir


	var is_near_teammate = false
	for p in get_tree().get_nodes_in_group("players"):
		if p != self and not p.is_dead and not p.is_suffocating:
			if global_position.distance_to(p.global_position) < 100.0:
				is_near_teammate = true
				break
	
	if is_near_teammate:
		coop_speed_bonus = move_toward(coop_speed_bonus, 0.25, delta) # 25% speed boost when close
	else:
		coop_speed_bonus = move_toward(coop_speed_bonus, 0.0, 0.5 * delta)

	if is_dashing:

		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		else:
			velocity = dash_dir * (dash_speed * 1.8)
			var old_dash_vel = velocity
			move_and_slide()
			
			if get_slide_collision_count() > 0:
				var coll = get_slide_collision(0)
				if old_dash_vel.normalized().dot(-coll.get_normal()) > 0.5:
					flash_white(0.15)
					shake_camera(10.0, 0.25)
					is_dashing = false
					dash_timer = 0.0
					velocity = old_dash_vel.bounce(coll.get_normal()) * 0.6
					
			position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
			
			var teammate_dash = get_survivor()
			if teammate_dash and not teammate_dash.is_dead:
				var dist_dash = global_position.distance_to(teammate_dash.global_position)
				if dist_dash < 65.0:
					teammate_dash.apply_slingshot_launch.rpc(dash_dir * (dash_speed * 1.5))
					is_dashing = false
					dash_timer = 0.0
					velocity = -dash_dir * 120.0
			return

	var is_shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	var just_pressed_shift = is_shift_pressed and not was_shift_pressed
	was_shift_pressed = is_shift_pressed
	
	if just_pressed_shift and dash_cooldown_timer <= 0.0 and not is_stunned:
		var d_dir = input_dir
		if d_dir == Vector2.ZERO:
			d_dir = Vector2.UP.rotated(sprite.rotation)
		
		if oxygen > 0.0:
			oxygen = max(0.0, oxygen - dash_oxygen_cost)
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			dash_dir = d_dir
			velocity = dash_dir * dash_speed * 1.8
			shake_camera(8.0, 0.25)
			flash_white(0.1)
			
			move_and_slide()
			position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
			
			if oxygen <= 0.0:
				oxygen = 0.0
				start_suffocating()
			return
	
	var is_solo = (multiplayer.get_peers().size() == 0)
	var slipstream_boost = 1.0
	var teammate_slip = get_survivor()
	if teammate_slip and not teammate_slip.is_dead:
		var dist_slip = global_position.distance_to(teammate_slip.global_position)
		if dist_slip < 120.0:
			slipstream_boost = 1.4
			if teammate_slip.velocity.normalized().dot(velocity.normalized()) > 0.8:
				slipstream_boost = 1.55
	
	var current_speed = base_speed * 0.4 if is_suffocating else base_speed
	current_speed *= slipstream_boost
	if coop_speed_bonus > 0.0:
		current_speed *= (1.0 + coop_speed_bonus)
		coop_speed_bonus = move_toward(coop_speed_bonus, 0.0, 0.15 * delta)
	
	if is_stunned:
		current_speed *= 0.3 # Smoła stuna
	
	if input_dir != Vector2.ZERO:
		if velocity.length() > current_speed:
			var steer_strength = 8.0 * delta
			var target_vel = input_dir * velocity.length()
			velocity = velocity.lerp(target_vel, steer_strength)
			velocity = velocity.move_toward(input_dir * current_speed, water_friction * 0.6 * delta)
		else:
			velocity = velocity.move_toward(input_dir * current_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, water_friction * delta)
		
	var old_velocity = velocity
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		var hit_dot = old_velocity.normalized().dot(-collision.get_normal())
		if hit_dot > 0.6 and old_velocity.length() > 250.0:
			flash_white(0.15)
			shake_camera(8.0, 0.2)
			velocity = old_velocity.bounce(collision.get_normal()) * 0.5
			
	position.x = clamp(position.x, -horizontal_boundary, horizontal_boundary)
	position.y = min(position.y, 3750.0)

	var is_e_pressed = Input.is_key_pressed(KEY_E)
	var just_pressed_e = is_e_pressed and not was_e_pressed
	was_e_pressed = is_e_pressed
	
	if just_pressed_e and not is_suffocating and oxygen > 40.0:
		var teammate_oxy = get_survivor()
		if teammate_oxy and teammate_oxy.is_suffocating:
			var dist_oxy = global_position.distance_to(teammate_oxy.global_position)
			if dist_oxy < 50.0:
				var other_peer_id = teammate_oxy.name.to_int()
				if other_peer_id > 0:
					if multiplayer.has_multiplayer_peer():
						teammate_oxy.receive_shared_oxygen.rpc_id(other_peer_id, 30.0, multiplayer.get_unique_id())
					else:
						teammate_oxy.receive_shared_oxygen(30.0, 1)
					coop_speed_bonus = 0.3

	if is_local_authority() and oxygen > 0:
		var current_depletion = depletion_rate
		if is_solo:
			current_depletion *= 0.3 # W solo zużycie tlenu jest dużo mniejsze
		if is_stunned:
			current_depletion *= stun_oxygen_depletion_multiplier
		oxygen -= current_depletion * delta
		if oxygen <= 0:
			oxygen = 0
			start_suffocating()

func apply_bubble_boost(force: Vector2) -> void:
	if not is_dead:
		velocity += force

func recharge_oxygen() -> void:
	if not is_dead:
		oxygen = max_oxygen
		if is_suffocating:
			stop_suffocating()
		
		# Oxygen Tether: Share with nearby players
		for p in get_tree().get_nodes_in_group("players"):
			if p != self and not p.is_dead and not p.is_suffocating:
				if global_position.distance_to(p.global_position) < 180.0:
					p.oxygen = min(p.max_oxygen, p.oxygen + 50.0)

func die() -> void:
	if not multiplayer.has_multiplayer_peer():
		_die_rpc()
	elif is_local_authority() or multiplayer.is_server():
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
	spawn_intro_timer = 1.0
	velocity = Vector2.ZERO
	if is_local_authority():
		camera.global_position = Vector2(0, pos.y)

func shake_camera(intensity: float, duration: float) -> void:
	if is_local_authority():
		shake_amount = intensity
		shake_decay = intensity / duration

func flash_white(duration: float) -> void:
	flash_timer = max(flash_timer, duration)

func _process(delta: float) -> void:
	if is_launched:
		launch_timer -= delta
		if launch_timer <= 0.0:
			is_launched = false

	if is_local_authority():
		if not is_dead:
			camera.global_position = Vector2(0, global_position.y)
		else:
			var survivor = get_survivor()
			if survivor:
				camera.global_position = Vector2(0, global_position.y)
				camera.global_position.y = lerp(camera.global_position.y, survivor.global_position.y, 5.0 * delta)
		
		var lookahead = Vector2(0, velocity.y * 0.12)
		if shake_amount > 0.0:
			shake_amount = max(0.0, shake_amount - shake_decay * delta)
			var shake_offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
			camera.offset = camera.offset.lerp(shake_offset + lookahead, 16.0 * delta)
		else:
			camera.offset = camera.offset.lerp(lookahead, 10.0 * delta)
				
	var base_scale = Vector2(3.75, 3.75)
	sprite.scale = base_scale

	var pulse: float = 0.0
	if flash_timer > 0.0:
		flash_timer -= delta
		sprite.self_modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif is_suffocating and not is_dead:
		pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		sprite.self_modulate = original_color.lerp(Color(0.9, 0.1, 0.1), pulse)
	elif is_stunned and not is_dead:
		pulse = (sin(Time.get_ticks_msec() * 0.04) + 1.0) * 0.5
		sprite.self_modulate = original_color.lerp(Color(1.0, 1.0, 0.2), pulse)
	else:
		sprite.self_modulate = original_color

	if not is_dead:
		anim_time += delta
		if spawn_intro_timer > 0.0:
			spawn_intro_timer -= delta
			
		if last_look_dir != Vector2.ZERO:
			var target_rotation = last_look_dir.angle() + PI/2
			sprite.rotation = lerp_angle(sprite.rotation, target_rotation, 12.0 * delta)
		
		sprite.flip_h = false

		if bubble_particles:
			if is_dashing or is_launched or spawn_intro_timer > 0.0:
				bubble_particles.emitting = true
				bubble_particles.speed_scale = 1.5
			elif velocity.length() > 10.0:
				bubble_particles.emitting = true
				bubble_particles.speed_scale = 1.0
			else:
				bubble_particles.emitting = false
				
		if wind_particles:
			if velocity.length() > 80.0 and not is_dead:
				wind_particles.emitting = true
				var move_dir = velocity.normalized()
				if move_dir != Vector2.ZERO:
					wind_particles.direction = -move_dir
					wind_particles.rotation = move_dir.angle() - PI/2
			else:
				wind_particles.emitting = false

		var frame_idx: int = 0
		if is_dashing or is_launched:
			frame_idx = int(anim_time * 24.0) % 12
			sprite.frame_coords = Vector2i(frame_idx, 1)
		elif is_stunned or is_suffocating:
			frame_idx = int(anim_time * 8.0) % 4
			sprite.frame_coords = Vector2i(frame_idx, 0)
		elif velocity.length() > 10.0:
			var speed_mult = 0.8 if is_suffocating else 1.0
			frame_idx = int(anim_time * 12.0 * speed_mult) % 12
			sprite.frame_coords = Vector2i(frame_idx, 1)
		else:
			frame_idx = int(anim_time * 10.0) % 7
			sprite.frame_coords = Vector2i(frame_idx, 2)
	else:
		if bubble_particles:
			bubble_particles.emitting = false
		if wind_particles:
			wind_particles.emitting = false

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
	if is_local_authority():
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
	if is_local_authority():
		oxygen = max(0.0, oxygen - amount)

@rpc("any_peer", "call_local", "reliable")
func shock(duration: float) -> void:
	if is_dead:
		return
	is_stunned = true
	stun_time_left = max(stun_time_left, duration)
	is_dashing = false
	print(name, " was shocked!")

@rpc("any_peer", "call_local", "reliable")
func apply_slingshot_launch(launch_vel: Vector2) -> void:
	if is_dead:
		return
	is_launched = true
	launch_timer = launch_duration_total
	launch_direction = launch_vel.normalized()
	is_stunned = false
	is_suffocating = false
	suffocate_time_left = 5.0
	
	if is_local_authority():
		velocity = launch_vel
		shake_camera(12.0, 0.4)

func is_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()
