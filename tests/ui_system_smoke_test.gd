extends SceneTree

const UI_MANAGER_SCRIPT = preload("res://addons/lifecity_ui/ui_manager.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var ui_manager := UI_MANAGER_SCRIPT.new()
	var root := Control.new()
	var button := Button.new()
	button.text = "Test"
	root.add_child(button)

	ui_manager.apply_to_tree(root)
	if button.custom_minimum_size.y < 48.0:
		push_error("UI buttons must meet the minimum touch target height.")
		ui_manager.free()
		quit(1)
		return

	var panel := Control.new()
	ui_manager.apply_safe_panel_layout(panel)
	if panel.anchor_left < 0.0 or panel.anchor_right > 1.0 or panel.anchor_left >= panel.anchor_right:
		push_error("Responsive safe-panel anchors are invalid.")
		ui_manager.free()
		quit(1)
		return

	print("LIFE_CITY_UI_SMOKE_TEST_PASS")
	root.free()
	panel.free()
	ui_manager.free()
	quit(0)
