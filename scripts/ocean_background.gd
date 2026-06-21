extends Node2D

@export var spritesheet: Texture2D = preload("res://assets/glebokosci2.png")
@export var start_depth: float = 300.0
@export var end_depth: float = 3600.0

var top_colors = []
var bottom_colors = []
var transition_depths = [1125.0, 1950.0, 2775.0]
var frame_width = 72
var frame_height = 50
var bg_scale = 8.0

var level_width_min = -288.0
var level_width_max = 288.0

func _ready() -> void:


	if spritesheet:
		var img = spritesheet.get_image()
		for i in range(4):
			# Sample colors from left column of the frame to avoid any edge artifacts
			var tc = img.get_pixel(i * frame_width, 0)
			var bc = img.get_pixel(i * frame_width, frame_height - 1)
			top_colors.append(tc)
			bottom_colors.append(bc)
	
	z_index = -10
	queue_redraw()

func _draw() -> void:
	if not spritesheet or top_colors.size() < 3:
		return
		
	var current_y = -200000.0
	
	# Initial solid color to first transition
	draw_rect(Rect2(level_width_min, current_y, level_width_max - level_width_min, transition_depths[0] + 400.0 - current_y), Color("#639bff"))
	
	for i in range(3):
		var trans_y = transition_depths[i]
		
		# Draw exactly ONE frame scaled up
		var tile_x = level_width_min
		var src_rect = Rect2(i * frame_width, 0, frame_width, frame_height)
		var dest_rect = Rect2(tile_x, trans_y, frame_width * bg_scale, frame_height * bg_scale)
		draw_texture_rect_region(spritesheet, dest_rect, src_rect)
			
		var next_y = transition_depths[i+1] if i < 2 else 200000.0
		var current_bottom_y = trans_y + frame_height * bg_scale
		var next_top_color = top_colors[i+1] if i < 2 else bottom_colors[2]
		
		# Smooth gradient to next transition
		var points = PackedVector2Array([
			Vector2(level_width_min, current_bottom_y),
			Vector2(level_width_max, current_bottom_y),
			Vector2(level_width_max, next_y),
			Vector2(level_width_min, next_y)
		])
		var colors = PackedColorArray([
			bottom_colors[i],
			bottom_colors[i],
			next_top_color,
			next_top_color
		])
		draw_polygon(points, colors)
	
	if bottom_colors.size() > 3:
		draw_rect(Rect2(level_width_min, 3600.0 + (frame_height * bg_scale), level_width_max - level_width_min, 100000.0), bottom_colors[3])

		
