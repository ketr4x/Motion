extends Control

@onready var clippy_sprite: Sprite2D = $Content/ClippySprite
@onready var tip_label: Label = $Content/TipLabel
@onready var content_node: Control = $Content

# Animation data: [row, frame_count, fps]
var anims = {
	"vote": [0, 6, 6.0],
	"clock": [1, 8, 6.0],
	"talking": [2, 6, 6.0],
	"idle": [3, 4, 4.0]
}

var current_anim: String = "idle"
var anim_time: float = 0.0

# Typewriter
var full_text: String = ""
var visible_chars: int = 0
var type_timer: float = 0.0
var type_speed: float = 0.04
var cursor_visible: bool = true
var cursor_timer: float = 0.0
var cursor_blink_speed: float = 0.3
var typing_done: bool = true

# Tips system
var tips = {
	"controls": {"text": "WASD to swim. Shift to dash.", "anim": "talking", "max_shows": 1, "shows": 0, "cooldown": 9999.0, "last_shown": -9999.0, "priority": 10},
	"low_oxygen": {"text": "Oxygen low! Find bubbles fast!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 45.0, "last_shown": -9999.0, "priority": 6},
	"low_oxygen_near": {"text": "Oxygen nearby! Swim to it!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 40.0, "last_shown": -9999.0, "priority": 7},
	"suffocating": {"text": "Suffocating! Get air in 5 sec!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 12.0, "last_shown": -9999.0, "priority": 9},
	"stunned": {"text": "Jellyfish sting! Oxygen drains 3x!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 30.0, "last_shown": -9999.0, "priority": 8},
	"teammate_dead": {"text": "Partner down! Survive to respawn!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 20.0, "last_shown": -9999.0, "priority": 8},
	"teammate_suffocating": {"text": "Teammate choking! Press E near them!", "anim": "clock", "max_shows": 1, "shows": 0, "cooldown": 25.0, "last_shown": -9999.0, "priority": 7},
	"coop_gate": {"text": "Co-op gate! Both levers, 4 sec!", "anim": "talking", "max_shows": 1, "shows": 0, "cooldown": 40.0, "last_shown": -9999.0, "priority": 5},
	"coop_gate_solo": {"text": "Solo gate! Hit both levers quick!", "anim": "talking", "max_shows": 1, "shows": 0, "cooldown": 40.0, "last_shown": -9999.0, "priority": 5},
	"shoal_fish": {"text": "Fish incoming! They push you up!", "anim": "talking", "max_shows": 1, "shows": 0, "cooldown": 30.0, "last_shown": -9999.0, "priority": 5},
	"slingshot": {"text": "Dash into teammate for a slingshot!", "anim": "talking", "max_shows": 1, "shows": 0, "cooldown": 90.0, "last_shown": -9999.0, "priority": 3},
	"suggest_reroll": {"text": "Press H to vote for seed reroll!", "anim": "vote", "max_shows": 1, "shows": 0, "cooldown": 9999.0, "last_shown": -9999.0, "priority": 11}
}

var current_tip_id: String = ""
var is_showing: bool = false
var show_timer: float = 0.0
var check_timer: float = 0.0
var reveal_progress: float = 0.0  # 0 = hidden, 1 = fully shown
var reveal_target: float = 0.0
var reveal_speed: float = 8.0  # steps per second for retro feel
var reveal_step_size: float = 0.125  # 1/8 = 8 discrete steps

# Reroll Voting System
var vote_active: bool = false
var votes_yes: Dictionary = {}
var votes_no: Dictionary = {}
var vote_timer: float = 0.0
var vote_duration: float = 15.0
var vote_initiated_by: int = 0
var has_voted: bool = false
var has_suggested_reroll: bool = false

func _ready() -> void:
	modulate.a = 1.0
	reveal_progress = 0.0
	reveal_target = 0.0
	_apply_reveal()
	is_showing = false
	
	await get_tree().create_timer(1.8).timeout
	trigger_tip("controls")

func _apply_reveal() -> void:
	# clip_contents on parent clips the Content node
	# We move Content down so it's hidden behind the clip mask
	var total_h = size.y
	var offset = total_h * (1.0 - reveal_progress)
	content_node.position.y = offset
	# Hard visibility toggle at 0
	content_node.visible = reveal_progress > 0.0

func play_anim(anim_name: String) -> void:
	if current_anim != anim_name:
		current_anim = anim_name
		anim_time = 0.0

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
	if is_showing:
		var current_tip = tips.get(current_tip_id)
		if current_tip and current_tip["priority"] >= tip["priority"]:
			return
		else:
			hide_clippy()
			await get_tree().create_timer(0.35).timeout
	
	current_tip_id = tip_id
	tip["shows"] += 1
	tip["last_shown"] = time_now
	
	# Start typewriter
	full_text = tip["text"]
	visible_chars = 0
	type_timer = 0.0
	typing_done = false
	tip_label.text = "█"
	
	# Play matching animation
	play_anim(tip["anim"])
	show_clippy()

func show_clippy() -> void:
	is_showing = true
	show_timer = 4.0
	reveal_target = 1.0

func hide_clippy() -> void:
	is_showing = false
	current_tip_id = ""
	play_anim("idle")
	reveal_target = 0.0

func _process(delta: float) -> void:
	# Retro stepped reveal/hide
	if reveal_progress != reveal_target:
		if reveal_target > reveal_progress:
			reveal_progress = min(reveal_progress + reveal_step_size, reveal_target)
		else:
			reveal_progress = max(reveal_progress - reveal_step_size * 2.0, reveal_target)
		_apply_reveal()
	
	# Animate sprite
	var anim_data = anims[current_anim]
	var row = anim_data[0]
	var frame_count = anim_data[1]
	var fps = anim_data[2]
	anim_time += delta
	var frame_idx = int(anim_time * fps) % frame_count
	if clippy_sprite:
		clippy_sprite.frame_coords = Vector2i(frame_idx, row)
	
	# Typewriter effect
	if not typing_done:
		type_timer += delta
		if type_timer >= type_speed:
			type_timer -= type_speed
			visible_chars += 1
			if visible_chars >= full_text.length():
				visible_chars = full_text.length()
				typing_done = true
	
	# Cursor blink
	cursor_timer += delta
	if cursor_timer >= cursor_blink_speed:
		cursor_timer -= cursor_blink_speed
		cursor_visible = not cursor_visible
	
	# Update label
	if tip_label and full_text.length() > 0:
		var shown = full_text.substr(0, visible_chars)
		var cursor_char = "█" if cursor_visible else " "
		tip_label.text = shown + cursor_char
	
	# Vote timer
	if vote_active:
		var old_ceil = int(ceil(vote_timer))
		vote_timer -= delta
		var new_ceil = int(ceil(vote_timer))
		if old_ceil != new_ceil:
			update_vote_ui_text()
		if vote_timer <= 0.0:
			resolve_vote(false, "Vote timed out!")
	elif is_showing:
		show_timer -= delta
		if show_timer <= 0.0:
			hide_clippy()
	
	# Periodic game state check
	check_timer += delta
	if check_timer >= 0.35:
		check_timer = 0.0
		check_game_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			try_start_vote()
		elif event.keycode == KEY_F1 or event.keycode == KEY_Y:
			try_vote(true)
		elif event.keycode == KEY_F2 or event.keycode == KEY_N:
			try_vote(false)

# === Voting System (keep all RPC logic identical) ===
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
	votes_yes[initiator_id] = true
	
	play_anim("vote")
	update_vote_ui_text()
	is_showing = true
	show_timer = 99.0
	reveal_target = 1.0

func try_vote(vote_yes: bool) -> void:
	if not vote_active:
		return
	var sender_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
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
	full_text = "Reroll? [F1]Yes %d/%d [F2]No %d/%d %ds" % [yes_count, total_players, no_count, total_players, int(ceil(vote_timer))]
	visible_chars = full_text.length()
	typing_done = true

func check_vote_resolution() -> void:
	var total_players = MultiplayerManager.players.size() if multiplayer.has_multiplayer_peer() else 1
	if votes_yes.size() >= total_players:
		resolve_vote(true)
	elif votes_no.size() > 0:
		resolve_vote(false, "Vote failed!")

func resolve_vote(passed: bool, message: String = "") -> void:
	vote_active = false
	if passed:
		full_text = "Rerolling seed..."
		visible_chars = full_text.length()
		typing_done = true
		show_timer = 5.0
		await get_tree().create_timer(1.2).timeout
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				MultiplayerManager.load_game_scene.rpc()
		else:
			get_tree().reload_current_scene()
	else:
		full_text = message
		visible_chars = full_text.length()
		typing_done = true
		show_timer = 2.0

func check_game_state() -> void:
	var game_node = get_parent().get_parent()
	if not game_node:
		return
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
		for child in children:
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
	for child in children:
		if child is CharacterBody2D and child != local_player:
			teammate = child
			break
	if teammate:
		if teammate.is_dead:
			trigger_tip("teammate_dead")
			return
		if teammate.is_suffocating:
			var dist_team = local_player.global_position.distance_to(teammate.global_position)
			if dist_team < 180.0:
				trigger_tip("teammate_suffocating")
				return
		var dist_sling = local_player.global_position.distance_to(teammate.global_position)
		if dist_sling < 120.0 and not local_player.is_dashing and not teammate.is_dashing:
			trigger_tip("slingshot")
	for child in game_node.get_children():
		if child.name.begins_with("CoopGate_"):
			var dist_gate = local_player.global_position.distance_to(child.global_position)
			if dist_gate < 240.0:
				if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
					trigger_tip("coop_gate")
				else:
					trigger_tip("coop_gate_solo")
				break
		elif child.name.begins_with("Shoal_"):
			var dist_shoal = local_player.global_position.distance_to(child.global_position)
			if dist_shoal < 280.0:
				trigger_tip("shoal_fish")
				break
