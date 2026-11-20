@tool
extends EditorPlugin
const MENU := "LIFE CITY / Vehicle Rigging / Create Wheel Rig"
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _create_rig)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
func _create_rig() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty() or not selected[0] is Node3D:
		push_warning("Select a Node3D vehicle root first.")
		return
	var rig := Node3D.new()
	rig.name = "VehicleWheelRig"
	selected[0].add_child(rig)
	rig.owner = EditorInterface.get_edited_scene_root()
	for item in [{"name":"Wheel_FL","pos":Vector3(-1,0.4,-1.3)}, {"name":"Wheel_FR","pos":Vector3(1,0.4,-1.3)}, {"name":"Wheel_RL","pos":Vector3(-1,0.4,1.3)}, {"name":"Wheel_RR","pos":Vector3(1,0.4,1.3)}]:
		var pivot := Marker3D.new()
		pivot.name = item.name
		pivot.position = item.pos
		rig.add_child(pivot)
		pivot.owner = EditorInterface.get_edited_scene_root()
	var steering := Marker3D.new()
	steering.name = "SteeringWheelPivot"
	rig.add_child(steering)
	steering.owner = EditorInterface.get_edited_scene_root()
