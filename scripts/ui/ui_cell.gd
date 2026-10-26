class_name FieldCell
extends TextureRect

signal cell_clicked(cell: FieldCell)

const SCRAP_TEXTURES: Array[Texture2D] = [
	preload("res://sprites/bg/scrap1.png"),
	preload("res://sprites/bg/scrap2.png"),
	preload("res://sprites/bg/scrap3.png"),
]
const FADE_DURATION := 0.16
const DEBRIS_LIFETIME := 0.4
const CLICK_SHAKE_DURATION := 0.1
const CLICK_SHAKE_DISTANCE := 0.6

static var _debris_palettes: Dictionary[Texture2D, Gradient] = {}

@export_range(1, 20, 1) var clicks_required: int = 1

var clicks_left: int
var _fade_tween: Tween
var _shake_tween: Tween
var _cell_visual: TextureRect


func _ready() -> void:
	texture = SCRAP_TEXTURES.pick_random()
	# Animate the picture independently of the grid layout and click area.
	_cell_visual = TextureRect.new()
	_cell_visual.name = "CellVisual"
	_cell_visual.texture = texture
	_cell_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cell_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cell_visual)
	_cell_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self_modulate.a = 0.0
	set_clicks_required(clicks_required)


func set_clicks_required(amount: int) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	if is_instance_valid(_cell_visual):
		_cell_visual.position = Vector2.ZERO
	clicks_required = maxi(amount, 1)
	clicks_left = clicks_required
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hit()
			accept_event()


func hit() -> void:
	if clicks_left <= 0:
		return

	clicks_left -= 1

	var opacity := float(clicks_left) / float(clicks_required)
	if clicks_required == 2 and clicks_left == 1:
		opacity = 0.55
	if is_inside_tree():
		_emit_debris()
		_shake_cell()
		_fade_to(opacity)
	else:
		modulate.a = opacity

	if clicks_left == 0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_clicked.emit(self)


func _shake_cell() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	# Hold a full-pixel kick so it stays visible at ordinary frame rates.
	var distance := maxf(1.0, roundf(CLICK_SHAKE_DISTANCE))
	_cell_visual.position = Vector2(0.0, -distance)
	_shake_tween = create_tween()
	_shake_tween.tween_interval(CLICK_SHAKE_DURATION * 0.2)
	_shake_tween.tween_property(_cell_visual, "position:y", distance, CLICK_SHAKE_DURATION * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(_cell_visual, "position:y", 0.0, CLICK_SHAKE_DURATION * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fade_to(opacity: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if is_zero_approx(opacity):
		_fade_tween.tween_interval(CLICK_SHAKE_DURATION)
	_fade_tween.tween_property(self, "modulate:a", opacity, FADE_DURATION)


func _emit_debris() -> void:
	var debris := CPUParticles2D.new()
	debris.name = "CellDebris"
	debris.emitting = false
	debris.amount = 10
	debris.lifetime = DEBRIS_LIFETIME
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.direction = Vector2.UP
	debris.spread = 80.0
	debris.initial_velocity_min = 18.0
	debris.initial_velocity_max = 42.0
	debris.gravity = Vector2(0.0, 100.0)
	debris.scale_amount_min = 1.0
	debris.scale_amount_max = 2.0
	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	debris.emission_rect_extents = size * 0.25
	debris.color_initial_ramp = _get_debris_palette()
	debris.color = Color(modulate.r, modulate.g, modulate.b, 1.0)
	var fade := Gradient.new()
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.6, Color.WHITE)
	debris.color_ramp = fade
	debris.z_index = z_index + 1
	debris.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	debris.finished.connect(debris.queue_free)
	# Sibling particles stay visible when the clicked cell becomes transparent.
	get_parent().add_child(debris)
	debris.position = position + size * 0.5
	debris.emitting = true


func _get_debris_palette() -> Gradient:
	if _debris_palettes.has(texture):
		return _debris_palettes[texture]
	var image := texture.get_image()
	var background := image.get_pixel(0, 0)
	var colors := PackedColorArray()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0 and color != background and not colors.has(color):
				colors.append(color)
	if colors.is_empty():
		colors.append(background)
	# Repeat the last color so every palette entry occupies a full gradient segment.
	colors.append(colors[-1])
	var palette := Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.colors = colors
	var offsets := PackedFloat32Array()
	for index in colors.size():
		offsets.append(float(index) / float(colors.size() - 1))
	palette.offsets = offsets
	_debris_palettes[texture] = palette
	return palette
