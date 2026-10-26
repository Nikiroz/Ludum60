extends Control

signal battle_started
signal round_finished

enum State { PREPARATION, FIGHTING, VICTORY, DEFEAT }

const BossUnitData = preload("res://scripts/boss_unit.gd")
const UNIT_SLOT_SCENE: PackedScene = preload("res://scenes/ui/battle_unit_slot.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
const MIN_UNIT_SLOTS := 4
const TICK_SECONDS := 1.0
const CRIT_MULTIPLIER := 2.0
const DEBUG_CLICK_DAMAGE := 100.0

@export_range(0.0, 0.2, 0.01) var attack_animation_stagger: float = 0.08
@export var punch_sounds: Array[AudioStream] = []
@onready var _unit_slots: HBoxContainer = $MarginContainer/HBoxContainer
@onready var _boss_container: MarginContainer = $MarginContainer2
@onready var _battle_timer: Timer = $BattleTimer
@onready var _punch_players: Array[AudioStreamPlayer] = [$PunchSound1, $PunchSound2]
@onready var _damage_numbers: Control = $DamageNumbers
@onready var _escape_button: Button = $EscapeButton
@onready var _speed_button: Button = $SpeedButton
@onready var _pause_button: Button = $PauseButton

# Массив позиций на поле. null означает пустой слот.
var units: Array[BattleUnit] = []
var boss: BossUnitData
var state: State = State.PREPARATION
var tick_count := 0
var battle_speed := 1.0
var battle_log: Array[String] = []
var _attack_progress: Dictionary[BattleUnit, float] = {}
var _initial_unit_stats: Dictionary[BattleUnit, Dictionary] = {}
var _boss_pattern_index := 0
var _units_provided := false
var _boss_provided := false
var _rebuilding_slots := false
var _damage_number_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_damage_number_rng.randomize()
	_battle_timer.wait_time = TICK_SECONDS
	_battle_timer.one_shot = true
	_battle_timer.ignore_time_scale = true
	_battle_timer.timeout.connect(_on_battle_timeout)
	_unit_slots.child_order_changed.connect(_on_unit_order_changed)
	ControllerGame.debug_mode_changed.connect(_update_boss_debug_input)
	if not _units_provided:
		set_units(ControllerGame.units)
	else:
		_rebuild_unit_slots()
	if not _boss_provided:
		set_boss(BossUnitData.new())
	else:
		_rebuild_boss_slot()
	_log_event("Подготовка: юнитов %d, слотов %d, босс %s." % [
		_count_living_units(), units.size(), "готов" if boss != null else "отсутствует"
	])


func set_units(new_units: Array) -> void:
	var provided_units: Array[BattleUnit] = []
	provided_units.assign(new_units)
	_units_provided = true
	units = provided_units
	_ensure_unit_slots()
	if is_instance_valid(_unit_slots):
		_rebuild_unit_slots()


func set_boss(new_boss: BossUnitData) -> void:
	_boss_provided = true
	boss = new_boss
	if boss != null:
		boss.max_health = boss.health
	if is_instance_valid(_boss_container):
		_rebuild_boss_slot()


func add_unit(unit: BattleUnit) -> void:
	_units_provided = true
	if unit == null:
		return
	_ensure_unit_slots()
	var empty_index := units.find(null)
	if empty_index != -1:
		units[empty_index] = unit
		if is_instance_valid(_unit_slots):
			(_unit_slots.get_child(empty_index) as DraggableSlot).unit = unit
		return

	units.append(unit)
	if is_instance_valid(_unit_slots):
		_create_unit_slot(unit)


func remove_unit(unit: BattleUnit) -> void:
	_units_provided = true
	if unit == null:
		return
	var index := units.find(unit)
	if index == -1:
		return
	units[index] = null
	_attack_progress.erase(unit)
	if not is_instance_valid(_unit_slots):
		return

	var slot := _unit_slots.get_child(index) as DraggableSlot
	if DraggableSlot.active_slot == slot:
		slot._clear_drag()
	slot.unit = null


func _ensure_unit_slots() -> void:
	if units.size() < MIN_UNIT_SLOTS:
		units.resize(MIN_UNIT_SLOTS)


func _rebuild_unit_slots() -> void:
	_ensure_unit_slots()
	_rebuilding_slots = true
	for slot in _unit_slots.get_children():
		_unit_slots.remove_child(slot)
		slot.queue_free()

	for unit in units:
		_create_unit_slot(unit)
	_rebuilding_slots = false


func _create_unit_slot(unit: BattleUnit) -> void:
	var slot := UNIT_SLOT_SCENE.instantiate() as DraggableSlot
	slot.unit = unit
	slot.dragging_enabled = state == State.PREPARATION
	_unit_slots.add_child(slot)


func _rebuild_boss_slot() -> void:
	for slot in _boss_container.get_children():
		_boss_container.remove_child(slot)
		slot.queue_free()

	if boss == null:
		return

	var slot := UNIT_SLOT_SCENE.instantiate() as DraggableSlot
	slot.unit = boss
	slot.dragging_enabled = false
	_boss_container.add_child(slot)
	slot.icon.gui_input.connect(_on_boss_gui_input)
	_update_boss_debug_input()


func _update_boss_debug_input() -> void:
	for slot in _boss_container.get_children():
		slot.icon.mouse_filter = Control.MOUSE_FILTER_STOP if ControllerGame.debug_mode else Control.MOUSE_FILTER_IGNORE
		slot.icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ControllerGame.debug_mode else Control.CURSOR_ARROW


func _on_boss_gui_input(event: InputEvent) -> void:
	if not ControllerGame.debug_mode or get_tree().paused or state not in [State.PREPARATION, State.FIGHTING]:
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if boss == null or boss.health <= 0.0:
		return
	accept_event()
	boss.health = maxf(boss.health - DEBUG_CLICK_DAMAGE, 0.0)
	_find_unit_view(boss).play_hit()
	_log_event("Отладочный удар -> Босс: урон %d; осталось жизней %d." % [DEBUG_CLICK_DAMAGE, boss.health])
	if boss.health <= 0.0:
		_finish_battle(true)


func _on_unit_order_changed() -> void:
	if _rebuilding_slots or not is_inside_tree() or not _unit_slots.is_inside_tree():
		return

	units.clear()
	for slot in _unit_slots.get_children():
		if slot is DraggableSlot:
			units.append(slot.unit)
	_log_event("Расстановка изменена: %s." % _describe_formation())


func start_battle() -> bool:
	if state != State.PREPARATION:
		_log_event("Запуск отклонён: битва уже начата или закончена.")
		return false
	_remove_dead_units()
	if boss == null or boss.health <= 0.0 or _count_living_units() == 0:
		_log_event("Запуск отклонён: нужны живой босс и хотя бы один живой юнит.")
		return false

	_initial_unit_stats.clear()
	for unit in units:
		if unit != null:
			_initial_unit_stats[unit] = {
				"health": unit.health,
				"attack_speed": unit.attack_speed,
				"damage": unit.damage,
				"crit_chance": unit.crit_chance,
			}

	state = State.FIGHTING
	tick_count = 0
	_boss_pattern_index = 0
	_attack_progress.clear()
	_set_target_slot(-1)
	for slot in _unit_slots.get_children():
		(slot as DraggableSlot).dragging_enabled = false
	_log_event("Битва началась. Расстановка: %s." % _describe_formation())
	_log_event("Босс: жизни %d, урон %d, паттерн %s." % [
		boss.health, boss.damage, str(boss.attack_sequence)
	])
	for index in range(units.size()):
		var unit := units[index]
		if unit != null:
			_log_event("Слот %d: жизни %d, атак/с %.2f, урон %d, крит %.1f%%." % [
				index + 1, unit.health, unit.attack_speed, unit.damage, unit.crit_chance * 100.0
			])
	_battle_timer.start(TICK_SECONDS / battle_speed)
	_escape_button.show()
	battle_started.emit()
	return true


func _on_escape_pressed() -> void:
	if Transition.transitioning or ControllerGame.menu_paused or not _escape_button.visible:
		return
	if state == State.FIGHTING:
		_finish_battle(false, "отряд покинул поле боя")
	_battle_timer.stop()
	ControllerGame.gameplay_paused = false
	_play_control_click()
	Transition.change_scene("res://scenes/garage.tscn")


func _on_speed_pressed() -> void:
	if Transition.transitioning or ControllerGame.menu_paused:
		return
	var previous_speed := battle_speed
	battle_speed = 3.0 if battle_speed == 1.0 else 1.0
	if not _battle_timer.is_stopped():
		# Preserve progress through the current tick when switching speeds.
		_battle_timer.start(maxf(_battle_timer.time_left * previous_speed / battle_speed, 0.000001))
	_speed_button.set_pressed_no_signal(battle_speed == 3.0)
	_play_control_click()


func _on_pause_pressed() -> void:
	if Transition.transitioning or ControllerGame.menu_paused:
		return
	ControllerGame.gameplay_paused = not ControllerGame.gameplay_paused
	_pause_button.set_pressed_no_signal(ControllerGame.gameplay_paused)
	_play_control_click()


func _play_control_click() -> void:
	ControllerGame.play_one_shot(preload("uid://21gf6qfxd331"))


func _on_battle_timeout() -> void:
	_on_battle_tick()
	if state == State.FIGHTING:
		_battle_timer.start(TICK_SECONDS / battle_speed)


func _on_battle_tick() -> void:
	if state != State.FIGHTING:
		return
	tick_count += 1
	_log_event("Тик начался.")
	_remove_dead_units()
	if boss == null or boss.health <= 0.0:
		_finish_battle(true)
		return
	if _count_living_units() == 0:
		_finish_battle(false)
		return

	for index in range(units.size()):
		var unit := units[index]
		if unit == null:
			continue
		var progress: float = _attack_progress.get(unit, 0.0)
		progress += maxf(unit.attack_speed, 0.0) * TICK_SECONDS
		var attack_count := floori(progress + 0.000001)
		_attack_progress[unit] = maxf(progress - attack_count, 0.0)
		if attack_count == 0:
			_log_event("Слот %d копит атаку: %.2f/1." % [index + 1, progress])
		for attack in range(attack_count):
			_deal_attack(unit, boss, "Слот %d (%s)" % [index + 1, unit.name], "Босс")
			if boss.health <= 0.0:
				_log_event("Босс погиб.")
				_finish_battle(true)
				return

	_boss_attack()
	if _count_living_units() == 0:
		_finish_battle(false)


func _boss_attack() -> void:
	if boss.attack_sequence.is_empty():
		_set_target_slot(-1)
		_log_event("Босс пропускает атаку: паттерн пуст.")
		return

	var slot_number := boss.attack_sequence[_boss_pattern_index % boss.attack_sequence.size()]
	_boss_pattern_index = (_boss_pattern_index + 1) % boss.attack_sequence.size()
	var index := slot_number - 1
	if index < 0 or index >= units.size():
		_set_target_slot(-1)
		_log_event("Босс пропускает атаку: слота %d не существует." % slot_number)
		return

	_set_target_slot(index)
	var target := units[index]
	if target == null:
		_play_attack_animation(boss)
		_log_event("Босс атакует пустой слот %d: промах." % slot_number)
		return
	_deal_attack(boss, target, "Босс", "Слот %d" % slot_number)
	_remove_dead_units()


func _deal_attack(attacker: BattleUnit, target: BattleUnit, attacker_name: String, target_name: String) -> void:
	var critical := randf() < clampf(attacker.crit_chance, 0.0, 1.0)
	var damage := roundf(maxf(attacker.damage, 0.0) * (CRIT_MULTIPLIER if critical else 1.0))
	var impact_delay := _play_attack_animation(attacker)
	if damage > 0.0:
		var target_slot := _find_unit_view(target)
		if target_slot != null:
			target_slot.play_hit(impact_delay)
			_show_damage_number(target_slot, damage, critical, impact_delay)
	target.health = maxf(target.health - damage, 0.0)
	_log_event("%s -> %s: урон %d%s; осталось жизней %d." % [
		attacker_name, target_name, damage, " (КРИТ x2)" if critical else "", target.health
	])


func _show_damage_number(target_slot: DraggableSlot, damage: float, critical: bool, impact_delay: float) -> void:
	var origin := _damage_numbers.get_global_transform().affine_inverse() * target_slot.get_damage_number_position()
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	if target_slot.unit is BossUnitData:
		origin += Vector2(_damage_number_rng.randf_range(-36.0, 36.0), _damage_number_rng.randf_range(-18.0, 18.0))
		number.float_offset = Vector2(_damage_number_rng.randf_range(-14.0, 14.0), -_damage_number_rng.randf_range(24.0, 36.0))
	_damage_numbers.add_child(number)
	number.appeared.connect(_play_punch_sound)
	number.animate(damage, critical, origin, impact_delay)


func _play_punch_sound() -> void:
	if punch_sounds.is_empty():
		return
	for player in _punch_players:
		if not player.playing:
			player.stream = punch_sounds.pick_random()
			player.play()
			return


func _find_unit_view(unit: BattleUnit) -> DraggableSlot:
	for slot in _unit_slots.get_children():
		if slot is DraggableSlot and slot.unit == unit:
			return slot
	for slot in _boss_container.get_children():
		if slot is DraggableSlot and slot.unit == unit:
			return slot
	return null


func _play_attack_animation(attacker: BattleUnit) -> float:
	var slot := _find_unit_view(attacker)
	if slot != null:
		var order := units.size() if attacker == boss else slot.get_index()
		# Даже большой отряд начинает все рывки в пределах одного тика.
		var stagger := minf(attack_animation_stagger, 0.35 / maxi(units.size(), 1))
		return slot.play_attack(
			Vector2.LEFT if attacker == boss else Vector2.RIGHT, order * stagger
		)
	return 0.0


func _remove_dead_units() -> void:
	for index in range(units.size()):
		var unit := units[index]
		if unit != null and unit.health <= 0.0:
			_log_event("Слот %d: юнит погиб и удалён с поля." % (index + 1))
			remove_unit(unit)


func _count_living_units() -> int:
	var count := 0
	for unit in units:
		if unit != null and unit.health > 0.0:
			count += 1
	return count


func _set_target_slot(index: int) -> void:
	for slot_index in range(_unit_slots.get_child_count()):
		(_unit_slots.get_child(slot_index) as DraggableSlot).set_targeted(slot_index == index)


func _finish_battle(victory: bool, defeat_reason: String = "все юниты погибли") -> void:
	_battle_timer.stop()
	ControllerGame.gameplay_paused = false
	_pause_button.set_pressed_no_signal(false)
	state = State.VICTORY if victory else State.DEFEAT
	_set_target_slot(-1)
	if boss != null and boss.health <= 0.0:
		_rebuild_boss_slot()
	_log_event("ПОБЕДА: босс повержен." if victory else "ПОРАЖЕНИЕ: %s." % defeat_reason)
	if victory:
		ControllerGame.play_one_shot(preload("uid://bnimep0a8hcls"))
	else:
		ControllerGame.play_one_shot(preload("uid://b4mfanx6w5yup"))
	_restore_unit_stats()
	round_finished.emit()
	if victory:
		ControllerGame.show_victory_dialog()


func _restore_unit_stats() -> void:
	for unit in _initial_unit_stats:
		var stats: Dictionary = _initial_unit_stats[unit]
		unit.health = stats.health
		unit.attack_speed = stats.attack_speed
		unit.damage = stats.damage
		unit.crit_chance = stats.crit_chance
	_initial_unit_stats.clear()


func _describe_formation() -> String:
	var formation: PackedStringArray = []
	for index in range(units.size()):
		var unit := units[index]
		formation.append("%d:%s" % [
			index + 1, "пусто" if unit == null else str(unit.get_instance_id())
		])
	return " ".join(formation)


func _log_event(message: String) -> void:
	var entry := "[Battle][тик %d] %s" % [tick_count, message]
	battle_log.append(entry)
	print(entry)


func _exit_tree() -> void:
	ControllerGame.gameplay_paused = false
	if state == State.FIGHTING:
		_log_event("Битва прервана: выход с экрана.")
		_restore_unit_stats()
	if is_instance_valid(_battle_timer):
		_battle_timer.stop()
