extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var cooldown_time: float = 12.0
var is_active: bool = true

var bubbles: Array[ColorRect] = []
var bubble_offsets: Array[Vector2] = []
var bubble_phases: Array[float] = []

var is_absorbing: bool = false
var absorb_target: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if has_node("Sprite2D"):
		$Sprite2D.queue_free()
	
	for i in range(40):
		var b = ColorRect.new()
		b.custom_minimum_size = Vector2(3.75, 3.75)
		b.size = Vector2(3.75, 3.75)
		b.color = Color(0.3, 0.7, 1.0, 0.7)
		add_child(b)
		bubbles.append(b)
		
		var rx = randf_range(-12, 12)
		var ry = randf_range(-12, 12)
		bubble_offsets.append(Vector2(rx, ry))
		bubble_phases.append(randf() * PI * 2)
		b.position = Vector2(rx, ry)

func _process(delta: float) -> void:
	if is_active:
		for i in range(bubbles.size()):
			bubble_phases[i] += delta * randf_range(2.0, 4.0)
			var offset_x = sin(bubble_phases[i]) * 2.5
			var offset_y = cos(bubble_phases[i] * 0.9) * 2.5
			bubbles[i].position = bubbles[i].position.lerp(bubble_offsets[i] + Vector2(offset_x, offset_y), 5.0 * delta)
	elif is_absorbing and absorb_target != null:
		var all_arrived = true
		for i in range(bubbles.size()):
			if not bubbles[i].visible:
				continue
			var target_local = absorb_target.global_position - global_position
			var dist = bubbles[i].position.distance_to(target_local)
			if dist < 8.0:
				bubbles[i].visible = false
			else:
				var dir = (target_local - bubbles[i].position).normalized()
				bubbles[i].position += dir * 350.0 * delta
				all_arrived = false
		if all_arrived:
			is_absorbing = false

func _on_body_entered(body: Node2D) -> void:
	if is_active and body.is_multiplayer_authority() and body.has_method("recharge_oxygen"):
		body.recharge_oxygen()
		deactivate.rpc(body.name)

@rpc("any_peer", "call_local", "reliable")
func deactivate(peer_name: String = "") -> void:
	is_active = false
	collision_shape.set_deferred("disabled", true)
	
	if peer_name != "":
		for p in get_tree().get_nodes_in_group("players"):
			if p.name == peer_name:
				absorb_target = p
				break
	
	if absorb_target:
		is_absorbing = true
	else:
		for b in bubbles:
			b.visible = false
	
	await get_tree().create_timer(cooldown_time).timeout
	reactivate()

func reactivate() -> void:
	is_active = true
	is_absorbing = false
	absorb_target = null
	collision_shape.set_deferred("disabled", false)
	
	for i in range(bubbles.size()):
		bubbles[i].visible = true
		var rx = randf_range(-12, 12)
		var ry = randf_range(-12, 12)
		bubble_offsets[i] = Vector2(rx, ry)
		bubbles[i].position = bubble_offsets[i]
