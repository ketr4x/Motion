extends Node2D

@onready var vent_area: Area2D = $VentArea
@onready var button_area: Area2D = $ButtonArea
@onready var vent_sprite: Sprite2D = $VentArea/Sprite2D
@onready var button_sprite: Sprite2D = $ButtonArea/Sprite2D
@onready var vent_particles: CPUParticles2D = $VentArea/CPUParticles2D
@onready var button_label: Label = $ButtonArea/Label

@export var current_velocity: Vector2 = Vector2(400.0, 0.0)
@export var is_vent_active: bool = true

var players_on_button: int = 0
var local_player_on_button: bool = false

func _ready() -> void:
	button_area.body_entered.connect(_on_button_body_entered)
	button_area.body_exited.connect(_on_button_body_exited)
	update_visuals()

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var desired_active = (players_on_button == 0)
		if desired_active != is_vent_active:
			if multiplayer.has_multiplayer_peer():
				sync_vent_state.rpc(desired_active)
			else:
				is_vent_active = desired_active
				update_visuals()
	
	if is_vent_active:
		for body in vent_area.get_overlapping_bodies():
			if (not multiplayer.has_multiplayer_peer() or body.is_multiplayer_authority()) and body.has_method("recharge_oxygen") and not body.is_dead:
				body.velocity = body.velocity.lerp(current_velocity, 8.0 * delta)

@rpc("authority", "call_local", "reliable")
func sync_vent_state(active_state: bool) -> void:
	is_vent_active = active_state
	update_visuals()

func update_visuals() -> void:
	if is_vent_active:
		vent_sprite.self_modulate = Color(0.2, 0.5, 0.8, 1.0)
		button_sprite.self_modulate = Color(0.9, 0.2, 0.2, 1.0)
		button_label.text = "STAND HERE"
		if vent_particles:
			vent_particles.emitting = true
	else:
		vent_sprite.self_modulate = Color(0.4, 0.4, 0.4, 0.4)
		button_sprite.self_modulate = Color(0.2, 0.8, 0.3, 1.0)
		button_label.text = "ACTIVE!"
		if vent_particles:
			vent_particles.emitting = false

func _on_button_body_entered(body: Node2D) -> void:
	if body.has_method("recharge_oxygen"):
		if not multiplayer.has_multiplayer_peer() or body.is_multiplayer_authority():
			local_player_on_button = true
			if multiplayer.has_multiplayer_peer():
				request_button_press.rpc_id(1, true)
			else:
				request_button_press(true)

func _on_button_body_exited(body: Node2D) -> void:
	if body.has_method("recharge_oxygen"):
		if not multiplayer.has_multiplayer_peer() or body.is_multiplayer_authority():
			local_player_on_button = false
			if multiplayer.has_multiplayer_peer():
				request_button_press.rpc_id(1, false)
			else:
				request_button_press(false)

@rpc("any_peer", "call_local", "reliable")
func request_button_press(pressed: bool) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if pressed:
		players_on_button += 1
	else:
		players_on_button = max(0, players_on_button - 1)
