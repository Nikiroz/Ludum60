extends Control


func _ready() -> void:
	var cursor := TextureRect.new()
	cursor.texture = preload("res://sprites/cursors/cursor_drag.png")
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(cursor)
	ControllerGame.set_drag_cursor(true)


func _exit_tree() -> void:
	ControllerGame.set_drag_cursor(false)
