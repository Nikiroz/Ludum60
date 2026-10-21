# Item pack to transfer to the game

Transfer this entire folder into the **game project root**, so the path becomes `res://item_pack/`.

- `item_data.gd`: required Godot Resource class; update the game copy to support stat bonuses, body parts, equipment images and attachment points
- `items/*.tres`: items saved from the editor
- `sprites/*.png`: sprites copied by the editor
- `unit_sprites/*.png`: optional images displayed on the unit when equipped
- `unit_sprites/left_hand/*.png`, `unit_sprites/right_hand/*.png`: separate images for the unit's left and right hands

Read an item with `load("res://item_pack/items/<id>.tres")` then its sprite with `item.get_texture()`.

`body_part` uses `GridInventoryItemData.BodyPart`: `NONE`, `HEAD`, `BODY`, `HANDS`, `LEGS`. Old items default to `NONE`.

Head, body and leg images use `unit_sprite_path` / `get_unit_texture()`. Hands use `left_hand_sprite_path` / `get_left_hand_texture()` and `right_hand_sprite_path` / `get_right_hand_texture()`. Missing images return `null`. Left/right refer to the unit's own hands; the editor does not mirror images. Keep every sprite subfolder when transferring items. The game assigns the textures to the appropriate equipment sprites.

Attachment points use integer `Vector2i` pixel coordinates in the original equipment PNG: `(0, 0)` top-left, `(width, height)` bottom-right edge. `attachment_points` contains `"body"` for a head/leg or `"head"`, `"left_hand"`, `"right_hand"`, `"legs"` for a torso. Hand images each have one point in `left_hand_attachment_point` / `right_hand_attachment_point`; `Vector2i(-1, -1)` means unset. Read pixel points with `item.get_attachment_points()`, or pass `"left"` / `"right"` for hands. This method supplies defaults for missing points and migrates old normalized `Vector2` values to rounded pixels using the PNG size. New saves write `Vector2i`. The game aligns each part's `"body"` point with the corresponding torso socket, accounting for sprite transforms.

Stat modifiers: `health_bonus`, `attack_speed_bonus` (attacks/sec), `damage_bonus`, `crit_chance_bonus` (probability delta, e.g. `0.15` for +15 percentage points). All default to zero and can be negative. `item.get_stat_bonuses()` returns a dictionary keyed by `health`, `attack_speed`, `damage`, `crit_chance`. The game is responsible for applying the modifiers to base stats and clamping the final values.
