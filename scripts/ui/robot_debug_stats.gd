extends Label

const DEBUG_FONT: Font = preload("res://font/ChixaDemibold.ttf")

var unit: BattleUnit:
	set(value):
		unit = value
		if is_node_ready():
			_update_stats()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	add_theme_font_override("font", DEBUG_FONT)
	add_theme_font_size_override("font_size", 6)
	add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.04, 0.04, 0.9)
	background.content_margin_left = 2
	background.content_margin_right = 2
	background.content_margin_top = 1
	background.content_margin_bottom = 1
	background.anti_aliasing = false
	add_theme_stylebox_override("normal", background)
	ControllerGame.debug_mode_changed.connect(_update_stats)
	_update_stats()


func _process(_delta: float) -> void:
	_update_stats()


func _update_stats() -> void:
	visible = ControllerGame.debug_mode and unit != null
	set_process(visible)
	if not visible:
		return
	text = "HP %d\nDMG %d\nATK/s %.2f\nCRIT %.1f%%" % [
		unit.health, unit.damage, unit.attack_speed, unit.crit_chance * 100.0,
	]
