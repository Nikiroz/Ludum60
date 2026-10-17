# Item catalog

The enabled editor plugin scans `res://item_pack/items/*.tres` when the editor
opens, when its filesystem changes, and before every export (including command-line
exports). A sorted JSON array is saved in `res://generated/item_catalog.json`.
The Web preset explicitly includes this saved file, so it is also bundled if an
already open editor has not yet activated the newly installed plugin. The export
hook adds a freshly scanned catalog directly to the pack.

The game loads the original resources through those paths. It does not depend
on directory listings in exported builds, where resources can become `.remap`
entries. Item resources, their format, and their sprites are never rewritten.

In the editor, the plugin refreshes the saved catalog when the filesystem changes;
if no catalog exists, the game can scan the source directory directly. No manual
catalog generation is required. Keep
**Item Catalog** enabled in Project Settings > Plugins and keep the existing
`all_resources` export filter so dynamically referenced resources and sprites
are included.
