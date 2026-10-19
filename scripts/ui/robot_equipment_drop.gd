extends Control

var unit: BattleUnit
var _show_drop := false
var _hand_item := false
var _left_hand := true


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("inventory"):
		return false
	var item := data.get("item") as GridInventoryItemData
	_left_hand = at_position.x < size.x / 2.0
	_show_drop = ControllerGame.can_equip_item(unit, item, _left_hand)
	_hand_item = item != null and item.get_equipment_slot() == &"left_hand"
	queue_redraw()
	return _show_drop


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		ControllerGame.equip_item(unit, data.item, _left_hand)
	_show_drop = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_show_drop = false
		queue_redraw()


func _draw() -> void:
	if not _show_drop:
		return
	var region := Rect2(Vector2.ZERO, size)
	if _hand_item:
		region.size.x /= 2.0
		if not _left_hand:
			region.position.x = region.size.x
	draw_rect(region, Color(0.3, 1.0, 0.4, 0.15))
	draw_rect(region, Color(0.3, 1.0, 0.4, 0.8), false)
