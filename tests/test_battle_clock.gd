# Run with: Godot --headless --path . --script res://tests/test_battle_clock.gd
extends SceneTree

var _failed := false
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _run() -> void:
	var battle = load("res://scenes/battle.tscn").instantiate()
	var unit := BattleUnit.new()
	unit.health = 100000.0
	unit.attack_speed = 50.0
	unit.damage = 0.6
	var boss = load("res://scripts/boss_unit.gd").new()
	boss.health = 100000.0
	boss.damage = 0.0
	boss.attack_sequence.clear()
	battle.set_units([unit])
	battle.set_boss(boss)
	root.add_child(battle)
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 4.0
	battle.start_battle()
	await create_timer(0.4, true, false, true).timeout
	_expect(battle.tick_count == 0, "First battle tick occurred before one real second")
	await create_timer(0.75, true, false, true).timeout
	_expect(battle.tick_count == 1, "Attack speed or time scale accelerated the battle clock")
	await create_timer(1.0, true, false, true).timeout
	_expect(battle.tick_count == 2, "Battle did not keep a one-second tick interval")
	_expect(boss.health == 99900.0, "Two ticks did not apply exactly 100 attacks with rounded damage")
	var timer: Timer = battle.get_node("BattleTimer")
	paused = true
	var remaining := timer.time_left
	await create_timer(0.2, true, false, true).timeout
	_expect(battle.tick_count == 2 and is_equal_approx(timer.time_left, remaining), "Paused battle kept advancing its timer")
	paused = false
	Engine.time_scale = previous_time_scale
	battle.free()
	await process_frame
	if not _failed:
		print("Battle clock tests passed: %d checks (one real second per tick at 50 attacks/s)." % _checks)
	quit(1 if _failed else 0)
