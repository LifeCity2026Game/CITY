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
	var collision_nodes := car.find_children("*", "CollisionShape3D", true, false)
	if collision_nodes.is_empty():
		_fail("Vehicle collision is missing")
		return
	if car.wheel_nodes.size() != 4:
		_fail("Vehicle must have four wheels")
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
	if car.hood_hinge == null or car.trunk_hinge == null:
		_fail("Interactive hood or trunk hinge is missing")
		return
	if car.climate_label == null or car.transmission_label == null:
		_fail("Climate or transmission status display is missing")
		return
	car._cycle_vehicle_model()
	if car.vehicle_name != "پژو ۲۰۷":
		_fail("Vehicle model selector did not switch to Peugeot 207")
		return
	for model_step in range(8):
		car._cycle_vehicle_model()
	if car.vehicle_name != "دنا":
		_fail("Vehicle model selector did not cycle back to Dena")
		return

	if car.global_position.distance_to(player.global_position) > 7.0:
		_fail("Player starts too far from the test vehicle")
		return
	car._toggle_vehicle()
	if not car.occupied:
		_fail("Player could not enter the vehicle")
		return

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
	var temperature_before := car.cabin_temperature
	var player_temperature_before: float = player.body_temperature
	for climate_frame in range(90):
		await physics_frame
	if car.cabin_temperature >= temperature_before:
		_fail("Cooling did not change cabin temperature")
		return
	if player.body_temperature >= player_temperature_before:
		_fail("Vehicle climate did not affect player body temperature")
		return
	car._cycle_indicators()
	if car.indicators != 1:
		_fail("Left indicator did not activate")
		return
	await process_frame
	if not car.left_indicator_lamps[0].visible and not car.left_indicator_lamps[1].visible:
		_fail("Left indicator lamps did not illuminate")
		return
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
	car._set_control("accelerate", false)
	car.current_speed = 0.0
	car._toggle_vehicle()
	if car.occupied:
		_fail("Player could not exit the stopped vehicle")
		return

	print("VEHICLE_SMOKE_TEST_PASS")
	quit(0)
