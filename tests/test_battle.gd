# Run with: Godot --headless --path . --script res://tests/test_battle.gd
extends SceneTree

const BossData = preload("res://scripts/boss_unit.gd")
const ROBOT_TEXTURE: Texture2D = preload("res://sprites/robots/dummy1.png")

var _main: Node
var _battle_scene: PackedScene
var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Battle test: " + message)


func _unit(health: float = 100.0, speed: float = 1.0, damage: float = 10.0, crit: float = 0.0) -> BattleUnit:
	var unit := BattleUnit.new(ROBOT_TEXTURE)
	unit.health = health
	unit.attack_speed = speed
	unit.damage = damage
	unit.crit_chance = crit
	return unit


func _boss(health: float = 9999.0, damage: float = 0.0, pattern: Array = [1], crit: float = 0.0) -> BossData:
	var boss := BossData.new(ROBOT_TEXTURE)
	boss.health = health
	boss.damage = damage
	boss.attack_sequence.assign(pattern)
	boss.crit_chance = crit
	return boss


func _battle(army: Array, boss: BossData) -> Node:
	var battle := _battle_scene.instantiate()
	battle.generate_demo_units_on_start = false
	battle.set_units(army)
	battle.set_boss(boss)
	_main.add_child(battle)
	root.get_node("ControllerGame").set_gameplay_scene(battle)
	return battle


func _step(battle: Node) -> void:
	battle.get_node("BattleTimer").timeout.emit()


func _has_log(battle: Node, text: String) -> bool:
	for entry in battle.battle_log:
		if text in entry:
			return true
	return false


func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	# Load gameplay after autoloads have initialized.
	_battle_scene = load("res://scenes/battle.tscn")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	_main.get_node("MenuLayer/MainMenu").hide()
	var start_button: Button = _main.get_node("Navigation/StarBattleButton")

	# The real button starts exactly one timer and locks the formation.
	var attacker := _unit(100.0, 1.0, 2.0)
	var boss := _boss()
	var battle := _battle([attacker], boss)
	await process_frame
	await process_frame
	var row: HBoxContainer = battle.get_node("MarginContainer/HBoxContainer")
	var slot: Control = row.get_child(0)
	_expect(slot.size.is_equal_approx(Vector2(36, 60)), "Robot visual changed the slot hit area")
	_expect(slot.icon.size.is_equal_approx(Vector2(95, 100)), "Robot visual is not 95 by 100")
	_expect(start_button.visible, "Start button is missing during preparation")
	slot._start_drag()
	_expect(slot.active_slot == slot, "Preparation drag did not start")
	start_button.pressed.emit()
	_expect(not start_button.visible, "Start button stayed visible")
	_expect(slot.active_slot == null, "Starting battle did not cancel the active drag")
	_expect(slot._preview_layer == null, "Drag preview was not released")
	for view in row.get_children():
		_expect(not view.dragging_enabled, "A battle slot remained draggable")
	slot._start_drag()
	slot._animate_reorder(1)
	_expect(slot.active_slot == null and slot.get_index() == 0, "Locked slot was moved")
	_expect(not battle.get_node("BattleTimer").is_stopped(), "Battle timer was not started")
	_expect(is_equal_approx(battle.get_node("BattleTimer").wait_time, 1.0), "Tick duration is not one second")
	start_button.pressed.emit()
	_expect(_has_log(battle, "Запуск отклонён"), "Repeated start was not rejected")
	await create_timer(0.4).timeout
	_expect(battle.tick_count == 0, "Battle attacked before the first second")
	await create_timer(0.75).timeout
	_expect(battle.tick_count == 1, "Real timer did not produce exactly one tick")
	_expect(is_equal_approx(boss.health, 9997.0), "Real timer applied wrong damage")
	_expect(slot.target_arrow.visible, "Boss target arrow is missing")
	_expect(slot.target_arrow.get_global_rect().position.y >= slot.get_global_rect().end.y, "Arrow is not below its slot")
	battle.free()

	# Fractional attack speeds carry progress across ticks; boss cycles slot numbers.
	attacker = _unit(100.0, 1.5, 10.0)
	var second := _unit(100.0, 0.0, 0.0)
	boss = _boss(1000.0, 7.0, [1, 3, 2, 4])
	boss.attack_speed = 999.0
	battle = _battle([attacker, second], boss)
	_expect(battle.start_battle(), "Valid battle did not start")
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_expect(is_equal_approx(boss.health, 990.0), "1.5 attacks/s should attack once on tick 1")
	_expect(is_equal_approx(attacker.health, 93.0), "Boss must attack once per tick regardless of speed")
	_step(battle)
	_expect(is_equal_approx(boss.health, 970.0), "1.5 attacks/s should attack twice on tick 2")
	_expect(is_equal_approx(attacker.health, 93.0) and is_equal_approx(second.health, 100.0), "Empty target damaged a unit")
	row = battle.get_node("MarginContainer/HBoxContainer")
	_expect(row.get_child(2).target_arrow.visible, "Arrow did not follow the empty third slot")
	_step(battle)
	_expect(is_equal_approx(second.health, 93.0), "Boss did not follow slot 2 in its pattern")
	_step(battle)
	_expect(row.get_child(3).target_arrow.visible, "Arrow did not follow slot 4")
	_step(battle)
	_expect(is_equal_approx(attacker.health, 86.0), "Boss pattern did not loop")
	_expect(_has_log(battle, "пустой слот"), "Missed empty-slot attack was not logged")
	battle.free()

	attacker = _unit(100.0, 0.5, 3.0)
	boss = _boss(100.0)
	battle = _battle([attacker], boss)
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_expect(is_equal_approx(boss.health, 100.0), "0.5 attacks/s attacked too early")
	_step(battle)
	_expect(is_equal_approx(boss.health, 97.0), "0.5 attacks/s did not attack on tick 2")
	battle.free()

	# Both sides use the stored critical chance and double critical damage.
	attacker = _unit(100.0, 1.0, 10.0, 1.0)
	boss = _boss(100.0, 5.0, [1], 1.0)
	battle = _battle([attacker], boss)
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_expect(is_equal_approx(boss.health, 80.0) and is_equal_approx(attacker.health, 90.0), "Critical damage is not doubled")
	_expect(_has_log(battle, "КРИТ x2"), "Critical hit was not logged")
	battle.free()

	# Killing the boss ends the battle before its retaliation and removes its view.
	attacker = _unit(100.0, 1.0, 10.0)
	boss = _boss(5.0, 1000.0)
	battle = _battle([attacker], boss)
	var ended: Array = []
	battle.round_finished.connect(func() -> void: ended.append(true))
	battle.start_battle()
	_step(battle)
	_expect(boss.health == 0.0 and attacker.health == 100.0, "Dead boss retaliated or retained negative HP")
	_expect(battle.get_node("MarginContainer2").get_child_count() == 0, "Dead boss sprite remained on the field")
	_expect(battle.get_node("BattleTimer").is_stopped() and ended.size() == 1, "Victory did not stop and finish the battle")
	_expect(not start_button.visible, "Start button returned after victory")
	_expect(_has_log(battle, "ПОБЕДА"), "Victory was not logged")
	_step(battle)
	_expect(ended.size() == 1 and battle.tick_count == 1, "Finished battle continued ticking")
	battle.free()

	# A dead unit becomes an empty position without shifting the other slots.
	attacker = _unit(5.0, 0.0, 0.0)
	battle = _battle([attacker], _boss(100.0, 10.0))
	battle.start_battle()
	_step(battle)
	_expect(attacker.health == 5.0 and battle.units[0] == null, "Defeat did not restore the removed unit's health")
	row = battle.get_node("MarginContainer/HBoxContainer")
	_expect(row.get_child_count() == 4, "Death changed fixed slot numbering")
	_expect(row.get_child(0).icon.texture.resource_path.ends_with("dummy_blank.png"), "Dead unit sprite remained")
	_expect(not row.get_child(0).debug_stats.visible, "Dead unit stats remained visible")
	_expect(battle.get_node("BattleTimer").is_stopped() and _has_log(battle, "ПОРАЖЕНИЕ"), "Defeat did not stop the battle")
	_expect(not start_button.visible, "Start button returned after defeat")
	battle.free()

	# Invalid and empty patterns safely consume or skip the boss turn.
	attacker = _unit(100.0, 0.0, 0.0)
	battle = _battle([attacker], _boss(100.0, 50.0, [9, 0]))
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_step(battle)
	_expect(attacker.health == 100.0 and _has_log(battle, "не существует"), "Invalid pattern targeted a real unit")
	battle.free()
	battle = _battle([attacker], _boss(100.0, 50.0, []))
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_expect(attacker.health == 100.0 and _has_log(battle, "паттерн пуст"), "Empty pattern was not handled")
	battle.free()

	# Starting without a living army is rejected and dead sprites are cleaned up.
	battle = _battle([_unit(0.0)], _boss())
	_expect(not battle.start_battle(), "Battle started without a living army")
	_expect(start_button.visible and battle.get_node("BattleTimer").is_stopped(), "Rejected start changed battle UI or timer")
	_expect(battle.units[0] == null, "Already dead unit remained on the field")
	battle.free()
	battle = _battle([_unit()], null)
	_expect(not battle.start_battle(), "Battle started without a boss")
	battle.free()

	# Attacks start at different times; hit shakes follow their impact moments.
	attacker = _unit(100.0, 1.0, 1.0)
	second = _unit(100.0, 1.0, 1.0)
	var third := _unit(100.0, 1.0, 1.0)
	boss = _boss(1000.0, 1.0)
	battle = _battle([attacker, second, third], boss)
	await process_frame
	await process_frame
	row = battle.get_node("MarginContainer/HBoxContainer")
	slot = row.get_child(0)
	var second_view: Control = row.get_child(1)
	var third_view: Control = row.get_child(2)
	var boss_view: Control = battle.get_node("MarginContainer2").get_child(0)
	var original_slot_position: Vector2 = slot.position
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	_expect(boss.health == 997.0 and attacker.health == 99.0, "Visual offsets changed tick damage")
	await create_timer(0.04).timeout
	_expect(slot._attack_offset.x > 0.0, "First unit did not dash right")
	_expect(second_view._attack_offset.is_zero_approx() and third_view._attack_offset.is_zero_approx(), "Later units attacked without their offsets")
	_expect(boss_view._attack_offset.is_zero_approx(), "Boss attacked before its offset")
	_expect(boss_view._hit_offset.is_zero_approx(), "Hit shake started before the first impact")
	await create_timer(0.08).timeout
	_expect(second_view._attack_offset.x > 0.0, "Second unit did not attack after its offset")
	_expect(third_view._attack_offset.is_zero_approx(), "Third unit attacked too early")
	_expect(boss_view._hit_offset.length() > 0.0, "Boss did not shake after an impact")
	await create_timer(0.08).timeout
	_expect(third_view._attack_offset.x > 0.0, "Third unit did not attack after its offset")
	await create_timer(0.17).timeout
	_expect(boss_view._combat_motion.position.x < 0.0, "Boss did not dash left while receiving damage")
	_expect(slot.position.is_equal_approx(original_slot_position), "Attack animation moved the actual slot")
	await create_timer(0.4).timeout
	for view in [slot, second_view, third_view, boss_view]:
		_expect(view._combat_motion.position.is_zero_approx(), "Combat animation did not return to its origin")
		_expect(view.icon.position.is_equal_approx(view._icon_rest_position), "Combat animation affected the reorder position")
	_expect(battle.tick_count == 1, "Animation offsets advanced the battle clock")
	battle.free()

	# Two attacks in one tick each get a dash and a delayed damage reaction.
	attacker = _unit(100.0, 2.0, 10.0)
	boss = _boss(1000.0, 0.0, [])
	battle = _battle([attacker], boss)
	await process_frame
	await process_frame
	slot = battle.get_node("MarginContainer/HBoxContainer").get_child(0)
	boss_view = battle.get_node("MarginContainer2").get_child(0)
	battle.start_battle()
	battle.get_node("BattleTimer").stop()
	_step(battle)
	await create_timer(0.09).timeout
	_expect(boss_view._hit_offset.length() > 0.0, "First queued hit was lost")
	await create_timer(0.16).timeout
	_expect(slot._attack_offset.x > 0.0, "Second attack in the same tick had no dash")
	await create_timer(0.05).timeout
	_expect(boss_view._hit_offset.length() > 0.0, "Second queued hit was lost")
	await create_timer(0.3).timeout
	_expect(slot._combat_motion.position.is_zero_approx() and boss_view._combat_motion.position.is_zero_approx(), "Queued effects left a permanent offset")
	_expect(boss_view._pending_hit_tweens.is_empty(), "Completed hit callbacks were retained")
	_expect(boss.health == 980.0, "Multiple hit animations changed damage")
	battle.free()

	# Replacing a unit cancels any effects that were waiting to start.
	attacker = _unit()
	battle = _battle([attacker], _boss())
	await process_frame
	await process_frame
	slot = battle.get_node("MarginContainer/HBoxContainer").get_child(0)
	slot.play_attack(Vector2.RIGHT, 0.1)
	slot.play_hit(0.15)
	battle.remove_unit(attacker)
	var replacement := _unit()
	battle.add_unit(replacement)
	await create_timer(0.3).timeout
	_expect(slot.unit == replacement and slot._combat_motion.position.is_zero_approx(), "Replacement inherited an old unit's effect")
	_expect(slot._pending_hit_tweens.is_empty(), "Removing a unit left delayed hit callbacks")
	battle.free()

	# The existing tween for rearranging the preparation slots still works.
	attacker = _unit()
	second = _unit()
	battle = _battle([attacker, second], _boss())
	await process_frame
	await process_frame
	row = battle.get_node("MarginContainer/HBoxContainer")
	slot = row.get_child(0)
	var neighbor: Control = row.get_child(1)
	var click_position: Vector2 = slot.get_global_rect().get_center()
	_expect(neighbor.icon.get_global_rect().has_point(click_position), "Drag test needs overlapping robot visuals")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	root.push_input(press)
	_expect(slot.active_slot == slot, "Overlapping robot intercepted another slot's drag")
	if slot.active_slot != null:
		slot.active_slot._clear_drag()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = click_position
	root.push_input(release)
	slot._animate_reorder(1)
	await create_timer(0.05).timeout
	var shifted_view: Control = row.get_child(0)
	_expect(battle.units[0] == second and battle.units[1] == attacker, "Motion layer broke formation order")
	_expect(not shifted_view.icon.position.is_equal_approx(shifted_view._icon_rest_position), "Reorder tween no longer animates the icon")
	_expect(shifted_view._combat_motion.position.is_zero_approx(), "Reorder incorrectly changed combat offsets")
	await create_timer(0.25).timeout
	_expect(shifted_view.icon.position.is_equal_approx(shifted_view._icon_rest_position), "Reorder tween did not return the icon to its origin")
	battle.free()

	_main.free()
	if not _failed:
		print("Battle tests passed: %d checks (combat, animation offsets, queued hits, cleanup and rearranging)." % _checks)
	quit(1 if _failed else 0)
