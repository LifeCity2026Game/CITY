extends SceneTree

func _initialize() -> void:
	call_deferred("_run_city_checks")

func _fail(message: String) -> void:
	push_error("CITY_INTERIORS_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _run_city_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var city := game.get_node_or_null("CityFeatures")
	var player := game.get_node_or_null("Player")
	if city == null or player == null:
		_fail("City feature system or player is missing")
		return
	if city.generic_interior_positions.size() != 64:
		_fail("Expected 64 generated city interiors, found %d" % city.generic_interior_positions.size())
		return
	if city.interior_positions.size() != 14:
		_fail("Expected 14 service-building interiors, found %d" % city.interior_positions.size())
		return
	var categories := {}
	for entry in city.generic_interior_positions:
		var category := str(entry.category)
		categories[category] = int(categories.get(category, 0)) + 1
		var room := entry.node as Node3D
		if room == null:
			_fail("A generated interior room node is missing for category %s" % category)
			return
		if room.get_node_or_null("Floor") == null or room.get_node_or_null("BackWall") == null:
			_fail("A generic interior is missing its floor or walls")
			return
		if room.find_children("*", "Label3D", true, false).is_empty():
			_fail("A generic interior is missing its business/residence sign")
			return
	if categories.size() != 8:
		_fail("Not all eight building categories were generated: %s" % str(categories.keys()))
		return
	var city_buildings := get_nodes_in_group("city_buildings")
	var generic_building_count := 0
	for building in city_buildings:
		if str(building.name).begins_with("Building_"):
			generic_building_count += 1
			if building.get_node_or_null("WindowGlass") == null and building.find_children("WindowGlass", "Node3D", true, false).is_empty():
				_fail("A generic building lacks facade window details: " + str(building.name))
				return
			if building.get_node_or_null("RoofFrontParapet") == null:
				_fail("A generic building lacks roofline details: " + str(building.name))
				return
	if generic_building_count != 64:
		_fail("Expected 64 detailed exterior buildings, found %d" % generic_building_count)
		return
	var target: Dictionary = city.generic_interior_positions[0]
	player.global_position = target.world + Vector3(0, 1.2, 0)
	city._enter_nearest_building()
	if not city.inside_building:
		_fail("Player could not enter a generated city building")
		return
	if player.global_position.distance_to(target.interior + Vector3(0, 1.2, 2.8)) > 0.5:
		_fail("Player was not moved into the selected building interior")
		return
	city._exit_building()
	if city.inside_building:
		_fail("Player could not exit a generated city building")
		return
	print("CITY_INTERIORS_SMOKE_TEST_PASS")
	quit(0)
