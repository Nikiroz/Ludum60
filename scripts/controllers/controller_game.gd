extends Node

const CURSOR_NORMAL: Texture2D = preload("res://sprites/cursors/cursor.png")

var _navigation: CanvasLayer
var _location := "garage"
var _round_finished := false

var isMainMenu := true:
	set(value):
		isMainMenu = value
		_update_quit_to_main_menu_visibility()

func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_NORMAL, Input.CURSOR_ARROW)
	set_drag_cursor(false)
	call_deferred("_update_quit_to_main_menu_visibility")

func register_navigation(navigation: CanvasLayer, location: String) -> void:
	_navigation = navigation
	_location = location
	_round_finished = false
	_update_navigation_visibility()

func set_gameplay_scene(scene: Node) -> void:
	_location = scene.scene_file_path.get_file().get_basename()
	_round_finished = false
	if scene.has_signal("round_finished"):
		scene.connect("round_finished", _on_round_finished)
	_update_navigation_visibility()

func _on_round_finished() -> void:
	_round_finished = true
	_update_navigation_visibility()

func _update_navigation_visibility() -> void:
	if not is_instance_valid(_navigation):
		return

	_navigation.get_node("GarageButton").visible = _location == "battle" or _round_finished
	_navigation.get_node("ScrapyardButton").visible = _location == "garage" and not _round_finished
	_navigation.get_node("BattleButton").visible = _location == "garage" and not _round_finished
	_navigation.get_node("StarBattleButton").visible = _location == "battle"

func set_drag_cursor(dragging: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if dragging else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if isMainMenu:
		return

	if event.is_action_pressed("ui_cancel"):
		var warning := get_tree().current_scene.get_node_or_null("MenuLayer/Warning") as Control
		var settings := _get_settings()
		if warning != null and warning.is_visible_in_tree():
			warning.hide()
		elif settings != null and settings.is_visible_in_tree():
			settings.hide()
		else:
			show_settings()
		get_viewport().set_input_as_handled()

func show_settings() -> void:
	var settings := _get_settings()
	if settings == null:
		push_error("Settings node not found")
		return

	settings.show()
	_update_quit_to_main_menu_visibility()

func _get_settings() -> Control:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	return current_scene.get_node_or_null("MenuLayer/Settings") as Control

func _update_quit_to_main_menu_visibility() -> void:
	var settings := _get_settings()
	if settings == null:
		return

	var quit_to_main_menu := settings.get_node_or_null(
		"Panel/VBoxContainer2/QuitToMainMenu"
	) as Button
	if quit_to_main_menu != null:
		quit_to_main_menu.visible = not isMainMenu

func play_one_shot(stream: AudioStream, bus := "Sfx", volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p
