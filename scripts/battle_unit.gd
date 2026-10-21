class_name BattleUnit
extends RefCounted

signal equipment_changed

const UNIT_NAMES: Array[String] = ["Wally", "Mike", "Cost"]
const BASIC_TORSO: GridInventoryItemData = preload("res://item_pack/items/base_basic.tres")
const BASIC_LEGS: GridInventoryItemData = preload("res://item_pack/items/leg_basic.tres")

var name: String = UNIT_NAMES.pick_random()
var health: float = 100.0:
	set(value):
		health = roundf(value)
# Количество атак в секунду.
var attack_speed: float = 1.0
var damage: float = 0.0:
	set(value):
		damage = roundf(value)
# Вероятность от 0.0 до 1.0.
var crit_chance: float = 0.0
var sprite: Texture2D
var equipment: Dictionary[StringName, GridInventoryItemData] = {}


func _init(p_sprite: Texture2D = null) -> void:
	sprite = p_sprite
	equip_item(BASIC_TORSO.duplicate(true) as GridInventoryItemData, &"torso")
	equip_item(BASIC_LEGS.duplicate(true) as GridInventoryItemData, &"legs")


func equip_item(item: GridInventoryItemData, slot: StringName) -> GridInventoryItemData:
	var previous: GridInventoryItemData = equipment.get(slot)
	if previous != null:
		_apply_item_bonuses(previous, -1.0)
	equipment[slot] = item
	_apply_item_bonuses(item, 1.0)
	equipment_changed.emit()
	return previous


func _apply_item_bonuses(item: GridInventoryItemData, multiplier: float) -> void:
	# Round each bonus before applying/removing it so equipment remains reversible.
	health += roundf(item.health_bonus) * multiplier
	attack_speed += item.attack_speed_bonus * multiplier
	damage += roundf(item.damage_bonus) * multiplier
	crit_chance += item.crit_chance_bonus * multiplier


func unequip_item(slot: StringName) -> GridInventoryItemData:
	var item: GridInventoryItemData = equipment.get(slot)
	if item == null or item.is_service_item:
		return null
	match slot:
		&"torso":
			return equip_item(BASIC_TORSO.duplicate(true) as GridInventoryItemData, slot)
		&"legs":
			return equip_item(BASIC_LEGS.duplicate(true) as GridInventoryItemData, slot)
	equipment.erase(slot)
	_apply_item_bonuses(item, -1.0)
	equipment_changed.emit()
	return item
