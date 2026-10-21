# Run with: Godot --headless --path . --script res://tests/test_inventory.gd
extends SceneTree

var _failed := false
var _checks := 0
var _viewport: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	_viewport.push_input(event, true)


func _motion(position: Vector2, relative: Vector2, pressed: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_viewport.push_input(event, true)


func _run() -> void:
	create_timer(10).timeout.connect(func() -> void: quit(1))
	var controller = root.get_node("ControllerGame")
	controller.reset_progress()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 180)
	root.add_child(_viewport)
	var source = load("res://item_pack/items/head_lamp.tres")
	controller.add_collected_item(source)
	controller.add_collected_item(source)
	var first: GridInventoryItemData = controller.collected_items[0]
	var second: GridInventoryItemData = controller.collected_items[1]
	var garage = load("res://scenes/garage.tscn").instantiate()
	_viewport.add_child(garage)
	await process_frame
	await process_frame
	var grid = garage.find_child("HeadsContainer", true, false)
	_expect(grid != null and grid.items.size() == 2, "Found items did not appear in HeadsContainer")
	var texture_ref: WeakRef = weakref(grid._textures[first.sprite_path])
	await process_frame
	_expect(texture_ref.get_ref() != null, "Inventory released the texture after drawing, leaving white rectangles")
	var first_origin: Vector2i = controller.inventory_positions[first]
	var second_origin: Vector2i = controller.inventory_positions[second]
	_expect(first_origin != second_origin, "Duplicate items shared an inventory position")
	_expect(grid.item_at_cell(first_origin) == first, "Occupied cell did not select its item")
	_expect(not grid.can_place_item(first, second_origin), "Moving onto an occupied cell was allowed")
	_expect(not grid.can_place_item(first, Vector2i(-1, 0)), "Moving outside the grid was allowed")
	_expect(grid.can_place_item(first, Vector2i(grid.columns - 1, 0)), "Transparent image margin blocked the last column")
	_expect(not grid.can_place_item(first, Vector2i(grid.columns, 0)), "Occupied cell exceeded the grid width")

	# Exercise native drag and drop with a mouse grab on the item's second cell.
	var start: Vector2 = grid.global_position + Vector2(first_origin + Vector2i(0, 1)) * 12 + Vector2(6, 6)
	var destination := Vector2i(6, 2)
	var finish: Vector2 = grid.global_position + Vector2(destination + Vector2i(0, 1)) * 12 + Vector2(6, 6)
	_motion(start, Vector2.ZERO, false)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	await process_frame
	_expect(_viewport.gui_is_dragging(), "Mouse movement did not start native inventory drag")
	_motion(finish, finish - start)
	_mouse(finish, false)
	await process_frame
	_expect(controller.inventory_positions[first] == destination, "Drop lost the grabbed cell offset or did not move the item")
	_expect(controller.inventory_positions[second] == second_origin, "Moving one item moved another copy")
	_expect(grid._dragged_item == null, "Drag did not clear its preview state")

	# An occupied drop target must preserve both items.
	start = grid.global_position + Vector2(destination) * 12 + Vector2(6, 6)
	finish = grid.global_position + Vector2(second_origin) * 12 + Vector2(6, 6)
	_motion(start, Vector2.ZERO, false)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	_motion(finish, finish - start)
	_mouse(finish, false)
	await process_frame
	_expect(controller.inventory_positions[first] == destination and controller.inventory_positions[second] == second_origin, "Occupied drop target changed an item position")

	# Cancelled drops must leave the item at its original location.
	start = grid.global_position + Vector2(destination) * 12 + Vector2(6, 6)
	_motion(start, Vector2.ZERO, false)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	await process_frame
	_motion(Vector2(300, 170), Vector2(100, 100))
	_mouse(Vector2(300, 170), false)
	await process_frame
	_expect(controller.inventory_positions[first] == destination, "Dropping outside the inventory lost the item")

	controller.add_collected_item(source)
	_expect(grid.items.size() == 3, "Inventory did not update when another item was collected")
	garage.free()
	garage = load("res://scenes/garage.tscn").instantiate()
	_viewport.add_child(garage)
	await process_frame
	grid = garage.find_child("HeadsContainer", true, false)
	_expect(controller.inventory_positions[first] == destination and grid.item_at_cell(destination) == first, "Returning to the garage lost item positions")

	# Interlocking shapes use occupied cells, rather than reserving whole images.
	var hollow := GridInventoryItemData.new()
	hollow.grid_size = Vector2i(3, 3)
	hollow.occupied_cells = [Vector2i.ZERO, Vector2i(2, 0)]
	controller.add_collected_item(hollow)
	var hollow_copy: GridInventoryItemData = controller.collected_items.back()
	controller.inventory_positions[hollow_copy] = Vector2i(3, 6)
	var small := GridInventoryItemData.new()
	small.grid_size = Vector2i.ONE
	small.occupied_cells = [Vector2i.ZERO]
	_expect(grid.can_place_item(small, Vector2i(4, 6)), "Empty shape cells incorrectly blocked another item")
	_expect(not grid.can_place_item(small, Vector2i(3, 6)), "Occupied shape cell did not block another item")

	# Sprite canvases remain 3x3, but only the collision cells limit placement.
	var mouse_source = load("res://item_pack/items/hand_mouse.tres")
	_expect(grid.can_place_item(mouse_source, Vector2i(grid.columns - 1, grid.rows - 1)), "Transparent margins blocked the last row or column")
	_expect(grid.can_place_item(first, Vector2i(grid.columns - 1, grid.rows - 2)), "Two-cell shape did not fit in the last two rows")
	_expect(not grid.can_place_item(first, Vector2i(grid.columns - 1, grid.rows - 1)), "Two-cell shape crossed the grid bottom")
	controller.add_collected_item(mouse_source)
	var mouse_item: GridInventoryItemData = controller.collected_items.back()
	controller.inventory_positions[mouse_item] = Vector2i(1, grid.rows - 3)
	var scroll: ScrollContainer = grid.get_parent()
	scroll.scroll_vertical = 10000
	await process_frame
	await process_frame
	start = grid.global_position + Vector2(controller.inventory_positions[mouse_item]) * 12 + Vector2(6, 6)
	var corner := Vector2i(grid.columns - 1, grid.rows - 1)
	finish = grid.global_position + Vector2(corner) * 12 + Vector2(6, 6)
	_motion(start, Vector2.ZERO, false)
	_mouse(start, true)
	_motion(start + Vector2(12, 0), Vector2(12, 0))
	_motion(finish, finish - start)
	_mouse(finish, false)
	await process_frame
	_expect(controller.inventory_positions[mouse_item] == corner, "Native drop did not reach the bottom-right cell after scrolling")
	grid._sync_inventory()
	_expect(grid.rows == grid.initial_rows, "Transparent margins added phantom rows after an edge drop")
	var old_rows: int = grid.rows
	for index in range(20):
		controller.add_collected_item(load("res://item_pack/items/base_fridge.tres"))
	_expect(grid.rows > old_rows, "Full inventory did not add scrollable rows")
	_expect(grid.items.size() == controller.collected_items.size(), "Expanding the inventory lost found items")
	var occupied: Dictionary = {}
	for item in grid.items:
		for offset in item.occupied_cells:
			var cell: Vector2i = controller.inventory_positions[item] + offset
			_expect(not occupied.has(cell), "New items overlapped an existing item")
			occupied[cell] = item
	garage.free()
	_viewport.free()
	controller.reset_progress()
	await process_frame
	if not _failed:
		print("Inventory tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
