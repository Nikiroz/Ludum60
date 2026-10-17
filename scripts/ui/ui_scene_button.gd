extends UIButton

@export_file("*.tscn") var scene_path: String


func _on_pressed() -> void:
	if Transition.transitioning or scene_path.is_empty():
		return
	super._on_pressed()
	Transition.change_scene(scene_path)
