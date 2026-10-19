# Run with: Godot --headless --path . --script res://tests/test_equipment.gd
extends SceneTree

var _failed := false
var _checks := 0
var _controller: Node
var _viewport: SubViewport
var _garage
var _grid
var _tabs: TabContainer


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _give(id: String, health: float, speed: float, damage: float, crit: float) -> GridInventoryItemData:
	var item := GridInventoryItemData.new()
	item.item_id = id
	item.display_name = id
	item.sprite_path = "res://item_pack/sprites/head_lamp.png"
	item.occupied_cells = [Vector2i.ZERO]
	item.health_bonus = health
	item.attack_speed_bonus = speed
	item.damage_bonus = damage
	item.crit_chance_bonus = crit
	_controller.add_collected_item(item)
	return _controller.collected_items.back()


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_viewport.push_input(event, true)


func _motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(event, true)


func _drag(item: GridInventoryItemData, left_half: bool = true) -> void:
	_grid.get_parent().scroll_vertical = 0
	await process_frame
	var origin: Vector2i = _controller.inventory_positions[item]
	var start: Vector2 = _grid.global_position + Vector2(origin) * 12 + Vector2(6, 6)
	var page: Control = _tabs.get_current_tab_control()
	var finish: Vector2 = page.global_position + page.size * Vector2(0.25 if left_half else 0.75, 0.65)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	_expect(_viewport.gui_is_dragging(), "Inventory item did not start dragging")
	_motion(finish, finish - start)
	_mouse(finish, false)
	await process_frame
	await process_frame


func _stats(unit: BattleUnit, health: float, speed: float, damage: float, crit: float) -> void:
	_expect(is_equal_approx(unit.health, health), "Equipment health total is wrong")
	_expect(is_equal_approx(unit.attack_speed, speed), "Equipment speed total is wrong")
	_expect(is_equal_approx(unit.damage, damage), "Equipment damage total is wrong")
	_expect(is_equal_approx(unit.crit_chance, crit), "Equipment critical chance total is wrong")


func _open_garage() -> void:
	_garage = load("res://scenes/garage.tscn").instantiate()
	_viewport.add_child(_garage)
	_grid = _garage.find_child("HeadsContainer", true, false)
	_tabs = _garage.find_child("TabContainer2", true, false)
	await process_frame
	await process_frame


func _run() -> void:
	create_timer(10).timeout.connect(func() -> void: quit(1))
	_controller = root.get_node("ControllerGame")
	_controller.reset_progress()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 180)
	root.add_child(_viewport)
	await _open_garage()
	var first: BattleUnit = _controller.units[0]
	var second: BattleUnit = _controller.units[1]

	var head := _give("head_lamp", 10, 2, 3, 0.1)
	await _drag(head)
	_expect(first.equipment.get(&"head") == head, "Dropping on a robot did not equip its head")
	_expect(not _controller.collected_items.has(head) and not _grid.items.has(head), "Equipped item remained in inventory")
	_expect(not _controller.inventory_positions.has(head), "Equipped item still occupies grid cells")
	_stats(first, 11, 3, 4, 0.1)
	_expect(is_equal_approx(_garage.get_node("%Speed").text.to_float(), 3.0) and is_equal_approx(_garage.get_node("%Crit").text.trim_suffix("%").to_float(), 10.0), "Garage labels did not update after equipping")

	var replacement_head := _give("head_router", 20, 4, 5, 0.2)
	await _drag(replacement_head)
	_expect(first.equipment.get(&"head") == replacement_head, "New head did not replace the previous head")
	_expect(_controller.collected_items.count(head) == 1 and _grid.items.has(head), "Replaced head did not return to inventory exactly once")
	_stats(first, 21, 5, 6, 0.2)

	var torso := _give("base_fridge", 100, 0, 0, 0)
	await _drag(torso)
	_stats(first, 121, 5, 6, 0.2)
	var replacement_torso := _give("base_printer", 50, 1, 2, 0)
	await _drag(replacement_torso)
	_expect(first.equipment.get(&"torso") == replacement_torso and _grid.items.has(torso), "Torso replacement did not return the old torso")
	_stats(first, 71, 6, 8, 0.2)
	var legs := _give("leg_bicycle", 5, 2, 3, 0.05)
	await _drag(legs)
	_stats(first, 76, 8, 11, 0.25)
	var replacement_legs := _give("leg_bathtub", 8, -1, 0, 0)
	await _drag(replacement_legs)
	_expect(first.equipment.get(&"legs") == replacement_legs and _grid.items.has(legs), "Leg replacement did not return the previous legs")
	_stats(first, 79, 5, 8, 0.2)

	var left := _give("hand_drill", 0, 1, 10, 0.01)
	await _drag(left, true)
	var right := _give("hand_mouse", 2, 3, 4, 0.02)
	await _drag(right, false)
	_expect(first.equipment.get(&"left_hand") == left and first.equipment.get(&"right_hand") == right, "Drop halves did not assign independent hands")
	_stats(first, 81, 9, 22, 0.23)
	var replacement_left := _give("hand_mixer", 3, 5, 6, 0.03)
	await _drag(replacement_left, true)
	_expect(first.equipment.get(&"left_hand") == replacement_left and first.equipment.get(&"right_hand") == right, "Replacing the left hand changed the right hand")
	_expect(_grid.items.has(left) and not _grid.items.has(right), "Replacing one hand returned the wrong item")
	_stats(first, 84, 13, 18, 0.25)
	_expect(not _controller.equip_item(first, replacement_left), "Equipped item could be applied twice")
	_stats(first, 84, 13, 18, 0.25)

	var invalid := _give("unknown_part", 1000, 1000, 1000, 1)
	await _drag(invalid)
	_expect(_grid.items.has(invalid), "Unsupported item disappeared on an invalid drop")
	_stats(first, 84, 13, 18, 0.25)
	_tabs.current_tab = 1
	await _drag(head)
	_expect(second.equipment.get(&"head") == head and first.equipment.get(&"head") == replacement_head, "Drop affected a robot other than the active robot")
	_stats(second, 11, 3, 4, 0.1)
	_stats(first, 84, 13, 18, 0.25)
	_expect(not _controller.equip_item(BattleUnit.new(), invalid), "Foreign robot could equip an inventory item")

	_garage.free()
	await _open_garage()
	_expect(first.equipment.size() == 5 and first.equipment.get(&"right_hand") == right, "Returning to garage lost equipment")
	_expect(_grid.items.has(left) and not _grid.items.has(replacement_left), "Returning to garage changed equipped or returned item ownership")
	var battle = load("res://scenes/battle.tscn").instantiate()
	var boss = load("res://scripts/boss_unit.gd").new()
	boss.health = 1000000
	boss.damage = 1000000
	boss.attack_sequence.assign([1])
	battle.set_units([first])
	battle.set_boss(boss)
	_viewport.add_child(battle)
	_expect(battle.start_battle(), "Equipped robot could not start battle")
	battle.get_node("BattleTimer").stop()
	battle.get_node("BattleTimer").timeout.emit()
	_stats(first, 84, 13, 18, 0.25)
	_expect(first.equipment.size() == 5, "Finishing battle lost equipped parts")
	battle.free()
	_viewport.free()
	_controller.reset_progress()
	await process_frame
	if not _failed:
		print("Equipment tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
