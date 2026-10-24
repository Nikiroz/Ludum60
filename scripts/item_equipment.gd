extends RefCounted

# The item editor replaces item_pack on import. Keep game rules outside that folder.


static func get_body_part(item: GridInventoryItemData) -> GridInventoryItemData.BodyPart:
	if item == null:
		return GridInventoryItemData.BodyPart.NONE
	if item.body_part != GridInventoryItemData.BodyPart.NONE:
		return item.body_part
	# Older resources may not yet have a body part selected.
	match item.item_id.get_slice("_", 0):
		"head":
			return GridInventoryItemData.BodyPart.HEAD
		"base":
			return GridInventoryItemData.BodyPart.BODY
		"hand":
			return GridInventoryItemData.BodyPart.HANDS
		"leg":
			return GridInventoryItemData.BodyPart.LEGS
	return GridInventoryItemData.BodyPart.NONE


static func get_equipment_slot(item: GridInventoryItemData, left_hand: bool = true) -> StringName:
	match get_body_part(item):
		GridInventoryItemData.BodyPart.HEAD:
			return &"head"
		GridInventoryItemData.BodyPart.BODY:
			return &"torso"
		GridInventoryItemData.BodyPart.HANDS:
			return &"left_hand" if left_hand else &"right_hand"
		GridInventoryItemData.BodyPart.LEGS:
			return &"legs"
	return &""


static func is_service_item(item: GridInventoryItemData) -> bool:
	# Imported base parts may omit the flag, but must never become loot or removable.
	return item != null and (item.is_service_item or item.item_id in ["base_basic", "leg_basic"])


static func get_attachment_points(item: GridInventoryItemData, hand_side: String = "", sprite_size: Vector2i = Vector2i.ZERO) -> Dictionary:
	if item == null:
		return {}
	var part := get_body_part(item)
	if part == item.body_part:
		return item.get_attachment_points(hand_side, sprite_size)
	# Supply the inferred type without changing the shared source resource.
	var compatible_item := item.duplicate() as GridInventoryItemData
	compatible_item.body_part = part
	return compatible_item.get_attachment_points(hand_side, sprite_size)
