class_name BossUnit
extends BattleUnit

const HEALTH_SPRITES: Array[Texture2D] = [
	preload("res://sprites/boss/1.png"),
	preload("res://sprites/boss/2.png"),
	preload("res://sprites/boss/3.png"),
	preload("res://sprites/boss/4.png"),
	preload("res://sprites/boss/5.png"),
]

var max_health: float = 100.0:
	set(value):
		max_health = roundf(value)

# Номера слотов начинаются с 1. Элементы идут в порядке атак.
var attack_sequence: Array[int] = []


func _init(p_sprite: Texture2D = null) -> void:
	super(p_sprite if p_sprite != null else HEALTH_SPRITES[0])
	health = 9999.0
	max_health = health
	attack_speed = randf_range(0.5, 2.0)
	damage = randi_range(5, 25)
	crit_chance = randf_range(0.0, 1.0)
	attack_sequence.assign([1, 2, 3, 4])
	attack_sequence.shuffle()


func get_health_sprite() -> Texture2D:
	var ratio := clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	var state := clampi(HEALTH_SPRITES.size() - ceili(ratio * HEALTH_SPRITES.size()), 0, HEALTH_SPRITES.size() - 1)
	return HEALTH_SPRITES[state]
