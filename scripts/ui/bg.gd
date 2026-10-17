extends Sprite2D

@export var speed := Vector2(-0.15, 0.25)

var t := 0.0
@onready var mat := material as ShaderMaterial

func _process(delta: float) -> void:
	t += delta
	mat.set_shader_parameter("game_time", t)
	mat.set_shader_parameter("speed", speed)
