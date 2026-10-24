
extends Control

signal round_finished

const ItemCatalog = preload("res://scripts/item_catalog.gd")
const ItemEquipment = preload("res://scripts/item_equipment.gd")
const ITEM_COUNT := 8

@export var game_time: float = 30.0
@export var trash_sounds: Array[AudioStream] = []
@onready var timer: Timer = $VBoxContainer/Control2/Timer/Timer
@onready var timer_label: Label = $VBoxContainer/Control2/Timer
@onready var timer_slider: HSlider = $VBoxContainer/Control2/Control/MarginContainer/HSlider
@onready var field: GridContainer = $VBoxContainer/Control/Field
@onready var items_grid: GridContainer = $VBoxContainer/BottomPanel/Items

class SpawnPlan:
	var data: GridInventoryItemData
	var origin: Vector2i

	func _init(p_data: GridInventoryItemData, p_origin: Vector2i) -> void:
		data = p_data
		origin = p_origin

class HiddenItem:
	var data: GridInventoryItemData
	var sprite: Sprite2D
	var cells: Array[FieldCell] = []

var game_over := false

var field_cells: Array[FieldCell] = []
var inventory_slots: Array[TextureRect] = []

var hidden_items: Array[HiddenItem] = []
var cell_to_item: Dictionary = {}

var collected_items: Array[GridInventoryItemData] = []
var next_inventory_slot := 0


func _ready() -> void:
	timer_slider.min_value = 0
	timer_slider.max_value = game_time
	timer_slider.step = 0
	timer_slider.rounded = false
	timer_slider.editable = false

	timer.wait_time = game_time
	timer.one_shot = true
	timer.timeout.connect(func () -> void: 
		end_game() 
		ControllerGame.play_one_shot(preload("uid://d0ikcbhy4meec")))
	timer.start()
	update_timer_ui()


	for child in field.get_children():
		if child is FieldCell:
			var cell: FieldCell = child

			cell.z_index = 1

			field_cells.append(cell)
			cell.cell_clicked.connect(_on_cell_clicked)

	for child in items_grid.get_children():
		if child is TextureRect:
			inventory_slots.append(child)

	if inventory_slots.size() < ITEM_COUNT:
		push_error("Inventory requires at least 6 slots")
		return

	await get_tree().process_frame

	spawn_random_items()

func _process(_delta: float) -> void:
	if game_over:
		return

	update_timer_ui()

func update_timer_ui() -> void:
	timer_slider.value = timer.time_left
	var seconds: int = ceili(timer.time_left)
	var minutes: int = int(seconds / 60)

	timer_label.text = "%02d:%02d" % [
		minutes,
		seconds % 60
	]
	
func load_available_items() -> Array[GridInventoryItemData]:
	var result: Array[GridInventoryItemData] = []

	var columns: int = field.columns
	var rows: int = int(field_cells.size() / columns)

	for path in ItemCatalog.get_item_paths():
		var item: GridInventoryItemData = load(path) as GridInventoryItemData

		if item == null or ItemEquipment.is_service_item(item):
			continue

		if item.occupied_cells.is_empty():
			continue

		if item.grid_size.x <= 0 or item.grid_size.y <= 0:
			continue

		if item.grid_size.x > columns or item.grid_size.y > rows:
			continue

		if item.get_texture() == null:
			continue

		var valid := true

		for offset in item.occupied_cells:
			if (
				offset.x < 0 or offset.y < 0
				or offset.x >= item.grid_size.x
				or offset.y >= item.grid_size.y
			):
				valid = false
				break

		if valid:
			result.append(item)

	return result

func get_free_positions(item: GridInventoryItemData,occupied: Dictionary) -> Array[Vector2i]:

	var positions: Array[Vector2i] = []

	var columns: int = field.columns
	var rows: int = int(field_cells.size() / columns)

	for y in range(rows - item.grid_size.y + 1):
		for x in range(columns - item.grid_size.x + 1):

			var origin := Vector2i(x, y)
			var valid := true

			for dy in range(item.grid_size.y):
				for dx in range(item.grid_size.x):
					var pos := origin + Vector2i(dx, dy)

					if occupied.has(pos):
						valid = false
						break

				if not valid:
					break

			if valid:
				positions.append(origin)

	return positions

func spawn_random_items() -> void:
	var available_items := load_available_items()

	if available_items.is_empty():
		push_error("No suitable items found")
		return

	var plan: Array[SpawnPlan] = []

	for attempt in range(200):
		var occupied: Dictionary = {}
		var current_plan: Array[SpawnPlan] = []
		var item_pool: Array[GridInventoryItemData] = available_items.duplicate()

		for i in range(ITEM_COUNT):
			var found := false

			# Refill only after exhausting the remaining items that can fit.
			for pool_attempt in range(2):
				if item_pool.is_empty():
					item_pool.assign(available_items)
				item_pool.shuffle()

				while not item_pool.is_empty():
					var item: GridInventoryItemData = item_pool.pop_back()
					var positions := get_free_positions(item, occupied)

					if positions.is_empty():
						continue

					var origin: Vector2i = positions.pick_random()
					current_plan.append(SpawnPlan.new(item, origin))

					for dy in range(item.grid_size.y):
						for dx in range(item.grid_size.x):
							occupied[origin + Vector2i(dx, dy)] = true

					found = true
					break

				if found:
					break

			if not found:
				break

		if current_plan.size() == ITEM_COUNT:
			plan = current_plan
			break

	if plan.size() != ITEM_COUNT:
		push_error("Could not fit all %d items on the field" % ITEM_COUNT)
		return

	for placement in plan:
		place_item(placement.data, placement.origin)

	print("Spawned items: ", hidden_items.size())

func place_item(item: GridInventoryItemData,origin: Vector2i) -> void:

	var columns: int = field.columns

	var start_index: int = origin.y * columns + origin.x

	var end_index: int = (
		(origin.y + item.grid_size.y - 1) * columns
		+ origin.x + item.grid_size.x - 1
	)

	var first_cell: FieldCell = field_cells[start_index]
	var last_cell: FieldCell = field_cells[end_index]

	var start_pos: Vector2 = first_cell.position
	var end_pos: Vector2 = last_cell.position + last_cell.size
	var item_size: Vector2 = end_pos - start_pos

	var sprite := Sprite2D.new()

	sprite.texture = item.get_texture()
	sprite.centered = false
	sprite.position = start_pos
	sprite.scale = item_size / Vector2(sprite.texture.get_size())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 0

	field.add_child(sprite)

	var hidden := HiddenItem.new()

	hidden.data = item
	hidden.sprite = sprite

	for offset in item.occupied_cells:
		var cell_pos: Vector2i = origin + offset
		var index: int = cell_pos.y * columns + cell_pos.x

		var cell: FieldCell = field_cells[index]

		cell.set_clicks_required(2)

		hidden.cells.append(cell)
		cell_to_item[cell] = hidden

	hidden_items.append(hidden)

	print("Spawned: ", item.display_name, " at ", origin)

func _on_cell_clicked(cell: FieldCell) -> void:
	if game_over:
		return

	var hidden: HiddenItem = cell_to_item.get(cell) as HiddenItem

	if hidden != null:
		if is_item_revealed(hidden):
			collect_item(hidden)
			
	if not trash_sounds.is_empty():
		var sound: AudioStream = trash_sounds.pick_random()
		ControllerGame.play_one_shot(sound)

func is_item_revealed(hidden: HiddenItem) -> bool:
	for cell in hidden.cells:
		if cell.clicks_left > 0:
			return false

	return true

func collect_item(hidden: HiddenItem) -> void:
	if next_inventory_slot >= inventory_slots.size():
		push_warning("Inventory is full")
		return

	var slot: TextureRect = inventory_slots[next_inventory_slot]

	var icon := TextureRect.new()
	icon.texture = hidden.data.get_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slot.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	collected_items.append(hidden.data)
	ControllerGame.add_collected_item(hidden.data)
	next_inventory_slot += 1

	if is_instance_valid(hidden.sprite):
		hidden.sprite.queue_free()

	for cell in hidden.cells:
		cell_to_item.erase(cell)

	hidden_items.erase(hidden)

	if collected_items.size() >= ITEM_COUNT:
		end_game()

	ControllerGame.play_one_shot(preload("uid://dgopqhqch8r0o"))

	print("Collected: ", hidden.data.display_name)
	print("Collected total: ", collected_items.size())

func end_game() -> void:
	if game_over:
		return

	game_over = true
	timer.stop()
	update_timer_ui()

	for cell in field_cells:
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	print("GAME OVER")
	round_finished.emit()
