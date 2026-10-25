extends Control

const ITEM_TOOLTIP = preload("res://scripts/ui/item_tooltip.gd")
const ITEM_DRAG_PREVIEW = preload("res://scripts/ui/item_drag_preview.gd")
const ItemEquipment = preload("res://scripts/item_equipment.gd")

var unit: BattleUnit
var _show_drop := false
var _hand_item := false
var _left_hand := true
var _left_hand_on_left := false
var _hand_split := 0.0
var _dragged_slot: StringName = &""
var _drop_highlight: Control


func _ready() -> void:
	theme = ITEM_TOOLTIP.THEME
	_drop_highlight = Control.new()
	_drop_highlight.name = "DropHighlight"
	_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_highlight.z_index = 3
	add_child(_drop_highlight)
	_drop_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drop_highlight.draw.connect(_draw_drop_highlight)
	_drop_highlight.resized.connect(_drop_highlight.queue_redraw)


func _slot_at(at_position: Vector2) -> StringName:
	var preview: Control = $EquipmentPreview
	var preview_position := preview.get_global_transform().affine_inverse() * (get_global_transform() * at_position)
	return preview.get_slot_at(preview_position)


func _get_drag_data(at_position: Vector2) -> Variant:
	if unit == null:
		return null
	var slot := _slot_at(at_position)
	var item: GridInventoryItemData = unit.equipment.get(slot)
	if not ControllerGame.can_unequip_item(unit, slot, item):
		return null
	var grab_offset := item.occupied_cells[0] if not item.occupied_cells.is_empty() else Vector2i.ZERO
	var preview := ITEM_DRAG_PREVIEW.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = item.get_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(item.grid_size) * 12
	icon.position = -Vector2(grab_offset) * 12 - Vector2(6, 6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(icon)
	set_drag_preview(preview)
	_dragged_slot = slot
	ControllerGame.play_one_shot(preload("uid://bpb1s3t6lape4"))
	$EquipmentPreview.get_node(NodePath(slot)).modulate.a = 0.25
	return {"equipment": self, "unit": unit, "slot": slot, "item": item, "grab_offset": grab_offset}


func _get_tooltip(at_position: Vector2) -> String:
	if unit == null:
		return ""
	return ITEM_TOOLTIP.get_text(unit.equipment.get(_slot_at(at_position)))


func _make_custom_tooltip(for_text: String) -> Object:
	return null if for_text.is_empty() else ITEM_TOOLTIP.new(for_text)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("inventory"):
		return false
	var item := data.get("item") as GridInventoryItemData
	var preview: Control = $EquipmentPreview
	var preview_to_local := get_global_transform().affine_inverse() * preview.get_global_transform()
	var left_socket: Vector2 = preview_to_local * preview.get_attachment_position(&"torso", &"left_hand")
	var right_socket: Vector2 = preview_to_local * preview.get_attachment_position(&"torso", &"right_hand")
	_left_hand_on_left = left_socket.x < right_socket.x
	_hand_split = clampf((left_socket.x + right_socket.x) / 2.0, 0.0, size.x)
	_left_hand = (at_position.x < _hand_split) == _left_hand_on_left
	_show_drop = ControllerGame.can_equip_item(unit, item, _left_hand)
	_hand_item = ItemEquipment.get_equipment_slot(item) == &"left_hand"
	_drop_highlight.queue_redraw()
	return _show_drop


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		ControllerGame.equip_item(unit, data.item, _left_hand)
	_show_drop = false
	ControllerGame.play_one_shot(preload("uid://cyhdsnc7rlc5w")) 
	_drop_highlight.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragged_slot != &"":
		$EquipmentPreview.get_node(NodePath(_dragged_slot)).modulate.a = 1.0
		_dragged_slot = &""
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_show_drop = false
		if is_instance_valid(_drop_highlight):
			_drop_highlight.queue_redraw()


func _draw_drop_highlight() -> void:
	if not _show_drop:
		return
	var region := Rect2(Vector2.ZERO, size)
	if _hand_item:
		if _left_hand == _left_hand_on_left:
			region.size.x = _hand_split
		else:
			region.position.x = _hand_split
			region.size.x -= _hand_split
	_drop_highlight.draw_rect(region, Color(Color("#6faf86"), 0.25))
