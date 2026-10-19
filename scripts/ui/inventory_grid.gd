extends Control

const CELL_TEXTURE: Texture2D = preload("res://sprites/ui/cell_bg.png")
const CELL_SIZE := 12

@export_range(3, 30) var columns := 12
@export_range(1, 100) var initial_rows := 14

var rows: int
var items: Array[GridInventoryItemData] = []
# Drawing commands keep texture RIDs, so retain the resources between frames.
var _textures: Dictionary[String, Texture2D] = {}
var _dragged_item: GridInventoryItemData
var _drop_origin := Vector2i.ZERO
var _show_drop := false
var _drop_valid := false
var _drop_item: GridInventoryItemData


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ControllerGame.inventory_changed.connect(_sync_inventory)
	_sync_inventory()


func _sync_inventory() -> void:
	items.assign(ControllerGame.collected_items)
	rows = initial_rows
	for item in items:
		if not _textures.has(item.sprite_path):
			_textures[item.sprite_path] = item.get_texture()
		var occupied_size := _occupied_size(item)
		columns = maxi(columns, occupied_size.x)
		if ControllerGame.inventory_positions.has(item):
			rows = maxi(rows, ControllerGame.inventory_positions[item].y + occupied_size.y)
	for item in items:
		if ControllerGame.inventory_positions.has(item):
			continue
		var origin := _find_space(item)
		while origin == Vector2i(-1, -1):
			rows += maxi(1, _occupied_size(item).y)
			origin = _find_space(item)
		ControllerGame.inventory_positions[item] = origin
	custom_minimum_size = Vector2(columns, rows) * CELL_SIZE
	queue_redraw()


func _occupied_size(item: GridInventoryItemData) -> Vector2i:
	var extent := Vector2i.ZERO
	for offset in item.occupied_cells:
		extent.x = maxi(extent.x, offset.x + 1)
		extent.y = maxi(extent.y, offset.y + 1)
	return extent


func _find_space(item: GridInventoryItemData) -> Vector2i:
	var occupied_size := _occupied_size(item)
	for y in range(rows - occupied_size.y + 1):
		for x in range(columns - occupied_size.x + 1):
			var origin := Vector2i(x, y)
			if can_place_item(item, origin):
				return origin
	return Vector2i(-1, -1)


func can_place_item(item: GridInventoryItemData, origin: Vector2i) -> bool:
	if origin.x < 0 or origin.y < 0:
		return false
	for offset in item.occupied_cells:
		var cell := origin + offset
		if cell.x >= columns or cell.y >= rows:
			return false
		var occupying_item := item_at_cell(cell)
		if occupying_item != null and occupying_item != item:
			return false
	return true


func item_at_cell(cell: Vector2i) -> GridInventoryItemData:
	for item in items:
		if not ControllerGame.inventory_positions.has(item):
			continue
		var origin: Vector2i = ControllerGame.inventory_positions[item]
		if item.occupies(cell - origin):
			return item
	return null


func _cell_at(at_position: Vector2) -> Vector2i:
	return Vector2i((at_position / CELL_SIZE).floor())


func _get_drag_data(at_position: Vector2) -> Variant:
	var item := item_at_cell(_cell_at(at_position))
	if item == null:
		return null
	_dragged_item = item
	var origin: Vector2i = ControllerGame.inventory_positions[item]
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = _textures.get(item.sprite_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(item.grid_size) * CELL_SIZE
	icon.position = Vector2(origin) * CELL_SIZE - at_position
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(icon)
	set_drag_preview(preview)
	queue_redraw()
	return {"inventory": self, "item": item, "grab_offset": _cell_at(at_position) - origin}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var item := data.get("item") as GridInventoryItemData
	var inventory_move: bool = data.get("inventory") == self and ControllerGame.collected_items.has(item)
	var equipment_return: bool = data.has("equipment") and ControllerGame.can_unequip_item(
		data.get("unit") as BattleUnit, data.get("slot", &""), item
	)
	if not inventory_move and not equipment_return:
		return false
	_drop_origin = _cell_at(at_position) - data.grab_offset
	_drop_item = item
	_drop_valid = can_place_item(item, _drop_origin)
	_show_drop = true
	queue_redraw()
	return _drop_valid


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		if data.get("inventory") == self:
			ControllerGame.inventory_positions[data.item] = _drop_origin
		else:
			ControllerGame.unequip_item(data.unit, data.slot, data.item, _drop_origin)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var item := item_at_cell(_cell_at(event.position))
		tooltip_text = item.display_name if item != null else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragged_item = null
		_drop_item = null
		_show_drop = false
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_show_drop = false
		queue_redraw()


func _draw() -> void:
	for y in range(rows):
		for x in range(columns):
			draw_texture(CELL_TEXTURE, Vector2(x, y) * CELL_SIZE)
	for item in items:
		if not ControllerGame.inventory_positions.has(item):
			continue
		var texture: Texture2D = _textures.get(item.sprite_path)
		if texture == null:
			continue
		var origin: Vector2i = ControllerGame.inventory_positions[item]
		var tint := Color(1, 1, 1, 0.25 if item == _dragged_item else 1.0)
		draw_texture_rect(texture, Rect2(Vector2(origin) * CELL_SIZE, Vector2(item.grid_size) * CELL_SIZE), false, tint)
	if _show_drop and _drop_item != null:
		var color := Color(0.3, 1.0, 0.4, 0.45) if _drop_valid else Color(1.0, 0.2, 0.2, 0.45)
		for offset in _drop_item.occupied_cells:
			draw_rect(Rect2(Vector2(_drop_origin + offset) * CELL_SIZE, Vector2.ONE * CELL_SIZE), color)
