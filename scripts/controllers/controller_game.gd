extends Node

signal item_collected(item: GridInventoryItemData)
signal inventory_changed
signal scrapyard_availability_changed
signal debug_mode_changed

enum MusicMode { MAIN_MENU, BACKGROUND, BATTLE }

const CURSOR_NORMAL: Texture2D = preload("res://sprites/cursors/cursor.png")
const BACKGROUND_MUSIC: AudioStreamOggVorbis = preload("res://sounds/MUSIC 1.ogg")
const BATTLE_MUSIC: AudioStreamOggVorbis = preload("res://sounds/MUSIC 2.ogg")
const MAIN_MENU_MUSIC: AudioStreamOggVorbis = preload("res://sounds/MUSIC 3.ogg")

var _background_music: AudioStreamPlayer
var _battle_music: AudioStreamPlayer
var _main_menu_music: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var debug_mode := false:
	set(value):
		if debug_mode == value:
			return
		debug_mode = value
		debug_mode_changed.emit()

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
		play_music(MusicMode.MAIN_MENU if isMainMenu else MusicMode.BACKGROUND)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background_music = _create_music_player("BackgroundMusic", BACKGROUND_MUSIC)
	_battle_music = _create_music_player("BattleMusic", BATTLE_MUSIC)
	_main_menu_music = _create_music_player("MainMenuMusic", MAIN_MENU_MUSIC)
	play_music(MusicMode.MAIN_MENU if isMainMenu else MusicMode.BACKGROUND)
	Input.set_custom_mouse_cursor(CURSOR_NORMAL, Input.CURSOR_ARROW)
	set_drag_cursor(false)
	call_deferred("_update_quit_to_main_menu_visibility")

func _exit_tree() -> void:
	for player in [_background_music, _battle_music, _main_menu_music]:
		if is_instance_valid(player):
			player.stop()

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
	play_music(MusicMode.BATTLE if location == "battle" else MusicMode.BACKGROUND)
	if location == "scrapyard":
		scrapyard_available = false
	elif location == "battle":
		scene.connect("round_finished", _on_battle_round_finished)

func play_music(mode: MusicMode) -> void:
	var active_player: AudioStreamPlayer
	match mode:
		MusicMode.MAIN_MENU:
			active_player = _main_menu_music
		MusicMode.BACKGROUND:
			active_player = _background_music
		MusicMode.BATTLE:
			active_player = _battle_music
	if not is_instance_valid(active_player):
		return
	if _active_music == active_player and active_player.has_stream_playback() and not active_player.stream_paused:
		return

	for player in [_background_music, _battle_music, _main_menu_music]:
		if not is_instance_valid(player) or player == active_player:
			continue
		if player.has_stream_playback() and not player.stream_paused:
			player.stream_paused = true

	# Paused streams report playing == false; keep their playback and position.
	if active_player.has_stream_playback():
		active_player.stream_paused = false
	else:
		active_player.play()
	_active_music = active_player

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
	units.clear()
	var names: Array[String] = BattleUnit.UNIT_NAMES.duplicate()
	names.shuffle()
	for unit_name in names:
		var unit := BattleUnit.new()
		unit.name = unit_name
		unit.health = 1.0
		unit.damage = 1.0
		units.append(unit)
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

func show_victory_dialog() -> void:
	var main := get_tree().current_scene
	if main == null or Transition.transitioning:
		return
	var dialog = main.get_node_or_null("MenuLayer/VictoryDialog")
	if dialog != null:
		dialog.open()

func return_to_main_menu() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var main_menu := main.get_node_or_null("MenuLayer/MainMenu") as Control
	if main_menu == null:
		return
	for panel_name in ["Settings", "Warning", "Credits", "VictoryDialog"]:
		var panel := main.get_node_or_null("MenuLayer/" + panel_name) as Control
		if panel != null:
			panel.hide()
	if is_instance_valid(Transition.gameplay_scene):
		Transition.gameplay_scene.process_mode = Node.PROCESS_MODE_DISABLED
		Transition.gameplay_scene.queue_free()
	Transition.gameplay_scene = null
	isMainMenu = true
	main_menu.show()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_F9 and event.physical_keycode != KEY_F9:
		return
	debug_mode = not debug_mode
	get_viewport().set_input_as_handled()

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
