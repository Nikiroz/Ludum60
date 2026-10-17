extends UIShowButton

func _on_pressed() -> void:
	super._on_pressed()
	var node := get_parent()
	var root := get_tree().current_scene
	var settings := root.get_node_or_null("Settings") as Control
	if settings != null:
		settings.hide()
	ControllerGame.isMainMenu = true

	while node != null:
		if node.get_parent() == root:
			node.hide()
			return

		node = node.get_parent()
