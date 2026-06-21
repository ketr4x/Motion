extends Area2D

@export var speed: float = 160.0
@export var push_force: float = 350.0

var fish_spritesheet: Texture2D
var fish_list = []
var time_passed: float = 0.0

func _ready() -> void:
	fish_spritesheet = preload("res://assets/rybki.png")
	var rng = RandomNumberGenerator.new()
	rng.seed = int(global_position.y)
	
	for i in range(25):
		var offset = Vector2(
			rng.randf_range(-140.0, 140.0),
			rng.randf_range(-50.0, 50.0)
		)
		var phase = rng.randf_range(0.0, PI * 2)
		var size = rng.randf_range(2.5, 3.5)
		var frame = rng.randi_range(0, 13)
		fish_list.append({
			"offset": offset,
			"phase": phase,
			"size": size,
			"frame": frame
		})

func _process(delta: float) -> void:
	time_passed += delta
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		position.x += speed * delta
		if position.x > 700:
			queue_free()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_multiplayer_authority() and body.has_method("recharge_oxygen") and not body.is_dead:
			body.velocity.y = -push_force
			body.position.y -= 8.0

func _draw() -> void:
	if fish_spritesheet == null:
		return
	for fish in fish_list:
		var pos = fish["offset"]
		var phase = fish["phase"]
		var sz = fish["size"]
		var frame = fish["frame"]
		
		var wiggle_y = sin(time_passed * 6.0 + phase) * 4.0
		var draw_pos = pos + Vector2(0, wiggle_y)
		
		var src_rect = Rect2(frame * 16, 0, 16, 16)
		var dest_size = Vector2(16, 16) * sz
		var dest_rect = Rect2(draw_pos - dest_size * 0.5, dest_size)
		
		draw_texture_rect_region(fish_spritesheet, dest_rect, src_rect)
