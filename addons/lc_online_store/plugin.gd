@tool
extends EditorPlugin

const CATALOG_PATH := "res://docs/online_store/catalog.json"

func _enter_tree() -> void:
	add_tool_menu_item("LIFE CITY / Online Store / Open Commerce Guide", _open_guide)
	add_tool_menu_item("LIFE CITY / Online Store / Validate Catalog", _validate_catalog)

func _exit_tree() -> void:
	remove_tool_menu_item("LIFE CITY / Online Store / Open Commerce Guide")
	remove_tool_menu_item("LIFE CITY / Online Store / Validate Catalog")

func _open_guide() -> void:
	var guide := load("res://docs/online_store/README.md")
	if guide == null:
		push_warning("LIFE CITY Online Store guide is missing.")
		return
	print("LIFE CITY Online Store guide: res://docs/online_store/README.md")

func _validate_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Online Store catalog not found: " + CATALOG_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("categories"):
		push_error("Online Store catalog must contain a categories object.")
		return
	var item_count := 0
	for category in parsed.categories.values():
		if not category is Array:
			push_error("Every store category must be an array.")
			return
		item_count += category.size()
	print("LIFE CITY Online Store catalog valid: %d categories, %d entries." % [parsed.categories.size(), item_count])
