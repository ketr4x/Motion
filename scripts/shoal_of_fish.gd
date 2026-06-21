extends Area2D

@export var speed: float = 160.0
@export var push_force: float = 350.0

var fish_list = []
var time_passed: float = 0.0

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(global_position.y)
	
	for i in range(25):
		var offset = Vector2(
			rng.randf_range(-140.0, 140.0),
			rng.randf_range(-50.0, 50.0)
		)
		var phase = rng.randf_range(0.0, PI * 2)
		var size = rng.randf_range(0.8, 1.2)
		var color = Color(rng.randf_range(0.8, 1.0), rng.randf_range(0.4, 0.6), rng.randf_range(0.1, 0.2), 0.9)
		fish_list.append({
			"offset": offset,
			"phase": phase,
			"size": size,
			"color": color
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
	for fish in fish_list:
		var pos = fish["offset"]
		var phase = fish["phase"]
		var size = fish["size"]
		var color = fish["color"]
		
		var wiggle = sin(time_passed * 16.0 + phase) * 3.0 * size
		
		var body_pts = PackedVector2Array([
			pos + Vector2(-6, 0) * size,
			pos + Vector2(-2, -3) * size,
			pos + Vector2(4, -2) * size,
			pos + Vector2(8, 0) * size,
			pos + Vector2(4, 2) * size,
			pos + Vector2(-2, 3) * size
		])
		
		var tail_pts = PackedVector2Array([
			pos + Vector2(-5, 0) * size,
			pos + Vector2(-10, -4 + wiggle) * size,
			pos + Vector2(-10, 4 + wiggle) * size
		])
		
		draw_polygon(tail_pts, [color])
		draw_polygon(body_pts, [color])
		draw_circle(pos + Vector2(4, -1) * size, 1.0 * size, Color(0.1, 0.1, 0.1, 1.0))
