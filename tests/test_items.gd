# Run with: Godot --headless --path . --script res://tests/test_items.gd
extends SceneTree

const ItemCatalog = preload("res://scripts/item_catalog.gd")
const ItemEquipment = preload("res://scripts/item_equipment.gd")

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
		_expect(ItemEquipment.get_equipment_slot(item) == slots.get(item.body_part), "Item body part selects the wrong equipment slot: " + item.item_id)
		_expect(ItemEquipment.is_service_item(item) == (item.item_id in ["base_basic", "leg_basic"]), "Item has the wrong service flag: " + item.item_id)
		if item.body_part == GridInventoryItemData.BodyPart.HANDS:
			_expect(item.get_left_hand_texture() != null and item.get_right_hand_texture() != null, "Hand item is missing a side's texture: " + item.item_id)
			_expect(ItemEquipment.get_equipment_slot(item, false) == &"right_hand", "Hand item cannot equip the right hand: " + item.item_id)
		else:
			_expect(item.get_unit_texture() != null, "Unit texture is missing: " + item.item_id)

	# Explicit body parts must take precedence over legacy ID prefixes.
	var custom := GridInventoryItemData.new()
	custom.item_id = "base_custom"
	for body_part in slots:
		custom.body_part = body_part
		_expect(ItemEquipment.get_equipment_slot(custom) == slots[body_part], "Equipment slot depends on the ID instead of the selected body part")
	custom.body_part = GridInventoryItemData.BodyPart.NONE
	var legacy_slots := {"head_custom": &"head", "base_custom": &"torso", "hand_custom": &"left_hand", "leg_custom": &"legs"}
	for id in legacy_slots:
		custom.item_id = id
		_expect(ItemEquipment.get_equipment_slot(custom) == legacy_slots[id], "Legacy item lost its equipment slot: " + id)
	custom.item_id = "hand_custom"
	_expect(ItemEquipment.get_equipment_slot(custom, false) == &"right_hand", "Legacy hand lost its right-hand slot")
	custom.item_id = "unknown_part"
	_expect(ItemEquipment.get_equipment_slot(custom) == &"", "Unsupported item can be equipped")
	_expect(not ItemEquipment.is_service_item(custom), "Ordinary item became service equipment")
	custom.is_service_item = true
	_expect(ItemEquipment.is_service_item(custom), "Explicit service flag was ignored")
	custom.is_service_item = false
	for id in ["base_basic", "leg_basic"]:
		custom.item_id = id
		_expect(ItemEquipment.is_service_item(custom), "Imported basic part needs an explicit service flag: " + id)
	_expect(ItemEquipment.get_equipment_slot(null) == &"", "An empty drag has an equipment slot")
	if not _failed:
		print("Item data tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
