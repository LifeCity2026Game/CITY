extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("DENA_PLUS_VEHICLE_TEST_FAIL: " + message)
	quit(1)

func _run() -> void:
	var vehicle_script := load("res://scripts/vehicle_controller.gd") as Script
	if vehicle_script == null:
		_fail("Vehicle controller script could not be loaded")
		return
	var car: Variant = CharacterBody3D.new()
	car.name = "DenaPlusAcceptanceVehicle"
	car.set_script(vehicle_script)
	root.add_child(car)
	await process_frame

	if car.vehicle_name != "دنا":
		_fail("Default selected vehicle is not Dena Plus")
		return
	if car.imported_model_root == null or not car.imported_model_root.visible:
		_fail("Dena GLB did not load as the visible vehicle body")
		return
	if car.imported_wheel_nodes.size() < 4 or car.imported_front_wheel_nodes.size() < 2:
		_fail("Dena GLB wheel pivots were not bound")
		return
	if car.imported_steering_node == null:
		_fail("Dena steering wheel pivot was not bound")
		return
	if car.style_root == null or not car.style_root.visible:
		_fail("Dena-specific exterior trim overlay is not visible")
		return
	var dena_profile := car.style_root.get_node_or_null("Profile_dena")
	if dena_profile == null or dena_profile.get_child_count() < 8:
		_fail("Dena-specific grille, lamps, trim and badges are incomplete")
		return
	if car.interior_camera == null or car.vehicle_camera == null:
		_fail("Interior/exterior cameras are missing")
		return
	if car.left_door == null or car.right_door == null or car.hood_hinge == null or car.trunk_hinge == null:
		_fail("Dena door, hood or trunk interaction rig is missing")
		return
	if car.transmission_mode != "automatic" or car.gear != "P":
		_fail("Dena did not initialize in automatic Park mode")
		return

	# Verify simultaneous touch steering does not cancel the still-held direction.
	car._set_control("left", true)
	car._set_control("right", true)
	if absf(car.steering) > 0.001:
		_fail("Opposing steering buttons should neutralize")
		return
	car._set_control("left", false)
	if absf(car.steering - 1.0) > 0.001:
		_fail("Releasing left must preserve the still-held right steering input")
		return
	car._set_control("right", false)
	if absf(car.steering) > 0.001:
		_fail("Steering must return to center after both buttons release")
		return

	# Test automatic forward and reverse drive with the imported Dena body attached.
	car.occupied = true
	car.gear = "D"
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Dena did not accelerate in automatic Drive")
		return
	car.throttle = 0.0
	car.brake_pressed = true
	for frame in range(30):
		await physics_frame
	car.brake_pressed = false
	if absf(car.current_speed) > 1.0:
		_fail("Dena brake did not bring the vehicle to a stop")
		return

	car.gear = "R"
	car.throttle = 1.0
	for frame in range(24):
		await physics_frame
	if car.current_speed >= 0.0:
		_fail("Dena did not move backwards in Reverse")
		return
	car.throttle = 0.0
	car.brake_pressed = true
	for frame in range(30):
		await physics_frame
	car.brake_pressed = false
	if absf(car.current_speed) > 1.0:
		_fail("Dena reverse braking did not stop the vehicle")
		return

	# Test manual gearbox and clutch interlock.
	car._toggle_transmission()
	if car.transmission_mode != "manual":
		_fail("Manual gearbox mode did not engage")
		return
	car.clutch_pressed = true
	car._cycle_gear()
	if car.gear != "1":
		_fail("Manual first gear could not be selected with clutch engaged")
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
		_fail("Dena did not move in manual first gear after clutch release")
		return

	print("DENA_PLUS_VEHICLE_TEST_PASS")
	quit(0)
