@tool
extends EditorPlugin
const MENU := "LIFE CITY / Vehicle Physics / Apply Balanced Preset"
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _apply_preset)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
func _apply_preset() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		push_warning("Select a vehicle root first.")
		return
	selected[0].set_meta("lifecity_vehicle_physics", {"acceleration":11.0,"brake_strength":24.0,"max_forward_speed":34.0,"max_reverse_speed":9.0,"steering_speed":1.65})
