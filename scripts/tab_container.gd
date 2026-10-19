extends TabContainer

@export var normal_icon: Texture2D
@export var active_icon: Texture2D


func _ready() -> void:
	tab_changed.connect(_on_tab_changed)
	_on_tab_changed(current_tab)


func _on_tab_changed(active_tab: int) -> void:
	for i in range(get_tab_count()):
		set_tab_icon(
			i,
			active_icon if i == active_tab else normal_icon
		)
