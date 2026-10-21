extends Control

const HOVER_SOUND: AudioStream = preload("uid://dwhqj3qn0qll1")

@export_group("Layer 1 Speeds", "layer_1_")
@export_range(0.0, 20.0, 0.1) var layer_1_horizontal_speed := 1.0
@export_range(0.0, 20.0, 0.1) var layer_1_vertical_speed := 1.0

@export_group("Layer 2 Speeds", "layer_2_")
@export_range(0.0, 20.0, 0.1) var layer_2_horizontal_speed := 1.5
@export_range(0.0, 20.0, 0.1) var layer_2_vertical_speed := 1.5

@export_group("Layer 3 Speeds", "layer_3_")
@export_range(0.0, 20.0, 0.1) var layer_3_horizontal_speed := 2.0
@export_range(0.0, 20.0, 0.1) var layer_3_vertical_speed := 2.0

@onready var _layers: Array[TextureRect] = [$Paralax_1, $Paralax_2, $Paralax_3]

var _layer_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _interaction_enabled := true
var _button_states: Dictionary[Button, Dictionary] = {}


func _ready() -> void:
	for button in $MarginContainer/Buttons.get_children():
		if button is Button:
			button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))
			button.add_theme_color_override("font_disabled_color", button.get_theme_color("font_color"))
			button.mouse_entered.connect(_on_menu_button_mouse_entered.bind(button))
			button.pressed.connect(button.release_focus)


func set_interaction_enabled(enabled: bool) -> void:
	if _interaction_enabled == enabled:
		return
	_interaction_enabled = enabled
	for child in $MarginContainer/Buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		if enabled:
			var state: Dictionary = _button_states[button]
			button.disabled = state.disabled
			button.focus_mode = state.focus_mode
		else:
			_button_states[button] = {"disabled": button.disabled, "focus_mode": button.focus_mode}
			button.release_focus()
			button.focus_mode = Control.FOCUS_NONE
			button.disabled = true


func _on_menu_button_mouse_entered(button: Button) -> void:
	if not button.disabled and can_process() and not Transition.transitioning:
		ControllerGame.play_one_shot(HOVER_SOUND)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Transition.transitioning or size.x <= 0.0 or size.y <= 0.0:
		return
	var mouse := (get_local_mouse_position() / size * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	var speeds: Array[Vector2] = [
		Vector2(layer_1_horizontal_speed, layer_1_vertical_speed),
		Vector2(layer_2_horizontal_speed, layer_2_vertical_speed),
		Vector2(layer_3_horizontal_speed, layer_3_vertical_speed),
	]
	for index in range(_layers.size()):
		var target := -mouse * speeds[index]
		var offset := _layer_offsets[index]
		offset.x = lerpf(offset.x, target.x, 1.0 - exp(-speeds[index].x * delta))
		offset.y = lerpf(offset.y, target.y, 1.0 - exp(-speeds[index].y * delta))
		_layers[index].position += offset - _layer_offsets[index]
		_layer_offsets[index] = offset
