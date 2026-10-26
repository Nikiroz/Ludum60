extends HBoxContainer

@onready var tabs: TabContainer = $RobotTabs
@onready var buttons: VBoxContainer = $TabButtons


func _ready() -> void:
	for index in range(buttons.get_child_count()):
		var button := buttons.get_child(index) as TextureButton
		button.pressed.connect(_select_tab.bind(index))
	tabs.tab_changed.connect(_update_buttons)
	_update_buttons(tabs.current_tab)


func _select_tab(index: int) -> void:
	ControllerGame.play_one_shot(preload("uid://21gf6qfxd331"))
	tabs.current_tab = index
	_update_buttons(index)


func _update_buttons(selected: int) -> void:
	for index in range(buttons.get_child_count()):
		var button := buttons.get_child(index) as TextureButton
		button.set_pressed_no_signal(index == selected)
		button.self_modulate = Color.WHITE if index == selected else Color(0.5, 0.5, 0.5)
