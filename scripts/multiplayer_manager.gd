extends Node

signal player_list_changed
signal connection_status(success: bool, message: String)

const DEFAULT_PORT = 12345
const DEFAULT_IP = "127.0.0.1"

var players = {}
var local_player_name = "Player"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(player_name: String, port: int = DEFAULT_PORT) -> bool:
	local_player_name = player_name
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error != OK:
		connection_status.emit(false, "Failed to start server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = peer
	players[1] = { "name": local_player_name }
	player_list_changed.emit()
	connection_status.emit(true, "Hosting on port " + str(port))
	return true

func join_game(player_name: String, ip: String = DEFAULT_IP, port: int = DEFAULT_PORT) -> void:
	local_player_name = player_name
	if ip.strip_edges() == "":
		ip = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		connection_status.emit(false, "Failed to connect: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	connection_status.emit(true, "Connecting to " + ip + ":" + str(port) + "...")

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		register_player.rpc_id(id, local_player_name)

@rpc("any_peer", "reliable")
func register_player(p_name: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = { "name": p_name }
	player_list_changed.emit()
	
	if multiplayer.is_server():
		sync_players.rpc(players)

@rpc("authority", "reliable")
func sync_players(new_players: Dictionary) -> void:
	players = new_players
	player_list_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_changed.emit()

func _on_connected_to_server() -> void:
	register_player.rpc_id(1, local_player_name)

func _on_connection_failed() -> void:
	connection_status.emit(false, "Connection to server failed.")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	players.clear()
	player_list_changed.emit()
	connection_status.emit(false, "Server disconnected.")
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func start_game() -> void:
	if multiplayer.is_server():
		load_game_scene.rpc()

@rpc("authority", "reliable", "call_local")
func load_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
