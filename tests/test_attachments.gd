# Run with: Godot --headless --path . --script res://tests/test_attachments.gd
extends SceneTree

const ItemCatalog = preload("res://scripts/item_catalog.gd")
const SLOTS: Array[StringName] = [&"legs", &"left_hand", &"right_hand", &"torso", &"head"]

var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _point(preview: Control, slot: StringName, name: StringName) -> Vector2:
	var layer: Sprite2D = preview.get_node(NodePath(slot))
	var item: GridInventoryItemData = preview.unit.equipment[slot]
	var side := "left" if slot == &"left_hand" else "right" if slot == &"right_hand" else ""
	var points := item.get_attachment_points(side, Vector2i(layer.texture.get_size()))
	return layer.to_global(Vector2(points[name]) - layer.region_rect.position + layer.offset)


func _connections(preview: Control) -> void:
	for slot in [&"head", &"legs", &"left_hand", &"right_hand"]:
		var layer: Sprite2D = preview.get_node(NodePath(slot))
		if layer.visible:
			_expect(_point(preview, slot, &"body").is_equal_approx(_point(preview, &"torso", slot)),
				"Attachment mismatch: %s / %s" % [preview.unit.equipment[&"torso"].item_id, slot])


func _bounds(preview: Control) -> Rect2:
	var result := Rect2()
	var found := false
	for child in preview.get_children():
		if child is Sprite2D and child.visible:
			var rect: Rect2 = child.transform * Rect2(child.offset, child.region_rect.size)
			result = result.merge(rect) if found else rect
			found = true
	return result


func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	var unit := BattleUnit.new()
	var preview: Control = load("res://scripts/ui/robot_equipment_preview.gd").new()
	preview.size = Vector2(121, 113)
	preview.unit = unit
	root.add_child(preview)
	var torsos: Array[GridInventoryItemData] = []
	var parts: Array[GridInventoryItemData] = []
	for path in ItemCatalog.get_item_paths():
		var item := load(path) as GridInventoryItemData
		if item.get_equipment_slot() == &"torso":
			torsos.append(item)
		else:
			parts.append(item)
	# Every authored torso must accept every head, leg and both hand images.
	for torso in torsos:
		unit.equip_item(torso, &"torso")
		for item in parts:
			unit.equip_item(item, item.get_equipment_slot())
			if item.body_part == GridInventoryItemData.BodyPart.HANDS:
				unit.equip_item(item, &"right_hand")
			_connections(preview)
			_expect(_bounds(preview).get_center().distance_to(preview.size / 2.0) <= 0.71,
				"Assembly is not centered on its visible bounds")
	# Reflow on resize and floor alignment must move the entire assembly together.
	preview.size = Vector2(95, 80)
	preview.align_to_bottom = true
	preview._layout_parts()
	_connections(preview)
	var legs: Sprite2D = preview.get_node("legs")
	_expect(is_equal_approx(legs.position.y + legs.region_rect.size.y, preview.size.y), "Feet lost the battle floor")
	var positions: Dictionary = {}
	for slot in SLOTS:
		positions[slot] = preview.get_node(NodePath(slot)).position
	preview._layout_parts()
	for slot in SLOTS:
		_expect(preview.get_node(NodePath(slot)).position.is_equal_approx(positions[slot]), "Repeated layout moved equipment")
	# Fractional sprite transforms cannot separate two connected points.
	var torso_layer: Sprite2D = preview.get_node("torso")
	torso_layer.rotation = 0.17
	torso_layer.scale = Vector2(1.1, 0.9)
	torso_layer.offset = Vector2(3, -2)
	var head_layer: Sprite2D = preview.get_node("head")
	head_layer.rotation = -0.13
	head_layer.scale = Vector2(0.9, 1.2)
	head_layer.offset = Vector2(-2, 1)
	preview._layout_parts()
	_connections(preview)
	torso_layer.rotation = 0.0
	torso_layer.scale = Vector2.ONE
	torso_layer.offset = Vector2.ZERO
	head_layer.rotation = 0.0
	head_layer.scale = Vector2.ONE
	head_layer.offset = Vector2.ZERO
	# Legacy resources still get valid default sockets and normalized point migration.
	var legacy_torso := torsos[0].duplicate(true) as GridInventoryItemData
	legacy_torso.body_part = GridInventoryItemData.BodyPart.NONE
	legacy_torso.attachment_points = {}
	unit.equip_item(legacy_torso, &"torso")
	var legacy_head := unit.equipment[&"head"].duplicate(true) as GridInventoryItemData
	legacy_head.attachment_points = {"body": Vector2(0.25, 0.75)}
	unit.equip_item(legacy_head, &"head")
	var head_size := Vector2i(head_layer.texture.get_size())
	_expect(legacy_head.get_attachment_points("", head_size).body == Vector2i((Vector2(head_size) * Vector2(0.25, 0.75)).round()), "Normalized head point did not migrate to pixels")
	var legacy_hand := unit.equipment[&"left_hand"].duplicate(true) as GridInventoryItemData
	legacy_hand.left_hand_attachment_point = Vector2(0.2, 0.6)
	legacy_hand.right_hand_attachment_point = Vector2i(-1, -1)
	unit.equip_item(legacy_hand, &"left_hand")
	unit.equip_item(legacy_hand, &"right_hand")
	var left_layer: Sprite2D = preview.get_node("left_hand")
	var right_layer: Sprite2D = preview.get_node("right_hand")
	var left_size := Vector2i(left_layer.texture.get_size())
	var right_size := Vector2i(right_layer.texture.get_size())
	_expect(legacy_hand.get_attachment_points("left", left_size).body == Vector2i((Vector2(left_size) * Vector2(0.2, 0.6)).round()), "Normalized hand point did not migrate to pixels")
	_expect(legacy_hand.get_attachment_points("right", right_size).body == Vector2i((Vector2(right_size) / 2.0).round()), "Unset hand point did not use its image center")
	_connections(preview)
	var missing_head := legacy_head.duplicate(true) as GridInventoryItemData
	missing_head.unit_sprite_path = ""
	unit.equip_item(missing_head, &"head")
	_expect(not head_layer.visible, "A missing texture left a visible equipment layer")
	_connections(preview)
	preview.unit = null
	for slot in SLOTS:
		_expect(not preview.get_node(NodePath(slot)).visible, "An empty preview kept equipment visible")
	preview.free()
	if not _failed:
		print("Attachment tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
