extends Area2D

@export var stun_duration: float = 1.8
@export var speed: float = 30.0
@export var float_range: float = 30.0

var spawn_y: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	spawn_y = position.y
	time_passed = randf_range(0.0, 10.0)

func _process(delta: float) -> void:
	time_passed += delta
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		position.y = spawn_y + sin(time_passed * 1.5) * float_range
		
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var pulse_scale = 1.0 + sin(time_passed * 3.0) * 0.15
		sprite.scale = Vector2(24.0, 24.0) * pulse_scale

func _on_body_entered(body: Node2D) -> void:
	if body.is_multiplayer_authority() and body.has_method("shock"):
		body.shock(stun_duration)
