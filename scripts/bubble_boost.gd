extends Area2D

@export var boost_direction: Vector2 = Vector2.DOWN
@export var boost_strength: float = 500.0

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody2D and "is_dead" in body and not body.is_dead:
			var boost = boost_direction.normalized() * boost_strength * delta
			body.velocity += boost
