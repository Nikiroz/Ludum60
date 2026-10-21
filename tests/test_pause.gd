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


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = keycode
	root.push_input(event)


func _escape() -> void:
	_key(KEY_ESCAPE)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var menu_music: AudioStreamPlayer = root.get_node("ControllerGame/MainMenuMusic")
	var main_menu: Control = main.get_node("MenuLayer/MainMenu")
	var settings_button: Button = main_menu.get_node("MarginContainer/Buttons/Settings_button")
	settings_button.grab_focus()
	_click(settings_button)
	_expect(paused and menu_music.playing and not menu_music.stream_paused and menu_music.can_process(), "Main menu settings stopped main menu music")
	_expect(not settings_button.has_focus() and not main_menu.can_process(), "Settings left the background menu focused or processing")
	_expect(settings_button.get_draw_mode() not in [BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED], "Clicked settings button stays visually highlighted behind the panel")
	_expect(settings_button.get_theme_stylebox("disabled") == settings_button.get_theme_stylebox("normal") and settings_button.get_theme_color("font_disabled_color") == settings_button.get_theme_color("font_color"), "Background button does not use its idle appearance")
	_key(KEY_TAB)
	var focused := root.gui_get_focus_owner()
	_expect(focused == null or not main_menu.is_ancestor_of(focused), "Tab focused a button behind settings")
	var layer: Control = main_menu.get_node("Paralax_3")
	var background_position := layer.position
	await create_timer(0.1).timeout
	_expect(layer.position.is_equal_approx(background_position), "Parallax moved behind the settings menu")
	_click(main.get_node("MenuLayer/Settings/Panel/VBoxContainer2/Button2"))
	_expect(main_menu.can_process(), "Closing settings did not resume the main menu")
	_expect(not settings_button.disabled and settings_button.focus_mode == Control.FOCUS_ALL, "Closing settings did not restore main menu interaction")
	var credits_button: Button = main_menu.get_node("MarginContainer/Buttons/Credits_button")
	credits_button.grab_focus()
	_click(credits_button)
	_expect(menu_music.playing and not menu_music.stream_paused, "Opening credits stopped main menu music")
	_expect(not credits_button.has_focus() and not main_menu.can_process(), "Credits left the background menu focused or processing")
	_expect(credits_button.get_draw_mode() not in [BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED], "Clicked credits button stays visually highlighted behind the panel")
	_key(KEY_TAB)
	focused = root.gui_get_focus_owner()
	_expect(focused == null or not main_menu.is_ancestor_of(focused), "Tab focused a button behind credits")
	background_position = layer.position
	await create_timer(0.1).timeout
	_expect(layer.position.is_equal_approx(background_position), "Parallax moved behind credits")
	_click(main.get_node("MenuLayer/Credits/Panel/VBoxContainer2/Button"))
	_expect(main_menu.can_process(), "Closing credits did not resume the main menu")
	_expect(not credits_button.disabled and credits_button.focus_mode == Control.FOCUS_ALL, "Closing credits did not restore main menu interaction")
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
	_expect(menu_music.playing and not menu_music.stream_paused and music.stream_paused, "Returning to the main menu through settings did not switch to main menu music")
	await create_timer(preload("res://sounds/click.wav").get_length() + 0.1).timeout
	main.free()
	await process_frame
	if not _failed:
		print("Pause tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
