extends Label

signal appeared

const FLOAT_DISTANCE := 24.0
const DURATION := 0.8

var float_offset := Vector2(0.0, -FLOAT_DISTANCE)
var _has_appeared := false


func animate(damage: float, critical: bool, origin: Vector2, start_delay: float = 0.0) -> void:
	text = "-%d" % roundi(damage)
	add_theme_color_override("font_color", Color.RED if critical else Color.WHITE)
	size = get_minimum_size()
	position = origin - size / 2.0
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.75
	modulate.a = 0.0
	_has_appeared = false
	var tween := create_tween()
	if start_delay > 0.0:
		tween.tween_interval(start_delay)
	tween.tween_property(self, "position", position + float_offset, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_fade_in, 0.0, 1.0, 0.06)
	tween.parallel().tween_property(self, "modulate:a", 0.0, DURATION - 0.2).from(1.0).set_delay(0.2)
	tween.tween_callback(queue_free)


func _fade_in(alpha: float) -> void:
	modulate.a = alpha
	if alpha > 0.0 and not _has_appeared:
		_has_appeared = true
		appeared.emit()
