# Run with: Godot --headless --path . --script res://tests/test_game_progress.gd
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


func _run() -> void:
	var controller = root.get_node("ControllerGame")
	var transition = root.get_node("Transition")
	var music: AudioStreamPlayer = controller.get_node("BackgroundMusic")
	var battle_music: AudioStreamPlayer = controller.get_node("BattleMusic")
	var menu_music: AudioStreamPlayer = controller.get_node("MainMenuMusic")
	var menu_playback := menu_music.get_stream_playback()
	_expect(menu_music.playing and not menu_music.stream_paused and menu_music.bus == &"Music", "Main menu music is missing or uses the wrong bus")
	_expect(menu_music.stream.resource_path == "res://sounds/MUSIC 3.ogg" and menu_music.stream.loop, "Main menu has the wrong track or loop setting")
	_expect(not music.playing or music.stream_paused, "Gameplay background music is audible in the main menu")
	_expect(music.stream is AudioStreamOggVorbis and music.stream.loop, "Background music is not looped")
	_expect(battle_music.stream.resource_path == "res://sounds/MUSIC 2.ogg" and battle_music.stream.loop and battle_music.bus == &"Music", "Battle music has the wrong track, loop setting or bus")
	_expect(not battle_music.playing or battle_music.stream_paused, "Battle music is audible in the main menu")
	controller.reset_progress()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_expect(not main.has_node("Navigation"), "Main scene still contains shared navigation")
	var garage = load("res://scenes/garage.tscn").instantiate()
	main.add_child(garage)
	controller.set_gameplay_scene(garage)
	_expect(music.playing and not music.stream_paused, "Garage has no background music")
	_expect(menu_music.stream_paused, "Main menu music is audible in the garage")
	_expect(not battle_music.playing or battle_music.stream_paused, "Battle music is audible in the garage")
	music.seek(8.0)
	await create_timer(0.1).timeout
	var background_playback := music.get_stream_playback()
	var background_position := music.get_playback_position()
	var scrapyard_button: Button = garage.get_node("ScrapyardButton")
	_expect(controller.scrapyard_available and not scrapyard_button.disabled, "Scrapyard must initially be available")

	var yard = load("res://scenes/scrapyard.tscn").instantiate()
	main.add_child(yard)
	controller.set_gameplay_scene(yard)
	_expect(music.playing and not music.stream_paused, "Scrapyard has no background music")
	_expect(music.get_stream_playback() == background_playback and music.get_playback_position() >= background_position, "Entering the scrapyard restarted or rewound background music")
	_expect(menu_music.stream_paused, "Main menu music is audible in the scrapyard")
	_expect(not battle_music.playing or battle_music.stream_paused, "Battle music is audible in the scrapyard")
	await process_frame
	await process_frame
	_expect(not controller.scrapyard_available, "Entering the scrapyard did not consume the visit")
	_expect(scrapyard_button.disabled, "Used scrapyard button is still enabled")
	_expect(not yard.get_node("GarageButton").visible, "Garage button appeared before the scrapyard round ended")
	garage.free()
	var hidden = yard.hidden_items[0]
	for cell in hidden.cells:
		while cell.clicks_left > 0:
			cell.hit()
	_expect(controller.collected_items.size() == 1, "Revealing an item did not save it in the controller")
	var saved: GridInventoryItemData = controller.collected_items[0]
	_expect(saved.item_id == hidden.data.item_id and saved.sprite_path == hidden.data.sprite_path, "Saved item lost its display data")
	_expect(saved != hidden.data, "Collected instance still shares its catalog resource")
	yard.end_game()
	_expect(not controller.scrapyard_available, "Finishing the scrapyard reopened it before battle")
	_expect(yard.get_node("GarageButton").visible, "Finishing the scrapyard did not show its garage button")
	yard.free()
	_expect(controller.collected_items.size() == 1, "Leaving the scrapyard lost its collected item")

	garage = load("res://scenes/garage.tscn").instantiate()
	main.add_child(garage)
	controller.set_gameplay_scene(garage)
	_expect(music.get_stream_playback() == background_playback and music.get_playback_position() >= background_position, "Returning from the scrapyard restarted or rewound background music")
	_expect(music.get_parent() == controller, "Background music depends on a gameplay scene")
	scrapyard_button = garage.get_node("ScrapyardButton")
	_expect(scrapyard_button.visible and scrapyard_button.disabled, "Garage did not show the unavailable scrapyard")
	transition.change_scene("res://scenes/scrapyard.tscn")
	_expect(not transition.transitioning, "Direct transition bypassed the scrapyard availability flag")
	transition.gameplay_scene = garage
	garage.get_node("VBoxContainer/MarginContainer2/HBoxContainer/BattleButton").pressed.emit()
	while transition.transitioning:
		await process_frame
	var opened_battle: Node = transition.gameplay_scene
	_expect(is_instance_valid(opened_battle) and opened_battle.scene_file_path == "res://scenes/battle.tscn", "Garage battle button did not open the battle scene")
	_expect(music.stream_paused, "Background music continued on the battle screen")
	_expect(battle_music.playing and not battle_music.stream_paused, "Battle screen has no battle music")
	var battle_playback := battle_music.get_stream_playback()
	_expect(menu_music.stream_paused, "Main menu music is audible in battle")
	_expect(not opened_battle.get_node("GarageButton").visible, "Battle preparation showed the garage button")
	opened_battle.get_node("StarBattleButton").pressed.emit()
	_expect(not opened_battle.get_node("GarageButton").visible, "Starting battle showed the garage button")
	opened_battle._finish_battle(true)
	_expect(opened_battle.get_node("GarageButton").visible, "Finishing battle did not show the garage button")
	var victory_dialog: Control = main.get_node("MenuLayer/VictoryDialog")
	_expect(victory_dialog.visible and paused, "Victory did not open its modal dialog")
	victory_dialog.get_node("Panel/VBoxContainer/Buttons/Yes").pressed.emit()
	opened_battle.get_node("GarageButton").pressed.emit()
	while transition.transitioning:
		await process_frame
	garage = transition.gameplay_scene
	_expect(is_instance_valid(garage) and garage.scene_file_path == "res://scenes/garage.tscn", "Battle garage button did not return to the garage")
	_expect(music.playing and not music.stream_paused, "Returning from battle did not resume the background music")
	_expect(music.get_stream_playback() == background_playback and music.get_playback_position() >= background_position, "Returning from battle restarted or rewound background music")
	_expect(battle_music.stream_paused, "Returning from battle did not pause battle music")
	garage.free()

	for victory in [true, false]:
		controller.scrapyard_available = false
		var battle = load("res://scenes/battle.tscn").instantiate()
		main.add_child(battle)
		controller.set_gameplay_scene(battle)
		_expect(battle_music.playing and not battle_music.stream_paused, "Battle preparation has no battle music")
		_expect(battle_music.get_stream_playback() == battle_playback, "Opening another battle restarted battle music")
		_expect(not controller.scrapyard_available, "Battle preparation reopened the scrapyard")
		var start_button: Button = battle.get_node("StarBattleButton")
		_expect(start_button.visible and not start_button.disabled, "Battle preparation hid or disabled its start button")
		_expect(not battle.get_node("GarageButton").visible, "Battle preparation showed its garage button")
		battle._finish_battle(victory)
		_expect(music.stream_paused, "Finishing battle resumed background music on the battle screen")
		_expect(battle_music.playing and not battle_music.stream_paused, "Finishing battle paused battle music on the battle screen")
		_expect(controller.scrapyard_available, "Completing battle did not reopen the scrapyard")
		_expect(start_button.visible and start_button.disabled, "Completed battle did not leave its start button visible and disabled")
		_expect(battle.get_node("GarageButton").visible, "Completed battle hid its garage button")
		_expect(victory_dialog.visible == victory, "Victory dialog appeared for the wrong result")
		if victory:
			victory_dialog.get_node("Panel/VBoxContainer/Buttons/Yes").pressed.emit()
		_expect(controller.collected_items.size() == 1, "Battle cleared collected items")
		battle.free()
		garage = load("res://scenes/garage.tscn").instantiate()
		main.add_child(garage)
		controller.set_gameplay_scene(garage)
		scrapyard_button = garage.get_node("ScrapyardButton")
		_expect(scrapyard_button.visible and not scrapyard_button.disabled, "Returning to the garage did not enable its scrapyard button")
		garage.free()

	controller.add_collected_item(saved)
	_expect(controller.collected_items.size() == 2, "Collecting another copy overwrote an existing item")
	controller.reset_progress()
	_expect(controller.collected_items.is_empty() and controller.scrapyard_available, "New game did not reset progress")
	var final_battle = load("res://scenes/battle.tscn").instantiate()
	main.add_child(final_battle)
	controller.set_gameplay_scene(final_battle)
	paused = true
	_expect(battle_music.playing and not battle_music.stream_paused and battle_music.can_process(), "Battle music stopped processing while the game was paused")
	paused = false
	controller.isMainMenu = true
	_expect(menu_music.playing and not menu_music.stream_paused, "Returning to the main menu from battle did not resume main menu music")
	_expect(menu_music.get_stream_playback() == menu_playback, "Returning to the main menu restarted menu music")
	_expect(music.stream_paused, "Returning to the main menu did not pause gameplay background music")
	_expect(battle_music.stream_paused, "Returning to the main menu did not pause battle music")
	background_playback = music.get_stream_playback()
	await create_timer(0.1).timeout
	background_position = music.get_playback_position()
	await create_timer(0.1).timeout
	_expect(is_equal_approx(music.get_playback_position(), background_position), "Inactive background music did not stay paused in the main menu")
	controller.isMainMenu = false
	_expect(music.playing and not music.stream_paused and menu_music.stream_paused, "Starting a new game did not switch from main menu music to gameplay music")
	_expect(music.get_stream_playback() == background_playback and music.get_playback_position() >= background_position, "Returning from the main menu restarted or rewound background music")
	main.free()
	await process_frame
	if not _failed:
		print("Game progress tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
