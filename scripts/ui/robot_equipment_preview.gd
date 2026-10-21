extends Control

# Back-to-front order also determines which overlapping part receives a grab.
const SLOTS: Array[StringName] = [&"legs", &"left_hand", &"torso", &"right_hand", &"head"]
const DebugStats = preload("res://scripts/ui/robot_debug_stats.gd")

@export var align_to_bottom := false

var unit: BattleUnit:
	set(value):
		if unit != null and unit.equipment_changed.is_connected(_refresh):
			unit.equipment_changed.disconnect(_refresh)
		unit = value
		if unit != null:
			unit.equipment_changed.connect(_refresh)
		if is_node_ready():
			_debug_stats.unit = unit
			_refresh()

var _layers: Dictionary[StringName, Sprite2D] = {}
var _images: Dictionary[StringName, Image] = {}
var _attachment_points: Dictionary[StringName, Dictionary] = {}
var _debug_stats: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for slot in SLOTS:
		var layer := Sprite2D.new()
		layer.name = slot
		layer.centered = false
		layer.region_enabled = true
		add_child(layer)
		_layers[slot] = layer
	_debug_stats = DebugStats.new()
	_debug_stats.name = "DebugStats"
	_debug_stats.unit = unit
	add_child(_debug_stats)
	_debug_stats.resized.connect(_layout_parts)
	resized.connect(_layout_parts)
	_refresh()


func _refresh() -> void:
	for slot in SLOTS:
		var item: GridInventoryItemData = unit.equipment.get(slot) if unit != null else null
		var layer := _layers[slot]
		layer.texture = null
		if item != null:
			match slot:
				&"left_hand":
					layer.texture = item.get_left_hand_texture()
				&"right_hand":
					layer.texture = item.get_right_hand_texture()
				_:
					layer.texture = item.get_unit_texture()
		layer.visible = layer.texture != null
		if layer.texture != null:
			_images[slot] = layer.texture.get_image()
			layer.region_rect = _images[slot].get_used_rect()
			var hand_side := "left" if slot == &"left_hand" else "right" if slot == &"right_hand" else ""
			_attachment_points[slot] = item.get_attachment_points(hand_side, _images[slot].get_size())
		else:
			_images.erase(slot)
			_attachment_points.erase(slot)
	_layout_parts()


func get_slot_at(at_position: Vector2) -> StringName:
	# Pick the frontmost opaque pixel, so transparent margins cannot steal a grab.
	for index in range(SLOTS.size() - 1, -1, -1):
		var slot := SLOTS[index]
		var layer := _layers[slot]
		if not layer.visible:
			continue
		var local := layer.get_transform().affine_inverse() * at_position - layer.offset
		if not Rect2(Vector2.ZERO, layer.region_rect.size).has_point(local):
			continue
		var pixel := Vector2i(local.floor()) + Vector2i(layer.region_rect.position)
		if _images[slot].get_pixelv(pixel).a > 0.0:
			return slot
	return &""


func _part_size(slot: StringName) -> Vector2:
	var layer := _layers[slot]
	return layer.region_rect.size if layer.visible else Vector2.ZERO


func _attachment_offset(slot: StringName, point_name: StringName) -> Vector2:
	var layer := _layers[slot]
	if not layer.visible:
		return Vector2.ZERO
	# Authored points belong to the full PNG; sprites display only its opaque region.
	var pixel := Vector2(_attachment_points[slot].get(point_name, Vector2i.ZERO))
	return layer.transform.basis_xform(pixel - layer.region_rect.position + layer.offset)


func get_attachment_position(slot: StringName, point_name: StringName) -> Vector2:
	return _layers[slot].position + _attachment_offset(slot, point_name)


func _layout_parts() -> void:
	if _layers.is_empty():
		return
	var positions: Dictionary[StringName, Vector2] = {&"torso": Vector2.ZERO}
	for slot in SLOTS:
		if slot != &"torso":
			positions[slot] = _attachment_offset(&"torso", slot) - _attachment_offset(slot, &"body")
	var bounds := Rect2()
	var legs_bounds := Rect2()
	var has_parts := false
	for slot in SLOTS:
		if not _layers[slot].visible:
			continue
		var part_transform := _layers[slot].transform
		part_transform.origin = positions[slot]
		var part := part_transform * Rect2(_layers[slot].offset, _part_size(slot))
		if slot == &"legs":
			legs_bounds = part
		bounds = bounds.merge(part) if has_parts else part
		has_parts = true
	if not has_parts or not bounds.has_area():
		return
	var origin := (size - bounds.size) / 2.0 - bounds.position
	if align_to_bottom:
		var bottom := legs_bounds.end.y if _layers[&"legs"].visible else bounds.end.y
		origin.y = size.y - bottom
	# Round the entire assembly together so connected points remain coincident.
	origin = origin.round()
	for slot in SLOTS:
		_layers[slot].position = origin + positions[slot]
	_debug_stats.position = (origin + bounds.get_center() - _debug_stats.size / 2.0).round()
