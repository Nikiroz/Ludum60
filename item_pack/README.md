# Item pack to transfer to the game

Transfer this entire folder into the **game project root**, so the path becomes `res://item_pack/`.

- `item_data.gd`: required Godot Resource class; update the game copy to support stat bonuses
- `items/*.tres`: items saved from the editor
- `sprites/*.png`: sprites copied by the editor

Read an item with `load("res://item_pack/items/<id>.tres")` then its sprite with `item.get_texture()`.

Stat modifiers: `health_bonus`, `attack_speed_bonus` (attacks/sec), `damage_bonus`, `crit_chance_bonus` (probability delta, e.g. `0.15` for +15 percentage points). All default to zero and can be negative. `item.get_stat_bonuses()` returns a dictionary keyed by `health`, `attack_speed`, `damage`, `crit_chance`. The game is responsible for applying the modifiers to base stats and clamping the final values.
