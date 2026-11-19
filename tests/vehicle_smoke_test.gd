extends SceneTree

func _initialize() -> void:
	call_deferred("_run_vehicle_checks")

func _fail(message: String) -> void:
	push_error("VEHICLE_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _run_vehicle_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	var car := game.get_node_or_null("CityVehicle")
	var player := game.get_node_or_null("Player")
	if car == null or player == null:
		_fail("CityVehicle or Player node is missing")
		return
	if car.driver != player:
		_fail("Vehicle driver was not configured with the player")
		return
	var city := game.get_node_or_null("CityFeatures")
	if city == null or not city.interior_positions.has("repair_garage"):
		_fail("Vehicle repair garage or its enterable interior is missing")
		return
	var collision_nodes := car.find_children("*", "CollisionShape3D", true, false)
	if collision_nodes.is_empty():
		_fail("Vehicle collision is missing")
		return
	if car.wheel_nodes.size() != 4:
		_fail("Vehicle must have four wheels")
		return
	if car.front_wheels.size() != 2:
		_fail("Front steering wheels are missing")
		return
	if car.interior_camera == null or car.vehicle_camera == null:
		_fail("Vehicle cameras are missing")
		return
	if car.left_door == null or car.right_door == null:
		_fail("Door hinges are missing")
		return
	if car.headlamps.size() != 2 or car.tail_lamps.size() != 2:
		_fail("Vehicle lamps are missing")
		return
	if car.left_indicator_lamps.size() != 2 or car.right_indicator_lamps.size() != 2:
		_fail("Front and rear turn signal lamps are missing")
		return
	if car.VEHICLE_CATALOG.size() != 9:
		_fail("The requested nine vehicle presets are not registered")
		return
	if car.vehicle_name != "دنا" or car.style_root == null:
		_fail("Default Dena exterior profile was not initialized")
		return
	if car.hood_hinge == null or car.trunk_hinge == null:
		_fail("Interactive hood or trunk hinge is missing")
		return
	if car.climate_label == null or car.transmission_label == null:
		_fail("Climate or transmission status display is missing")
		return
	var selected_names: Array[String] = [str(car.vehicle_name)]
	for model_step in range(8):
		car._cycle_vehicle_model()
		selected_names.append(str(car.vehicle_name))
	if selected_names.size() != 9 or selected_names.has("City Sedan"):
		_fail("Vehicle selector did not expose all nine named cars")
		return
	var unique_names := selected_names.duplicate()
	unique_names.sort()
	for name_index in range(unique_names.size() - 1):
		if unique_names[name_index] == unique_names[name_index + 1]:
			_fail("Vehicle catalog contains duplicate names")
			return
	if car.vehicle_name != "پراید" or car.style_root == null:
		_fail("Vehicle selector did not finish on the ninth model with a style profile")
		return

	if car.global_position.distance_to(player.global_position) > 7.0:
		_fail("Player starts too far from the test vehicle")
		return
	car._toggle_vehicle()
	if not car.occupied:
		_fail("Player could not enter the vehicle")
		return

	car._toggle_doors()
	if absf(car.left_door.rotation.y) < 0.1 or absf(car.right_door.rotation.y) < 0.1:
		_fail("Vehicle doors did not open")
		return
	car._toggle_doors()
	car._toggle_lights()
	if not car.headlamps[0].visible or not car.headlamps[1].visible:
		_fail("Headlights did not turn on")
		return
	car._toggle_lights()
	car._set_control("right", true)
	await physics_frame
	await physics_frame
	if absf(car.front_wheels[0].rotation.y) < 0.01 or absf(car.steering_wheel.rotation.z) < 0.01:
		_fail("Steering failed: input=%s front=%s wheel=%s" % [str(car.steering), str(car.front_wheels[0].rotation.y), str(car.steering_wheel.rotation.z)])
		return
	car._set_control("right", false)
	car._toggle_hood()
	if not car.hood_open:
		_fail("Hood did not open")
		return
	car._toggle_hood()
	car._toggle_trunk()
	if not car.trunk_open:
		_fail("Trunk did not open")
		return
	car._toggle_trunk()
	car._cycle_climate()
	if car.climate_mode != "cool":
		_fail("Climate system did not switch to cooling")
		return
	var temperature_before: float = float(car.cabin_temperature)
	var player_temperature_before: float = player.body_temperature
	for climate_frame in range(90):
		await physics_frame
	if car.cabin_temperature >= temperature_before:
		_fail("Cooling did not change cabin temperature")
		return
	if player.body_temperature >= player_temperature_before:
		_fail("Vehicle climate did not affect player body temperature")
		return
	var cool_temperature: float = car.cabin_temperature
	car._cycle_climate()
	if car.climate_mode != "heat":
		_fail("Climate system did not switch to heating")
		return
	for heat_frame in range(90):
		await physics_frame
	if car.cabin_temperature <= cool_temperature or player.body_temperature <= cool_temperature:
		_fail("Heater did not warm the cabin and player")
		return
	car._cycle_climate()
	car._cycle_indicators()
	if car.indicators != 1:
		_fail("Left indicator did not activate")
		return
	var signal_seen := false
	for signal_frame in range(60):
		await process_frame
		if car.left_indicator_lamps[0].visible or car.left_indicator_lamps[1].visible:
			signal_seen = true
			break
	if not signal_seen:
		_fail("Left indicator lamps did not illuminate")
		return
	car.apply_impact(10.0)
	if car.vehicle_health >= 100.0:
		_fail("Collision did not reduce vehicle condition")
		return
	car.global_position = Vector3(-55.0, 0.2, 64.0)
	car.repair_vehicle()
	if car.vehicle_health != 100.0:
		_fail("Vehicle repair did not restore full condition")
		return
	car.global_position = Vector3(4.0, 0.2, 7.0)
	car._toggle_transmission()
	if car.transmission_mode != "manual":
		_fail("Manual transmission mode did not activate")
		return
	car._toggle_clutch()
	if not car.clutch_pressed:
		_fail("Manual clutch did not engage")
		return
	car._cycle_gear()
	if car.gear != "1":
		_fail("Manual gear selector did not engage first gear")
		return
	car._toggle_transmission()
	if car.transmission_mode != "automatic":
		_fail("Automatic transmission mode did not restore")
		return

	# The vehicle starts in Park; select Drive before testing acceleration.
	car.gear = "D"
	car._update_gear_label()
	car._set_control("accelerate", true)
	for frame in range(30):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Vehicle did not accelerate in Drive")
		return
	var forward_speed: float = car.current_speed
	car._set_control("accelerate", false)
	car._set_control("brake", true)
	for brake_frame in range(20):
		await physics_frame
	if car.current_speed >= forward_speed:
		_fail("Brake pedal did not reduce forward speed")
		return
	car._set_control("brake", false)
	car.current_speed = 0.0
	car.gear = "R"
	car._set_control("accelerate", true)
	for reverse_frame in range(30):
		await physics_frame
	if car.current_speed >= 0.0:
		_fail("Vehicle did not move in reverse")
		return
	car._set_control("accelerate", false)
	car._set_control("brake", true)
	for reverse_brake_frame in range(30):
		await physics_frame
	if absf(car.current_speed) > 1.0:
		_fail("Brake pedal did not stop the vehicle in reverse")
		return
	car._set_control("brake", false)
	car.current_speed = 0.0
	car.gear = "P"
	car._toggle_vehicle()
	if car.occupied:
		_fail("Player could not exit the stopped vehicle")
		return

	print("VEHICLE_SMOKE_TEST_PASS")
	quit(0)
