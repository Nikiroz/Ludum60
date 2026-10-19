class_name BossUnit
extends BattleUnit

const HEALTH_SPRITES: Array[Texture2D] = [
	preload("res://sprites/boss/1.png"),
	preload("res://sprites/boss/2.png"),
	preload("res://sprites/boss/3.png"),
	preload("res://sprites/boss/4.png"),
	preload("res://sprites/boss/5.png"),
]

var max_health: float = 100.0

# Номера слотов начинаются с 1. Элементы идут в порядке атак.
var attack_sequence: Array[int] = []


func get_health_sprite() -> Texture2D:
	var ratio := clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	var state := clampi(HEALTH_SPRITES.size() - ceili(ratio * HEALTH_SPRITES.size()), 0, HEALTH_SPRITES.size() - 1)
	return HEALTH_SPRITES[state]
