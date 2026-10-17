extends UIShowButton

func _on_pressed() -> void:
	super._on_pressed()
	var node := get_parent()
	var root := get_tree().current_scene
	var settings := root.get_node_or_null("MenuLayer/Settings") as Control
	if settings != null:
		settings.hide()
	ControllerGame.isMainMenu = true

	while node != null:
		if node is Control and (node.get_parent() == root or node.get_parent() is CanvasLayer):
			node.hide()
			return

		node = node.get_parent()
