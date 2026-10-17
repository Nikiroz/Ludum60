extends HScrollBar

@export var bus_name: StringName

var bus_index := -1


func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("Audio bus not found: " + bus_name)
		return

	value_changed.connect(_on_value_changed)
	_sync_with_bus()


func _sync_with_bus() -> void:
	if AudioServer.is_bus_mute(bus_index):
		set_value_no_signal(min_value)
		return

	var linear_volume := db_to_linear(AudioServer.get_bus_volume_db(bus_index))
	set_value_no_signal(lerpf(min_value, max_value, linear_volume))


func _on_value_changed(new_value: float) -> void:
	if bus_index == -1:
		return

	var linear_volume := inverse_lerp(min_value, max_value, new_value)
	var muted := is_zero_approx(linear_volume)
	AudioServer.set_bus_mute(bus_index, muted)

	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))
