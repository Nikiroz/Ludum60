extends Control

# Back-to-front order keeps the attachment edges under the torso.
const SLOTS: Array[StringName] = [&"legs", &"left_hand", &"right_hand", &"torso", &"head"]

@export var align_to_bottom := false

var unit: BattleUnit:
	set(value):
		if unit != null and unit.equipment_changed.is_connected(_refresh):
			unit.equipment_changed.disconnect(_refresh)
		unit = value
		if unit != null:
			unit.equipment_changed.connect(_refresh)
		if is_node_ready():
			_refresh()

var _layers: Dictionary[StringName, Sprite2D] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for slot in SLOTS:
		var layer := Sprite2D.new()
		layer.name = slot
		layer.centered = false
		layer.region_enabled = true
		layer.flip_h = slot == &"left_hand"
		add_child(layer)
		_layers[slot] = layer
	resized.connect(_layout_parts)
	_refresh()


func _refresh() -> void:
	for slot in SLOTS:
		var item: GridInventoryItemData = unit.equipment.get(slot) if unit != null else null
		var layer := _layers[slot]
		layer.texture = item.get_unit_texture() if item != null else null
		layer.visible = layer.texture != null
		if layer.texture != null:
			layer.region_rect = layer.texture.get_image().get_used_rect()
	_layout_parts()


func _part_size(slot: StringName) -> Vector2:
	var layer := _layers[slot]
	return layer.region_rect.size if layer.visible else Vector2.ZERO


func _layout_parts() -> void:
	if _layers.is_empty():
		return
	var torso := _part_size(&"torso")
	var legs := _part_size(&"legs")
	var head := _part_size(&"head")
	var left := _part_size(&"left_hand")
	var right := _part_size(&"right_hand")
	var positions: Dictionary[StringName, Vector2] = {
		&"torso": Vector2(-torso.x / 2.0, 0),
		&"legs": Vector2(-legs.x / 2.0, torso.y - 3),
		&"head": Vector2(-head.x / 2.0, 2 - head.y),
		&"left_hand": Vector2(-torso.x / 2.0 - left.x + 4, torso.y * 0.4 - left.y / 2.0),
		&"right_hand": Vector2(torso.x / 2.0 - 4, torso.y * 0.4 - right.y / 2.0),
	}
	var bounds := Rect2()
	var has_parts := false
	for slot in SLOTS:
		if not _layers[slot].visible:
			continue
		var part := Rect2(positions[slot], _part_size(slot))
		bounds = bounds.merge(part) if has_parts else part
		has_parts = true
	if not has_parts or not bounds.has_area():
		return
	var origin := (size - bounds.size) / 2.0 - bounds.position
	if align_to_bottom:
		var bottom := positions[&"legs"].y + legs.y if _layers[&"legs"].visible else bounds.end.y
		origin.y = size.y - bottom
	for slot in SLOTS:
		_layers[slot].position = (origin + positions[slot]).round()
