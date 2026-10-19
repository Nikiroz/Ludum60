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
	controller.reset_progress()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var scrapyard_button: Button = main.get_node("Navigation/ScrapyardButton")
	_expect(controller.scrapyard_available and not scrapyard_button.disabled, "Scrapyard must initially be available")

	var yard = load("res://scenes/scrapyard.tscn").instantiate()
	main.add_child(yard)
	controller.set_gameplay_scene(yard)
	await process_frame
	await process_frame
	_expect(not controller.scrapyard_available, "Entering the scrapyard did not consume the visit")
	_expect(scrapyard_button.disabled, "Used scrapyard button is still enabled")
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
	yard.free()
	_expect(controller.collected_items.size() == 1, "Leaving the scrapyard lost its collected item")

	var garage = load("res://scenes/garage.tscn").instantiate()
	main.add_child(garage)
	controller.set_gameplay_scene(garage)
	_expect(scrapyard_button.visible and scrapyard_button.disabled, "Garage did not show the unavailable scrapyard")
	transition.change_scene("res://scenes/scrapyard.tscn")
	_expect(not transition.transitioning, "Direct transition bypassed the scrapyard availability flag")
	garage.free()

	for victory in [true, false]:
		controller.scrapyard_available = false
		var battle = load("res://scenes/battle.tscn").instantiate()
		main.add_child(battle)
		controller.set_gameplay_scene(battle)
		_expect(not controller.scrapyard_available, "Battle preparation reopened the scrapyard")
		battle._finish_battle(victory)
		_expect(controller.scrapyard_available and not scrapyard_button.disabled, "Completing battle did not reopen the scrapyard")
		_expect(controller.collected_items.size() == 1, "Battle cleared collected items")
		battle.free()

	controller.add_collected_item(saved)
	_expect(controller.collected_items.size() == 2, "Collecting another copy overwrote an existing item")
	controller.reset_progress()
	_expect(controller.collected_items.is_empty() and controller.scrapyard_available, "New game did not reset progress")
	main.free()
	await process_frame
	if not _failed:
		print("Game progress tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
