extends PanelContainer

const THEME: Theme = preload("res://styles/item_tooltip.tres")
const ItemEquipment = preload("res://scripts/item_equipment.gd")
const STAT_LABELS := {
	"health": "Health",
	"attack_speed": "Attack speed",
	"damage": "Damage",
	"crit_chance": "Crit chance",
}


func _init(for_text: String = "") -> void:
	theme = THEME
	theme_type_variation = &"ItemTooltipPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 1)
	add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"ItemTooltipTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = for_text.get_slice("\n", 0)
	content.add_child(title)
	var line_break := for_text.find("\n")
	if line_break != -1:
		var properties := Label.new()
		properties.name = "Properties"
		properties.mouse_filter = Control.MOUSE_FILTER_IGNORE
		properties.text = for_text.substr(line_break + 1)
		content.add_child(properties)
	resized.connect(queue_redraw)


func _draw() -> void:
	var screen_transform := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var inset := Vector2(0.5, 0.5) / screen_transform.get_scale().abs()
	# A negative width keeps the white frame one screen pixel wide when the UI scales.
	draw_rect(Rect2(inset, size - inset * 2.0), Color.WHITE, false, -1.0)


static func get_text(item: GridInventoryItemData) -> String:
	if item == null or ItemEquipment.is_service_item(item):
		return ""
	var lines := PackedStringArray([item.display_name])
	var bonuses := item.get_stat_bonuses()
	for stat in STAT_LABELS:
		var value: float = bonuses[stat]
		if value == 0.0:
			continue
		var suffix := ""
		if stat == "crit_chance":
			value *= 100.0
			suffix = "%"
		elif stat == "attack_speed":
			suffix = "/s"
		var amount := ("%.4f" % value).rstrip("0").rstrip(".")
		if value > 0.0:
			amount = "+" + amount
		lines.append("%s: %s%s" % [STAT_LABELS[stat], amount, suffix])
	return "\n".join(lines)
