extends Node2D

@export var spike_scene: PackedScene = preload("res://scenes/spike.tscn")
@export var jellyfish_scene: PackedScene = preload("res://scenes/jellyfish.tscn")
@export var oxygen_spot_scene: PackedScene = preload("res://scenes/oxygen_spot.tscn")

@export var start_depth: float = 300.0
@export var end_depth: float = 3600.0
@export var depth_interval: float = 180.0
@export var x_min: float = -350.0
@export var x_max: float = 350.0

var level_seed: int = 0

func generate_level(p_seed: int) -> void:
	level_seed = p_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = level_seed
	
	print("Generating level with seed: ", level_seed)
	
	var current_depth = start_depth
	var oxygen_spawn_counter = 0
	
	while current_depth < end_depth:
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
				var obstacle
				if rng.randf() < 0.4:
					obstacle = jellyfish_scene.instantiate()
					obstacle.name = "Jellyfish_" + str(int(current_depth)) + "_" + str(i)
				else:
					obstacle = spike_scene.instantiate()
					obstacle.name = "Spike_" + str(int(current_depth)) + "_" + str(i)
				
				obstacle.position = Vector2(obstacle_x, current_depth)
				get_parent().add_child(obstacle)
		
		oxygen_spawn_counter += 1
		if oxygen_spawn_counter >= 3:
			oxygen_spawn_counter = 0
			var ox_x = rng.randf_range(x_min, x_max)
			var valid_pos = true
			for spike_x in spawned_x_positions:
				if abs(spike_x - ox_x) < 50.0:
					valid_pos = false
					break
			if not valid_pos:
				ox_x = ox_x + 100.0 if ox_x < 0 else ox_x - 100.0
			
			var ox_spot = oxygen_spot_scene.instantiate()
			ox_spot.position = Vector2(ox_x, current_depth)
			ox_spot.name = "Oxygen_" + str(int(current_depth))
			get_parent().add_child(ox_spot)
		
		current_depth += depth_interval
