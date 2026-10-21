extends CanvasLayer

@onready var main_menu: Control = $MainMenu
@onready var settings: Control = $Settings
@onready var credits: Control = $Credits
@onready var warning: Control = $Warning
@onready var victory_dialog: Control = $VictoryDialog


func _ready() -> void:
	settings.visibility_changed.connect(_update_pause_state)
	warning.visibility_changed.connect(_update_pause_state)
	victory_dialog.visibility_changed.connect(_update_pause_state)
	credits.visibility_changed.connect(_update_main_menu_state)
	_update_pause_state()


func _update_pause_state() -> void:
	get_tree().paused = settings.is_visible_in_tree() or warning.is_visible_in_tree() or victory_dialog.is_visible_in_tree()
	_update_main_menu_state()


func _update_main_menu_state() -> void:
	var covered := settings.is_visible_in_tree() or credits.is_visible_in_tree() or warning.is_visible_in_tree() or victory_dialog.is_visible_in_tree()
	if covered:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and main_menu.is_ancestor_of(focused):
			focused.release_focus()
	main_menu.set_interaction_enabled(not covered)
	main_menu.process_mode = Node.PROCESS_MODE_DISABLED if covered else Node.PROCESS_MODE_INHERIT


func _exit_tree() -> void:
	get_tree().paused = false
