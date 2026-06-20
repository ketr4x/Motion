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

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if multiplayer.is_server():
		spawn_players()
		var level_seed = randi()
		$LevelGenerator.generate_level(level_seed)
		$ShoalTimer.timeout.connect(_on_shoal_timer_timeout)
	else:
		$ShoalTimer.stop()
		
	setup_hud()

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
	if local_player == null:
		var peer_id = multiplayer.get_unique_id()
		var player_node = get_node_or_null(str(peer_id))
		if player_node != null and player_node.is_multiplayer_authority():
			local_player = player_node
	
	if local_player != null:
		var depth_m = max(0, int(local_player.position.y / 10))
		depth_label.text = "Depth: " + str(depth_m) + "m"
		
		if oxygen_bar:
			oxygen_bar.value = local_player.oxygen
			if oxygen_bar_fill:
				if local_player.oxygen > 50:
					oxygen_bar_fill.bg_color = Color(0.2, 0.8, 0.4)
				elif local_player.oxygen > 20:
					oxygen_bar_fill.bg_color = Color(0.9, 0.6, 0.1)
				else:
					oxygen_bar_fill.bg_color = Color(0.9, 0.2, 0.2)

func player_died(peer_id: int) -> void:
	print("Game: Player ", peer_id, " died.")
	
	if not multiplayer.is_server():
		return
		
	player_status[peer_id] = "dead"
	
	var all_dead = true
	for p_id in player_status:
		if player_status[p_id] == "alive":
			all_dead = false
			break
			
	if all_dead:
		print("Game: All players are dead. Game Over!")
		transition_to_death.rpc()
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
			respawn_player.rpc(peer_id, survivor_pos)

@rpc("authority", "call_local", "reliable")
func respawn_player(peer_id: int, pos: Vector2) -> void:
	var player_node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.respawn(pos)

@rpc("authority", "call_local", "reliable")
func transition_to_death() -> void:
	call_deferred("_transition_to_death")

func _transition_to_death() -> void:
	multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_shoal_timer_timeout() -> void:
	if not multiplayer.is_server():
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
	
	if multiplayer.is_server():
		var all_dead = true
		for p_id in player_status:
			if player_status[p_id] == "alive":
				all_dead = false
				break
		if all_dead:
			transition_to_death.rpc()
