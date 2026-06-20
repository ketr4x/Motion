extends Node2D

@onready var main_panel: PanelContainer = $CanvasLayer/VBoxContainer/UIContainer/MainPanel
@onready var lobby_panel: PanelContainer = $CanvasLayer/VBoxContainer/UIContainer/LobbyPanel
@onready var settings_panel: PanelContainer = $CanvasLayer/VBoxContainer/UIContainer/SettingsPanel
@onready var ui_container: CenterContainer = $CanvasLayer/VBoxContainer/UIContainer

@onready var boat_player_1: ColorRect = $CanvasLayer/VBoxContainer/WorldContainer/Boat/Player1
@onready var boat_player_2: ColorRect = $CanvasLayer/VBoxContainer/WorldContainer/Boat/Player2

@onready var name_input: LineEdit = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/NameBox/NameInput
@onready var ip_input: LineEdit = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/IPBox/IPInput
@onready var host_button: Button = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsBox/HostButton
@onready var join_button: Button = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsBox/JoinButton
@onready var settings_button: Button = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsBox/SettingsButton
@onready var status_label: Label = $CanvasLayer/VBoxContainer/UIContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

@onready var player_list_label: Label = $CanvasLayer/VBoxContainer/UIContainer/LobbyPanel/MarginContainer/VBoxContainer/PlayerList
@onready var start_button: Button = $CanvasLayer/VBoxContainer/UIContainer/LobbyPanel/MarginContainer/VBoxContainer/ButtonsBox/StartButton
@onready var leave_button: Button = $CanvasLayer/VBoxContainer/UIContainer/LobbyPanel/MarginContainer/VBoxContainer/ButtonsBox/LeaveButton
@onready var settings_back_button: Button = $CanvasLayer/VBoxContainer/UIContainer/SettingsPanel/MarginContainer/VBoxContainer/SettingsBackButton

@onready var resolution_btn: OptionButton = $CanvasLayer/VBoxContainer/UIContainer/SettingsPanel/MarginContainer/VBoxContainer/ResolutionBox/ResolutionBtn
@onready var fullscreen_check: CheckBox = $CanvasLayer/VBoxContainer/UIContainer/SettingsPanel/MarginContainer/VBoxContainer/FullscreenBox/FullscreenCheck
@onready var volume_slider: HSlider = $CanvasLayer/VBoxContainer/UIContainer/SettingsPanel/MarginContainer/VBoxContainer/VolumeBox/VolumeSlider



func _ready() -> void:	
	name_input.text = "Diver_" + str(randi() % 999)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	
	MultiplayerManager.player_list_changed.connect(_on_player_list_changed)
	MultiplayerManager.connection_status.connect(_on_connection_status)
	
	# Setup Resolution OptionButton
	resolution_btn.clear()
	resolution_btn.add_item("1280x720")
	resolution_btn.add_item("1600x900")
	resolution_btn.add_item("1920x1080")
	resolution_btn.item_selected.connect(_on_resolution_selected)
	
	var current_size = DisplayServer.window_get_size()
	if current_size == Vector2i(1280, 720):
		resolution_btn.selected = 0
	elif current_size == Vector2i(1600, 900):
		resolution_btn.selected = 1
	elif current_size == Vector2i(1920, 1080):
		resolution_btn.selected = 2
	else:
		resolution_btn.selected = 0
		
	# Fullscreen CheckBox
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	# Volume Slider
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var vol_db = AudioServer.get_bus_volume_db(master_bus_idx)
	volume_slider.value = db_to_linear(vol_db)
	volume_slider.value_changed.connect(_on_volume_changed)


func _on_host_pressed() -> void:
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		name_text = "Host"
	if MultiplayerManager.host_game(name_text):
		main_panel.visible = false
		lobby_panel.visible = true
		start_button.visible = true

func _on_join_pressed() -> void:
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		name_text = "Client"
	var ip_text = ip_input.text.strip_edges()
	if ip_text == "":
		ip_text = "127.0.0.1"
	
	MultiplayerManager.join_game(name_text, ip_text)

func _on_start_pressed() -> void:
	MultiplayerManager.start_game()

func _on_leave_pressed() -> void:
	multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	lobby_panel.visible = false
	main_panel.visible = true
	start_button.visible = false
	status_label.text = "Status: Disconnected"
	_on_player_list_changed()

func _on_player_list_changed() -> void:
	var list_text = "Players connected:\n"
	for peer_id in MultiplayerManager.players:
		var p_info = MultiplayerManager.players[peer_id]
		var suffix = " (Host)" if peer_id == 1 else ""
		list_text += "- " + p_info["name"] + suffix + "\n"
	player_list_label.text = list_text
	
	# Update player boxes visibility on the boat deck
	boat_player_1.visible = 1 in MultiplayerManager.players
	boat_player_2.visible = MultiplayerManager.players.size() > 1
	
	if multiplayer.multiplayer_peer != null:
		main_panel.visible = false
		lobby_panel.visible = true

func _on_connection_status(success: bool, message: String) -> void:
	status_label.text = "Status: " + message
	if not success:
		lobby_panel.visible = false
		main_panel.visible = true
		start_button.visible = false
		_on_player_list_changed()


func _on_settings_pressed() -> void:
	main_panel.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	main_panel.visible = true

func _on_resolution_selected(index: int) -> void:
	var size = Vector2i(1280, 720)
	match index:
		0:
			size = Vector2i(1280, 720)
		1:
			size = Vector2i(1600, 900)
		2:
			size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(size)
	
	# Center window on screen
	var screen = DisplayServer.window_get_current_screen()
	var screen_rect = DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - size) / 2)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
