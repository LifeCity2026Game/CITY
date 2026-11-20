extends SceneTree

func _initialize() -> void:
	call_deferred("_run_graphics_checks")

func _fail(message: String) -> void:
	push_error("GRAPHICS_SETTINGS_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _run_graphics_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	var graphics := game.get_node_or_null("GraphicsSettings")
	var sun := game.get("sun") as DirectionalLight3D
	if graphics == null or sun == null:
		_fail("Graphics controller or sun light is missing")
		return

	graphics.apply_quality("low")
	if graphics.current_quality != "low" or sun.shadow_enabled:
		_fail("Low preset did not disable shadows")
		return
	if absf(game.get_viewport().scaling_3d_scale - 0.72) > 0.01:
		_fail("Low preset did not reduce 3D render scale")

	graphics.apply_quality("medium")
	if graphics.current_quality != "medium" or not sun.shadow_enabled:
		_fail("Medium preset did not restore balanced shadows")
		return
	if absf(game.get_viewport().scaling_3d_scale - 0.85) > 0.01:
		_fail("Medium preset render scale is incorrect")
		return

	graphics.set_auto_mode()
	if graphics.quality_mode != "auto":
		_fail("Automatic quality mode did not activate")
		return
	graphics.current_quality = "high"
	graphics._apply_quality_preset("high")
	graphics.evaluate_performance_sample(20.0)
	graphics.evaluate_performance_sample(20.0)
	if graphics.current_quality != "medium":
		_fail("Sustained low FPS did not reduce quality from high to medium")
		return
	graphics.evaluate_performance_sample(20.0)
	graphics.evaluate_performance_sample(20.0)
	if graphics.current_quality != "low":
		_fail("Sustained low FPS did not reduce quality from medium to low")
		return
	for sample in range(6):
		graphics.evaluate_performance_sample(60.0)
	if graphics.current_quality != "high":
		_fail("Sustained high FPS did not restore higher quality")
		return
	if graphics.quality_mode != "auto":
		_fail("Adaptive controller unexpectedly left automatic mode")
		return

	print("GRAPHICS_SETTINGS_SMOKE_TEST_PASS")
	quit(0)
