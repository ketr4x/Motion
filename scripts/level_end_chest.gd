extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
var is_opened: bool = false
var anim_timer: float = 0.0
var anim_frame: int = 3
var playing_anim: bool = false
var time_per_frame: float = 0.15

signal chest_opened

func _ready() -> void:
	sprite.frame = 3
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	if playing_anim:
		anim_timer += delta
		if anim_timer >= time_per_frame:
			anim_timer = 0.0
			anim_frame += 1
			if anim_frame > 6:
				anim_frame = 6
				playing_anim = false
				chest_opened.emit()
				
				# Call win_game on the server/authority
				if multiplayer.has_multiplayer_peer():
					var game = get_tree().current_scene
					if game and game.has_method("win_game_chest"):
						if multiplayer.is_server():
							game.win_game_chest.rpc()
						else:
							game.request_win_game.rpc_id(1)
				else:
					var game = get_tree().current_scene
					if game and game.has_method("win_game_chest"):
						game.win_game_chest()
			
			sprite.frame = anim_frame

func _unhandled_input(event: InputEvent) -> void:
	if is_opened:
		return
		
	if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo):
		var bodies = get_overlapping_bodies()
		var local_player_here = false
		for b in bodies:
			if b is CharacterBody2D and (not multiplayer.has_multiplayer_peer() or b.is_multiplayer_authority()):
				local_player_here = true
				break
				
		if local_player_here:
			is_opened = true
			playing_anim = true
			anim_frame = 3
			anim_timer = 0.0
