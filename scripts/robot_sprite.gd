
class_name DraggableSlot
extends Control

@export_group("Animation")
@export_range(0.05, 0.5, 0.01)
var shift_duration: float = 0.2

@export_group("Cursors")
@export var cursor_drag: Texture2D = preload("res://sprites/cursors/cursor_drag.png")
@export var cursor_hotspot := Vector2.ZERO

@onready var icon: TextureRect = $Icon

static var active_slot: DraggableSlot = null

var _preview_layer: CanvasLayer
var _preview: TextureRect
var _drag_cursor: TextureRect

var _original_index: int
var _saved_alpha: float

var _shift_tween: Tween
var _waiting_for_sort := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_process(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if active_slot == null:
				_start_drag()
				accept_event()

func _start_drag() -> void:
	if not get_parent() is HBoxContainer:
		return

	active_slot = self
	_original_index = get_index()
	_saved_alpha = icon.self_modulate.a

	if _shift_tween and _shift_tween.is_running():
		_shift_tween.kill()

	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 100
	get_tree().root.add_child(_preview_layer)

	_preview = TextureRect.new()
	_preview.texture = icon.texture
	_preview.size = icon.size
	_preview.expand_mode = icon.expand_mode
	_preview.stretch_mode = icon.stretch_mode
	_preview.texture_filter = icon.texture_filter
	_preview.modulate = icon.modulate
	_preview.self_modulate = icon.self_modulate
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_preview_layer.add_child(_preview)

	_drag_cursor = TextureRect.new()
	_drag_cursor.texture = cursor_drag
	_drag_cursor.size = cursor_drag.get_size()
	_drag_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_layer.add_child(_drag_cursor)

	icon.self_modulate.a = 0.0

	ControllerGame.set_drag_cursor(true)

	set_process(true)
	_update_preview()

func _process(_delta: float) -> void:
	if active_slot != self:
		return

	_update_preview()
	_update_reorder()


func _update_preview() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if is_instance_valid(_preview):
		_preview.position = mouse_pos - _preview.size / 2.0

	if is_instance_valid(_drag_cursor):
		_drag_cursor.position = mouse_pos - cursor_hotspot

func _update_reorder() -> void:
	if _waiting_for_sort:
		return

	var row: HBoxContainer = get_parent() as HBoxContainer

	if row == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()

	if not row.get_global_rect().has_point(mouse_pos):
		return

	var new_index := 0

	for child in row.get_children():
		if child == self:
			continue

		if child is DraggableSlot:
			var center_x: float = child.get_global_rect().get_center().x

			if mouse_pos.x > center_x:
				new_index += 1

	if new_index != get_index():
		_animate_reorder(new_index)

func _animate_reorder(new_index: int) -> void:
	var row: HBoxContainer = get_parent() as HBoxContainer

	if row == null or _waiting_for_sort:
		return

	_waiting_for_sort = true

	var old_positions: Dictionary = {}

	for child in row.get_children():
		if child is DraggableSlot and child != self:
			var slot: DraggableSlot = child
			old_positions[slot] = slot.icon.global_position

	row.sort_children.connect(
		func() -> void:
			for child in row.get_children():
				if child is DraggableSlot and child != self:
					var slot: DraggableSlot = child

					if old_positions.has(slot):
						var old_pos: Vector2 = old_positions[slot]
						slot._animate_from(old_pos)

			_waiting_for_sort = false,
		CONNECT_ONE_SHOT
	)

	row.move_child(self, new_index)

func _animate_from(old_global_pos: Vector2) -> void:

	if _shift_tween and _shift_tween.is_running():
		_shift_tween.kill()

	icon.position = (
		get_global_transform().affine_inverse() * old_global_pos
	)

	_shift_tween = create_tween()
	_shift_tween.set_trans(Tween.TRANS_CUBIC)
	_shift_tween.set_ease(Tween.EASE_OUT)

	_shift_tween.tween_property(
		icon,
		"position",
		Vector2.ZERO,
		shift_duration
	)

func _input(event: InputEvent) -> void:
	if active_slot != self:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag()


func _finish_drag() -> void:
	var row: HBoxContainer = get_parent() as HBoxContainer

	if row != null:
		var mouse_pos: Vector2 = get_global_mouse_position()

		if not row.get_global_rect().has_point(mouse_pos):
			if not _waiting_for_sort:
				_animate_reorder(_original_index)

	_clear_drag()

func _clear_drag() -> void:
	set_process(false)

	icon.self_modulate.a = _saved_alpha

	if is_instance_valid(_preview_layer):
		_preview_layer.queue_free()

	_preview_layer = null
	_preview = null

	active_slot = null

	ControllerGame.set_drag_cursor(false)
	_drag_cursor = null

func _exit_tree() -> void:
	if active_slot == self:
		_clear_drag()
