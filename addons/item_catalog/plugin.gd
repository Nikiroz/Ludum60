@tool
extends EditorPlugin

const CatalogExport = preload("res://addons/item_catalog/export_plugin.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
var catalog_export: EditorExportPlugin


func _enter_tree() -> void:
	catalog_export = CatalogExport.new()
	add_export_plugin(catalog_export)
	ItemCatalog.save_source_catalog()
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_refresh_catalog)


func _exit_tree() -> void:
	get_editor_interface().get_resource_filesystem().filesystem_changed.disconnect(_refresh_catalog)
	remove_export_plugin(catalog_export)
	catalog_export = null


func _refresh_catalog() -> void:
	ItemCatalog.save_source_catalog()
