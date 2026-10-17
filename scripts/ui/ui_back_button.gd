extends UIButton

func _on_pressed() -> void:
	super._on_pressed()
	var node := get_parent()
	var root := get_tree().current_scene

	while node != null:
		if node.get_parent() == root:
			node.hide()
			return

		node = node.get_parent()
