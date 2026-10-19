# Run with: Godot --headless --path . --script res://tests/test_unit_pool.gd
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
	create_timer(10).timeout.connect(func() -> void: quit(1))
	var controller = root.get_node("ControllerGame")
	_expect(controller.units.is_empty(), "Units were generated before starting a game")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.get_node("MenuLayer/MainMenu/MarginContainer/Buttons/NewGame").pressed.emit()
	_expect(controller.units.size() == 3, "New game did not create exactly three units")
	var original_units: Array[BattleUnit] = controller.units.duplicate()
	var sprites: Array[Texture2D] = []
	for unit in original_units:
		_expect(unit.health == 1.0 and unit.attack_speed == 1.0 and unit.damage == 1.0 and unit.crit_chance == 0.0, "Starting unit has incorrect stats")
		_expect(unit.name in ["биба", "боба", "абоба"], "Starting unit lost its random name")
		_expect(unit.sprite != null and not sprites.has(unit.sprite), "Starting robot sprites are missing or repeated")
		sprites.append(unit.sprite)
	await create_timer(1.0).timeout
	var garage = root.get_node("Transition").gameplay_scene
	var tabs: TabContainer = garage.find_child("TabContainer2", true, false)
	var buttons: VBoxContainer = garage.find_child("TabButtons", true, false)
	for index in range(3):
		var tab := tabs.get_tab_control(index)
		var icon := tab.get_child(0) as TextureRect
		_expect(tab.name == "robot%d" % (index + 1), "Robot is assigned to the wrong garage tab")
		_expect(icon.texture == original_units[index].sprite, "Garage tab does not show its unit's sprite")
		_expect(buttons.get_child(index).tooltip_text == original_units[index].name, "Garage tab tooltip does not show its unit's name")

	var name_field: LineEdit = garage.find_child("robotname", true, false)
	_expect(name_field.text == original_units[0].name, "Name field did not show the active robot")
	var second_name := original_units[1].name
	name_field.grab_focus()
	name_field.select_all()
	var new_name := "Робот Вася"
	for character in new_name:
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		root.push_input(key)
	await process_frame
	name_field.release_focus()
	_expect(name_field.text == new_name and original_units[0].name == new_name, "Typing a name did not update the unit")
	_expect(buttons.get_child(0).tooltip_text == new_name, "Renaming did not update the robot tab tooltip")
	tabs.current_tab = 1
	_expect(name_field.text == second_name, "Changing tabs did not show the selected robot's name")
	_expect(original_units[0].name == new_name and original_units[1].name == second_name, "Switching robots overwrote a unit name")
	tabs.current_tab = 0
	_expect(name_field.text == new_name, "Returning to a robot lost its edited name")
	name_field.grab_focus()
	name_field.caret_column = name_field.text.length()
	var last_key := InputEventKey.new()
	last_key.pressed = true
	last_key.unicode = "!".unicode_at(0)
	root.push_input(last_key)
	tabs.current_tab = 1
	await process_frame
	new_name += "!"
	_expect(original_units[0].name == new_name and original_units[1].name == second_name, "Immediate tab switching saved the final character to the wrong robot")
	tabs.current_tab = 0
	name_field.release_focus()

	# Changing scenes must reuse the same objects and preserve their modified stats.
	original_units[0].damage = 7.0
	for attempt in range(2):
		var battle = load("res://scenes/battle.tscn").instantiate()
		main.add_child(battle)
		for index in range(3):
			_expect(battle.units[index] == original_units[index], "Opening battle regenerated a pooled unit")
		_expect(battle.units[0].damage == 7.0, "Opening battle reset a unit's stats")
		_expect(controller.units.size() == 3 and battle.units.size() == 4, "Battle empty slot changed the controller pool")
		_expect(battle.get_node("MarginContainer/HBoxContainer").get_child(0).debug_stats.text.begins_with(new_name + "\n"), "Battle did not display the edited name")
		battle.free()
		var another_garage = load("res://scenes/garage.tscn").instantiate()
		main.add_child(another_garage)
		_expect(another_garage.find_child("robotname", true, false).text == new_name, "Reopening the garage lost the edited name")
		for index in range(3):
			_expect(controller.units[index] == original_units[index], "Opening garage regenerated a pooled unit")
		another_garage.free()

	# Finished battles restore the same pooled units, including fallen robots.
	var boss_script = load("res://scripts/boss_unit.gd")
	for victory in [true, false]:
		var boss = boss_script.new()
		boss.health = 9999.0
		boss.damage = 1.0
		boss.attack_sequence.assign([1, 2, 3])
		var battle = load("res://scenes/battle.tscn").instantiate()
		battle.set_boss(boss)
		main.add_child(battle)
		controller.set_gameplay_scene(battle)
		_expect(battle.start_battle(), "Restored army could not start another battle")
		original_units[0].attack_speed = 2.0
		original_units[0].damage = 11.0
		original_units[0].crit_chance = 0.5
		battle.get_node("BattleTimer").stop()
		battle.get_node("BattleTimer").timeout.emit()
		_expect(original_units[0].health == 0.0, "Health was restored before combat finished")
		if victory:
			boss.health = 0.0
			battle.get_node("BattleTimer").timeout.emit()
		else:
			battle.get_node("BattleTimer").timeout.emit()
			battle.get_node("BattleTimer").timeout.emit()
		for index in range(3):
			_expect(controller.units[index] == original_units[index], "Finishing battle replaced a pooled unit")
			_expect(original_units[index].health == 1.0, "Finished battle did not restore a fallen robot")
			_expect(original_units[index].attack_speed == 1.0 and original_units[index].crit_chance == 0.0, "Finished battle did not restore stats")
		_expect(original_units[0].damage == 7.0, "Finishing battle discarded a pre-battle improvement")
		_expect(controller.scrapyard_available, "Stat restoration prevented reopening the scrapyard")
		battle.free()

	controller.reset_progress()
	_expect(controller.units.size() == 3, "Restarting game changed the unit count")
	for index in range(3):
		_expect(controller.units[index] != original_units[index], "New game reused an old unit")
		_expect(controller.units[index].damage == 1.0, "New game retained previous unit stats")
	main.free()
	for child in controller.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	await create_timer(0.1).timeout
	if not _failed:
		print("Unit pool tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
