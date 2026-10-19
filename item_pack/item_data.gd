class_name GridInventoryItemData
extends Resource
## Exportable data asset for an item occupying arbitrary cells in a 3x3 grid.
## Keep the item_pack folder at res://item_pack/ when moving into the game.

@export var item_id: String = ""
@export var display_name: String = ""
## Built-in equipment: excluded from scrapyard loot and discarded when replaced.
@export var is_service_item: bool = false
## String path keeps the exported asset independent of the editor's texture-import state.
## Example: res://item_pack/sprites/iron_sword.png
@export_file("*.png") var sprite_path: String = ""
## Optional texture path for the robot preview, displayed at its original pixel size.
@export_file("*.png") var unit_sprite_path: String = ""
@export var occupied_cells: Array[Vector2i] = []
@export var grid_size: Vector2i = Vector2i(3, 3)

@export_group("Stat bonuses")
## Additive modifiers. Zero means the item does not change this stat.
@export var health_bonus: float = 0.0
## Additional attacks per second, matching BattleUnit.attack_speed.
@export var attack_speed_bonus: float = 0.0
@export var damage_bonus: float = 0.0
## Probability delta: 0.15 adds 15 percentage points to the crit chance.
@export_range(-1.0, 1.0, 0.0001) var crit_chance_bonus: float = 0.0


## Keys and units match the battle unit's stats; this resource has no game dependencies.
func get_stat_bonuses() -> Dictionary:
    return {
        "health": health_bonus,
        "attack_speed": attack_speed_bonus,
        "damage": damage_bonus,
        "crit_chance": crit_chance_bonus,
    }


func get_equipment_slot(left_hand: bool = true) -> StringName:
    match item_id.get_slice("_", 0):
        "head":
            return &"head"
        "base":
            return &"torso"
        "leg":
            return &"legs"
        "hand":
            return &"left_hand" if left_hand else &"right_hand"
    return &""


func occupies(cell: Vector2i) -> bool:
    return occupied_cells.has(cell)


func get_texture() -> Texture2D:
    if sprite_path.is_empty():
        return null
    return load(sprite_path) as Texture2D


func get_unit_texture() -> Texture2D:
    if not unit_sprite_path.is_empty() and ResourceLoader.exists(unit_sprite_path):
        return load(unit_sprite_path) as Texture2D
    return get_texture()
