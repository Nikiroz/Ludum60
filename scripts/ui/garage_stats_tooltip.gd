extends Control

const ITEM_TOOLTIP = preload("res://scripts/ui/item_tooltip.gd")
const STAT_KEYS := ["health", "attack_speed", "damage", "crit_chance"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = ITEM_TOOLTIP.THEME


func _get_tooltip(at_position: Vector2) -> String:
	if not Rect2(Vector2.ZERO, size).has_point(at_position):
		return ""
	var row := clampi(int(at_position.y / size.y * STAT_KEYS.size()), 0, STAT_KEYS.size() - 1)
	return ITEM_TOOLTIP.STAT_LABELS[STAT_KEYS[row]]


func _make_custom_tooltip(for_text: String) -> Object:
	return null if for_text.is_empty() else ITEM_TOOLTIP.new(for_text)
