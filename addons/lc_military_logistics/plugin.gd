@tool
extends EditorPlugin

const DATA_PATH := "res://data/military/logistics.json"
const DATA_KEY := "inventory_categories"
const MINIMUM_ENTRIES := 4
const MENU_PATH := "LIFE CITY / Military / Validate Logistics Inventory"

func _enter_tree() -> void:
	add_tool_menu_item(MENU_PATH, _validate_data)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_PATH)

func _validate_data() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Military add-on data file is missing: " + DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has(DATA_KEY):
		push_error("Military add-on data has an invalid structure: " + DATA_PATH)
		return
	var entries = parsed[DATA_KEY]
	if not entries is Array or entries.size() < MINIMUM_ENTRIES:
		push_error("Military add-on data does not contain the expected entries: " + DATA_PATH)
		return
	print("LIFE CITY military add-on validated: %s (%d entries)." % [DATA_PATH, entries.size()])
