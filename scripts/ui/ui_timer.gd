extends Label

@onready var timer: Timer = $Timer

func _process(_delta: float) -> void:
	var time_left: int = ceili(timer.time_left)
	var minutes: int = time_left / 60
	var seconds: int = time_left % 60

	text = "%02d:%02d" % [minutes, seconds]
