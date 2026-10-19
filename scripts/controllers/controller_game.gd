extends Node

signal item_collected(item: GridInventoryItemData)
signal inventory_changed
signal scrapyard_availability_changed

const CURSOR_NORMAL: Texture2D = preload("res://sprites/cursors/cursor.png")
const BACKGROUND_MUSIC: AudioStreamOggVorbis = preload("res://sounds/MUSIC 1.ogg")
const BATTLE_MUSIC: AudioStreamOggVorbis = preload("res://sounds/MUSIC 2.ogg")
const UnitGenerator = preload("res://scripts/temporary_unit_generator.gd")

var _background_music: AudioStreamPlayer
var _battle_music: AudioStreamPlayer
var units: Array[BattleUnit] = []
var collected_items: Array[GridInventoryItemData] = []
var inventory_positions: Dictionary[GridInventoryItemData, Vector2i] = {}
var scrapyard_available := true:
	set(value):
		scrapyard_available = value
		scrapyard_availability_changed.emit()

var isMainMenu := true:
	set(value):
		isMainMenu = value
		_update_quit_to_main_menu_visibility()
		if isMainMenu:
			_set_battle_music_enabled(false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background_music = _create_music_player("BackgroundMusic", BACKGROUND_MUSIC)
	_battle_music = _create_music_player("BattleMusic", BATTLE_MUSIC)
	_background_music.play()
	Input.set_custom_mouse_cursor(CURSOR_NORMAL, Input.CURSOR_ARROW)
	set_drag_cursor(false)
	call_deferred("_update_quit_to_main_menu_visibility")

func _exit_tree() -> void:
	if is_instance_valid(_background_music):
		_background_music.stop()
	if is_instance_valid(_battle_music):
		_battle_music.stop()

func _create_music_player(player_name: String, stream: AudioStreamOggVorbis) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.stream.loop = true
	player.bus = &"Music"
	add_child(player)
	return player

func set_gameplay_scene(scene: Node) -> void:
	var location := scene.scene_file_path.get_file().get_basename()
	_set_battle_music_enabled(location == "battle")
	if location == "scrapyard":
		scrapyard_available = false
	elif location == "battle":
		scene.connect("round_finished", _on_battle_round_finished)

func _set_battle_music_enabled(enabled: bool) -> void:
	if not is_instance_valid(_background_music) or not is_instance_valid(_battle_music):
		return
	_background_music.stream_paused = enabled
	if enabled and not _battle_music.playing:
		_battle_music.play()
	_battle_music.stream_paused = not enabled

func add_collected_item(item: GridInventoryItemData) -> void:
	var collected := item.duplicate(true) as GridInventoryItemData
	collected_items.append(collected)
	item_collected.emit(collected)
	inventory_changed.emit()

func can_equip_item(unit: BattleUnit, item: GridInventoryItemData, left_hand: bool = true) -> bool:
	return (
		unit != null and units.has(unit)
		and item != null and collected_items.has(item)
		and item.get_equipment_slot(left_hand) != &""
	)

func equip_item(unit: BattleUnit, item: GridInventoryItemData, left_hand: bool = true) -> bool:
	if not can_equip_item(unit, item, left_hand):
		return false
	var previous := unit.equip_item(item, item.get_equipment_slot(left_hand))
	collected_items.erase(item)
	inventory_positions.erase(item)
	if previous != null and not previous.is_service_item:
		collected_items.append(previous)
	inventory_changed.emit()
	return true

func reset_progress() -> void:
	units = UnitGenerator.generate_units(3)
	collected_items.clear()
	inventory_positions.clear()
	scrapyard_available = true
	inventory_changed.emit()

func can_unequip_item(unit: BattleUnit, slot: StringName, item: GridInventoryItemData) -> bool:
	return (
		unit != null and units.has(unit) and item != null
		and unit.equipment.get(slot) == item and not item.is_service_item
		and not collected_items.has(item)
	)

func unequip_item(unit: BattleUnit, slot: StringName, item: GridInventoryItemData, origin: Vector2i) -> bool:
	if not can_unequip_item(unit, slot, item) or origin.x < 0 or origin.y < 0:
		return false
	var removed := unit.unequip_item(slot)
	if removed == null:
		return false
	collected_items.append(removed)
	inventory_positions[removed] = origin
	inventory_changed.emit()
	return true

func _on_battle_round_finished() -> void:
	scrapyard_available = true

func set_drag_cursor(dragging: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if dragging else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if isMainMenu:
		return

	if event.is_action_pressed("ui_cancel"):
		var warning := get_tree().current_scene.get_node_or_null("MenuLayer/Warning") as Control
		var settings := _get_settings()
		if warning != null and warning.is_visible_in_tree():
			warning.hide()
		elif settings != null and settings.is_visible_in_tree():
			settings.hide()
		else:
			show_settings()
		get_viewport().set_input_as_handled()

func show_settings() -> void:
	var settings := _get_settings()
	if settings == null:
		push_error("Settings node not found")
		return

	settings.show()
	_update_quit_to_main_menu_visibility()

func _get_settings() -> Control:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	return current_scene.get_node_or_null("MenuLayer/Settings") as Control

func _update_quit_to_main_menu_visibility() -> void:
	var settings := _get_settings()
	if settings == null:
		return

	var quit_to_main_menu := settings.get_node_or_null(
		"Panel/VBoxContainer2/QuitToMainMenu"
	) as Button
	if quit_to_main_menu != null:
		quit_to_main_menu.visible = not isMainMenu

func play_one_shot(stream: AudioStream, bus := "Sfx", volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p
