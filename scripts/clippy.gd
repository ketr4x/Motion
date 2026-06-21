extends Control

@onready var clippy_texture: TextureRect = $ClippyTexture
@onready var title_label: Label = $SpeechBubble/MarginContainer/VBoxContainer/TitleLabel
@onready var content_label: Label = $SpeechBubble/MarginContainer/VBoxContainer/ContentLabel
@onready var close_button: Button = $SpeechBubble/MarginContainer/VBoxContainer/HBox/CloseButton

var tips = {
	"controls": {
		"text": "Hi there! I'm Clippy, your dive assistant. Use WASD / Arrows to swim. Watch your oxygen in the top-left corner!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 9999.0,
		"last_shown": -9999.0,
		"priority": 10
	},
	"low_oxygen_near": {
		"text": "Oxygen is low! There is an active Oxygen Spot very close to you! Go grab it!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 7
	},
	"low_oxygen": {
		"text": "It looks like you're running low on oxygen! Keep swimming down to find an Oxygen Spot!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 45.0,
		"last_shown": -9999.0,
		"priority": 6
	},
	"suffocating": {
		"text": "Oh no! You're suffocating! You have less than 5 seconds to find oxygen or get help!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 12.0,
		"last_shown": -9999.0,
		"priority": 9
	},
	"stunned": {
		"text": "Ouch! Jellyfish stuns you and causes your oxygen to deplete 3 times faster! Stay clear of them!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 30.0,
		"last_shown": -9999.0,
		"priority": 8
	},
	"teammate_dead": {
		"text": "Your partner has died! Stay alive for 5 seconds and they will respawn right next to you!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 20.0,
		"last_shown": -9999.0,
		"priority": 8
	},
	"teammate_suffocating": {
		"text": "Your partner is suffocating! Swim close to them and press [E] to share some of your oxygen!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 25.0,
		"last_shown": -9999.0,
		"priority": 7
	},
	"coop_gate": {
		"text": "This co-op gate requires coordination! Both of you must activate the levers within 4 seconds of each other.",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"coop_gate_solo": {
		"text": "This gate is locked! Activate one lever, then quickly swim to the other one before the active timer runs out!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"current_vent": {
		"text": "The strong current from this vent is blocking you. Stand on the red button to deactivate the vent!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 4
	},
	"shoal_fish": {
		"text": "Watch out! A shoal of fish is swimming by! They will push you back up if you collide with them!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 30.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"slingshot": {
		"text": "Pro tip: Dash (Shift key) directly into your teammate to slingshot them forward with a massive speed boost!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 90.0,
		"last_shown": -9999.0,
		"priority": 3
	}
}

var current_tip_id: String = ""
var is_visible: bool = false
var check_timer: float = 0.0
var show_timer: float = 0.0

var original_position_y: float = 0.0

func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	custom_minimum_size = Vector2(500, 240)
	offset_left = -520
	offset_top = -260
	offset_right = -20
	offset_bottom = -20
	
	_update_y_position()
	
	position.y = original_position_y + 300
	modulate.a = 0.0
	is_visible = false
	
	close_button.pressed.connect(dismiss)
	
	await get_tree().create_timer(1.8).timeout
	trigger_tip("controls")

func _update_y_position() -> void:
	var viewport_size = get_viewport_rect().size
	original_position_y = viewport_size.y - custom_minimum_size.y - 20

func trigger_tip(tip_id: String) -> void:
	if not tips.has(tip_id):
		return
		
	if tip_id != "controls" and tips["controls"]["shows"] == 0:
		return
		
	var tip = tips[tip_id]
	if tip["shows"] >= tip["max_shows"]:
		return
		
	var time_now = Time.get_ticks_msec() / 1000.0
	if time_now - tip["last_shown"] < tip["cooldown"]:
		return
		
	if is_visible:
		var current_tip = tips.get(current_tip_id)
		if current_tip and current_tip["priority"] >= tip["priority"]:
			return
		else:
			hide_ui()
			await get_tree().create_timer(0.35).timeout
			
	current_tip_id = tip_id
	tip["shows"] += 1
	tip["last_shown"] = time_now
	
	content_label.text = tip["text"]
	show_ui()

func show_ui() -> void:
	is_visible = true
	show_timer = 6.0
	_update_y_position()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", original_position_y, 0.45)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

func dismiss() -> void:
	if is_visible:
		hide_ui()

func hide_ui() -> void:
	is_visible = false
	current_tip_id = ""
	_update_y_position()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", original_position_y + 300, 0.4)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func _process(delta: float) -> void:
	if is_visible:
		show_timer -= delta
		if show_timer <= 0.0:
			hide_ui()
			
	check_timer += delta
	if check_timer >= 0.35:
		check_timer = 0.0
		check_game_state()

func check_game_state() -> void:
	var game_node = get_parent().get_parent()
	if not game_node:
		return
		
	var local_player = game_node.get("local_player")
	if not local_player or local_player.is_dead:
		return
		
	if local_player.is_suffocating:
		trigger_tip("suffocating")
		return
		
	if local_player.is_stunned:
		trigger_tip("stunned")
		return
		
	if local_player.oxygen < 30.0:
		var oxygen_spot_nearby = false
		for child in game_node.get_children():
			if child.name.begins_with("Oxygen_") and child.get("is_active"):
				var dist = local_player.global_position.distance_to(child.global_position)
				if dist < 320.0:
					oxygen_spot_nearby = true
					break
		if oxygen_spot_nearby:
			trigger_tip("low_oxygen_near")
		else:
			trigger_tip("low_oxygen")
		return
		
	var teammate = null
	for child in game_node.get_children():
		if child is CharacterBody2D and child != local_player:
			teammate = child
			break
			
	if teammate:
		if teammate.is_dead:
			trigger_tip("teammate_dead")
			return
		if teammate.is_suffocating:
			var dist = local_player.global_position.distance_to(teammate.global_position)
			if dist < 180.0:
				trigger_tip("teammate_suffocating")
				return
		var dist = local_player.global_position.distance_to(teammate.global_position)
		if dist < 120.0 and not local_player.is_dashing and not teammate.is_dashing:
			trigger_tip("slingshot")
			
	for child in game_node.get_children():
		if child.name.begins_with("CoopGate_"):
			var dist = local_player.global_position.distance_to(child.global_position)
			if dist < 240.0:
				if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
					trigger_tip("coop_gate")
				else:
					trigger_tip("coop_gate_solo")
				break
		elif child.name.begins_with("CurrentVent_"):
			var is_active = child.get("is_vent_active")
			if is_active:
				var dist = local_player.global_position.distance_to(child.global_position)
				if dist < 240.0:
					trigger_tip("current_vent")
					break
		elif child.name.begins_with("Shoal_"):
			var dist = local_player.global_position.distance_to(child.global_position)
			if dist < 280.0:
				trigger_tip("shoal_fish")
				break
