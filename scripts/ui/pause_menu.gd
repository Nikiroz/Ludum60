extends CanvasLayer

@onready var settings: Control = $Settings
@onready var warning: Control = $Warning


func _ready() -> void:
	settings.visibility_changed.connect(_update_pause_state)
	warning.visibility_changed.connect(_update_pause_state)
	_update_pause_state()


func _update_pause_state() -> void:
	get_tree().paused = settings.is_visible_in_tree() or warning.is_visible_in_tree()


func _exit_tree() -> void:
	get_tree().paused = false
