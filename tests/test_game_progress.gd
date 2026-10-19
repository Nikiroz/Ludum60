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
	_expect(music.playing and not music.stream_paused and music.bus == &"Music", "Main menu music is missing or uses the wrong bus")
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
	_expect(not battle_music.playing or battle_music.stream_paused, "Battle music is audible in the garage")
	var scrapyard_button: Button = garage.get_node("ScrapyardButton")
	_expect(controller.scrapyard_available and not scrapyard_button.disabled, "Scrapyard must initially be available")

	var yard = load("res://scenes/scrapyard.tscn").instantiate()
	main.add_child(yard)
	controller.set_gameplay_scene(yard)
	_expect(music.playing and not music.stream_paused, "Scrapyard has no background music")
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
	opened_battle.get_node("GarageButton").pressed.emit()
	while transition.transitioning:
		await process_frame
	garage = transition.gameplay_scene
	_expect(is_instance_valid(garage) and garage.scene_file_path == "res://scenes/garage.tscn", "Battle garage button did not return to the garage")
	_expect(music.playing and not music.stream_paused, "Returning from battle did not resume the background music")
	_expect(battle_music.stream_paused, "Returning from battle did not pause battle music")
	garage.free()

	for victory in [true, false]:
		controller.scrapyard_available = false
		var battle = load("res://scenes/battle.tscn").instantiate()
		main.add_child(battle)
		controller.set_gameplay_scene(battle)
		_expect(battle_music.playing and not battle_music.stream_paused, "Battle preparation has no battle music")
		_expect(not controller.scrapyard_available, "Battle preparation reopened the scrapyard")
		_expect(battle.get_node("StarBattleButton").visible, "Battle preparation hid its start button")
		_expect(battle.get_node("GarageButton").visible, "Battle preparation hid its garage button")
		battle._finish_battle(victory)
		_expect(music.stream_paused, "Finishing battle resumed background music on the battle screen")
		_expect(battle_music.playing and not battle_music.stream_paused, "Finishing battle paused battle music on the battle screen")
		_expect(controller.scrapyard_available, "Completing battle did not reopen the scrapyard")
		_expect(not battle.get_node("StarBattleButton").visible, "Completed battle showed its start button")
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
	_expect(music.playing and not music.stream_paused, "Returning to the main menu from battle did not resume background music")
	_expect(battle_music.stream_paused, "Returning to the main menu did not pause battle music")
	main.free()
	await process_frame
	if not _failed:
		print("Game progress tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
