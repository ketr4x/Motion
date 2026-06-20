extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var cooldown_time: float = 12.0
var is_active: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_active and body.is_multiplayer_authority() and body.has_method("recharge_oxygen"):
		body.recharge_oxygen()
		deactivate.rpc()

@rpc("any_peer", "call_local", "reliable")
func deactivate() -> void:
	is_active = false
	sprite.self_modulate = Color(0.1, 0.4, 0.2, 0.3)
	collision_shape.set_deferred("disabled", true)
	
	await get_tree().create_timer(cooldown_time).timeout
	
	reactivate()

func reactivate() -> void:
	is_active = true
	sprite.self_modulate = Color(0.2, 0.8, 0.5, 1.0)
	collision_shape.set_deferred("disabled", false)
