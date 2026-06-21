extends Node2D

@onready var lever_a: Area2D = $LeverA
@onready var lever_b: Area2D = $LeverB
@onready var gate_body: StaticBody2D = $GateBody

@onready var lever_a_sprite: Sprite2D = $LeverA/Sprite2D
@onready var lever_b_sprite: Sprite2D = $LeverB/Sprite2D
@onready var gate_sprite: Sprite2D = $GateBody/Sprite2D

@onready var lever_a_label: Label = $LeverA/Label
@onready var lever_b_label: Label = $LeverB/Label
@onready var gate_label: Label = $GateBody/Label

@onready var gate_collision: CollisionShape2D = $GateBody/CollisionShape2D

@export var activation_window: float = 4.0

var lever_a_active: bool = false
var lever_b_active: bool = false
var gate_open: bool = false

var lever_a_timer: float = 0.0
var lever_b_timer: float = 0.0

var local_in_lever_a: bool = false
var local_in_lever_b: bool = false

func _ready() -> void:
	lever_a.body_entered.connect(_on_lever_a_body_entered)
	lever_a.body_exited.connect(_on_lever_a_body_exited)
	
	lever_b.body_entered.connect(_on_lever_b_body_entered)
	lever_b.body_exited.connect(_on_lever_b_body_exited)
	
	update_visuals()

func _process(delta: float) -> void:
	if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and not gate_open:
		var changed = false
		if lever_a_active:
			lever_a_timer -= delta
			if lever_a_timer <= 0.0:
				lever_a_active = false
				lever_a_timer = 0.0
				changed = true
				
		if lever_b_active:
			lever_b_timer -= delta
			if lever_b_timer <= 0.0:
				lever_b_active = false
				lever_b_timer = 0.0
				changed = true
				
		if changed:
			if multiplayer.has_multiplayer_peer():
				sync_lever_states.rpc(lever_a_active, lever_a_timer, lever_b_active, lever_b_timer)
	else:
		if lever_a_active and lever_a_timer > 0.0:
			lever_a_timer = max(0.0, lever_a_timer - delta)
		if lever_b_active and lever_b_timer > 0.0:
			lever_b_timer = max(0.0, lever_b_timer - delta)
				
	if not gate_open:
		if local_in_lever_a and Input.is_key_pressed(KEY_E) and not lever_a_active:
			if multiplayer.has_multiplayer_peer():
				request_activate_lever.rpc_id(1, "A")
			else:
				request_activate_lever("A")
		elif local_in_lever_b and Input.is_key_pressed(KEY_E) and not lever_b_active:
			if multiplayer.has_multiplayer_peer():
				request_activate_lever.rpc_id(1, "B")
			else:
				request_activate_lever("B")
			
	update_visuals()

@rpc("any_peer", "call_local", "reliable")
func request_activate_lever(lever_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if gate_open:
		return
		
	if lever_id == "A":
		lever_a_active = true
		lever_a_timer = activation_window
	elif lever_id == "B":
		lever_b_active = true
		lever_b_timer = activation_window
		
	if multiplayer.has_multiplayer_peer():
		sync_lever_states.rpc(lever_a_active, lever_a_timer, lever_b_active, lever_b_timer)
	
	if lever_a_active and lever_b_active:
		if multiplayer.has_multiplayer_peer():
			open_gate.rpc()
		else:
			open_gate()

@rpc("authority", "call_local", "reliable")
func sync_lever_states(a_state: bool, a_time: float, b_state: bool, b_time: float) -> void:
	lever_a_active = a_state
	lever_a_timer = a_time
	lever_b_active = b_state
	lever_b_timer = b_time

@rpc("authority", "call_local", "reliable")
func open_gate() -> void:
	gate_open = true
	gate_collision.set_deferred("disabled", true)
	
	var game_node = get_parent()
	if game_node:
		var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var local_player = game_node.get_node_or_null(str(local_id))
		if local_player and local_player.has_method("shake_camera"):
			local_player.shake_camera(8.0, 0.5)
			
	var tween = create_tween()
	tween.tween_property(gate_sprite, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(gate_sprite, "scale:y", 0.1, 0.6)
	
	tween.parallel().tween_property(lever_a_label, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(lever_b_label, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(gate_label, "modulate:a", 0.0, 0.4)
	
	tween.tween_callback(queue_free)

func update_visuals() -> void:
	if gate_open:
		gate_label.text = "UNLOCKED!"
		return
		
	if lever_a_active:
		lever_a_sprite.self_modulate = Color(0.2, 0.8, 0.3)
		lever_a_label.text = "ACTIVE (%.1fs)" % lever_a_timer
	else:
		lever_a_sprite.self_modulate = Color(0.9, 0.2, 0.2)
		if local_in_lever_a:
			lever_a_label.text = "PRESS [E]"
		else:
			lever_a_label.text = "LEVER A"
			
	if lever_b_active:
		lever_b_sprite.self_modulate = Color(0.2, 0.8, 0.3)
		lever_b_label.text = "ACTIVE (%.1fs)" % lever_b_timer
	else:
		lever_b_sprite.self_modulate = Color(0.9, 0.2, 0.2)
		if local_in_lever_b:
			lever_b_label.text = "PRESS [E]"
		else:
			lever_b_label.text = "LEVER B"

func _on_lever_a_body_entered(body: Node2D) -> void:
	if body.is_multiplayer_authority():
		local_in_lever_a = true

func _on_lever_a_body_exited(body: Node2D) -> void:
	if body.is_multiplayer_authority():
		local_in_lever_a = false

func _on_lever_b_body_entered(body: Node2D) -> void:
	if body.is_multiplayer_authority():
		local_in_lever_b = true

func _on_lever_b_body_exited(body: Node2D) -> void:
	if body.is_multiplayer_authority():
		local_in_lever_b = false
