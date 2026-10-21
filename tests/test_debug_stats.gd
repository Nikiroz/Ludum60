# Run with: Godot --headless --path . --script res://tests/test_debug_stats.gd
extends SceneTree

const ItemCatalog = preload("res://scripts/item_catalog.gd")

var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Debug stats: " + message)


func _key(keycode: Key, echo: bool = false, physical: bool = false) -> void:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = keycode
	else:
		event.keycode = keycode
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = InputEventKey.new()
	if physical:
		event.physical_keycode = keycode
	else:
		event.keycode = keycode
	root.push_input(event)


func _click(at_position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at_position
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)


func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	var controller = root.get_node("ControllerGame")
	controller.reset_progress()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	controller.isMainMenu = false
	main.get_node("MenuLayer/MainMenu").hide()
	var garage = load("res://scenes/garage.tscn").instantiate()
	main.add_child(garage)
	await process_frame
	await process_frame
	var tabs: TabContainer = garage.find_child("TabContainer2", true, false)
	var preview: Control = tabs.get_tab_control(0).get_node("EquipmentPreview")
	var stats: Label = preview.get_node("DebugStats")
	_expect(not controller.debug_mode and not stats.visible, "Stats are visible before F9")
	garage.find_child("robotname", true, false).grab_focus()
	# F8 adds a separate copy of every catalog item and updates the open inventory.
	var paths := ItemCatalog.get_item_paths()
	controller.add_collected_item(load("res://item_pack/items/head_lamp.tres"))
	var existing: GridInventoryItemData = controller.collected_items[0]
	var existing_position: Vector2i = controller.inventory_positions[existing]
	_key(KEY_F8)
	_expect(controller.collected_items.size() == 1, "F8 granted items while debug mode was disabled")
	controller.add_all_items_to_inventory()
	_expect(controller.collected_items.size() == 1, "Direct item grant bypassed disabled debug mode")
	_key(KEY_F9)
	_expect(controller.debug_mode and stats.is_visible_in_tree(), "F9 did not enable debug mode before granting items")
	_key(KEY_F8)
	_expect(controller.collected_items.size() == paths.size() + 1, "F8 did not add exactly one full item set")
	var inventory = garage.find_child("HeadsContainer", true, false)
	_expect(inventory.items.size() == controller.collected_items.size(), "F8 did not update the visible inventory")
	_expect(controller.collected_items[0] == existing and controller.inventory_positions[existing] == existing_position, "F8 changed an existing item or its inventory position")
	for index in range(paths.size()):
		var source := load(paths[index]) as GridInventoryItemData
		var collected: GridInventoryItemData = controller.collected_items[index + 1]
		_expect(collected != source and collected.item_id == source.item_id, "F8 omitted an item or reused its source resource: " + paths[index])
	_key(KEY_F8, true)
	_expect(controller.collected_items.size() == paths.size() + 1, "Holding F8 repeatedly granted item sets")
	paused = true
	_key(KEY_F8, false, true)
	_expect(paused and controller.collected_items.size() == paths.size() * 2 + 1, "Physical F8 did not add another full set while paused")
	_expect(inventory.items.size() == controller.collected_items.size(), "Paused F8 did not update the inventory")
	_expect(controller.collected_items[1] != controller.collected_items[paths.size() + 1], "Repeated F8 reused an inventory item instance")
	_expect(controller.debug_mode, "F8 toggled the F9 debug overlay")
	paused = false
	_key(KEY_F9)
	_key(KEY_F8)
	_expect(not controller.debug_mode and controller.collected_items.size() == paths.size() * 2 + 1, "F8 kept granting items after disabling debug mode")
	_key(KEY_F9)
	_expect(controller.debug_mode and stats.is_visible_in_tree(), "F9 with a focused name field did not show garage stats")
	_expect(stats.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay intercepts equipment input")
	_key(KEY_F9, true)
	_expect(controller.debug_mode, "Held F9 toggled debug mode repeatedly")
	var unit: BattleUnit = controller.units[0]
	unit.health = 72.25
	unit.damage = 12.5
	unit.attack_speed = 1.75
	unit.crit_chance = 0.125
	await process_frame
	await process_frame
	_expect(unit.health == 72.0 and unit.damage == 13.0, "Health and damage were not rounded to the nearest integers")
	_expect(stats.text == "HP 72\nDMG 13\nATK/s 1.75\nCRIT 12.5%", "Overlay does not show current robot stats")
	_expect(garage.get_node("%Health").text == "72" and garage.get_node("%Damage").text == "13", "Garage HP and damage labels contain fractional values")
	_expect(Rect2(Vector2.ZERO, preview.size).encloses(stats.get_rect()), "Garage stats do not fit over the robot")
	garage.free()

	var battle = load("res://scenes/battle.tscn").instantiate()
	main.add_child(battle)
	controller.set_gameplay_scene(battle)
	await process_frame
	await process_frame
	var row: HBoxContainer = battle.get_node("MarginContainer/HBoxContainer")
	var slot: Control = row.get_child(0)
	stats = slot.equipment_preview.get_node("DebugStats")
	var boss_slot: Control = battle.get_node("MarginContainer2").get_child(0)
	var boss_stats: Label = boss_slot.icon.get_node("DebugStats")
	battle.boss.attack_sequence.assign([1])
	battle.boss.damage = 3.0
	battle.boss.crit_chance = 0.0
	_expect(controller.debug_mode and stats.is_visible_in_tree(), "Scene replacement lost debug mode")
	_expect(boss_stats.is_visible_in_tree() and boss_stats.text.begins_with("HP 9999\n"), "Boss stats are missing")
	var next_stats: Label = row.get_child(1).equipment_preview.get_node("DebugStats")
	_expect(not stats.get_global_rect().intersects(next_stats.get_global_rect()), "Adjacent robot stats overlap")
	_expect(Rect2(Vector2.ZERO, boss_slot.icon.size).encloses(boss_stats.get_rect()), "Boss stats do not fit over its sprite")
	_expect(not row.get_child(3).equipment_preview.get_node("DebugStats").visible, "An empty battle slot shows stats")
	slot._start_drag()
	_expect(slot._preview_equipment.get_node("DebugStats").is_visible_in_tree(), "Dragging a robot lost its stats")
	slot._clear_drag()
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	battle._on_battle_tick()
	await process_frame
	await process_frame
	_expect(unit.health == 69.0 and stats.text.begins_with("HP 69\n"), "Battle damage did not update robot stats")
	_expect(boss_stats.text.begins_with("HP %d\n" % boss_slot.unit.health), "Battle damage did not update boss stats")
	paused = true
	_key(KEY_F9)
	_expect(not controller.debug_mode and not stats.visible and not boss_stats.visible, "F9 while paused did not hide all stats")
	_key(KEY_F9)
	_expect(controller.debug_mode and stats.visible and boss_stats.visible and paused, "F9 changed gameplay pause state")
	paused = false
	controller.debug_mode = false
	battle.free()

	var boss = load("res://scripts/boss_unit.gd").new()
	boss.health = 250.0
	boss.damage = 0.0
	boss.attack_sequence.clear()
	unit.health = 100.0
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.set_units([unit])
	battle.set_boss(boss)
	main.add_child(battle)
	controller.set_gameplay_scene(battle)
	controller.scrapyard_available = false
	await process_frame
	await process_frame
	boss_slot = battle.get_node("MarginContainer2").get_child(0)
	var boss_rect: Rect2 = boss_slot.icon.get_global_rect()
	var click_point := Vector2(boss_rect.get_center().x, boss_rect.position.y + 8.0)
	_expect(not boss_slot.get_global_rect().has_point(click_point), "Click test does not cover the boss outside its slot")
	_click(click_point)
	_expect(boss.health == 250.0, "Clicking the boss outside debug mode dealt damage")
	_key(KEY_F9)
	_click(click_point, MOUSE_BUTTON_RIGHT)
	_expect(boss.health == 250.0, "Right-clicking the boss dealt debug damage")
	_click(Vector2(2, 50))
	_expect(boss.health == 250.0, "Clicking outside the boss dealt debug damage")
	_click(click_point)
	_expect(boss.health == 150.0 and battle.state == battle.State.PREPARATION, "One click did not deal exactly 100 HP during preparation")
	await process_frame
	await process_frame
	_expect(boss_slot.health_label.text == "150" and boss_slot.icon.texture == boss.get_health_sprite(), "Debug damage did not update boss health or sprite")
	controller.show_settings()
	_click(click_point)
	_expect(paused and boss.health == 150.0, "Clicking while paused damaged the boss")
	main.get_node("MenuLayer/Settings").hide()
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	unit.health = 42.0
	_click(boss_slot.icon.get_node("DebugStats").get_global_rect().get_center())
	_expect(boss.health == 50.0 and battle.state == battle.State.FIGHTING, "Clicking through the stats overlay did not deal exactly 100 HP")
	_click(click_point)
	_expect(boss.health == 0.0 and battle.state == battle.State.VICTORY, "Lethal debug damage did not finish battle or clamped HP incorrectly")
	_expect(battle.get_node("MarginContainer2").get_child_count() == 0 and battle.get_node("BattleTimer").is_stopped(), "Debug victory left the boss or timer active")
	_expect(main.get_node("MenuLayer/VictoryDialog").visible and paused and controller.scrapyard_available and unit.health == 100.0, "Debug victory did not show its dialog, restore robot health or unlock the scrapyard")
	main.get_node("MenuLayer/VictoryDialog/Panel/VBoxContainer/Buttons/Yes").pressed.emit()
	controller.debug_mode = false
	main.free()
	await process_frame
	if not _failed:
		print("Debug stats tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
