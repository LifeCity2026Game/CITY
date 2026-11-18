extends SceneTree

func _initialize() -> void:
	call_deferred("_run_vehicle_checks")

func _run_vehicle_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	assert(packed != null, "Main scene could not be loaded")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	var car := game.get_node_or_null("CityVehicle")
	var player := game.get_node_or_null("Player")
	assert(car != null, "CityVehicle node is missing")
	assert(player != null, "Player node is missing")
	assert(car.get_node_or_null("CollisionShape3D") != null, "Vehicle collision is missing")
	assert(car.wheel_nodes.size() == 4, "Vehicle must have four wheels")
	assert(car.interior_camera != null, "Interior camera is missing")
	assert(car.vehicle_camera != null, "Chase camera is missing")
	assert(car.left_door != null and car.right_door != null, "Door hinges are missing")
	assert(car.headlamps.size() == 2, "Headlamps are missing")
	assert(car.tail_lamps.size() == 2, "Tail lamps are missing")

	# Player starts close enough to enter the test vehicle.
	car._toggle_vehicle()
	assert(car.occupied, "Player could not enter the vehicle")
	car._set_control("accelerate", true)
	for frame in range(30):
		await physics_frame
	assert(car.current_speed > 0.0, "Vehicle did not accelerate")
	car._set_control("accelerate", false)
	car.current_speed = 0.0
	car._toggle_vehicle()
	assert(not car.occupied, "Player could not exit the stopped vehicle")

	print("VEHICLE_SMOKE_TEST_PASS")
	quit(0)
