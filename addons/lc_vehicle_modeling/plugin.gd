@tool
extends EditorPlugin
const MENU := "LIFE CITY / Vehicle Modeling / Create Model Root"
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _create_model_root)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
func _create_model_root() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty() or not selected[0] is Node3D:
		push_warning("Select a Node3D vehicle root first.")
		return
	var root := Node3D.new()
	root.name = "VehicleModelRoot"
	root.set_meta("lifecity_vehicle_profile", {"name":"دنا", "wheelbase":2.64, "scale":1.0})
	selected[0].add_child(root)
	root.owner = EditorInterface.get_edited_scene_root()
