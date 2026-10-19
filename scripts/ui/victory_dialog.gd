extends Control

var _previous_focus: Control


func open() -> void:
	if visible:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	if DraggableSlot.active_slot != null:
		DraggableSlot.active_slot._clear_drag()
	show()
	$Panel/VBoxContainer/Buttons/Yes.grab_focus()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_yes_pressed() -> void:
	ControllerGame.play_one_shot(preload("res://sounds/click.wav"))
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


func _on_no_pressed() -> void:
	ControllerGame.play_one_shot(preload("res://sounds/click.wav"))
	_previous_focus = null
	ControllerGame.return_to_main_menu()
