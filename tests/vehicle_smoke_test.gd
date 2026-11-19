extends SceneTree

func _initialize() -> void:
	call_deferred("_run_vehicle_checks")

func _fail(message: String) -> void:
	push_error("VEHICLE_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _press_button(root_node: Node, caption: String) -> bool:
	for item in root_node.find_children("*", "Button", true, false):
		var button := item as Button
		if button and button.text == caption:
			button.pressed.emit()
			return true
	return false

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
	var character_joystick := game.get_node_or_null("CharacterControls/CharacterJoystick")
	if character_joystick == null:
		_fail("On-foot character joystick is missing")
		return
	if not character_joystick.has_signal("vector_changed"):
		_fail("Character joystick vector signal is missing")
		return
	character_joystick.vector_changed.emit(Vector2(0.6, 0.8))
	if player.mobile_direction.distance_to(Vector2(0.6, 0.8)) > 0.01:
		_fail("Character joystick did not send movement direction to player")
		return
	character_joystick.vector_changed.emit(Vector2.ZERO)
	if player.mobile_direction.length() > 0.01:
		_fail("Character joystick did not release movement")
		return
	var services := game.get_node_or_null("LifeCityServices")
	if services == null or services.sim_cards.size() != 2:
		_fail("Mobile services or two-SIM configuration is missing")
		return
	if services.ONLINE_PRODUCTS.size() < 10 or services.HOME_CATALOG.size() < 4 or services.CAR_PRICES.size() != 9:
		_fail("Online shop, physical property store or vehicle catalog is incomplete")
		return
	if game.get_node("Stage2Systems").get("player_black_money") != null:
		_fail("Black money field should be removed")
		return
	if game.ownership_ledger.get_balance(2) != 0:
		_fail("New online citizen must start with zero balance")
		return
	services._create_account(0)
	services._create_account(0)
	services._create_account(0)
	services._create_account(0)
	if services.sim_cards[0].accounts.size() != 3:
		_fail("A SIM must allow at most three bank accounts")
		return
	services._assign_role(2)
	if not services.roles.has(2):
		_fail("Creator could not assign a citizen role")
		return
	game.ownership_ledger.balances[2] = 1000
	if not game.ownership_ledger.owner_withdraw(2, 200) or game.ownership_ledger.get_balance(2) != 800:
		_fail("Creator-only withdrawal did not update citizen balance")
		return
	services.order_list.append({"item":"مبل", "remaining":1.0, "delivered":false})
	services._process(1.1)
	if not bool(services.order_list[0].delivered):
		_fail("Online order did not deliver after one in-game day timer")
		return
	services.owned_vehicles.append("دنا")
	services._spawn_car("دنا")
	if car.global_position.distance_to(player.global_position) < 3.0:
		_fail("Garage spawn did not place owned vehicle near the player")
		return
	services.owned_homes.append("آپارتمان اقتصادی")
	services._enter_home()
	if not services.inside_owned_home or player.global_position.distance_to(services.home_interior.global_position) > 8.0:
		_fail("Purchased home interior could not be entered")
		return
	services._place_item("مبل")
	if services.home_interior.get_node_or_null("Furniture_مبل") == null:
		_fail("Purchased furniture was not placed visibly inside the home")
		return
	services._exit_home()
	if services.inside_owned_home:
		_fail("Home exit did not restore player to city")
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
	var model_button := car.controls_layer.get_node_or_null("ModelSelector") as Button
	if model_button == null:
		_fail("Vehicle model selection button is missing")
		return
	for model_step in range(8):
		model_button.pressed.emit()
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
	car.enter_button.pressed.emit()
	if not car.occupied:
		_fail("Player could not enter the vehicle")
		return

	if not _press_button(car.controls_layer, "درها"):
		_fail("Door control button is missing")
		return
	if absf(car.left_door.rotation.y) < 0.1 or absf(car.right_door.rotation.y) < 0.1:
		_fail("Vehicle doors did not open")
		return
	_press_button(car.controls_layer, "درها")
	_press_button(car.controls_layer, "چراغ")
	if not car.headlamps[0].visible or not car.headlamps[1].visible:
		_fail("Headlights did not turn on")
		return
	_press_button(car.controls_layer, "چراغ")
	if not _press_button(car.controls_layer, "دوربین") or not car.interior_camera.current:
		_fail("Interior camera button did not switch to driver view")
		return
	_press_button(car.controls_layer, "دوربین")
	if not car.vehicle_camera.current:
		_fail("Exterior camera button did not restore chase view")
		return
	var steering_button := car.controls_layer.find_child("Hold_right", true, false) as Button
	if steering_button == null:
		_fail("Right steering touch button is missing")
		return
	steering_button.button_down.emit()
	await physics_frame
	await physics_frame
	if absf(car.front_wheels[0].rotation.y) < 0.01 or absf(car.steering_wheel.rotation.z) < 0.01:
		_fail("Steering failed: input=%s front=%s wheel=%s" % [str(car.steering), str(car.front_wheels[0].rotation.y), str(car.steering_wheel.rotation.z)])
		return
	steering_button.button_up.emit()
	if not _press_button(car.controls_layer, "کاپوت"):
		_fail("Hood control button is missing")
		return
	if not car.hood_open:
		_fail("Hood did not open")
		return
	_press_button(car.controls_layer, "کاپوت")
	_press_button(car.controls_layer, "صندوق")
	if not car.trunk_open:
		_fail("Trunk did not open")
		return
	_press_button(car.controls_layer, "صندوق")
	_press_button(car.controls_layer, "کولر/بخاری")
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
	_press_button(car.controls_layer, "کولر/بخاری")
	if car.climate_mode != "heat":
		_fail("Climate system did not switch to heating")
		return
	for heat_frame in range(90):
		await physics_frame
	if car.cabin_temperature <= cool_temperature or player.body_temperature <= cool_temperature:
		_fail("Heater did not warm the cabin and player")
		return
	_press_button(car.controls_layer, "کولر/بخاری")
	_press_button(car.controls_layer, "راهنما")
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
	var max_speed_before_damage: float = car.max_forward_speed
	car.apply_impact(10.0)
	if car.vehicle_health >= 100.0 or car.max_forward_speed >= max_speed_before_damage:
		_fail("Collision did not reduce vehicle condition and performance")
		return
	car.global_position = Vector3(-55.0, 0.2, 64.0)
	if not _press_button(car.controls_layer, "تعمیر خودرو"):
		_fail("Vehicle repair button is missing")
		return
	if car.vehicle_health != 100.0 or car.max_forward_speed != max_speed_before_damage:
		_fail("Garage repair did not restore vehicle condition and performance")
		return
	car.global_position = Vector3(4.0, 0.2, 7.0)
	if not _press_button(car.controls_layer, "گیربکس"):
		_fail("Transmission mode button is missing")
		return
	if car.transmission_mode != "manual":
		_fail("Manual transmission mode did not activate")
		return
	var clutch_button := car.controls_layer.find_child("Hold_clutch", true, false) as Button
	if clutch_button == null:
		_fail("Manual clutch touch button is missing")
		return
	clutch_button.button_down.emit()
	if not car.clutch_pressed:
		_fail("Manual clutch pedal did not engage")
		return
	if not _press_button(car.controls_layer, "دنده"):
		_fail("Gear selector button is missing")
		return
	if car.gear != "1":
		_fail("Manual gear selector did not engage first gear")
		return
	var accelerator_button := car.controls_layer.find_child("Hold_accelerate", true, false) as Button
	if accelerator_button == null:
		_fail("Accelerator touch button is missing")
		return
	accelerator_button.button_down.emit()
	for clutch_hold_frame in range(15):
		await physics_frame
	if absf(car.current_speed) > 0.1:
		_fail("Pressed clutch did not disengage engine drive")
		return
	accelerator_button.button_up.emit()
	clutch_button.button_up.emit()
	if car.clutch_pressed:
		_fail("Manual clutch pedal did not release")
		return
	accelerator_button.button_down.emit()
	for manual_drive_frame in range(30):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Manual first gear did not drive after clutch release")
		return
	accelerator_button.button_up.emit()
	var brake_button := car.controls_layer.find_child("Hold_brake", true, false) as Button
	if brake_button == null:
		_fail("Brake touch button is missing")
		return
	brake_button.button_down.emit()
	for manual_stop_frame in range(30):
		await physics_frame
	brake_button.button_up.emit()
	if absf(car.current_speed) > 1.0:
		_fail("Manual transmission test vehicle did not stop")
		return
	_press_button(car.controls_layer, "گیربکس")
	if car.transmission_mode != "automatic":
		_fail("Automatic transmission mode did not restore")
		return

	# The vehicle starts in Park; select Drive before testing acceleration.
	car.gear = "D"
	car._update_gear_label()
	accelerator_button.button_down.emit()
	for frame in range(30):
		await physics_frame
	if car.current_speed <= 0.0:
		_fail("Vehicle did not accelerate in Drive")
		return
	var forward_speed: float = car.current_speed
	accelerator_button.button_up.emit()
	brake_button.button_down.emit()
	for brake_frame in range(20):
		await physics_frame
	if car.current_speed >= forward_speed:
		_fail("Brake pedal did not reduce forward speed")
		return
	brake_button.button_up.emit()
	car.current_speed = 0.0
	car.gear = "R"
	accelerator_button.button_down.emit()
	for reverse_frame in range(30):
		await physics_frame
	if car.current_speed >= 0.0:
		_fail("Vehicle did not move in reverse")
		return
	accelerator_button.button_up.emit()
	brake_button.button_down.emit()
	for reverse_brake_frame in range(30):
		await physics_frame
	if absf(car.current_speed) > 1.0:
		_fail("Brake pedal did not stop the vehicle in reverse")
		return
	brake_button.button_up.emit()
	car.current_speed = 0.0
	var obstacle := StaticBody3D.new()
	obstacle.name = "VehicleCollisionTestObstacle"
	obstacle.position = Vector3(4.0, 0.2, 2.5)
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(4.0, 3.0, 1.0)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	game.add_child(obstacle)
	car.gear = "D"
	var health_before_collision: float = car.vehicle_health
	accelerator_button.button_down.emit()
	for collision_frame in range(60):
		await physics_frame
	accelerator_button.button_up.emit()
	if car.vehicle_health >= health_before_collision:
		_fail("Physical collision with an obstacle did not damage the vehicle")
		return
	car.current_speed = 0.0
	car.gear = "P"
	car.enter_button.pressed.emit()
	if car.occupied:
		_fail("Player could not exit the stopped vehicle")
		return

	print("VEHICLE_SMOKE_TEST_PASS")
	quit(0)
