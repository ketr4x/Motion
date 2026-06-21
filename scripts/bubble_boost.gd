extends Area2D

@export var boost_direction: Vector2 = Vector2.UP
@export var boost_strength: float = 600.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("apply_bubble_boost"):
		body.apply_bubble_boost(boost_direction * boost_strength)
