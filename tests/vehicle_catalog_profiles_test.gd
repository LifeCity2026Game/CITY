extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("VEHICLE_CATALOG_TEST_FAIL: " + message)
	quit(1)

func _run() -> void:
	var vehicle_script: Script = load("res://scripts/vehicle_controller.gd")
	if vehicle_script == null:
		_fail("Vehicle controller script could not be loaded")
		return
	var car: Variant = CharacterBody3D.new()
	car.set_script(vehicle_script)
	root.add_child(car)
	await process_frame

	var expected_names: Array[String] = [
		"دنا", "پژو ۲۰۷", "لندکروزر", "لکسوس RX", "فراری",
		"لامبورگینی", "تیبا", "تیبا ۲", "پراید"
	]
	var expected_profiles: Array[String] = [
		"dena", "peugeot_207", "land_cruiser", "lexus_rx", "ferrari",
		"lamborghini", "tiba", "tiba_2", "pride"
	]
	var seen_profiles: Dictionary = {}
	var catalog: Array = car.VEHICLE_CATALOG
	if catalog.size() != expected_names.size():
		_fail("Catalog must contain exactly nine vehicles")
		return
	for index in range(expected_names.size()):
		if str(catalog[index].get("name", "")) != expected_names[index]:
			_fail("Vehicle catalog order/name mismatch at index %d" % index)
			return
		if str(catalog[index].get("style", "")) != expected_profiles[index]:
			_fail("Vehicle profile key mismatch for " + expected_names[index])
			return
		if car.model_index != index:
			_fail("Vehicle selector index did not advance correctly")
			return
		if car.vehicle_name != expected_names[index]:
			_fail("Selected vehicle name mismatch for " + expected_names[index])
			return
		if car.style_root == null or car.style_root.get_child_count() != 1:
			_fail("Unique profile root missing for " + expected_names[index])
			return
		var profile := car.style_root.get_child(0) as Node3D
		if profile == null or profile.name != "Profile_" + expected_profiles[index]:
			_fail("Distinct profile marker missing for " + expected_names[index])
			return
		if profile.get_child_count() < 2:
			_fail("Model-specific exterior details missing for " + expected_names[index])
			return
		if seen_profiles.has(profile.name):
			_fail("Duplicate vehicle profile: " + profile.name)
			return
		seen_profiles[profile.name] = true
		if index < expected_names.size() - 1:
			car._cycle_vehicle_model()
			await process_frame

	if seen_profiles.size() != 9:
		_fail("Not all nine unique vehicle profiles were exercised")
		return
	print("VEHICLE_CATALOG_TEST_PASS")
	quit(0)
