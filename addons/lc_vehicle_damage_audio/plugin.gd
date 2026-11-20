@tool
extends EditorPlugin
const MENU := "LIFE CITY / Vehicle Damage and Audio / Apply Feedback Profile"
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _apply_profile)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
func _apply_profile() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		push_warning("Select a vehicle root first.")
		return
	selected[0].set_meta("lifecity_vehicle_feedback", {"condition":100.0,"impact_factor":0.65,"engine_pitch_min":1.0,"engine_pitch_max":1.85,"repairable":true})
