extends "res://scripts/scrapyard.gd"

var available: Array[GridInventoryItemData] = []
var placements: Array[SpawnPlan] = []


func load_available_items() -> Array[GridInventoryItemData]:
	return available


func place_item(item: GridInventoryItemData, origin: Vector2i) -> void:
	placements.append(SpawnPlan.new(item, origin))
