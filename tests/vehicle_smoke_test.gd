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
	if car.get_node_or_null("CollisionShape3D") == null:
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

	if car.global_position.distance_to(player.global_position) > 7.0:
		_fail("Player starts too far from the test vehicle")
		return
	car._toggle_vehicle()
	if not car.occupied:
		_fail("Player could not enter the vehicle")
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
