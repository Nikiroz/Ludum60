# Run with: Godot --headless --path . --script res://tests/test_items.gd
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
		push_error(message)


func _run() -> void:
	var paths := ItemCatalog.get_item_paths()
	_expect(paths == ItemCatalog.scan_source_items(), "Item catalog does not match the exported resources")
	var slots := {
		GridInventoryItemData.BodyPart.HEAD: &"head",
		GridInventoryItemData.BodyPart.BODY: &"torso",
		GridInventoryItemData.BodyPart.HANDS: &"left_hand",
		GridInventoryItemData.BodyPart.LEGS: &"legs",
	}
	var item_ids: Dictionary = {}
	for path in paths:
		var item := load(path) as GridInventoryItemData
		_expect(item != null, "Could not load item: " + path)
		if item == null:
			continue
		_expect(not item.item_id.is_empty() and not item_ids.has(item.item_id), "Item ID is empty or repeated: " + path)
		item_ids[item.item_id] = true
		_expect(item.get_texture() != null, "Inventory texture is missing: " + item.item_id)
		_expect(slots.has(item.body_part), "Item has no body part: " + item.item_id)
		_expect(item.get_equipment_slot() == slots.get(item.body_part), "Item body part selects the wrong equipment slot: " + item.item_id)
		_expect(item.is_service_item == (item.item_id in ["base_basic", "leg_basic"]), "Item has the wrong service flag: " + item.item_id)
		if item.body_part == GridInventoryItemData.BodyPart.HANDS:
			_expect(item.get_left_hand_texture() != null and item.get_right_hand_texture() != null, "Hand item is missing a side's texture: " + item.item_id)
			_expect(item.get_equipment_slot(false) == &"right_hand", "Hand item cannot equip the right hand: " + item.item_id)
		else:
			_expect(item.get_unit_texture() != null, "Unit texture is missing: " + item.item_id)

	# Explicit body parts must take precedence over legacy ID prefixes.
	var custom := GridInventoryItemData.new()
	custom.item_id = "base_custom"
	for body_part in slots:
		custom.body_part = body_part
		_expect(custom.get_equipment_slot() == slots[body_part], "Equipment slot depends on the ID instead of the selected body part")
	custom.body_part = GridInventoryItemData.BodyPart.NONE
	_expect(custom.get_equipment_slot() == &"torso", "Legacy item lost its equipment slot")
	custom.item_id = "unknown_part"
	_expect(custom.get_equipment_slot() == &"", "Unsupported item can be equipped")
	if not _failed:
		print("Item data tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
