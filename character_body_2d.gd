extends CharacterBody2D
var speed = 50
var action : String

func _physics_process(delta: float) -> void:
	velocity.y = 100
	var dir = Input.get_axis("left", "right")
	velocity.x = speed * dir
	velocity.x = speed * dir
	if Input.is_action_just_released("left") && Input.is_action_just_released("right"):
		velocity.x = 0

	move_and_slide()
