class_name BattleUnit
extends RefCounted

const UNIT_NAMES: Array[String] = ["биба", "боба", "абоба"]

var name: String = UNIT_NAMES.pick_random()
var health: float = 100.0
# Количество атак в секунду.
var attack_speed: float = 1.0
var damage: float = 0.0
# Вероятность от 0.0 до 1.0.
var crit_chance: float = 0.0
var sprite: Texture2D


func _init(p_sprite: Texture2D = null) -> void:
	sprite = p_sprite
