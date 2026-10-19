class_name FieldCell
extends TextureRect

signal cell_clicked(cell: FieldCell)

const SCRAP_TEXTURES: Array[Texture2D] = [
	preload("res://sprites/bg/scrap1.png"),
	preload("res://sprites/bg/scrap2.png"),
	preload("res://sprites/bg/scrap3.png"),
]

@export_range(1, 20, 1) var clicks_required: int = 1

var clicks_left: int


func _ready() -> void:
	texture = SCRAP_TEXTURES.pick_random()
	set_clicks_required(clicks_required)


func set_clicks_required(amount: int) -> void:
	clicks_required = maxi(amount, 1)
	clicks_left = clicks_required
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hit()
			accept_event()


func hit() -> void:
	if clicks_left <= 0:
		return

	clicks_left -= 1

	modulate.a = float(clicks_left) / float(clicks_required)

	if clicks_left == 0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_clicked.emit(self)
