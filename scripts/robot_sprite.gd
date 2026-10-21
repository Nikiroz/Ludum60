
class_name DraggableSlot
extends Control

const BossUnitData = preload("res://scripts/boss_unit.gd")
const EquipmentPreview = preload("res://scripts/ui/robot_equipment_preview.gd")
const DebugStats = preload("res://scripts/ui/robot_debug_stats.gd")

var dragging_enabled := true:
	set(value):
		if dragging_enabled and not value and unit != null:
			_maximum_health = maxf(unit.health, 0.0)
		dragging_enabled = value
		if not value and active_slot == self:
			_clear_drag()

@export_group("Animation")
@export_range(0.05, 0.5, 0.01)
var shift_duration: float = 0.2
@export var attack_distance: float = 6.0
@export var attack_dash_duration: float = 0.06
@export var attack_return_duration: float = 0.14
@export var hit_shake_distance: float = 1.5
@export var hit_shake_duration: float = 0.18

@export_group("Cursors")
@export var cursor_drag: Texture2D = preload("res://sprites/cursors/cursor_drag.png")
@export var cursor_hotspot := Vector2.ZERO

@onready var _combat_motion: Control = $CombatMotion
@onready var _boss_shadow: TextureRect = $CombatMotion/BossShadow
@onready var icon: TextureRect = $CombatMotion/Icon
@onready var equipment_preview: Control = $CombatMotion/Icon/EquipmentPreview
@onready var _icon_rest_position: Vector2 = icon.position
@onready var health_bar: ProgressBar = $CombatMotion/Icon/HealthBar
@onready var health_label: Label = $CombatMotion/Icon/HealthBar/Value
@onready var name_label: Label = $CombatMotion/Icon/HealthBar/RobotName
@onready var target_arrow: TextureRect = $TargetArrow

var unit: BattleUnit:
	set(value):
		if unit != value:
			if active_slot == self:
				_clear_drag()
			_reset_combat_animation()
			_maximum_health = maxf(value.health, 0.0) if value != null else 0.0
		unit = value
		if is_instance_valid(icon):
			_update_appearance()
		_update_health()

static var active_slot: DraggableSlot = null

var _preview_layer: CanvasLayer
var _preview: TextureRect
var _preview_equipment: Control
var _preview_health_bar: ProgressBar
var _preview_health_label: Label
var _boss_debug_stats: Label
var _maximum_health := 0.0
var _drag_cursor: TextureRect

var _original_index: int
var _saved_alpha: float

var _shift_tween: Tween
var _waiting_for_sort := false
var _attack_tween: Tween
var _hit_tween: Tween
var _attack_offset := Vector2.ZERO:
	set(value):
		_attack_offset = value
		_update_combat_motion()
var _hit_offset := Vector2.ZERO:
	set(value):
		_hit_offset = value
		_update_combat_motion()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_debug_stats = DebugStats.new()
	_boss_debug_stats.name = "DebugStats"
	icon.add_child(_boss_debug_stats)
	_boss_debug_stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_update_appearance()

	_update_health()


func _update_appearance() -> void:
	var assembled := unit != null and not unit is BossUnitData
	_boss_shadow.visible = unit is BossUnitData
	_boss_shadow.position += Vector2(3, -2)
	_boss_debug_stats.unit = unit if unit is BossUnitData else null
	equipment_preview.unit = unit if assembled else null
	equipment_preview.visible = assembled
	if unit == null:
		icon.texture = null
	elif unit is BossUnitData:
		icon.texture = unit.get_health_sprite()
		# Исходный размер, центр по горизонтали и та же линия пола, что у сборки робота.
		var sprite_size := icon.texture.get_size()
		var floor_offset := 50.0 + equipment_preview.offset_bottom
		icon.offset_left = -sprite_size.x / 2.0
		icon.offset_right = sprite_size.x / 2.0
		icon.offset_top = floor_offset - sprite_size.y
		icon.offset_bottom = floor_offset
		_icon_rest_position = icon.position
	else:
		icon.texture = null if assembled else unit.sprite


func _update_health() -> void:
	if not is_instance_valid(health_bar):
		return

	health_bar.visible = unit != null and active_slot != self
	name_label.visible = unit != null and not unit is BossUnitData
	name_label.text = unit.name if name_label.visible else ""
	if unit == null:
		return

	if unit is BossUnitData:
		_maximum_health = maxf(unit.max_health, 0.0)
	elif dragging_enabled:
		_maximum_health = maxf(unit.health, 0.0)
	health_bar.max_value = _maximum_health if _maximum_health > 0.0 else 1.0
	health_bar.value = maxf(unit.health, 0.0)
	health_label.text = str(roundi(maxf(unit.health, 0.0)))
	var sprite_top := 0.0
	if equipment_preview.visible:
		sprite_top = icon.size.y
		for layer in equipment_preview.get_children():
			if layer is Sprite2D and layer.visible:
				sprite_top = minf(sprite_top, equipment_preview.position.y + layer.position.y)
	health_bar.position.y = floorf(sprite_top) - health_bar.size.y - 2.0
	if is_instance_valid(_preview_health_bar):
		_preview_health_bar.max_value = health_bar.max_value
		_preview_health_bar.value = health_bar.value
		_preview_health_bar.position = health_bar.position
		_preview_health_label.text = health_label.text
		var preview_name: Label = _preview_health_bar.get_node("RobotName")
		preview_name.text = name_label.text
		preview_name.visible = name_label.visible

func _gui_input(event: InputEvent) -> void:
	if not dragging_enabled or unit == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if active_slot == null:
				_start_drag()
				accept_event()

func _start_drag() -> void:
	if not dragging_enabled or unit == null or not get_parent() is HBoxContainer:
		return

	_reset_combat_animation()
	_update_health()
	active_slot = self
	_original_index = get_index()
	_saved_alpha = icon.modulate.a

	if _shift_tween and _shift_tween.is_running():
		_shift_tween.kill()

	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 100
	get_tree().root.add_child(_preview_layer)

	_preview = TextureRect.new()
	_preview.texture = icon.texture
	_preview.size = icon.size
	_preview.expand_mode = icon.expand_mode
	_preview.stretch_mode = icon.stretch_mode
	_preview.texture_filter = icon.texture_filter
	_preview.modulate = icon.modulate
	_preview.self_modulate = icon.self_modulate
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_preview_layer.add_child(_preview)

	if equipment_preview.visible:
		_preview_equipment = EquipmentPreview.new()
		_preview_equipment.align_to_bottom = equipment_preview.align_to_bottom
		_preview_equipment.show_shadow = equipment_preview.show_shadow
		_preview_equipment.unit = unit
		_preview.add_child(_preview_equipment)
		_preview_equipment.position = equipment_preview.position
		_preview_equipment.size = equipment_preview.size

	_preview_health_bar = health_bar.duplicate() as ProgressBar
	_preview.add_child(_preview_health_bar)
	_preview_health_label = _preview_health_bar.get_node("Value") as Label
	_preview_health_bar.show()
	health_bar.hide()

	_drag_cursor = TextureRect.new()
	_drag_cursor.texture = cursor_drag
	_drag_cursor.size = cursor_drag.get_size()
	_drag_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_layer.add_child(_drag_cursor)

	icon.modulate.a = 0.0

	ControllerGame.set_drag_cursor(true)

	set_process(true)
	_update_preview()

func _process(_delta: float) -> void:
	if unit is BossUnitData:
		icon.texture = unit.get_health_sprite()
	_update_health()
	if active_slot != self:
		return

	_update_preview()
	_update_reorder()


func _update_preview() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if is_instance_valid(_preview):
		_preview.position = mouse_pos - _preview.size / 2.0

	if is_instance_valid(_drag_cursor):
		_drag_cursor.position = mouse_pos - cursor_hotspot

func _update_reorder() -> void:
	if not dragging_enabled or _waiting_for_sort:
		return

	var row: HBoxContainer = get_parent() as HBoxContainer

	if row == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()

	if not row.get_global_rect().has_point(mouse_pos):
		return

	var new_index := 0

	for child in row.get_children():
		if child == self:
			continue

		if child is DraggableSlot:
			var center_x: float = child.get_global_rect().get_center().x

			if mouse_pos.x > center_x:
				new_index += 1

	if new_index != get_index():
		_animate_reorder(new_index)

func _animate_reorder(new_index: int) -> void:
	var row: HBoxContainer = get_parent() as HBoxContainer

	if not dragging_enabled or row == null or _waiting_for_sort:
		return

	_waiting_for_sort = true

	var old_positions: Dictionary = {}

	for child in row.get_children():
		if child is DraggableSlot and child != self:
			var slot: DraggableSlot = child
			old_positions[slot] = slot.icon.global_position

	row.sort_children.connect(
		func() -> void:
			for child in row.get_children():
				if child is DraggableSlot and child != self:
					var slot: DraggableSlot = child

					if old_positions.has(slot):
						var old_pos: Vector2 = old_positions[slot]
						slot._animate_from(old_pos)

			_waiting_for_sort = false,
		CONNECT_ONE_SHOT
	)

	row.move_child(self, new_index)

func _animate_from(old_global_pos: Vector2) -> void:

	if _shift_tween and _shift_tween.is_running():
		_shift_tween.kill()

	icon.position = (
		_combat_motion.get_global_transform().affine_inverse() * old_global_pos
	)

	_shift_tween = create_tween()
	_shift_tween.set_trans(Tween.TRANS_CUBIC)
	_shift_tween.set_ease(Tween.EASE_OUT)

	_shift_tween.tween_property(
		icon,
		"position",
		_icon_rest_position,
		shift_duration
	)

func _input(event: InputEvent) -> void:
	if active_slot != self:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag()


func _finish_drag() -> void:
	var row: HBoxContainer = get_parent() as HBoxContainer

	if row != null:
		var mouse_pos: Vector2 = get_global_mouse_position()

		if not row.get_global_rect().has_point(mouse_pos):
			if not _waiting_for_sort:
				_animate_reorder(_original_index)

	_clear_drag()

func _clear_drag() -> void:
	icon.modulate.a = _saved_alpha

	if is_instance_valid(_preview_layer):
		_preview_layer.queue_free()

	_preview_layer = null
	_preview = null
	_preview_equipment = null
	_preview_health_bar = null
	_preview_health_label = null

	active_slot = null
	_update_health()

	ControllerGame.set_drag_cursor(false)
	_drag_cursor = null

func _exit_tree() -> void:
	_reset_combat_animation()
	if active_slot == self:
		_clear_drag()


func set_targeted(targeted: bool) -> void:
	target_arrow.visible = targeted


func get_damage_number_position() -> Vector2:
	if equipment_preview.visible:
		var bounds := Rect2()
		var has_parts := false
		for layer in equipment_preview.get_children():
			if layer is Sprite2D and layer.visible:
				var part: Rect2 = layer.get_global_transform() * layer.get_rect()
				bounds = bounds.merge(part) if has_parts else part
				has_parts = true
		if has_parts:
			return bounds.get_center()
	return icon.get_global_rect().get_center()


func play_attack(direction: Vector2, start_delay: float = 0.0) -> float:
	if unit == null:
		return 0.0
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_offset = Vector2.ZERO
	var delay := maxf(start_delay, 0.0)
	_attack_tween = create_tween()
	if delay > 0.0:
		_attack_tween.tween_interval(delay)
	_attack_tween.tween_property(
		self, "_attack_offset", direction.normalized() * attack_distance, attack_dash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(
		self, "_attack_offset", Vector2.ZERO, attack_return_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return delay + attack_dash_duration


func play_hit(start_delay: float = 0.0) -> void:
	if unit == null:
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_offset = Vector2.ZERO
	_hit_tween = create_tween()
	if start_delay > 0.0:
		_hit_tween.tween_interval(start_delay)
	var offsets: Array[Vector2] = [
		Vector2(1.0, 0.0), Vector2(-1.0, 0.5),
		Vector2(0.7, -0.5), Vector2(-0.4, 0.0), Vector2.ZERO,
	]
	for offset in offsets:
		_hit_tween.tween_property(
			self, "_hit_offset", offset * hit_shake_distance, hit_shake_duration / offsets.size()
		)


func _update_combat_motion() -> void:
	if is_instance_valid(_combat_motion):
		_combat_motion.position = _attack_offset + _hit_offset


func _reset_combat_animation() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_attack_tween = null
	_hit_tween = null
	_attack_offset = Vector2.ZERO
	_hit_offset = Vector2.ZERO
