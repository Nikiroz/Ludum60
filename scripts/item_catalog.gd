extends RefCounted

const ITEMS_DIR := "res://item_pack/items"
const CATALOG_PATH := "res://generated/item_catalog.json"


static func scan_source_items() -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(ITEMS_DIR)
	if directory == null:
		push_error("Item directory not found: " + ITEMS_DIR)
		return paths
	for file_name in directory.get_files():
		if file_name.ends_with(".tres"):
			paths.append(ITEMS_DIR.path_join(file_name))
	paths.sort()
	return paths


static func save_source_catalog() -> void:
	var contents := JSON.stringify(Array(scan_source_items()), "\t") + "\n"
	if FileAccess.file_exists(CATALOG_PATH) and FileAccess.get_file_as_string(CATALOG_PATH) == contents:
		return
	var error := DirAccess.make_dir_recursive_absolute(CATALOG_PATH.get_base_dir())
	if error != OK:
		push_error("Cannot create item catalog directory: " + error_string(error))
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save item catalog: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(contents)


static func get_item_paths() -> PackedStringArray:
	if not FileAccess.file_exists(CATALOG_PATH):
		if OS.has_feature("editor"):
			return scan_source_items()
		push_error("Item catalog missing. Enable the Item Catalog export plugin and rebuild.")
		return PackedStringArray()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Array:
		push_error("Invalid item catalog: " + CATALOG_PATH)
		return PackedStringArray()
	var paths := PackedStringArray()
	for path in data:
		if not path is String or not path.begins_with(ITEMS_DIR + "/") or not path.ends_with(".tres"):
			push_error("Invalid item path in catalog")
			return PackedStringArray()
		paths.append(path)
	return paths
