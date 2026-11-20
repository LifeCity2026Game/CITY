extends SceneTree

const VEHICLES := [
	{"slot":"Dena Plus","path":"res://assets/vehicles/dena_plus/dena_plus.glb","style":"dena"},
	{"slot":"Peugeot 207","path":"res://assets/vehicles/peugeot_207/peugeot_207.glb","style":"peugeot_207"},
	{"slot":"Land Cruiser 300","path":"res://assets/vehicles/land_cruiser_300/land_cruiser_300.glb","style":"land_cruiser"},
	{"slot":"Lexus RX 2023","path":"res://assets/vehicles/lexus_rx_2023/lexus_rx_2023.glb","style":"lexus_rx"},
	{"slot":"Ferrari F40","path":"res://assets/vehicles/ferrari_f40/ferrari_f40.glb","style":"ferrari"},
	{"slot":"Lamborghini Huracan","path":"res://assets/vehicles/lamborghini_huracan/lamborghini_huracan.glb","style":"lamborghini"},
	{"slot":"Saipa Tiba","path":"res://assets/vehicles/saipa_tiba/saipa_tiba.glb","style":"tiba"},
	{"slot":"Saipa Tiba 2","path":"res://assets/vehicles/saipa_tiba_2/saipa_tiba_2.glb","style":"tiba_2"},
	{"slot":"Saipa Pride 131","path":"res://assets/vehicles/saipa_pride_131/saipa_pride_131.glb","style":"pride"},
]

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("VEHICLE_ASSET_INTEGRATION_FAIL: " + message)
	quit(1)

func _run() -> void:
	for spec in VEHICLES:
		var packed := load(str(spec.path)) as PackedScene
		if packed == null:
			_fail("GLB did not import as PackedScene: " + str(spec.path))
			return
		var model := packed.instantiate()
		root.add_child(model)
		await process_frame
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			_fail("No visible mesh nodes for " + str(spec.slot))
			return
		var animation_players := model.find_children("*", "AnimationPlayer", true, false)
		if animation_players.is_empty():
			_fail("No AnimationPlayer for " + str(spec.slot))
			return
		var animation_player := animation_players[0] as AnimationPlayer
		var clips := animation_player.get_animation_list()
		for clip in ["door-open", "door-close", "bonnet-open", "bonnet-close", "boot-open", "boot-close", "steer", "wheel-roll"]:
			var found := false
			for clip_name in clips:
				if clip_name.to_lower().contains(clip):
					found = true
					break
			if not found:
				_fail("Missing animation " + clip + " for " + str(spec.slot))
				return
		var node_names: Array[String] = []
		for node in model.find_children("*", "Node3D", true, false):
			node_names.append(node.name.to_lower())
		for pivot in ["wheel-front-left", "wheel-front-right", "wheel-rear-left", "wheel-rear-right"]:
			var found_pivot := false
			for node_name in node_names:
				if node_name.contains(pivot):
					found_pivot = true
					break
			if not found_pivot:
				_fail("Missing pivot " + pivot + " for " + str(spec.slot))
				return
		model.queue_free()
		print("VEHICLE_ASSET_SOURCE_PASS: " + str(spec.slot))

	var vehicle_script := load("res://scripts/vehicle_controller.gd") as Script
	if vehicle_script == null:
		_fail("Vehicle controller script failed to load")
		return
	var car := CharacterBody3D.new()
	car.set_script(vehicle_script)
	root.add_child(car)
	await process_frame
	for index in range(VEHICLES.size()):
		if index > 0:
			car._cycle_vehicle_model()
			await process_frame
		if car.imported_model_root == null:
			_fail("Controller did not load model at catalog index %d" % index)
			return
		if not car.imported_model_root.visible:
			_fail("Imported model root is hidden at catalog index %d" % index)
			return
		var visible_mesh_count := 0
		for mesh in car.imported_model_root.find_children("*", "MeshInstance3D", true, false):
			if (mesh as MeshInstance3D).visible:
				visible_mesh_count += 1
		if visible_mesh_count == 0:
			_fail("Imported GLB meshes are hidden at catalog index %d" % index)
			return
		if car.imported_wheel_nodes.size() < 4:
			_fail("Controller did not bind four wheel pivots at catalog index %d" % index)
			return
		var collision := car.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			_fail("Vehicle collision proxy missing at catalog index %d" % index)
			return
		if (collision.shape as BoxShape3D).size.length() < 2.0:
			_fail("Vehicle collision proxy dimensions invalid at catalog index %d" % index)
			return
		print("VEHICLE_CONTROLLER_ASSET_PASS: " + str(VEHICLES[index].slot))
	print("VEHICLE_ASSET_INTEGRATION_TEST_PASS")
	quit(0)
