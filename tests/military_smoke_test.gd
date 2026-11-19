extends SceneTree

func _initialize() -> void:
	call_deferred("_run_military_checks")

func _fail(message: String) -> void:
	push_error("MILITARY_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _run_military_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var military := game.get_node_or_null("MilitaryCommand")
	var services := game.get_node_or_null("LifeCityServices")
	if military == null or services == null:
		_fail("Military command or services node is missing")
		return
	if not game.get_node_or_null("CITY_HALL") is Node3D:
		_fail("City Hall building is missing")
		return
	if not game.get_node("CITY_HALL").is_in_group("city_buildings"):
		_fail("City Hall is not registered as a city building")
		return
	var hq := game.get_node_or_null("ARMED_FORCES_HQ")
	if hq == null:
		_fail("Army General Staff headquarters building is missing")
		return
	if hq.get_tree().get_nodes_in_group("hq_personnel").size() < 5:
		_fail("Headquarters must contain a commander and four soldier/officer NPCs")
		return
	military.open_panel()
	if not military.panel.visible:
		_fail("The real military command panel could not be opened")
		return
	if not services.ROLES.has("شهردار"):
		_fail("Mayor role is not available in the creator role list")
		return
	services.selected_role = "شهردار"
	services._assign_role(2)
	if str(services.roles.get(2, "")) != "شهردار":
		_fail("Creator could not appoint an online citizen as mayor")
		return
	services.active_page = "city_hall"
	services._render_page()
	var departments: Array = military.DEPARTMENTS
	if departments.size() != 7:
		_fail("All seven military branches must be registered")
		return
	for department in departments:
		military.selected_department = str(department)
		military._order_selected_units(Vector3(18.0, 0.0, -24.0), "move")
		var found := false
		var branch_unit: Node3D
		for unit in military.units:
			if is_instance_valid(unit) and str(unit.get_meta("department", "")) == str(department):
				found = true
				branch_unit = unit
				break
		if not found:
			_fail("No actual 3D unit spawned for branch: " + str(department))
			return
		if not bool(branch_unit.get_meta("ai_enabled", false)):
			_fail("Autonomous AI is not enabled for branch: " + str(department))
			return
		if str(branch_unit.get_meta("ai_profile", "")).is_empty():
			_fail("Dedicated AI profile is missing for branch: " + str(department))
			return
	military.selected_department = "نیروی دریایی"
	military._on_action("naval")
	var sea_unit_found := false
	for unit in military.units:
		if is_instance_valid(unit) and str(unit.name) == "ناو پشتیبانی":
			sea_unit_found = true
			if unit.position.z < 70.0 || unit.position.z > 120.0:
				_fail("Naval ship did not enter or remain in the ocean zone")
				return
	if not sea_unit_found:
		_fail("Naval patrol ship was not spawned")
		return
	military.selected_department = "نیروی هوایی"
	military._order_fighter_attack(Vector3(55.0, 0.0, 92.0), false)
	if not military.missile_active:
		_fail("Fighter conventional bomb/projectile was not launched")
		return
	military._update_missile(4.0)
	if military.missile_active or military.explosion_nodes.is_empty():
		_fail("Conventional fighter impact and explosion did not complete")
		return
	military._order_fighter_attack(Vector3(55.0, 0.0, 92.0), true)
	if not military.active_projectile_nuclear:
		_fail("Fictional nuclear payload mode was not activated")
		return
	military._update_missile(4.0)
	if military.missile_active or military.destroyed_buildings.is_empty():
		_fail("Nuclear game effect did not apply area damage to buildings")
		return
	var city_building_count := game.get_tree().get_nodes_in_group("city_buildings").size()
	if city_building_count < 10:
		_fail("City building registry is unexpectedly small")
		return
	services.selected_role = "وزیر"
	services._assign_role(2)
	if not services._has_role(2, "شهردار") or not services._has_role(2, "وزیر"):
		_fail("A citizen could not hold two simultaneous roles")
		return
	services._remove_role(2)
	if services._has_role(2, "وزیر") or not services._has_role(2, "شهردار"):
		_fail("Removing one role incorrectly removed another assigned role")
		return
	print("MILITARY_SMOKE_TEST_PASS")
	quit(0)
