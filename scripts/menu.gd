extends Node2D

@onready var titlecard: Sprite2D = $titlecard
@onready var titletext: Label = $titletext

@onready var main_panel: PanelContainer = $CanvasLayer/CenterContainer/MainPanel
@onready var lobby_panel: PanelContainer = $CanvasLayer/CenterContainer/LobbyPanel

@onready var name_input: LineEdit = $CanvasLayer/CenterContainer/MainPanel/MarginContainer/VBoxContainer/NameBox/NameInput
@onready var ip_input: LineEdit = $CanvasLayer/CenterContainer/MainPanel/MarginContainer/VBoxContainer/IPBox/IPInput
@onready var host_button: Button = $CanvasLayer/CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsBox/HostButton
@onready var join_button: Button = $CanvasLayer/CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsBox/JoinButton
@onready var status_label: Label = $CanvasLayer/CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

@onready var player_list_label: Label = $CanvasLayer/CenterContainer/LobbyPanel/MarginContainer/VBoxContainer/PlayerList
@onready var start_button: Button = $CanvasLayer/CenterContainer/LobbyPanel/MarginContainer/VBoxContainer/StartButton
@onready var leave_button: Button = $CanvasLayer/CenterContainer/LobbyPanel/MarginContainer/VBoxContainer/LeaveButton

func _ready() -> void:
	titlecard.visible = false
	titletext.visible = false
	
	name_input.text = "Diver_" + str(randi() % 999)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	MultiplayerManager.player_list_changed.connect(_on_player_list_changed)
	MultiplayerManager.connection_status.connect(_on_connection_status)

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

func _on_player_list_changed() -> void:
	var list_text = "Players connected:\n"
	for peer_id in MultiplayerManager.players:
		var p_info = MultiplayerManager.players[peer_id]
		var suffix = " (Host)" if peer_id == 1 else ""
		list_text += "- " + p_info["name"] + suffix + "\n"
	player_list_label.text = list_text
	
	if multiplayer.multiplayer_peer != null:
		main_panel.visible = false
		lobby_panel.visible = true

func _on_connection_status(success: bool, message: String) -> void:
	status_label.text = "Status: " + message
	if not success:
		lobby_panel.visible = false
		main_panel.visible = true
		start_button.visible = false
