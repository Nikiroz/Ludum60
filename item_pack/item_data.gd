class_name GridInventoryItemData
extends Resource
## Exportable data asset for an item occupying arbitrary cells in a 3x3 grid.
## Keep the item_pack folder at res://item_pack/ when moving into the game.

@export var item_id: String = ""
@export var display_name: String = ""
## String path keeps the exported asset independent of the editor's texture-import state.
## Example: res://item_pack/sprites/iron_sword.png
@export_file("*.png") var sprite_path: String = ""
@export var occupied_cells: Array[Vector2i] = []
@export var grid_size: Vector2i = Vector2i(3, 3)


func occupies(cell: Vector2i) -> bool:
    return occupied_cells.has(cell)


func get_texture() -> Texture2D:
    if sprite_path.is_empty():
        return null
    return load(sprite_path) as Texture2D
