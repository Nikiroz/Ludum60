# Run with: Godot --headless --path . --script res://tests/test_pause.gd
extends SceneTree

var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	root.push_input(event)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	root.get_node("ControllerGame").isMainMenu = false
	main.get_node("MenuLayer/MainMenu").hide()
	var settings: Control = main.get_node("MenuLayer/Settings")
	var warning: Control = main.get_node("MenuLayer/Warning")
	var running := Timer.new()
	main.add_child(running)
	running.start(10.0)
	var stopped := Timer.new()
	main.add_child(stopped)
	var already_paused := Timer.new()
	main.add_child(already_paused)
	already_paused.start(10.0)
	already_paused.paused = true
	await process_frame

	_escape()
	_expect(paused and settings.visible, "Escape did not open the menu and pause gameplay")
	var music: AudioStreamPlayer = root.get_node("ControllerGame/BackgroundMusic")
	_expect(music.playing and not music.stream_paused and music.can_process(), "Settings pause stopped the background music")
	var time_before := running.time_left
	await create_timer(0.1).timeout
	_expect(is_equal_approx(running.time_left, time_before), "Timer counted down while menu was open")
	_expect(settings.can_process(), "Menu controls stopped processing while paused")
	_escape()
	_expect(not paused and not settings.visible, "Second Escape did not resume gameplay")
	await create_timer(0.1).timeout
	_expect(running.time_left < time_before, "Timer did not resume from its remaining time")
	_expect(stopped.is_stopped(), "Resuming started a stopped timer")
	_expect(already_paused.paused and is_equal_approx(already_paused.time_left, 10.0), "Resuming changed an independently paused timer")

	_escape()
	settings.get_node("Panel/VBoxContainer2/Button2").pressed.emit()
	_expect(not paused and not settings.visible, "Back button did not resume gameplay")
	_escape()
	warning.show()
	_escape()
	_expect(paused and settings.visible and not warning.visible, "Dismissing confirmation resumed behind the settings menu")
	settings.get_node("Panel/VBoxContainer2/QuitToMainMenu").pressed.emit()
	warning.get_node("Panel/VBoxContainer/HBoxContainer/yes").pressed.emit()
	_expect(not paused and root.get_node("ControllerGame").isMainMenu, "Returning to the main menu left gameplay paused")
	await create_timer(preload("res://sounds/click.wav").get_length() + 0.1).timeout
	main.free()
	await process_frame
	if not _failed:
		print("Pause tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
