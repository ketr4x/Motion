extends Node2D

@onready var spawn_point_1: Node2D = $SpawnPoint1
@onready var spawn_point_2: Node2D = $SpawnPoint2

var player_scene = preload("res://scenes/player.tscn")
var local_player: CharacterBody2D

var hud_canvas: CanvasLayer
var oxygen_bar: ProgressBar
var depth_label: Label

func _ready() -> void:
	if multiplayer.is_server():
		spawn_players()
	setup_hud()

func spawn_players() -> void:
	var spawn_points = [spawn_point_1, spawn_point_2]
	var index = 0
	
	for peer_id in MultiplayerManager.players:
		var player_instance = player_scene.instantiate()
		player_instance.name = str(peer_id)
		
		var spawn_pos = spawn_points[index % spawn_points.size()].position
		player_instance.position = spawn_pos
		player_instance.set_multiplayer_authority(peer_id)
		
		add_child(player_instance)
		index += 1

func setup_hud() -> void:
	hud_canvas = CanvasLayer.new()
	add_child(hud_canvas)
	
	var hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_canvas.add_child(hud_root)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 60)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.2, 0.75)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_color = Color(0.2, 0.4, 0.7, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	
	hud_root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20, -80)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	var info_hbox = HBoxContainer.new()
	vbox.add_child(info_hbox)
	
	var name_label = Label.new()
	name_label.text = MultiplayerManager.local_player_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
	info_hbox.add_child(name_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_hbox.add_child(spacer)
	
	depth_label = Label.new()
	depth_label.text = "Depth: 0m"
	depth_label.add_theme_font_size_override("font_size", 12)
	depth_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info_hbox.add_child(depth_label)
	
	oxygen_bar = ProgressBar.new()
	oxygen_bar.max_value = 100.0
	oxygen_bar.value = 100.0
	oxygen_bar.show_percentage = false
	oxygen_bar.custom_minimum_size = Vector2(0, 16)
	
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.8, 0.4)
	fg_style.corner_radius_top_left = 4
	fg_style.corner_radius_top_right = 4
	fg_style.corner_radius_bottom_left = 4
	fg_style.corner_radius_bottom_right = 4
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.15, 0.2)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	
	oxygen_bar.add_theme_stylebox_override("fill", fg_style)
	oxygen_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(oxygen_bar)

func _process(_delta: float) -> void:
	if local_player == null:
		var peer_id = multiplayer.get_unique_id()
		var player_node = get_node_or_null(str(peer_id))
		if player_node != null and player_node.is_multiplayer_authority():
			local_player = player_node
	
	if local_player != null:
		oxygen_bar.value = local_player.oxygen
		
		var fill_style = oxygen_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if local_player.oxygen > 50:
				fill_style.bg_color = Color(0.2, 0.8, 0.4)
			elif local_player.oxygen > 20:
				fill_style.bg_color = Color(0.9, 0.6, 0.1)
			else:
				fill_style.bg_color = Color(0.9, 0.2, 0.2)
		
		var depth_m = max(0, int(local_player.position.y / 10))
		depth_label.text = "Depth: " + str(depth_m) + "m"

func player_died(peer_id: int) -> void:
	print("Game: Player ", peer_id, " died.")
	if peer_id == multiplayer.get_unique_id():
		call_deferred("_transition_to_death")

func _transition_to_death() -> void:
	multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
