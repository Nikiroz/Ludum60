extends RefCounted

const BossUnitData = preload("res://scripts/boss_unit.gd")

const ROBOT_SPRITES: Array[Texture2D] = [
	preload("res://sprites/robots/dummy1.png"),
	preload("res://sprites/robots/dummy2.png"),
	preload("res://sprites/robots/dummy3.png"),
	preload("res://sprites/robots/dummy4.png"),
]


static func generate_units(count: int = 3) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var sprites: Array[Texture2D] = ROBOT_SPRITES.duplicate()
	sprites.shuffle()

	for index in range(count):
		var unit := BattleUnit.new(sprites[index % sprites.size()])
		_randomize_stats(unit)
		result.append(unit)

	return result


static func generate_boss() -> BossUnitData:
	var boss := BossUnitData.new(ROBOT_SPRITES.pick_random())
	_randomize_stats(boss)
	boss.health = 9999.0
	boss.attack_sequence = [1, 2, 3, 4]
	boss.attack_sequence.shuffle()
	return boss


static func _randomize_stats(unit: BattleUnit) -> void:
	unit.health = randi_range(50, 150)
	unit.attack_speed = randf_range(0.5, 2.0)
	unit.damage = randi_range(5, 25)
	unit.crit_chance = randf_range(0.0, 1.0)
