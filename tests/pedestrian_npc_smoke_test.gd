extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	assert(packed != null, "Main scene could not be loaded")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var pedestrians := get_nodes_in_group("city_pedestrians")
	assert(pedestrians.size() >= 12, "Expected at least 12 pedestrian NPCs, found %d" % pedestrians.size())
	var initial_positions: Array[Vector3] = []
	for npc in pedestrians:
		assert(npc is CharacterBody3D, "Pedestrian is not a CharacterBody3D")
		assert(npc.get_node_or_null("CollisionShape3D") != null, "Pedestrian collision is missing")
		initial_positions.append(npc.global_position)
	await create_timer(1.4).timeout
	var moved_count := 0
	for index in range(pedestrians.size()):
		if pedestrians[index].global_position.distance_to(initial_positions[index]) > 0.15:
			moved_count += 1
	assert(moved_count >= 8, "Pedestrian AI did not move enough NPCs: %d" % moved_count)
	print("PEDESTRIAN_NPC_SMOKE_TEST_PASS count=%d moved=%d" % [pedestrians.size(), moved_count])
	quit(0)
