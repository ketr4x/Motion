extends Node2D

@export var jellyfish_scene: PackedScene = preload("res://scenes/jellyfish.tscn")
@export var oxygen_spot_scene: PackedScene = preload("res://scenes/oxygen_spot.tscn")
@export var coop_gate_scene: PackedScene = preload("res://scenes/coop_gate.tscn")
@export var bubble_boost_scene: PackedScene = preload("res://scenes/bubble_boost.tscn")
@export var chest_scene: PackedScene = preload("res://scenes/level_end_chest.tscn")

@export var start_depth: float = 300.0
@export var end_depth: float = 3600.0
@export var depth_interval: float = 180.0
@export var x_min: float = -288.0
@export var x_max: float = 288.0

var level_seed: int = 0

func generate_level(p_seed: int) -> void:
	level_seed = p_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = level_seed
	
	print("Generating level with seed: ", level_seed)
	
	var current_depth = start_depth
	var oxygen_spawn_counter = 0
	var boost_spawn_counter = 0
	
	while current_depth < end_depth:
		if abs(current_depth - 1200.0) < 10.0 or abs(current_depth - 2460.0) < 10.0:
			var gate = coop_gate_scene.instantiate()
			gate.position = Vector2(0, current_depth)
			gate.name = "CoopGate_" + str(int(current_depth))
			get_parent().add_child(gate)
			current_depth += depth_interval
			continue

		var obstacle_count = rng.randi_range(1, 2)
		var spawned_x_positions = []
		
		for i in range(obstacle_count):
			var obstacle_x = rng.randf_range(x_min, x_max)
			var too_close = false
			for prev_x in spawned_x_positions:
				if abs(prev_x - obstacle_x) < 80.0:
					too_close = true
					break
			
			if not too_close:
				spawned_x_positions.append(obstacle_x)
				var obstacle = jellyfish_scene.instantiate()
				obstacle.name = "Jellyfish_" + str(int(current_depth)) + "_" + str(i)
				obstacle.position = Vector2(obstacle_x, current_depth)
				get_parent().add_child(obstacle)
		
		oxygen_spawn_counter += 1
		if oxygen_spawn_counter >= 3:
			oxygen_spawn_counter = 0
			var ox_x = rng.randf_range(x_min, x_max)
			var valid_pos = true
			for obs_x in spawned_x_positions:
				if abs(obs_x - ox_x) < 50.0:
					valid_pos = false
					break
			if not valid_pos:
				ox_x = ox_x + 100.0 if ox_x < 0 else ox_x - 100.0
			
			var ox_spot = oxygen_spot_scene.instantiate()
			ox_spot.position = Vector2(ox_x, current_depth)
			ox_spot.name = "Oxygen_" + str(int(current_depth))
			get_parent().add_child(ox_spot)
		
		# Spawn bubble boost lanes every ~5 intervals
		boost_spawn_counter += 1
		if boost_spawn_counter >= 5:
			boost_spawn_counter = 0
			var side = -1 if rng.randf() < 0.5 else 1
			var boost_x = side * rng.randf_range(150.0, 280.0)
			var boost = bubble_boost_scene.instantiate()
			boost.position = Vector2(boost_x, current_depth)
			boost.name = "BubbleBoost_" + str(int(current_depth))
			get_parent().add_child(boost)
		current_depth += depth_interval
		
	# Spawn chest at end depth
	var chest = chest_scene.instantiate()
	chest.position = Vector2(0, end_depth)
	chest.name = "LevelEndChest"
	get_parent().add_child(chest)
