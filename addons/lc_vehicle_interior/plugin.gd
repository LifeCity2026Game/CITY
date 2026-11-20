@tool
extends EditorPlugin
const MENU := "LIFE CITY / Vehicle Interior / Create Cabin Anchors"
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _create_cabin)
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
func _create_cabin() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty() or not selected[0] is Node3D:
		push_warning("Select a Node3D vehicle root first.")
		return
	var cabin := Node3D.new()
	cabin.name = "CabinInteriorAnchors"
	selected[0].add_child(cabin)
	cabin.owner = EditorInterface.get_edited_scene_root()
	for item in [{"name":"DriverSeat","pos":Vector3(-0.42,0.9,0.25)}, {"name":"PassengerSeat","pos":Vector3(0.42,0.9,0.25)}, {"name":"RearSeatLeft","pos":Vector3(-0.42,0.9,1.15)}, {"name":"RearSeatRight","pos":Vector3(0.42,0.9,1.15)}, {"name":"Dashboard","pos":Vector3(0,1.25,-0.75)}, {"name":"CenterConsole","pos":Vector3(0,0.95,0)}]:
		var anchor := Marker3D.new()
		anchor.name = item.name
		anchor.position = item.pos
		cabin.add_child(anchor)
		anchor.owner = EditorInterface.get_edited_scene_root()
