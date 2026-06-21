extends Node2D

# ─── Cloud textures set in inspector (AtlasTextures from clouds.png) ─────────
@export var cloud_textures: Array[Texture2D] = []

# ─── Constants ───────────────────────────────────────────────────────────────
const CLOUD_SPEED := 35.0        # pixels per second
const CLOUD_COUNT := 5           # clouds across the sky
const CLOUD_Y_MIN := 180.0       # top boundary for cloud spawn (below logo)
const CLOUD_Y_MAX := 520.0       # bottom boundary for cloud spawn (above ship)
const CLOUD_SCALE := Vector2(8, 8)
const REFLECTION_BASE_ALPHA := 0.25

var WATERLINE_Y := 540.0         # Will be dynamically updated on resize

# Logo animation settings
const LOGO_BOB_AMP := 12.0       # Pixels to bob up and down
const LOGO_BOB_DURATION := 0.75  # Matches 4fps ship loop (0.75s down, 0.75s up = 1.5s total)

# ─── Node references ────────────────────────────────────────────────────────
# Background
@onready var sky_rect: ColorRect = $CanvasLayer/SkyRect
@onready var ocean_rect: ColorRect = $CanvasLayer/OceanRect

# Clouds
@onready var clouds_container: Node2D = $CanvasLayer/CloudsContainer
@onready var reflections_container: Node2D = $CanvasLayer/ReflectionsContainer

# Ship
@onready var ship_bg: AnimatedSprite2D = $CanvasLayer/ShipBG

# Logo
@onready var logo: AnimatedSprite2D = $CanvasLayer/Logo

# Main UI
@onready var ui_container: Control = $CanvasLayer/UIContainer
@onready var name_input: LineEdit = $CanvasLayer/UIContainer/VBox/NameInput
@onready var ip_input: LineEdit = $CanvasLayer/UIContainer/VBox/IPInput
@onready var host_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/HostButton
@onready var join_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/JoinButton
@onready var settings_button: Button = $CanvasLayer/UIContainer/VBox/ButtonsHBox/SettingsButton
@onready var status_label: Label = $CanvasLayer/UIContainer/VBox/StatusLabel

# Lobby
@onready var lobby_panel: PanelContainer = $CanvasLayer/LobbyPanel
@onready var player_list_label: Label = $CanvasLayer/LobbyPanel/MarginContainer/VBox/PlayerList
@onready var start_button: Button = $CanvasLayer/LobbyPanel/MarginContainer/VBox/ButtonsBox/StartButton
@onready var leave_button: Button = $CanvasLayer/LobbyPanel/MarginContainer/VBox/ButtonsBox/LeaveButton

# Settings
@onready var settings_panel: PanelContainer = $CanvasLayer/SettingsPanel
@onready var settings_back_button: Button = $CanvasLayer/SettingsPanel/MarginContainer/VBox/SettingsBackButton
@onready var resolution_btn: OptionButton = $CanvasLayer/SettingsPanel/MarginContainer/VBox/ResolutionBox/ResolutionBtn
@onready var fullscreen_check: CheckBox = $CanvasLayer/SettingsPanel/MarginContainer/VBox/FullscreenBox/FullscreenCheck
@onready var volume_slider: HSlider = $CanvasLayer/SettingsPanel/MarginContainer/VBox/VolumeBox/VolumeSlider

# ─── Internal state ──────────────────────────────────────────────────────────
var clouds: Array[Sprite2D] = []
var reflections: Array[Sprite2D] = []
var logo_flash_timer: Timer


# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_setup_seamless_colors()
	_on_viewport_resized() # Initial size update
	_spawn_clouds()
	_setup_logo()
	_setup_ui()
	_setup_networking()
	_setup_settings()


func _process(delta: float) -> void:
	_update_clouds(delta)


# ═════════════════════════════════════════════════════════════════════════════
# DYNAMIC RESIZING
# ═════════════════════════════════════════════════════════════════════════════

func _on_viewport_resized() -> void:
	var sz := get_viewport_rect().size
	
	# Scale ship to fit screen width (112 is the frame width)
	var s_scale := sz.x / 112.0
	ship_bg.scale = Vector2(s_scale, s_scale)
	
	# Center ship in middle of screen
	ship_bg.position = Vector2(sz.x / 2.0, sz.y / 2.0)
	
	# Keep logo centered horizontally
	logo.position.x = sz.x / 2.0
	
	# Calculate waterline (water starts roughly halfway down the 60px frame)
	WATERLINE_Y = (sz.y / 2.0) + (s_scale * 8.0)
	ocean_rect.anchor_top = WATERLINE_Y / sz.y


# ═════════════════════════════════════════════════════════════════════════════
# VISUAL SETUP
# ═════════════════════════════════════════════════════════════════════════════

func _setup_seamless_colors() -> void:
	var tex := load("res://assets/mainmenumotionfile.png") as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return

	var sky_color := img.get_pixel(img.get_width() / 2, 0)
	var ocean_color := img.get_pixel(img.get_width() / 2, img.get_height() - 1)
	sky_rect.color = sky_color
	ocean_rect.color = ocean_color


func _spawn_clouds() -> void:
	if cloud_textures.is_empty():
		return

	# Spread clouds evenly across a large viewport width with some randomness
	var spacing := 2200.0 / CLOUD_COUNT
	for i in CLOUD_COUNT:
		var cloud := Sprite2D.new()
		cloud.texture = cloud_textures[randi() % cloud_textures.size()]
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var base_x := i * spacing + randf_range(-100, 100)
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
		var dist := absf(reflection.position.y - WATERLINE_Y)
		reflection.modulate = Color(1, 1, 1, clampf(REFLECTION_BASE_ALPHA - dist * 0.0003, 0.01, REFLECTION_BASE_ALPHA))
		reflections_container.add_child(reflection)
		reflections.append(reflection)


func _update_clouds(delta: float) -> void:
	for i in clouds.size():
		clouds[i].position.x -= CLOUD_SPEED * delta

		if clouds[i].position.x < -200:
			clouds[i].position.x = get_viewport_rect().size.x + 200
			clouds[i].position.y = randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX)
			clouds[i].texture = cloud_textures[randi() % cloud_textures.size()]
			reflections[i].texture = clouds[i].texture
			reflections[i].position.y = 2.0 * WATERLINE_Y - clouds[i].position.y
			var dist := absf(reflections[i].position.y - WATERLINE_Y)
			reflections[i].modulate.a = clampf(REFLECTION_BASE_ALPHA - dist * 0.0003, 0.01, REFLECTION_BASE_ALPHA)

		reflections[i].position.x = clouds[i].position.x


# ═════════════════════════════════════════════════════════════════════════════
# LOGO ANIMATION
# ═════════════════════════════════════════════════════════════════════════════

func _setup_logo() -> void:
	logo.play("flash")
	logo.animation_finished.connect(_on_logo_animation_finished)

	# Bobbing animation ONLY (no rotation) matching the ship speed
	_start_logo_bobbing()

	logo_flash_timer = Timer.new()
	logo_flash_timer.one_shot = true
	logo_flash_timer.timeout.connect(_on_logo_flash_timeout)
	add_child(logo_flash_timer)
	_schedule_next_flash()


func _start_logo_bobbing() -> void:
	var tween_pos := create_tween().set_loops()
	var base_y := logo.position.y
	
	# Bob down and up
	tween_pos.tween_property(logo, "position:y", base_y + LOGO_BOB_AMP, LOGO_BOB_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween_pos.tween_property(logo, "position:y", base_y, LOGO_BOB_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _schedule_next_flash() -> void:
	logo_flash_timer.start(randf_range(5.0, 10.0))


func _on_logo_flash_timeout() -> void:
	logo.play("flash")


func _on_logo_animation_finished() -> void:
	if logo.animation == &"flash":
		logo.play("idle")
		_schedule_next_flash()


# ═════════════════════════════════════════════════════════════════════════════
# UI SETUP
# ═════════════════════════════════════════════════════════════════════════════

func _setup_ui() -> void:
	name_input.text = "Diver_" + str(randi() % 999)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)


func _setup_networking() -> void:
	MultiplayerManager.player_list_changed.connect(_on_player_list_changed)
	MultiplayerManager.connection_status.connect(_on_connection_status)


func _setup_settings() -> void:
	# Resolution OptionButton
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

	# Fullscreen
	var current_mode := DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# Volume
	var master_bus_idx := AudioServer.get_bus_index("Master")
	var vol_db := AudioServer.get_bus_volume_db(master_bus_idx)
	volume_slider.value = db_to_linear(vol_db)
	volume_slider.value_changed.connect(_on_volume_changed)


# ═════════════════════════════════════════════════════════════════════════════
# NETWORKING CALLBACKS
# ═════════════════════════════════════════════════════════════════════════════

func _on_host_pressed() -> void:
	var name_text := name_input.text.strip_edges()
	if name_text == "":
		name_text = "Host"
	if MultiplayerManager.host_game(name_text):
		ui_container.visible = false
		lobby_panel.visible = true
		start_button.visible = true


func _on_join_pressed() -> void:
	var name_text := name_input.text.strip_edges()
	if name_text == "":
		name_text = "Client"
	var ip_text := ip_input.text.strip_edges()
	if ip_text == "":
		ip_text = "127.0.0.1"

	MultiplayerManager.join_game(name_text, ip_text)


func _on_start_pressed() -> void:
	MultiplayerManager.start_game()


func _on_leave_pressed() -> void:
	multiplayer.multiplayer_peer = null
	MultiplayerManager.players.clear()
	lobby_panel.visible = false
	ui_container.visible = true
	start_button.visible = false
	status_label.text = "Status: Disconnected"
	_on_player_list_changed()


func _on_player_list_changed() -> void:
	var list_text := "Players connected:\n"
	for peer_id in MultiplayerManager.players:
		var p_info: Dictionary = MultiplayerManager.players[peer_id]
		var suffix := " (Host)" if peer_id == 1 else ""
		list_text += "- " + p_info["name"] + suffix + "\n"
	player_list_label.text = list_text

	if multiplayer.multiplayer_peer != null:
		ui_container.visible = false
		lobby_panel.visible = true


func _on_connection_status(success: bool, message: String) -> void:
	status_label.text = "Status: " + message
	if not success:
		lobby_panel.visible = false
		ui_container.visible = true
		start_button.visible = false
		_on_player_list_changed()


# ═════════════════════════════════════════════════════════════════════════════
# SETTINGS CALLBACKS
# ═════════════════════════════════════════════════════════════════════════════

func _on_settings_pressed() -> void:
	ui_container.visible = false
	settings_panel.visible = true


func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	ui_container.visible = true


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

	# Center window on screen
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
