class_name GridInventoryItemData
extends Resource
## Exportable data asset for an item occupying arbitrary cells in a 3x3 grid.
## Keep the item_pack folder at res://item_pack/ when moving into the game.

enum BodyPart { NONE, HEAD, BODY, HANDS, LEGS }

@export var item_id: String = ""
@export var display_name: String = ""
@export var is_service_item: bool = false
## String path keeps the exported asset independent of the editor's texture-import state.
## Example: res://item_pack/sprites/iron_sword.png
@export_file("*.png") var sprite_path: String = ""
## NONE keeps older items compatible until their body part is selected.
@export var body_part: BodyPart = BodyPart.NONE
## Separate image displayed on the unit when this item is equipped.
## Optional for existing items; copied to res://item_pack/unit_sprites/<id>.png.
@export_file("*.png") var unit_sprite_path: String = ""
## Optional separate shadow tile for LEGS, using the main leg sprite's attachment points.
## Copied to res://item_pack/unit_sprites/shadow/<id>.png.
@export_file("*.png") var shadow_sprite_path: String = ""
## Hands use independent images; no automatic mirroring is applied.
@export_file("*.png") var left_hand_sprite_path: String = ""
@export_file("*.png") var right_hand_sprite_path: String = ""
@export var occupied_cells: Array[Vector2i] = []
@export var grid_size: Vector2i = Vector2i(3, 3)

@export_group("Attachment points")
## Integer pixel coordinates in the original unit PNG, measured from its top-left.
## HEAD/LEGS: "body". BODY: "head", "left_hand", "right_hand", "legs".
## Empty dictionaries on older items use the defaults from get_attachment_points().
@export var attachment_points: Dictionary = {}
## Each hand PNG has its own point that connects to the torso's matching socket.
## Keep these dynamically typed to read legacy normalized Vector2 values unchanged.
## New saves use Vector2i. (-1, -1) means use the sprite's default point.
@export var left_hand_attachment_point = Vector2i(-1, -1)
@export var right_hand_attachment_point = Vector2i(-1, -1)

@export_group("Stat bonuses")
## Additive modifiers. Zero means the item does not change this stat.
@export var health_bonus: float = 0.0
## Additional attacks per second, matching BattleUnit.attack_speed.
@export var attack_speed_bonus: float = 0.0
@export var damage_bonus: float = 0.0
## Probability delta: 0.15 adds 15 percentage points to the crit chance.
@export_range(-1.0, 1.0, 0.0001) var crit_chance_bonus: float = 0.0


static func default_attachment_points(part: BodyPart, sprite_size: Vector2i = Vector2i.ZERO) -> Dictionary:
	var center := Vector2i((Vector2(sprite_size) / 2.0).round())
	match part:
		BodyPart.BODY:
			# Left/right refer to a front-facing unit's own hands.
			return {"head": Vector2i(center.x, 0), "left_hand": Vector2i(sprite_size.x, center.y),
				"right_hand": Vector2i(0, center.y), "legs": Vector2i(center.x, sprite_size.y)}
		BodyPart.HEAD:
			return {"body": Vector2i(center.x, sprite_size.y)}
		BodyPart.LEGS:
			return {"body": Vector2i(center.x, 0)}
		BodyPart.HANDS:
			return {"body": center}
	return {}


## Returns Vector2i pixel points, with defaults and migration for older resources.
## For HANDS, pass "left" or "right" to select the corresponding PNG.
## Passing a known sprite size avoids loading its PNG to calculate the defaults.
func get_attachment_points(hand_side: String = "", sprite_size: Vector2i = Vector2i.ZERO) -> Dictionary:
	if sprite_size == Vector2i.ZERO:
		var path := unit_sprite_path
		if body_part == BodyPart.HANDS:
			path = left_hand_sprite_path if hand_side == "left" else right_hand_sprite_path
		if not path.is_empty() and FileAccess.file_exists(path):
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null:
				sprite_size = image.get_size()
	var result := default_attachment_points(body_part, sprite_size)
	if body_part == BodyPart.HANDS:
		if hand_side == "left":
			return {"body": _pixel_attachment_point(left_hand_attachment_point, result.body, sprite_size)}
		if hand_side == "right":
			return {"body": _pixel_attachment_point(right_hand_attachment_point, result.body, sprite_size)}
		return {}
	for point_name in result:
		result[point_name] = _pixel_attachment_point(attachment_points.get(point_name), result[point_name], sprite_size)
	return result


static func _pixel_attachment_point(value: Variant, fallback: Vector2i, sprite_size: Vector2i) -> Vector2i:
	var point := fallback
	if value is Vector2i and value != Vector2i(-1, -1):
		point = value
	elif value is Vector2:
		# Previously saved points were normalized floating-point coordinates.
		point = Vector2i((value.clamp(Vector2.ZERO, Vector2.ONE) * Vector2(sprite_size)).round())
	if sprite_size != Vector2i.ZERO:
		return point.clamp(Vector2i.ZERO, sprite_size)
	return point.max(Vector2i.ZERO)


## Keys and units match the battle unit's stats; this resource has no game dependencies.
func get_stat_bonuses() -> Dictionary:
	return {
		"health": health_bonus,
		"attack_speed": attack_speed_bonus,
		"damage": damage_bonus,
		"crit_chance": crit_chance_bonus,
	}


func occupies(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


func get_texture() -> Texture2D:
	return _load_sprite_texture(sprite_path)


func get_unit_texture() -> Texture2D:
	return _load_sprite_texture(unit_sprite_path)


func get_shadow_texture() -> Texture2D:
	if body_part != BodyPart.LEGS:
		return null
	return _load_sprite_texture(shadow_sprite_path)


## Shadow slots always follow the main leg sprite, in the same pixel coordinates.
## Pass the MAIN sprite's size, never the shadow size, when supplying a known size.
func get_shadow_attachment_points(sprite_size: Vector2i = Vector2i.ZERO) -> Dictionary:
	if body_part != BodyPart.LEGS or shadow_sprite_path.is_empty():
		return {}
	return get_attachment_points("", sprite_size)


func get_left_hand_texture() -> Texture2D:
	return _load_sprite_texture(left_hand_sprite_path)


func get_right_hand_texture() -> Texture2D:
	return _load_sprite_texture(right_hand_sprite_path)


static func _load_sprite_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	# The desktop editor saves PNGs while running, before Godot imports them.
	# Read the source first so newly saved or replaced sprites are immediately visible.
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	# Exported games may only contain the imported texture, without the source PNG.
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
