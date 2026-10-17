# Item pack to transfer to the game

Transfer this entire folder into the **game project root**, so the path becomes `res://item_pack/`.

- `item_data.gd`: required Godot Resource class
- `items/*.tres`: items saved from the editor
- `sprites/*.png`: sprites copied by the editor

Read an item with `load("res://item_pack/items/<id>.tres")` then its sprite with `item.get_texture()`.
