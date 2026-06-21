extends Node2D

@onready var spawn_point_1: Node2D = $SpawnPoint1
@onready var spawn_point_2: Node2D = $SpawnPoint2

var player_scene = preload("res://scenes/player.tscn")
var local_player: CharacterBody2D
var player_status = {}

@onready var hud_canvas: CanvasLayer = $HUD
@onready var oxygen_bar: ProgressBar = $HUD/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/OxygenBar
@onready var depth_label: Label = $HUD/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/InfoHBox/DepthLabel
@onready var name_label: Label = $HUD/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/InfoHBox/NameLabel
var oxygen_bar_fill: StyleBoxFlat
var ready_peers = []
var game_started = false
var current_seed: int = 0
var game_start_time: float = 0.0
var game_ended: bool = false

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if multiplayer.is_server():
			$ShoalTimer.timeout.connect(_on_shoal_timer_timeout)
			register_ready_peer(1)
		else:
			$ShoalTimer.stop()
			notify_server_ready.rpc_id(1, multiplayer.get_unique_id())
	else:
		$ShoalTimer.timeout.connect(_on_shoal_timer_timeout)
		spawn_local_player_for_preview()
		
	setup_hud()

func spawn_local_player_for_preview() -> void:
	player_status.clear()
	player_status[1] = "alive"
	var player_instance = player_scene.instantiate()
	player_instance.name = "1"
	player_instance.position = spawn_point_1.position
	player_instance.set_multiplayer_authority(1)
	add_child(player_instance)
	current_seed = randi()
	$LevelGenerator.generate_level(current_seed)
	game_start_time = Time.get_ticks_msec()

@rpc("any_peer", "call_local", "reliable")
func notify_server_ready(peer_id: int) -> void:
	if multiplayer.is_server():
		register_ready_peer(peer_id)

func register_ready_peer(peer_id: int) -> void:
	if not ready_peers.has(peer_id):
		ready_peers.append(peer_id)
	check_all_ready()

func check_all_ready() -> void:
	if game_started or not multiplayer.is_server():
		return
		
	var all_ready = true
	for p_id in MultiplayerManager.players:
		if not ready_peers.has(p_id):
			all_ready = false
			break
			
	if all_ready and MultiplayerManager.players.size() > 0:
		game_started = true
		start_level_generation()

func start_level_generation() -> void:
	spawn_players()
	var level_seed = randi()
	$LevelGenerator.generate_level(level_seed)
	if multiplayer.has_multiplayer_peer():
		sync_level_seed.rpc(level_seed)
	else:
		current_seed = level_seed
		game_start_time = Time.get_ticks_msec()

@rpc("authority", "call_local", "reliable")
func sync_level_seed(p_seed: int) -> void:
	current_seed = p_seed
	game_start_time = Time.get_ticks_msec()

func spawn_players() -> void:
	var spawn_points = [spawn_point_1, spawn_point_2]
	var index = 0
	
	player_status.clear()
	for peer_id in MultiplayerManager.players:
		player_status[peer_id] = "alive"
		
		var player_instance = player_scene.instantiate()
		player_instance.name = str(peer_id)
		
		var spawn_pos = spawn_points[index % spawn_points.size()].position
		player_instance.position = spawn_pos
		player_instance.set_multiplayer_authority(peer_id)
		
		add_child(player_instance)
		index += 1

func setup_hud() -> void:
	name_label.text = MultiplayerManager.local_player_name
	oxygen_bar_fill = oxygen_bar.get_theme_stylebox("fill") as StyleBoxFlat

func _process(_delta: float) -> void:
	if not game_ended and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var all_doomed = true
		var player_nodes = []
		for peer_id in MultiplayerManager.players:
			var p_node = get_node_or_null(str(peer_id))
			if p_node:
				player_nodes.append(p_node)
				if not (p_node.is_dead or p_node.is_suffocating):
					all_doomed = false
					break
		if player_nodes.size() > 1 and all_doomed:
			var any_suffocating = false
			for p in player_nodes:
				if p.is_suffocating:
					any_suffocating = true
					break
			if any_suffocating:
				print("Game: All players are suffocating or dead. Game Over!")
				var elapsed_doomed = Time.get_ticks_msec() - game_start_time
				transition_to_death.rpc(elapsed_doomed)

	if local_player == null:
		var peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var player_node = get_node_or_null(str(peer_id))
		if player_node != null and (not multiplayer.has_multiplayer_peer() or player_node.is_multiplayer_authority()):
			local_player = player_node
	
	if local_player != null:
		var depth_m = max(0, int(local_player.position.y / 10))
		var elapsed_sec = 0.0
		if game_start_time > 0.0:
			elapsed_sec = (Time.get_ticks_msec() - game_start_time) / 1000.0
		depth_label.text = "Depth: " + str(depth_m) + "m | Time: " + format_time(elapsed_sec)
		
		if not game_ended:
			var current_depth = local_player.position.y
			if current_depth >= $LevelGenerator.end_depth:
				game_ended = true
				var elapsed_end = Time.get_ticks_msec() - game_start_time
				if multiplayer.has_multiplayer_peer():
					win_game.rpc(elapsed_end)
				else:
					win_game(elapsed_end)
		
		if oxygen_bar:
			oxygen_bar.value = local_player.oxygen
			if oxygen_bar_fill:
				if local_player.oxygen > 50:
					oxygen_bar_fill.bg_color = Color(0.2, 0.8, 0.4)
				elif local_player.oxygen > 20:
					oxygen_bar_fill.bg_color = Color(0.9, 0.6, 0.1)
				else:
					oxygen_bar_fill.bg_color = Color(0.9, 0.2, 0.2)

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	var msecs = int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, secs, msecs]

@rpc("any_peer", "call_local", "reliable")
func win_game(final_time_ms: float) -> void:
	game_ended = true
	MultiplayerManager.last_seed = current_seed
	MultiplayerManager.last_time = final_time_ms / 1000.0
	MultiplayerManager.show_ending_screen = true
	MultiplayerManager.ending_victory = true
	
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	
	call_deferred("_transition_to_menu")

func _transition_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func player_died(peer_id: int) -> void:
	print("Game: Player ", peer_id, " died.")
	
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	player_status[peer_id] = "dead"
	
	var all_dead = true
	for p_id in player_status:
		if player_status[p_id] == "alive":
			all_dead = false
			break
			
	if all_dead:
		print("Game: All players are dead. Game Over!")
		var elapsed = Time.get_ticks_msec() - game_start_time
		if multiplayer.has_multiplayer_peer():
			transition_to_death.rpc(elapsed)
		else:
			transition_to_death(elapsed)
	else:
		print("Game: Starting 5s respawn timer for player ", peer_id)
		await get_tree().create_timer(5.0).timeout
		
		if player_status.get(peer_id) == "dead" and not all_dead:
			var survivor_pos = Vector2.ZERO
			for p_id in player_status:
				if player_status[p_id] == "alive":
					var survivor_node = get_node_or_null(str(p_id))
					if survivor_node:
						survivor_pos = survivor_node.position
						break
			
			player_status[peer_id] = "alive"
			if multiplayer.has_multiplayer_peer():
				respawn_player.rpc(peer_id, survivor_pos)
			else:
				respawn_player(peer_id, survivor_pos)

@rpc("authority", "call_local", "reliable")
func respawn_player(peer_id: int, pos: Vector2) -> void:
	var player_node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.respawn(pos)

@rpc("authority", "call_local", "reliable")
func transition_to_death(final_time_ms: float) -> void:
	game_ended = true
	MultiplayerManager.last_seed = current_seed
	MultiplayerManager.last_time = final_time_ms / 1000.0
	MultiplayerManager.show_ending_screen = true
	MultiplayerManager.ending_victory = false
	
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	call_deferred("_transition_to_death")

func _transition_to_death() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_shoal_timer_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	
	var living_players = []
	for p_id in player_status:
		if player_status[p_id] == "alive":
			var p_node = get_node_or_null(str(p_id))
			if p_node:
				living_players.append(p_node)
				
	if living_players.size() > 0:
		var target_player = living_players[randi() % living_players.size()]
		var spawn_depth = target_player.position.y
		
		var shoal_scene = preload("res://scenes/shoal_of_fish.tscn")
		var shoal = shoal_scene.instantiate()
		shoal.position = Vector2(-600, spawn_depth)
		shoal.name = "Shoal_" + str(Time.get_ticks_msec())
		add_child(shoal)

func _on_peer_disconnected(id: int) -> void:
	if id in player_status:
		player_status.erase(id)
	if id in ready_peers:
		ready_peers.erase(id)
	
	if multiplayer.is_server():
		if not game_started:
			check_all_ready()
		else:
			var all_dead = true
			for p_id in player_status:
				if player_status[p_id] == "alive":
					all_dead = false
					break
			if all_dead:
				var elapsed = Time.get_ticks_msec() - game_start_time
				transition_to_death.rpc(elapsed)
