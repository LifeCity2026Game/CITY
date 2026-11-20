extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("PEUGEOT_207_VEHICLE_TEST_FAIL: " + message)
	quit(1)

func _run() -> void:
	var vehicle_script := load("res://scripts/vehicle_controller.gd") as Script
	if vehicle_script == null:
		_fail("Vehicle controller script could not be loaded")
		return
	var car: Variant = CharacterBody3D.new()
	car.name = "Peugeot207AcceptanceVehicle"
	car.set_script(vehicle_script)
	root.add_child(car)
	await process_frame
	car._cycle_vehicle_model()
	await process_frame

	if car.vehicle_name != "پژو ۲۰۷":
		_fail("Catalog index 1 is not Peugeot 207")
		return
	if car.imported_model_root == null or not car.imported_model_root.visible:
		_fail("Peugeot 207 GLB did not load as the visible vehicle body")
		return
	if car.imported_model_root.name != "ImportedVehicleModel_peugeot_207":
		_fail("The Peugeot 207 catalog slot loaded the wrong asset")
		return
	if car.imported_wheel_nodes.size() < 4 or car.imported_front_wheel_nodes.size() < 2:
		_fail("Peugeot 207 GLB wheel pivots were not bound")
		return
	if car.imported_steering_node == null:
		_fail("Peugeot 207 steering pivot was not bound")
		return
	if car.style_root == null or not car.style_root.visible:
		_fail("Peugeot 207 trim overlay is not visible")
		return
	var profile := car.style_root.get_node_or_null("Profile_peugeot_207")
	if profile == null or profile.get_child_count() < 14:
		_fail("Peugeot 207 front, side and hatchback trim is incomplete")
		return
	for required_part in ["Peugeot207LionBadge", "Peugeot207SweptHeadlamp", "Peugeot207LowerIntake", "Peugeot207HatchSpoiler", "Peugeot207RearLamp"]:
		if profile.find_child(required_part, true, false) == null:
			_fail("Missing Peugeot 207 styling part: " + required_part)
			return
	if car.interior_camera == null or car.vehicle_camera == null:
		_fail("Interior/exterior cameras are missing")
		return
	if car.left_door == null or car.right_door == null or car.hood_hinge == null or car.trunk_hinge == null:
		_fail("Door, hood or trunk interaction rig is missing")
		return
	if car.transmission_mode != "automatic" or car.gear != "P":
		_fail("Peugeot 207 did not initialize in automatic Park mode")
		return

	car._set_control("left", true)
	car._set_control("right", true)
	if absf(car.steering) > 0.001:
		_fail("Opposing steering buttons should neutralize")
		return
	car._set_control("left", false)
	if absf(car.steering - 1.0) > 0.001:
		_fail("Releasing left must preserve still-held right input")
		return
	car._set_control("right", false)
	if absf(car.steering) > 0.001:
		_fail("Steering must center after both buttons release")
		return

	car.occupied = true
	car.gear = "D"
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Peugeot 207 did not accelerate in Drive")
		return
	car.throttle = 0.0
	car.brake_pressed = true
	for frame in range(30):
		await physics_frame
	car.brake_pressed = false
	if absf(car.current_speed) > 1.0:
		_fail("Peugeot 207 service brake did not stop the car")
		return

	car.gear = "R"
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if car.current_speed >= 0.0:
		_fail("Peugeot 207 did not move in Reverse")
		return
	car.throttle = 0.0
	car.brake_pressed = true
	for frame in range(30):
		await physics_frame
	car.brake_pressed = false
	if absf(car.current_speed) > 1.0:
		_fail("Peugeot 207 reverse braking did not stop the car")
		return

	car._toggle_transmission()
	if car.transmission_mode != "manual":
		_fail("Manual transmission did not engage")
		return
	car.clutch_pressed = true
	car._cycle_gear()
	if car.gear != "1":
		_fail("Manual first gear could not be selected with clutch")
		return
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if absf(car.current_speed) > 0.1:
		_fail("Clutch did not disconnect engine drive")
		return
	car.throttle = 0.0
	car.clutch_pressed = false
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Peugeot 207 did not move in first gear after clutch release")
		return

	print("PEUGEOT_207_VEHICLE_TEST_PASS")
	quit(0)
