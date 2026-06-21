extends Node2D

# ─── Cloud textures set in inspector (AtlasTextures from clouds.png) ─────────
@export var cloud_textures: Array[Texture2D] = []

# ─── Constants ───────────────────────────────────────────────────────────────
const CLOUD_SPEED := 45.0        # pixels per second
const CLOUD_COUNT := 2           # clouds across the sky
const CLOUD_Y_MIN := 50.0        # top boundary for cloud spawn (above logo)
const CLOUD_Y_MAX := 250.0       # bottom boundary for cloud spawn (above ship/water)
const CLOUD_SCALE := Vector2(16, 16)
const REFLECTION_BASE_ALPHA := 0.45

const WATERLINE_Y := 680.0       # Dynamic waterline for 1920x1080 pixel art scaling

# Logo animation settings
const LOGO_BOB_AMP := 15.0       # Pixels to bob up and down
const LOGO_BOB_DURATION := 0.75  # Matches 4fps ship loop (0.75s down, 0.75s up = 1.5s total)

# ─── Node references ────────────────────────────────────────────────────────
# Background
@onready var sky_rect: ColorRect = $CanvasLayer/SkyRect
@onready var ocean_rect: ColorRect = $CanvasLayer/OceanRect

# Clouds
@onready var clouds_container: Node2D = $CanvasLayer/CloudsContainer
@onready var reflections_container: Node2D = $CanvasLayer/ReflectionsContainer

# Particles
@onready var wind_particles: CPUParticles2D = $CanvasLayer/WindParticles
@onready var bubble_particles: CPUParticles2D = $CanvasLayer/BubbleParticles

# Ship
@onready var ship_bg: AnimatedSprite2D = $CanvasLayer/ShipBG

# Logo
@onready var logo: AnimatedSprite2D = $CanvasLayer/Logo

# Main UI
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

# Lobby
@onready var lobby_panel: PanelContainer = $CanvasLayer/LobbyPanel
@onready var player_list_label: Label = $CanvasLayer/LobbyPanel/VBox/PlayerList
@onready var start_button: Button = $CanvasLayer/LobbyPanel/VBox/ButtonsBox/StartButton
@onready var leave_button: Button = $CanvasLayer/LobbyPanel/VBox/ButtonsBox/LeaveButton

# Settings
@onready var settings_panel: PanelContainer = $CanvasLayer/SettingsPanel
@onready var settings_back_button: Button = $CanvasLayer/SettingsPanel/VBox/SettingsBackButton
@onready var resolution_btn: OptionButton = $CanvasLayer/SettingsPanel/VBox/ResolutionBox/ResolutionBtn
@onready var fullscreen_check: CheckBox = $CanvasLayer/SettingsPanel/VBox/FullscreenBox/FullscreenCheck
@onready var volume_slider: HSlider = $CanvasLayer/SettingsPanel/VBox/VolumeBox/VolumeSlider

# ─── Internal state ──────────────────────────────────────────────────────────
var clouds: Array[Sprite2D] = []
var reflections: Array[Sprite2D] = []
var logo_flash_timer: Timer
var is_background_paused := false

# Drag functionality
var dragging_window := false
var drag_offset := Vector2.ZERO

# ═════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_seamless_colors()
	_spawn_clouds()
	_setup_logo()
	_setup_ui()
	_setup_networking()
	_setup_settings()


func _process(delta: float) -> void:
	_update_clouds(delta)


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


# ═════════════════════════════════════════════════════════════════════════════
# LOGO ANIMATION
# ═════════════════════════════════════════════════════════════════════════════

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
		_schedule_next_flash() # try again later


func _on_logo_animation_finished() -> void:
	if logo.animation == &"flash":
		logo.play("idle")
		_schedule_next_flash()


# ═════════════════════════════════════════════════════════════════════════════
# UI SETUP & DRAGGING
# ═════════════════════════════════════════════════════════════════════════════

func _setup_ui() -> void:
	name_input.text = "Diver_" + str(randi() % 999)

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)

	# Setup draggable window feature
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
		pause_background()


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
	resume_background()
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
		pause_background()


func _on_connection_status(success: bool, message: String) -> void:
	status_label.text = "Status: " + message
	if not success:
		lobby_panel.visible = false
		ui_container.visible = true
		start_button.visible = false
		resume_background()
		_on_player_list_changed()


# ═════════════════════════════════════════════════════════════════════════════
# SETTINGS CALLBACKS
# ═════════════════════════════════════════════════════════════════════════════

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
