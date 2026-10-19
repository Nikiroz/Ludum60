# Run with: Godot --headless --path . --script res://tests/test_scrapyard.gd
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

func _item(width: int = 1) -> GridInventoryItemData:
	var item := GridInventoryItemData.new()
	item.grid_size = Vector2i(width, 1)
	item.occupied_cells = [Vector2i.ZERO]
	return item

func _run() -> void:
	seed(12345)
	var real_yard = load("res://scripts/scrapyard.gd").new()
	real_yard.field = GridContainer.new()
	real_yard.field.columns = 8
	real_yard.field_cells.resize(64)
	var loot: Array[GridInventoryItemData] = real_yard.load_available_items()
	var catalog = load("res://scripts/item_catalog.gd")
	_expect(loot.size() == catalog.get_item_paths().size() - 2, "Scrapyard loot did not exclude exactly the two basic items")
	for item in loot:
		_expect(item.item_id != "base_basic" and item.item_id != "leg_basic", "Basic equipment can spawn in the scrapyard")
	real_yard.field.free()
	real_yard.free()

	var yard = load("res://tests/fixtures/scrapyard.gd").new()
	yard.field = GridContainer.new()
	yard.field.columns = 8
	yard.field_cells.resize(8)

	# All choices fit: a pool must be exhausted before any item repeats.
	for pool_size in [10, 3, 1]:
		yard.available.clear()
		for index in range(pool_size):
			yard.available.append(_item())
		for attempt in range(20):
			yard.placements.clear()
			yard.spawn_random_items()
			_expect(yard.placements.size() == 8, "Pool did not fill all eight positions")
			var used: Array[GridInventoryItemData] = []
			var occupied: Dictionary = {}
			for placement in yard.placements:
				if used.size() == pool_size:
					used.clear()
				_expect(not used.has(placement.data), "Item repeated before the pool was exhausted")
				used.append(placement.data)
				_expect(not occupied.has(placement.origin), "Placements overlap")
				occupied[placement.origin] = true

	# A large remaining item cannot block refilling with items that still fit.
	var small := _item()
	yard.available.assign([_item(8), small])
	yard.placements.clear()
	yard.spawn_random_items()
	_expect(yard.placements.size() == 8, "Unplaceable item blocked refilling the pool")
	for placement in yard.placements:
		_expect(placement.data == small, "An oversized item overlapped another placement")
	yard.field.free()
	yard.free()
	if not _failed:
		print("Scrapyard pool tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
