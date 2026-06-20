extends Node2D
@onready var titlecard: Sprite2D = $titlecard
@onready var titletext: Label = $titletext


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	titlecard.modulate.a -= 0.01
	if titlecard.modulate.a == 0:
		titletext.modulate.a -= 0.01
	pass
