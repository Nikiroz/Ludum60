# Run with: Godot --headless --path . --script res://tests/test_victory_dialog.gd
extends SceneTree

var _failed := false
var _checks := 0
var _main: Node
var _controller: Node
var _transition: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Victory dialog test: " + message)


func _key(keycode: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = keycode
	root.push_input(event)


func _click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)


func _battle(health: float = 10.0, damage: float = 0.0) -> Node:
	_controller.isMainMenu = false
	_main.get_node("MenuLayer/MainMenu").hide()
	var boss = load("res://scripts/boss_unit.gd").new()
	boss.health = health
	boss.damage = damage
	boss.crit_chance = 0.0
	boss.attack_sequence.assign([1])
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.generate_demo_units_on_start = false
	battle.set_units([_controller.units[0]])
	battle.set_boss(boss)
	_main.add_child(battle)
	_transition.gameplay_scene = battle
	_controller.set_gameplay_scene(battle)
	return battle


func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	_controller = root.get_node("ControllerGame")
	_transition = root.get_node("Transition")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	var dialog: Control = _main.get_node("MenuLayer/VictoryDialog")
	var yes: Button = dialog.get_node("Panel/VBoxContainer/Buttons/Yes")
	var no: Button = dialog.get_node("Panel/VBoxContainer/Buttons/No")
	var menu_music: AudioStreamPlayer = _controller.get_node("MainMenuMusic")
	var battle_music: AudioStreamPlayer = _controller.get_node("BattleMusic")
	_expect(not dialog.visible and not paused, "Dialog is open before victory")
	_key(KEY_F9)
	_expect(not dialog.visible and not paused, "F9 still opens the victory dialog")
	_controller.show_victory_dialog()
	await process_frame
	await process_frame
	_expect(dialog.visible and paused and yes.has_focus(), "Victory dialog did not open as a focused modal")
	_expect(dialog.get_node("Panel/VBoxContainer/Message").text == "You won!\nDo you want to continue?" and yes.text == "Yes" and no.text == "No", "Dialog text is not English")
	_expect(menu_music.playing and not menu_music.stream_paused and menu_music.can_process(), "Popup stopped main menu music")
	_expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(dialog.get_node("Panel").get_global_rect()), "Popup does not fit the game viewport")
	_key(KEY_TAB)
	_expect(no.has_focus(), "Tab did not move focus to No")
	_key(KEY_TAB)
	_expect(yes.has_focus(), "Tab allowed focus to leave the popup")
	_key(KEY_F9, true)
	_key(KEY_ESCAPE)
	_expect(dialog.visible and not _main.get_node("MenuLayer/Settings").visible, "Repeated F9 or Escape dismissed the popup or opened settings behind it")
	_click(yes)
	_expect(not dialog.visible and not paused and _controller.isMainMenu, "Yes from a debug popup changed the current screen or left it paused")

	_controller.reset_progress()
	_controller.add_collected_item(load("res://item_pack/items/head_router.tres"))
	var saved: GridInventoryItemData = _controller.collected_items[0]
	_controller.inventory_positions[saved] = Vector2i(2, 2)
	var unit: BattleUnit = _controller.units[0]
	unit.health = 100.0
	unit.damage = 20.0
	unit.attack_speed = 1.0
	unit.crit_chance = 0.0
	var battle := _battle()
	_controller.scrapyard_available = false
	await process_frame
	await process_frame
	var slot: Control = battle.get_node("MarginContainer/HBoxContainer").get_child(0)
	slot._start_drag()
	_controller.show_victory_dialog()
	_expect(dialog.visible and slot.active_slot == null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Debug popup left a robot drag or hidden cursor active")
	_expect(battle.state == battle.State.PREPARATION and unit.health == 100.0 and not _controller.scrapyard_available, "Debug popup changed battle progress")
	_click(yes)
	battle.start_battle()
	var timer: Timer = battle.get_node("BattleTimer")
	_controller.show_victory_dialog()
	var time_left := timer.time_left
	await create_timer(0.1).timeout
	_expect(paused and is_equal_approx(timer.time_left, time_left) and battle.tick_count == 0, "Debug popup allowed combat to advance")
	_click(yes)
	_expect(not paused and battle.state == battle.State.FIGHTING, "Yes did not resume a debug-paused battle")
	timer.stop()
	battle._on_battle_tick()
	_expect(dialog.visible and paused and battle.state == battle.State.VICTORY, "Defeating the boss did not automatically open the popup")
	_expect(_controller.scrapyard_available and unit.health == 100.0, "Popup opened before victory restored progress and robot health")
	_expect(battle_music.playing and not battle_music.stream_paused, "Victory popup switched away from battle music")
	_click(yes)
	_expect(not dialog.visible and not paused and _transition.gameplay_scene == battle, "Yes did not keep the normal victory screen")
	_expect(battle.get_node("GarageButton").visible and battle.get_node("StarBattleButton").disabled, "Yes changed the completed battle controls")
	_expect(_controller.collected_items[0] == saved and _controller.inventory_positions[saved] == Vector2i(2, 2), "Continuing lost inventory progress")
	battle.free()
	_transition.gameplay_scene = null

	battle = _battle()
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	battle._on_battle_tick()
	_expect(dialog.visible and paused, "Second victory did not open the popup")
	_click(no)
	await process_frame
	await process_frame
	_expect(_controller.isMainMenu and _main.get_node("MenuLayer/MainMenu").visible and not paused and not dialog.visible, "No did not return to the unpaused main menu")
	_expect(not is_instance_valid(battle) and _transition.gameplay_scene == null, "No retained the old battle")
	_expect(menu_music.playing and not menu_music.stream_paused and battle_music.stream_paused, "No did not switch to main menu music")
	_expect(_controller.collected_items[0] == saved and _controller.inventory_positions[saved] == Vector2i(2, 2), "Returning to the menu lost inventory progress")

	unit.damage = 0.0
	battle = _battle(100.0, 7.0)
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	battle._on_battle_tick()
	_expect(unit.health == 93.0, "Debug exit check did not damage the robot")
	_controller.show_victory_dialog()
	_click(no)
	await process_frame
	await process_frame
	_expect(unit.health == 100.0 and not is_instance_valid(battle) and not paused, "No from a debug popup did not stop combat and restore robot health")

	unit.health = 5.0
	battle = _battle(100.0, 10.0)
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	battle._on_battle_tick()
	_expect(battle.state == battle.State.DEFEAT and not dialog.visible and not paused, "Defeat opened a victory popup")
	_controller.return_to_main_menu()
	await process_frame
	_main.free()
	await process_frame
	if not _failed:
		print("Victory dialog tests passed: %d checks." % _checks)
	quit(1 if _failed else 0)
