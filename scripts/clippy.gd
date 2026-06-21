extends Control

@onready var clippy_texture: TextureRect = $ClippyTexture
@onready var title_label: Label = $SpeechBubble/MarginContainer/VBoxContainer/TitleLabel
@onready var content_label: Label = $SpeechBubble/MarginContainer/VBoxContainer/ContentLabel

var tips = {
	"controls": {
		"text": "Use WASD or Arrows to swim. Watch oxygen in top-left!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 9999.0,
		"last_shown": -9999.0,
		"priority": 10
	},
	"low_oxygen_near": {
		"text": "Oxygen is low! An active Oxygen Spot is very close!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 7
	},
	"low_oxygen": {
		"text": "You are low on oxygen. Swim down to find spots!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 45.0,
		"last_shown": -9999.0,
		"priority": 6
	},
	"suffocating": {
		"text": "Suffocating! Find oxygen or get teammate help in 5 seconds!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 12.0,
		"last_shown": -9999.0,
		"priority": 9
	},
	"stunned": {
		"text": "Jellyfish stun drains your oxygen three times faster. Avoid them!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 30.0,
		"last_shown": -9999.0,
		"priority": 8
	},
	"teammate_dead": {
		"text": "Partner dead! Stay alive 5 seconds to respawn them nearby!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 20.0,
		"last_shown": -9999.0,
		"priority": 8
	},
	"teammate_suffocating": {
		"text": "Teammate is suffocating! Swim close and press E to share!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 25.0,
		"last_shown": -9999.0,
		"priority": 7
	},
	"coop_gate": {
		"text": "Co-op gate: Activate both levers within 4 seconds of each other!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"coop_gate_solo": {
		"text": "Solo gate: Activate one lever, then quickly reach the second!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"current_vent": {
		"text": "Vent current blocks you. Stand on red button to deactivate!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 40.0,
		"last_shown": -9999.0,
		"priority": 4
	},
	"shoal_fish": {
		"text": "Shoal of fish approaching! They will push you back up!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 30.0,
		"last_shown": -9999.0,
		"priority": 5
	},
	"slingshot": {
		"text": "Dash (Shift key) into your teammate to slingshot them forward!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 90.0,
		"last_shown": -9999.0,
		"priority": 3
	},
	"suggest_reroll": {
		"text": "Do you want to reroll the seed? Press H to initialize voting!",
		"max_shows": 1,
		"shows": 0,
		"cooldown": 9999.0,
		"last_shown": -9999.0,
		"priority": 11
	}
}

var current_tip_id: String = ""
var is_visible: bool = false
var check_timer: float = 0.0
var show_timer: float = 0.0
var original_position_y: float = 0.0

# Reroll Voting System properties
var vote_active: bool = false
var votes_yes: Dictionary = {}
var votes_no: Dictionary = {}
var vote_timer: float = 0.0
var vote_duration: float = 15.0
var vote_initiated_by: int = 0
var has_voted: bool = false
var has_suggested_reroll: bool = false

func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	
	custom_minimum_size = Vector2(640, 260)
	offset_left = -660
	offset_top = 20
	offset_right = -20
	offset_bottom = 280
	
	_update_y_position()
	
	position.y = original_position_y - 350
	modulate.a = 0.0
	is_visible = false
	
	await get_tree().create_timer(1.8).timeout
	trigger_tip("controls")

func _update_y_position() -> void:
	original_position_y = 20

func trigger_tip(tip_id: String) -> void:
	if not tips.has(tip_id):
		return
		
	if tip_id != "controls" and tip_id != "suggest_reroll" and tips["controls"]["shows"] == 0:
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
	show_timer = 3.5
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
	tween.tween_property(self, "position:y", original_position_y - 350, 0.4)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func _process(delta: float) -> void:
	if vote_active:
		vote_timer -= delta
		update_vote_ui_text()
		if vote_timer <= 0.0:
			resolve_vote(false, "Vote timed out! Reroll cancelled.")
	elif is_visible:
		show_timer -= delta
		if show_timer <= 0.0:
			hide_ui()
			
	check_timer += delta
	if check_timer >= 0.35:
		check_timer = 0.0
		check_game_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			try_start_vote()
		elif event.keycode == KEY_F1:
			try_vote(true)
		elif event.keycode == KEY_F2:
			try_vote(false)

# Voting network sync logic
func try_start_vote() -> void:
	if vote_active:
		return
		
	var sender_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if multiplayer.has_multiplayer_peer():
		rpc("start_vote_rpc", sender_id)
	else:
		start_vote_rpc(sender_id)

@rpc("any_peer", "call_local", "reliable")
func start_vote_rpc(initiator_id: int) -> void:
	vote_active = true
	vote_initiated_by = initiator_id
	votes_yes.clear()
	votes_no.clear()
	vote_timer = vote_duration
	has_voted = false
	
	# The initiator automatically votes Yes!
	votes_yes[initiator_id] = true
	
	title_label.text = "Reroll Vote"
	update_vote_ui_text()
	show_ui_override()

func show_ui_override() -> void:
	is_visible = true
	show_timer = 99.0 # Keep visible
	_update_y_position()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", original_position_y, 0.45)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

func try_vote(vote_yes: bool) -> void:
	if not vote_active:
		return
		
	var sender_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	# Prevent double voting if already recorded
	if vote_yes and votes_yes.has(sender_id):
		return
	if not vote_yes and votes_no.has(sender_id):
		return
		
	if multiplayer.has_multiplayer_peer():
		rpc("submit_vote_rpc", sender_id, vote_yes)
	else:
		submit_vote_rpc(sender_id, vote_yes)

@rpc("any_peer", "call_local", "reliable")
func submit_vote_rpc(voter_id: int, vote_yes: bool) -> void:
	if not vote_active:
		return
		
	if vote_yes:
		votes_yes[voter_id] = true
		votes_no.erase(voter_id)
	else:
		votes_no[voter_id] = true
		votes_yes.erase(voter_id)
		
	update_vote_ui_text()
	check_vote_resolution()

func update_vote_ui_text() -> void:
	var total_players = MultiplayerManager.players.size() if multiplayer.has_multiplayer_peer() else 1
	var yes_count = votes_yes.size()
	var no_count = votes_no.size()
	
	content_label.text = "Reroll seed?\n[F1] Yes (%d/%d) | [F2] No (%d/%d)\nTime left: %ds" % [yes_count, total_players, no_count, total_players, int(ceil(vote_timer))]

func check_vote_resolution() -> void:
	var total_players = MultiplayerManager.players.size() if multiplayer.has_multiplayer_peer() else 1
	
	# If everyone voted Yes, we pass!
	if votes_yes.size() >= total_players:
		resolve_vote(true)
	# If anyone voted No, it fails immediately!
	elif votes_no.size() > 0:
		resolve_vote(false, "Vote failed! Reroll cancelled.")

func resolve_vote(passed: bool, message: String = "") -> void:
	vote_active = false
	title_label.text = "Clippy"
	if passed:
		content_label.text = "Vote passed! Rerolling seed..."
		show_timer = 5.0
		await get_tree().create_timer(1.2).timeout
		
		# Server triggers the restart
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				MultiplayerManager.load_game_scene.rpc()
		else:
			get_tree().reload_current_scene()
	else:
		content_label.text = message
		show_timer = 2.0 # Fade out in 2 seconds

func check_game_state() -> void:
	var game_node = get_parent().get_parent()
	if not game_node:
		return
		
	# Check if we should suggest a reroll (not crossed 200m in 30s)
	var game_time = 0.0
	if game_node.get("game_start_time") != null:
		game_time = (Time.get_ticks_msec() - game_node.game_start_time) / 1000.0
		
	var local_player = game_node.get("local_player")
	if not local_player:
		return
		
	var depth_m = max(0, int(local_player.position.y / 10))
	
	if game_time >= 30.0 and depth_m < 200 and not has_suggested_reroll and not vote_active:
		has_suggested_reroll = true
		trigger_tip("suggest_reroll")
		return
		
	if local_player.is_dead:
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
