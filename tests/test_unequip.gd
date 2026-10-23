# Run with: Godot --headless --path . --script res://tests/test_unequip.gd
extends SceneTree

var _failed := false
var _checks := 0
var _controller: Node
var _viewport: SubViewport
var _garage
var _grid
var _tabs: TabContainer
var _unit: BattleUnit


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _open_garage() -> void:
	_garage = load("res://scenes/garage.tscn").instantiate()
	_viewport.add_child(_garage)
	_grid = _garage.find_child("HeadsContainer", true, false)
	_tabs = _garage.find_child("TabContainer2", true, false)
	_tabs.current_tab = 0
	await process_frame
	await process_frame


func _equip(id: String, left_hand: bool = true) -> GridInventoryItemData:
	var source := load("res://item_pack/items/%s.tres" % id) as GridInventoryItemData
	_controller.add_collected_item(source)
	var item: GridInventoryItemData = _controller.collected_items.back()
	item.health_bonus = 3
	item.attack_speed_bonus = 0.2
	item.damage_bonus = 4
	item.crit_chance_bonus = 0.05
	_expect(_controller.equip_item(_unit, item, left_hand), "Could not prepare equipped item")
	return item


func _stats(parts: int) -> void:
	_expect(is_equal_approx(_unit.health, 1 + parts * 3), "Removing equipment left the wrong health total")
	_expect(is_equal_approx(_unit.attack_speed, 1 + parts * 0.2), "Removing equipment left the wrong speed total")
	_expect(is_equal_approx(_unit.damage, 1 + parts * 4), "Removing equipment left the wrong damage total")
	_expect(is_equal_approx(_unit.crit_chance, parts * 0.05), "Removing equipment left the wrong crit total")


func _part_position(slot: StringName) -> Vector2:
	var tab: Control = _tabs.get_current_tab_control()
	var preview: Control = tab.get_node("EquipmentPreview")
	var layer: Sprite2D = preview.get_node(NodePath(slot))
	var picture := layer.texture.get_image()
	var region := Rect2i(layer.region_rect)
	for y in range(region.size.y):
		for x in range(region.size.x):
			if picture.get_pixelv(region.position + Vector2i(x, y)).a < 0.5:
				continue
			var position := layer.to_global(Vector2(x + 0.5, y + 0.5))
			var local := preview.get_global_transform().affine_inverse() * position
			if tab.get_global_rect().has_point(position) and preview.get_slot_at(local) == slot:
				return position
	_expect(false, "No visible grab point for equipment slot: " + slot)
	return tab.get_global_rect().get_center()


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


func _inventory_point(origin: Vector2i) -> Vector2:
	return _grid.global_position + Vector2(origin) * 12 + Vector2(6, 6)


func _drag_part(slot: StringName, finish: Vector2, should_drag: bool = true) -> void:
	var item: GridInventoryItemData = _unit.equipment.get(slot)
	var start := _part_position(slot)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	_expect(_viewport.gui_is_dragging() == should_drag, "Equipped item has the wrong drag availability: " + slot)
	_expect(_unit.equipment.get(slot) == item and not _controller.collected_items.has(item), "Starting a drag moved equipment before a successful drop")
	_motion(finish, finish - start)
	_mouse(finish, false)
	await process_frame
	await process_frame
	var preview: Control = _tabs.get_current_tab_control().get_node("EquipmentPreview")
	_expect(is_equal_approx(preview.get_node(NodePath(slot)).modulate.a, 1.0), "Equipment drag did not restore its tint")


func _run() -> void:
	create_timer(10).timeout.connect(func() -> void: quit(1))
	_controller = root.get_node("ControllerGame")
	_controller.reset_progress()
	_unit = _controller.units[0]
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 180)
	root.add_child(_viewport)
	await _open_garage()
	for slot in [&"torso", &"legs"]:
		var basic: GridInventoryItemData = _unit.equipment[slot]
		_expect(not _controller.can_unequip_item(_unit, slot, basic), "Basic equipment can be removed")
		await _drag_part(slot, _inventory_point(Vector2i(6, 2)), false)
	_expect(_controller.collected_items.is_empty(), "Dragging basic equipment created inventory items")

	var head := _equip("head_lamp")
	var torso := _equip("base_fridge")
	var legs := _equip("leg_bicycle")
	var left := _equip("hand_drill")
	var right := _equip("hand_mouse", false)
	_stats(5)
	_controller.add_collected_item(load("res://item_pack/items/head_router.tres"))
	var blocker: GridInventoryItemData = _controller.collected_items.back()
	await process_frame
	await process_frame
	await _drag_part(&"head", Vector2(310, 175))
	_expect(_unit.equipment.get(&"head") == head and not _controller.collected_items.has(head), "Cancelled equipment drag lost the item")
	_stats(5)
	await _drag_part(&"head", _inventory_point(_controller.inventory_positions[blocker]))
	_expect(_unit.equipment.get(&"head") == head and _grid.items.size() == 1, "Occupied inventory drop removed or duplicated equipment")
	_stats(5)
	_expect(not _controller.unequip_item(_unit, &"head", right, Vector2i(6, 2)), "Stale equipment drag removed another part")
	_expect(not _controller.unequip_item(_unit, &"head", head, Vector2i(-1, 0)), "Equipment could be returned outside the inventory")
	_expect(not _controller.can_unequip_item(BattleUnit.new(), &"head", head), "Foreign robot can return equipment")

	var slots: Array[StringName] = [&"head", &"torso", &"legs", &"left_hand", &"right_hand"]
	var returned: Array[GridInventoryItemData] = [head, torso, legs, left, right]
	var origins: Array[Vector2i] = [Vector2i(6, 2), Vector2i(9, 2), Vector2i(3, 5), Vector2i(6, 5), Vector2i(9, 5)]
	for index in range(slots.size()):
		await _drag_part(slots[index], _inventory_point(origins[index]))
		_expect(_controller.collected_items.count(returned[index]) == 1 and _grid.items.has(returned[index]), "Unequipped item did not return exactly once")
		_expect(_controller.inventory_positions.get(returned[index]) == origins[index], "Unequipped item did not stay at its drop position")
		_stats(4 - index)
		if slots[index] == &"torso" or slots[index] == &"legs":
			var basic: GridInventoryItemData = _unit.equipment[slots[index]]
			_expect(basic.item_id == ("base_basic" if slots[index] == &"torso" else "leg_basic"), "Unequipping did not restore the correct basic part")
			_expect(basic.is_service_item and not _controller.collected_items.has(basic), "Restored basic part entered inventory")
		else:
			_expect(not _unit.equipment.has(slots[index]), "Unequipped optional slot is still occupied")
	_expect(_unit.equipment.size() == 2, "Unequipping all items did not leave exactly two basic parts")
	_expect(_controller.units[1].equipment.size() == 2, "Unequipping affected another robot")
	_expect(not _controller.unequip_item(_unit, &"head", head, Vector2i(0, 8)), "Returned equipment could be added twice")
	var basic_torso: GridInventoryItemData = _unit.equipment[&"torso"]
	var basic_legs: GridInventoryItemData = _unit.equipment[&"legs"]
	_expect(_controller.equip_item(_unit, torso) and _controller.equip_item(_unit, legs), "Returned equipment could not be equipped again")
	_expect(not _controller.collected_items.has(basic_torso) and not _controller.collected_items.has(basic_legs), "Re-equipping returned restored basics to inventory")
	_stats(2)
	_garage.free()
	await _open_garage()
	_expect(_unit.equipment.get(&"torso") == torso and _unit.equipment.get(&"legs") == legs, "Reopening the garage lost re-equipped parts")
	_expect(_grid.items.has(head) and _controller.inventory_positions[head] == origins[0], "Reopening the garage lost returned item ownership or position")
	_viewport.free()
	_controller.reset_progress()
	await process_frame
	if not _failed:
		print("Unequip tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
