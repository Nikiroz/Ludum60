extends CanvasLayer

@onready var overlay: TextureRect = $TextureRect
@onready var shader_material: ShaderMaterial = overlay.material

var transitioning := false
var gameplay_scene: Node


func _ready() -> void:
	overlay.hide()
	shader_material.set_shader_parameter("progress", 0.0)


func change_scene(path: String) -> void:
	if transitioning:
		return

	transitioning = true
	overlay.show()

	await animate_progress(0.5)

	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Failed to open scene: " + path)
		reset_transition()
		return

	var main := get_tree().current_scene
	var new_scene := scene.instantiate()
	if main is Node2D:
		get_tree().root.add_child(new_scene)
		get_tree().current_scene = new_scene
		main.queue_free()
	else:
		if is_instance_valid(gameplay_scene):
			main.remove_child(gameplay_scene)
			gameplay_scene.queue_free()
		main.add_child(new_scene)
		main.move_child(new_scene, 0)
	gameplay_scene = new_scene
	ControllerGame.set_gameplay_scene(new_scene)
	var main_menu := main.get_node_or_null("MenuLayer/MainMenu") as Control
	if main_menu != null:
		main_menu.hide()

	await animate_progress(1.0)
	
	reset_transition()


func animate_progress(target: float) -> void:
	var tween := create_tween()
	tween.tween_property(
		shader_material,
		"shader_parameter/progress",
		target,
		0.4
	)
	await tween.finished


func reset_transition() -> void:
	overlay.hide()
	shader_material.set_shader_parameter("progress", 0.0)
	transitioning = false
