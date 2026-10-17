@tool
extends EditorExportPlugin

const ItemCatalog = preload("res://scripts/item_catalog.gd")


func _get_name() -> String:
	return "ItemCatalog"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	ItemCatalog.save_source_catalog()
	var paths := ItemCatalog.scan_source_items()
	add_file(ItemCatalog.CATALOG_PATH, JSON.stringify(Array(paths), "\t").to_utf8_buffer(), false)
	print("Item catalog: exported %d item paths" % paths.size())


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path == ItemCatalog.CATALOG_PATH:
		# The freshly generated catalog was already added in _export_begin.
		skip()
