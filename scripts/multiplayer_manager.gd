extends Node

signal player_list_changed
signal connection_status(success: bool, message: String)
signal team_name_changed(new_name: String)

const DEFAULT_PORT = 12345
const DEFAULT_IP = "127.0.0.1"

var players = {}
var local_player_name = "Player"
var host_ip: String = ""
var team_name = ""

var signaling_url = "wss://motion-w7fu.onrender.com"
var ws_peer: WebSocketPeer = null
var rtc_peer: WebRTCMultiplayerPeer = null
var rtc_connection: WebRTCPeerConnection = null
var is_webrtc_active = false
var room_code = ""
var is_host = false
var _ws_was_connected = false
var connection_in_progress = false

var last_seed: int = 0
var last_time: float = 0.0
var show_ending_screen: bool = false
var ending_victory: bool = false

func get_best_time() -> float:
	var config = ConfigFile.new()
	var err = config.load("user://save_data.cfg")
	if err == OK:
		return config.get_value("stats", "best_time", 999999.0)
	return 999999.0

func save_best_time(new_time: float) -> bool:
	var config = ConfigFile.new()
	config.load("user://save_data.cfg")
	var current_best = config.get_value("stats", "best_time", 999999.0)
	if new_time < current_best:
		config.set_value("stats", "best_time", new_time)
		config.save("user://save_data.cfg")
		return true
	return false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func is_webrtc_available() -> bool:
	return ClassDB.class_exists("WebRTCPeerConnection")

func host_game(player_name: String, ip_method: String = "", port: int = DEFAULT_PORT) -> bool:
	local_player_name = player_name
	
	var use_enet = false
	if ip_method.contains(".") or ip_method.to_lower() == "localhost" or ip_method.to_lower() == "lan":
		use_enet = true
		
	if not use_enet and not is_webrtc_available():
		connection_status.emit(false, "WebRTC addon is missing on desktop. Falling back to local LAN.")
		use_enet = true
		
	if use_enet:
		is_webrtc_active = false
		return _host_enet(port)
	else:
		is_webrtc_active = true
		return _host_webrtc()

func _host_enet(port: int) -> bool:
	is_host = true
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error != OK:
		connection_status.emit(false, "Failed to start server: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = peer
	players[1] = { "name": local_player_name, "ready": true }
	player_list_changed.emit()
	connection_status.emit(true, "Hosting on ENet port " + str(port))
	return true

func _host_webrtc() -> bool:
	is_host = true
	
	rtc_peer = WebRTCMultiplayerPeer.new()
	var error = rtc_peer.create_server()
	if error != OK:
		connection_status.emit(false, "Failed to create WebRTC server: " + str(error))
		return false
		
	multiplayer.multiplayer_peer = rtc_peer
	
	ws_peer = WebSocketPeer.new()
	var ws_error = ws_peer.connect_to_url(signaling_url)
	if ws_error != OK:
		connection_status.emit(false, "Failed to connect to signaling server: " + str(ws_error))
		_reset_connection()
		return false
		
	connection_status.emit(true, "Connecting to signaling server...")
	return true

func join_game(player_name: String, ip: String = DEFAULT_IP, port: int = DEFAULT_PORT) -> void:
	local_player_name = player_name
	host_ip = ip
	
	connection_in_progress = true
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(func():
		if connection_in_progress:
			connection_status.emit(false, "Connection timed out.")
			_reset_connection()
	)
	
	var use_enet = false
	if ip.contains(".") or ip.to_lower() == "localhost" or ip.to_lower() == "lan":
		use_enet = true
		
	if not use_enet and not is_webrtc_available():
		connection_status.emit(false, "WebRTC addon is missing on desktop. Falling back to local LAN.")
		use_enet = true
		
	if use_enet:
		is_webrtc_active = false
		_join_enet(ip, port)
	else:
		is_webrtc_active = true
		_join_webrtc(ip)

func _join_enet(ip: String, port: int) -> void:
	is_host = false
	if ip.strip_edges() == "":
		ip = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		connection_status.emit(false, "Failed to connect: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	connection_status.emit(true, "Connecting to ENet " + ip + ":" + str(port) + "...")

func _join_webrtc(room_to_join: String) -> void:
	is_host = false
	room_code = room_to_join.strip_edges().to_upper()
	
	if room_code == "":
		connection_status.emit(false, "Please enter a valid 4-character Room Code.")
		return
		
	rtc_peer = WebRTCMultiplayerPeer.new()
	var error = rtc_peer.create_client(2)
	if error != OK:
		connection_status.emit(false, "Failed to create WebRTC client: " + str(error))
		return
		
	multiplayer.multiplayer_peer = rtc_peer
	
	ws_peer = WebSocketPeer.new()
	var ws_error = ws_peer.connect_to_url(signaling_url)
	if ws_error != OK:
		connection_status.emit(false, "Failed to connect to signaling server: " + str(ws_error))
		_reset_connection()
		return
		
	connection_status.emit(true, "Connecting to signaling server...")

func leave_game() -> void:
	_reset_connection()
	players.clear()

func _reset_connection() -> void:
	connection_in_progress = false
	if ws_peer:
		ws_peer.close()
		ws_peer = null
	_ws_was_connected = false
	rtc_connection = null
	rtc_peer = null
	multiplayer.multiplayer_peer = null

func _process(_delta: float) -> void:
	if ws_peer:
		ws_peer.poll()
		var state = ws_peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if not _ws_was_connected:
				_ws_was_connected = true
				_on_signaling_connected()
				
			while ws_peer and ws_peer.get_available_packet_count() > 0:
				var packet = ws_peer.get_packet()
				_on_signaling_message(packet.get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			if _ws_was_connected or (is_webrtc_active and not multiplayer.has_multiplayer_peer()):
				connection_status.emit(false, "Signaling server disconnected.")
				_reset_connection()
			elif is_webrtc_active and multiplayer.get_peers().size() == 0:
				connection_status.emit(false, "Failed to connect to signaling server.")
				_reset_connection()

func _on_signaling_connected() -> void:
	if is_host:
		_send_signaling_msg({ "type": "host" })
	else:
		_send_signaling_msg({ "type": "join", "room": room_code })

func _on_signaling_message(message_str: String) -> void:
	var msg = JSON.parse_string(message_str)
	if msg == null: return
	
	match msg.type:
		"hosted":
			room_code = msg.room
			connection_status.emit(true, "Hosting on WebRTC. Code: " + room_code)
			players[1] = { "name": local_player_name, "ready": true }
			player_list_changed.emit()
			
		"joined":
			room_code = msg.room
			connection_status.emit(true, "Joined room: " + room_code + ". Connecting to host...")
			if not is_host:
				_create_rtc_connection(1)
				
		"peer_connected":
			if is_host:
				_create_rtc_connection(2)
				
		"signal":
			_handle_rtc_signal(msg.data)
			
		"peer_disconnected":
			connection_status.emit(false, "Peer disconnected.")
			_reset_connection()
			
		"error":
			connection_status.emit(false, "Error: " + msg.message)
			_reset_connection()

func _send_signaling_msg(msg: Dictionary) -> void:
	if ws_peer and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(JSON.stringify(msg))

func _create_rtc_connection(target_peer_id: int) -> void:
	rtc_connection = WebRTCPeerConnection.new()
	rtc_connection.initialize({
		"iceServers": [
			{ "urls": ["stun:stun.l.google.com:19302"] }
		]
	})
	
	rtc_connection.session_description_created.connect(func(type, sdp):
		rtc_connection.set_local_description(type, sdp)
		_send_signaling_msg({
			"type": "signal",
			"data": { "type": type, "sdp": sdp }
		})
	)
	
	rtc_connection.ice_candidate_created.connect(func(media, index, name):
		_send_signaling_msg({
			"type": "signal",
			"data": {
				"type": "candidate",
				"media": media,
				"index": index,
				"name": name
			}
		})
	)
	
	rtc_peer.add_peer(rtc_connection, target_peer_id)
	
	if is_host:
		rtc_connection.create_offer()

func _handle_rtc_signal(data: Dictionary) -> void:
	if rtc_connection == null: return
	
	if data.type == "offer" or data.type == "answer":
		rtc_connection.set_remote_description(data.type, data.sdp)
	elif data.type == "candidate":
		rtc_connection.add_ice_candidate(data.media, data.index, data.name)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		register_player.rpc_id(id, local_player_name)
	else:
		connection_in_progress = false

@rpc("any_peer", "reliable")
func register_player(p_name: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = { "name": p_name, "ready": false }
	player_list_changed.emit()
	
	if multiplayer.is_server():
		sync_players.rpc(players)
		sync_team_name.rpc(team_name)

func set_team_name(new_name: String) -> void:
	team_name = new_name
	team_name_changed.emit(new_name)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_team_name.rpc(new_name)

@rpc("authority", "reliable")
func sync_team_name(new_name: String) -> void:
	team_name = new_name
	team_name_changed.emit(new_name)

@rpc("any_peer", "call_local", "reliable")
func toggle_ready() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if sender_id in players:
		players[sender_id]["ready"] = !players[sender_id].get("ready", false)
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
	connection_in_progress = false
	register_player.rpc_id(1, local_player_name)

func _on_connection_failed() -> void:
	connection_status.emit(false, "Connection to server failed.")
	_reset_connection()

func _on_server_disconnected() -> void:
	players.clear()
	player_list_changed.emit()
	connection_status.emit(false, "Server disconnected.")
	_reset_connection()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func start_game() -> void:
	if multiplayer.is_server():
		load_game_scene.rpc()

@rpc("authority", "reliable", "call_local")
func load_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
