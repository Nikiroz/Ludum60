extends Control

# Back-to-front order also determines which overlapping part receives a grab.
const SLOTS: Array[StringName] = [&"right_hand", &"torso", &"legs", &"head", &"left_hand"]
const DebugStats = preload("res://scripts/ui/robot_debug_stats.gd")
const ItemEquipment = preload("res://scripts/item_equipment.gd")

@export var align_to_bottom := false
@export var show_shadow := false

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
var _shadow: TextureRect
var _shadow_attachment_point := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow = TextureRect.new()
	_shadow.name = "RobotShadow"
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.visible = false
	add_child(_shadow)
	for slot in SLOTS:
		var layer := Sprite2D.new()
		layer.name = slot
		layer.centered = false
		layer.region_enabled = true
		layer.z_index = 1 if slot == &"left_hand" else 0
		add_child(layer)
		_layers[slot] = layer
	_debug_stats = DebugStats.new()
	_debug_stats.name = "DebugStats"
	_debug_stats.z_index = 2
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
			_attachment_points[slot] = ItemEquipment.get_attachment_points(item, hand_side, _images[slot].get_size())
		else:
			_images.erase(slot)
			_attachment_points.erase(slot)
	_shadow.texture = null
	_shadow_attachment_point = Vector2.ZERO
	var legs_item: GridInventoryItemData = unit.equipment.get(&"legs") if unit != null else null
	if legs_item != null and _images.has(&"legs"):
		_shadow.texture = legs_item.get_shadow_texture()
		if _shadow.texture != null:
			_shadow.size = _shadow.texture.get_size()
			var points := legs_item.get_shadow_attachment_points(_images[&"legs"].get_size())
			_shadow_attachment_point = Vector2(points.get("body", Vector2i.ZERO))
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
	# Torso sockets were authored from the robot's perspective; hands use screen sides.
	if slot == &"torso":
		if point_name == &"left_hand":
			point_name = &"right_hand"
		elif point_name == &"right_hand":
			point_name = &"left_hand"
	# Authored points belong to the full PNG; sprites display only its opaque region.
	var pixel := Vector2(_attachment_points[slot].get(point_name, Vector2i.ZERO))
	return layer.transform.basis_xform(pixel - layer.region_rect.position + layer.offset)


func get_attachment_position(slot: StringName, point_name: StringName) -> Vector2:
	return _layers[slot].position + _attachment_offset(slot, point_name)


func _layout_parts() -> void:
	pivot_offset = Vector2(size.x / 2.0, size.y)
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
	_shadow.visible = show_shadow and _shadow.texture != null and _layers[&"legs"].visible and has_parts and bounds.has_area()
	if not has_parts or not bounds.has_area():
		return
	var floor_bounds := legs_bounds if _layers[&"legs"].visible else bounds
	var feet := Vector2(floor_bounds.get_center().x, floor_bounds.end.y)
	var origin := (size - bounds.size) / 2.0 - bounds.position
	if align_to_bottom:
		# The torso socket fixes the standing axis; leg widths cannot shift the body.
		if _layers[&"torso"].visible:
			feet.x = _attachment_offset(&"torso", &"legs").x
		origin = Vector2(size.x / 2.0, size.y) - feet
	# Round the entire assembly together so connected points remain coincident.
	origin = origin.round()
	pivot_offset = origin + feet
	for slot in SLOTS:
		_layers[slot].position = origin + positions[slot]
	if _shadow.visible:
		var legs_layer := _layers[&"legs"]
		_shadow.rotation = legs_layer.rotation
		_shadow.scale = legs_layer.scale
		# Shadow points use the full leg PNG, independent of its cropped visible region.
		_shadow.position = get_attachment_position(&"legs", &"body") - legs_layer.transform.basis_xform(_shadow_attachment_point)
	_debug_stats.position = (origin + bounds.get_center() - _debug_stats.size / 2.0).round()
