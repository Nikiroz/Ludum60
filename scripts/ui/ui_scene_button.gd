extends UIButton

@export_file("*.tscn") var scene_path: String
@export var show_after_round_finished := false


func _ready() -> void:
	if show_after_round_finished:
		hide()
		owner.connect("round_finished", show)
	if scene_path == "res://scenes/scrapyard.tscn":
		ControllerGame.scrapyard_availability_changed.connect(_update_scrapyard_availability)
		_update_scrapyard_availability()


func _update_scrapyard_availability() -> void:
	disabled = not ControllerGame.scrapyard_available


func _on_pressed() -> void:
	
	if Transition.transitioning or scene_path.is_empty():
		return
	super._on_pressed()
	Transition.change_scene(scene_path)
