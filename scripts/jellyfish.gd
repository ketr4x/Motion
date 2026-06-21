extends Area2D

@export var stun_duration: float = 1.8
@export var speed: float = 30.0
@export var float_range: float = 30.0

var spawn_y: float = 0.0
var time_passed: float = 0.0
var is_stinging: bool = false
var sting_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	spawn_y = position.y
	time_passed = randf_range(0.0, 10.0)

func _process(delta: float) -> void:
	if is_stinging:
		sting_timer += delta
		if has_node("Sprite2D"):
			var sprite = $Sprite2D
			if int(sting_timer * 20.0) % 2 == 0:
				sprite.self_modulate = Color(100, 100, 100, 1)
			else:
				sprite.self_modulate = Color(1, 1, 1, 1)
		return

	time_passed += delta
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		position.y = spawn_y + sin(time_passed * 1.5) * float_range
		
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		sprite.frame = int(time_passed * 6.0) % 4
		sprite.self_modulate = Color(1, 1, 1, 1)

func _on_body_entered(body: Node2D) -> void:
	if body.is_multiplayer_authority() and body.has_method("shock"):
		body.shock(stun_duration)
		sting.rpc()

@rpc("any_peer", "call_local", "reliable")
func sting() -> void:
	if is_stinging: return
	is_stinging = true
	sting_timer = 0.0
	
	await get_tree().create_timer(1.0).timeout
	
	is_stinging = false
