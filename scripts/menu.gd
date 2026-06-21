extends Node2D

@export var cloud_textures: Array[Texture2D] = []

const CLOUD_SPEED := 45.0
const CLOUD_COUNT := 2
const CLOUD_Y_MIN := 50.0
const CLOUD_Y_MAX := 250.0
const CLOUD_SCALE := Vector2(16, 16)
const REFLECTION_BASE_ALPHA := 0.45

const WATERLINE_Y := 680.0

const LOGO_BOB_AMP := 15.0
const LOGO_BOB_DURATION := 0.75

@onready var sky_rect: ColorRect = $CanvasLayer/SkyRect
@onready var ocean_rect: ColorRect = $CanvasLayer/OceanRect

@onready var clouds_container: Node2D = $CanvasLayer/CloudsContainer
@onready var reflections_container: Node2D = $CanvasLayer/ReflectionsContainer

@onready var wind_particles: CPUParticles2D = $CanvasLayer/WindParticles
@onready var bubble_particles: CPUParticles2D = $CanvasLayer/BubbleParticles

@onready var ship_bg: AnimatedSprite2D = $CanvasLayer/ShipBG

@onready var logo: AnimatedSprite2D = $CanvasLayer/Logo

@onready var ui_container: Control = $CanvasLayer/UIContainer
@onready var window_title_bar: PanelContainer = $CanvasLayer/UIContainer/VBox/WindowTitleBar
@onready var min_btn: Button = $CanvasLayer/UIContainer/VBox/WindowTitleBar/HBox/MinBtn
@onready var close_btn: Button = $CanvasLayer/UIContainer/VBox/WindowTitleBar/HBox/CloseBtn

@onready var name_input: LineEdit = $CanvasLayer/UIContainer/VBox/NameInput
@onready var ip_input: LineEdit = $CanvasLayer/UIContainer/VBox/IPInput
@onready var host_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/HostButton
@onready var join_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/JoinButton
@onready var settings_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/SettingsButton
@onready var status_label: Label = $CanvasLayer/UIContainer/VBox/StatusLabel

@onready var lobby_panel: PanelContainer = $CanvasLayer/LobbyPanel
@onready var player_list_label: Label = $CanvasLayer/LobbyPanel/VBox/PlayerList
@onready var start_button: Button = $CanvasLayer/LobbyPanel/VBox/ButtonsBox/StartButton
@onready var leave_button: Button = $CanvasLayer/LobbyPanel/VBox/ButtonsBox/LeaveButton
@onready var team_input: LineEdit = $CanvasLayer/LobbyPanel/VBox/TeamBox/TeamInput

@onready var settings_panel: PanelContainer = $CanvasLayer/SettingsPanel
@onready var settings_back_button: Button = $CanvasLayer/SettingsPanel/VBox/SettingsBackButton
@onready var resolution_btn: OptionButton = $CanvasLayer/SettingsPanel/VBox/ResolutionBox/ResolutionBtn
@onready var fullscreen_check: CheckBox = $CanvasLayer/SettingsPanel/VBox/FullscreenBox/FullscreenCheck
@onready var volume_slider: HSlider = $CanvasLayer/SettingsPanel/VBox/VolumeBox/VolumeSlider

@onready var ending_panel: PanelContainer = $CanvasLayer/EndingPanel
@onready var ending_status_label: Label = $CanvasLayer/EndingPanel/VBox/StatusLabel
@onready var ending_seed_label: Label = $CanvasLayer/EndingPanel/VBox/StatsVBox/SeedLabel
@onready var ending_time_label: Label = $CanvasLayer/EndingPanel/VBox/StatsVBox/TimeLabel
@onready var ending_best_time_label: Label = $CanvasLayer/EndingPanel/VBox/StatsVBox/BestTimeLabel
@onready var ending_wr_label: Label = $CanvasLayer/EndingPanel/VBox/StatsVBox/WRLabel
@onready var ending_back_button: Button = $CanvasLayer/EndingPanel/VBox/EndingBackButton
@onready var leaderboard_panel: PanelContainer = $CanvasLayer/LeaderboardPanel
@onready var leaderboard_list_label: Label = $CanvasLayer/LeaderboardPanel/VBox/LeaderboardList

var clouds: Array[Sprite2D] = []
var reflections: Array[Sprite2D] = []
var logo_flash_timer: Timer
var is_background_paused := false

var dragging_window := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#639BFF"))
	_setup_seamless_colors()
	_spawn_clouds()
	_setup_logo()
	_setup_ui()
	_setup_networking()
	_setup_settings()
	_setup_ending()

func _process(delta: float) -> void:
	_update_clouds(delta)

func _setup_seamless_colors() -> void:
	var tex := load("res://assets/mainmenumotionfile.png") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return

	var sky_color := img.get_pixel(img.get_width() / 2, 0)
	sky_rect.color = sky_color
	ocean_rect.color = Color("#639bff")

func _spawn_clouds() -> void:
	if cloud_textures.is_empty():
		return

	var spacing := 4000.0 / CLOUD_COUNT
	for i in CLOUD_COUNT:
		var cloud := Sprite2D.new()
		cloud.texture = cloud_textures[randi() % cloud_textures.size()]
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var base_x := i * spacing + randf_range(100, 1000)
		cloud.position = Vector2(base_x, randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX))
		cloud.scale = CLOUD_SCALE
		clouds_container.add_child(cloud)
		clouds.append(cloud)

		var reflection := Sprite2D.new()
		reflection.texture = cloud.texture
		reflection.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		reflection.flip_v = true
		reflection.scale = CLOUD_SCALE
		reflection.position = Vector2(cloud.position.x, 2.0 * WATERLINE_Y - cloud.position.y)
		reflection.modulate = Color(1, 1, 1, REFLECTION_BASE_ALPHA)
		reflections_container.add_child(reflection)
		reflections.append(reflection)

func _update_clouds(delta: float) -> void:
	if is_background_paused: return

	for i in clouds.size():
		clouds[i].position.x -= CLOUD_SPEED * delta

		if clouds[i].position.x < -400:
			clouds[i].position.x = 4000 + randf_range(0, 1500)
			clouds[i].position.y = randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX)
			clouds[i].texture = cloud_textures[randi() % cloud_textures.size()]
			reflections[i].texture = clouds[i].texture
			reflections[i].position.y = 2.0 * WATERLINE_Y - clouds[i].position.y
			reflections[i].modulate.a = REFLECTION_BASE_ALPHA

		reflections[i].position.x = clouds[i].position.x

func pause_background() -> void:
	is_background_paused = true
	ship_bg.pause()
	logo.pause()
	wind_particles.speed_scale = 0.0
	bubble_particles.speed_scale = 0.0

func resume_background() -> void:
	is_background_paused = false
	ship_bg.play()
	logo.play()
	wind_particles.speed_scale = 1.0
	bubble_particles.speed_scale = 1.0

func _setup_logo() -> void:
	logo.play("flash")
	logo.animation_finished.connect(_on_logo_animation_finished)

	_start_logo_bobbing()

	logo_flash_timer = Timer.new()
	logo_flash_timer.one_shot = true
	logo_flash_timer.timeout.connect(_on_logo_flash_timeout)
	add_child(logo_flash_timer)
	_schedule_next_flash()

func _start_logo_bobbing() -> void:
	var tween_pos := create_tween().set_loops()
	var base_y := logo.position.y

	tween_pos.tween_property(logo, "position:y", base_y + LOGO_BOB_AMP, LOGO_BOB_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween_pos.tween_property(logo, "position:y", base_y, LOGO_BOB_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _schedule_next_flash() -> void:
	logo_flash_timer.start(randf_range(5.0, 10.0))

func _on_logo_flash_timeout() -> void:
	if not is_background_paused:
		logo.play("flash")
	else:
		_schedule_next_flash()

func _on_logo_animation_finished() -> void:
	if logo.animation == &"flash":
		logo.play("idle")
		_schedule_next_flash()

func _setup_ui() -> void:
	name_input.text = "Diver_" + str(randi() % 999)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	
	team_input.text_changed.connect(_on_team_name_changed)
	MultiplayerManager.team_name_changed.connect(_on_team_name_changed_from_manager)

	window_title_bar.gui_input.connect(_on_title_bar_gui_input)
	min_btn.pressed.connect(_on_window_close_or_min)
	close_btn.pressed.connect(_on_window_close_or_min)

func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_window = true
				drag_offset = event.global_position - ui_container.global_position
			else:
				dragging_window = false
	elif event is InputEventMouseMotion and dragging_window:
		ui_container.global_position = event.global_position - drag_offset

func _on_window_close_or_min() -> void:
	ui_container.visible = false
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): ui_container.visible = true)

func _setup_networking() -> void:
	MultiplayerManager.player_list_changed.connect(_on_player_list_changed)
	MultiplayerManager.connection_status.connect(_on_connection_status)

func _setup_settings() -> void:
	resolution_btn.clear()
	resolution_btn.add_item("1280x720")
	resolution_btn.add_item("1600x900")
	resolution_btn.add_item("1920x1080")
	resolution_btn.item_selected.connect(_on_resolution_selected)

	var current_size := DisplayServer.window_get_size()
	if current_size == Vector2i(1280, 720):
		resolution_btn.selected = 0
	elif current_size == Vector2i(1600, 900):
		resolution_btn.selected = 1
	elif current_size == Vector2i(1920, 1080):
		resolution_btn.selected = 2
	else:
		resolution_btn.selected = 2

	var current_mode := DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	var master_bus_idx := AudioServer.get_bus_index("Master")
	var vol_db := AudioServer.get_bus_volume_db(master_bus_idx)
	volume_slider.value = db_to_linear(vol_db)
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_host_pressed() -> void:
	var name_text := name_input.text.strip_edges()
	if name_text == "":
		name_text = "Host"
	
	ui_container.visible = false
	lobby_panel.visible = true
	player_list_label.text = "Status: Initializing connection...\n\n(Starting connection to signaling server...)"
	start_button.visible = true
	pause_background()
	
	MultiplayerManager.team_name = ""
	team_input.text = ""
	
	if not MultiplayerManager.host_game(name_text, ip_input.text):
		lobby_panel.visible = false
		ui_container.visible = true
		start_button.visible = false
		resume_background()

func _on_join_pressed() -> void:
	if join_button.text == "Cancel":
		MultiplayerManager.leave_game()
		join_button.text = "Join"
		host_button.disabled = false
		settings_button.disabled = false
		ip_input.editable = true
		name_input.editable = true
		status_label.text = "Status: Connection cancelled."
		return

	var name_text := name_input.text.strip_edges()
	if name_text == "":
		name_text = "Client"
	var ip_text := ip_input.text.strip_edges()
	if ip_text == "":
		status_label.text = "Status: Please enter a Room Code or IP address."
		return

	join_button.text = "Cancel"
	host_button.disabled = true
	settings_button.disabled = true
	ip_input.editable = false
	name_input.editable = false

	MultiplayerManager.team_name = ""
	team_input.text = ""

	MultiplayerManager.join_game(name_text, ip_text)

func _on_start_pressed() -> void:
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if local_id == 1:
		MultiplayerManager.start_game()
	else:
		MultiplayerManager.toggle_ready.rpc()

func _on_leave_pressed() -> void:
	MultiplayerManager.leave_game()
	lobby_panel.visible = false
	ui_container.visible = true
	start_button.visible = false
	status_label.text = "Status: Disconnected"
	resume_background()
	_on_player_list_changed()
	
	# Reset join buttons/fields in case we were connecting or in a lobby
	join_button.text = "Join"
	host_button.disabled = false
	settings_button.disabled = false
	ip_input.editable = true
	name_input.editable = true

func _on_player_list_changed() -> void:
	var is_host = true
	if multiplayer.multiplayer_peer != null:
		is_host = multiplayer.is_server()
	
	team_input.editable = is_host
	if is_host:
		team_input.placeholder_text = "Enter team name..."
	else:
		team_input.placeholder_text = "Waiting for host to set team name..."

	var list_text := "Players connected:\n"
	var all_ready = true
	var players_dict = MultiplayerManager.players
	var has_client = players_dict.size() > 1

	for peer_id in players_dict:
		var p_info: Dictionary = players_dict[peer_id]
		var suffix := " (Host)" if peer_id == 1 else ""
		var ready_status = " [READY]" if p_info.get("ready", false) else " [NOT READY]"
		list_text += "- " + p_info["name"] + suffix + ready_status + "\n"
		if not p_info.get("ready", false):
			all_ready = false

	if multiplayer.multiplayer_peer != null:
		if is_host:
			if MultiplayerManager.is_webrtc_active:
				list_text += "\nRoom Code: " + MultiplayerManager.room_code
				list_text += "\n(Share this code with the other player)"
			else:
				var ips: Array[String] = []
				for ip in IP.get_local_addresses():
					if ip.contains(":") or ip == "127.0.0.1" or ip.begins_with("169.254."):
						continue
					ips.append(ip)
				if ips.size() > 0:
					list_text += "\nHost LAN IP: " + ", ".join(ips)
					list_text += "\n(Connect using this IP address)"
		else:
			if MultiplayerManager.is_webrtc_active:
				list_text += "\nRoom Code: " + MultiplayerManager.room_code
			else:
				list_text += "\nConnected to: " + MultiplayerManager.host_ip

	player_list_label.text = list_text

	if multiplayer.multiplayer_peer != null:
		ui_container.visible = false
		lobby_panel.visible = true
		pause_background()

		var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		if local_id == 1:
			start_button.visible = true
			start_button.text = "Start Game"
			var team_name_ok = team_input.text.strip_edges() != ""
			start_button.disabled = not all_ready or not has_client or not team_name_ok
		else:
			start_button.visible = true
			start_button.disabled = false
			var local_ready = players_dict.get(local_id, {}).get("ready", false)
			start_button.text = "Unready" if local_ready else "Ready"

func _on_connection_status(success: bool, message: String) -> void:
	status_label.text = "Status: " + message
	if not success:
		lobby_panel.visible = false
		ui_container.visible = true
		start_button.visible = false
		resume_background()
		_on_player_list_changed()
		
		# Reset buttons
		join_button.text = "Join"
		host_button.disabled = false
		settings_button.disabled = false
		ip_input.editable = true
		name_input.editable = true
	else:
		if lobby_panel.visible and MultiplayerManager.players.is_empty():
			player_list_label.text = "Status: " + message + "\n\n(This might take up to a minute if the signaling server is waking up...)"

func _on_settings_pressed() -> void:
	ui_container.visible = false
	settings_panel.visible = true
	pause_background()

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	ui_container.visible = true
	resume_background()

func _on_resolution_selected(index: int) -> void:
	var size := Vector2i(1920, 1080)
	match index:
		0:
			size = Vector2i(1280, 720)
		1:
			size = Vector2i(1600, 900)
		2:
			size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(size)

	var screen := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - size) / 2)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_volume_changed(value: float) -> void:
	var master_bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))

func _setup_ending() -> void:
	ending_back_button.pressed.connect(_on_ending_back_pressed)

	if MultiplayerManager.show_ending_screen:
		MultiplayerManager.show_ending_screen = false

		ui_container.visible = false
		ending_panel.visible = true
		leaderboard_panel.visible = true
		pause_background()

		if MultiplayerManager.ending_victory:
			ending_status_label.text = "VICTORY!"
			ending_status_label.add_theme_color_override("font_color", Color(0.1, 0.7, 0.2))
		else:
			ending_status_label.text = "DEFEAT!"
			ending_status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

		ending_seed_label.text = "Seed: " + str(MultiplayerManager.last_seed)

		ending_time_label.text = "Time: " + format_time(MultiplayerManager.last_time)

		var pb_changed = false
		if MultiplayerManager.ending_victory:
			pb_changed = MultiplayerManager.save_best_time(MultiplayerManager.last_time)

		var best_time = MultiplayerManager.get_best_time()
		if pb_changed and MultiplayerManager.ending_victory:
			ending_best_time_label.text = "Best Time: " + format_time(best_time) + " (NEW PB!)"
		elif best_time < 999999.0:
			ending_best_time_label.text = "Best Time: " + format_time(best_time)
		else:
			ending_best_time_label.text = "Best Time: --:--.--"


		ending_wr_label.text = "WR: --:--.--"

		# Animated entrance
		ending_panel.modulate = Color(1, 1, 1, 0)
		ending_panel.scale = Vector2(0.8, 0.8)
		await get_tree().process_frame
		ending_panel.pivot_offset = ending_panel.size / 2.0
		var tween_end = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween_end.tween_property(ending_panel, "modulate:a", 1.0, 0.5)
		tween_end.parallel().tween_property(ending_panel, "scale", Vector2(1.0, 1.0), 0.6)
		
		if MultiplayerManager.ending_victory:
			# Flash effect on victory
			ending_status_label.modulate = Color(3.0, 3.0, 3.0, 1.0)
			var flash_tween = create_tween()
			flash_tween.tween_property(ending_status_label, "modulate", Color(1, 1, 1, 1), 0.8)


		_update_talo_leaderboard()

func _update_talo_leaderboard() -> void:
	leaderboard_list_label.text = "Connecting to Talo..."

	var t_name = MultiplayerManager.team_name
	if t_name.strip_edges() == "":
		t_name = "Team"

	var player = await Talo.players.identify("username", t_name)
	if player == null:
		leaderboard_list_label.text = "Failed to authenticate with Talo.\nMake sure settings.cfg has a valid access_key."
		return

	if MultiplayerManager.ending_victory:
		leaderboard_list_label.text = "Submitting score..."
		var res = await Talo.leaderboards.add_entry("speedrun_times", MultiplayerManager.last_time)
		if res == null:
			print("Talo Error: Failed to submit score. Make sure the leaderboard 'speedrun_times' is created in the Talo dashboard.")

	leaderboard_list_label.text = "Loading global scores..."
	var options = LeaderboardsAPI.GetEntriesOptions.new()
	options.page = 0
	var entries_page = await Talo.leaderboards.get_entries("speedrun_times", options)

	if entries_page == null:
		leaderboard_list_label.text = "Failed to load leaderboard.\nMake sure a leaderboard named 'speedrun_times'\nexists in the Talo dashboard."
		return

	if entries_page.entries.size() == 0:
		leaderboard_list_label.text = "No scores submitted yet!\nBe the first to set a record!"
		ending_wr_label.text = "WR: --:--.--"
		return

	var list_text = ""
	var rank = 1
	for entry in entries_page.entries:
		if rank > 20:
			break
		var name_str = entry.player_alias.identifier
		var score_str = format_time(entry.score)
		list_text += "%d. %s - %s\n" % [rank, name_str, score_str]
		if rank == 1:
			ending_wr_label.text = "WR: %s" % score_str
		rank += 1

	leaderboard_list_label.text = list_text

func _on_ending_back_pressed() -> void:
	ending_panel.visible = false
	leaderboard_panel.visible = false
	ui_container.visible = true
	resume_background()

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	var msecs = int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, secs, msecs]

func play_start_transition() -> void:
	var tween = create_tween().set_parallel(true)
	if lobby_panel.visible:
		lobby_panel.pivot_offset = lobby_panel.size / 2.0
		tween.tween_property(lobby_panel, "scale", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	if ui_container.visible:
		ui_container.pivot_offset = ui_container.size / 2.0
		tween.tween_property(ui_container, "scale", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	
	ocean_rect.size.y = 5000.0
	tween.tween_property($CanvasLayer, "offset:y", -3000.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
func _on_team_name_changed(new_text: String) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			MultiplayerManager.set_team_name(new_text)
	else:
		MultiplayerManager.team_name = new_text
	_on_player_list_changed()

func _on_team_name_changed_from_manager(new_name: String) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		if team_input.text != new_name:
			team_input.text = new_name
			_on_player_list_changed()
