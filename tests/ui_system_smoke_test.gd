extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var root := Control.new()
	var button := Button.new()
	button.text = "Test"
	root.add_child(button)

	LifeCityUI.apply_to_tree(root)
	if button.custom_minimum_size.y < 48.0:
		push_error("UI buttons must meet the minimum touch target height.")
		quit(1)
		return

	var panel := Control.new()
	LifeCityUI.apply_safe_panel_layout(panel)
	if panel.anchor_left < 0.0 or panel.anchor_right > 1.0 or panel.anchor_left >= panel.anchor_right:
		push_error("Responsive safe-panel anchors are invalid.")
		quit(1)
		return

	print("LIFE_CITY_UI_SMOKE_TEST_PASS")
	root.free()
	panel.free()
	quit(0)
