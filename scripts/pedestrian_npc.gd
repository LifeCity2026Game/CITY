extends CharacterBody3D
## Lightweight, articulated pedestrian AI for mobile performance.
@export var walk_speed: float = 1.15
@export var waypoint_a := Vector3(11.2, 0.0, -88.0)
@export var waypoint_b := Vector3(11.2, 0.0, 88.0)
@export var pedestrian_name := "شهروند"
@export var outfit_color := Color(0.18, 0.38, 0.66)
var target := Vector3.ZERO
var gait := 0.0
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var turn_pause := 0.0

func _ready() -> void:
	add_to_group("city_pedestrians")
	target = waypoint_b if global_position.distance_to(waypoint_a) < global_position.distance_to(waypoint_b) else waypoint_a
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	add_child(collider)
	_build_humanoid()
	var label := Label3D.new()
	label.text = pedestrian_name
	label.font_size = 15
	label.position.y = 2.45
	label.modulate = Color(0.92, 0.94, 0.98)
	add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func _capsule(parent: Node3D, radius: float, height: float, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = at
	parent.add_child(mesh_node)
	return mesh_node

func _build_humanoid() -> void:
	var skin := _material(Color(0.72, 0.52, 0.39))
	var shirt := _material(outfit_color)
	var trousers := _material(Color(0.12, 0.15, 0.20))
	var shoe := _material(Color(0.035, 0.035, 0.04))
	_capsule(self, 0.25, 0.68, shirt, Vector3(0, 1.20, 0))
	_capsule(self, 0.17, 0.34, skin, Vector3(0, 1.72, 0))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.material_override = skin
	head.position.y = 2.02
	add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.195
	hair_mesh.height = 0.15
	hair.mesh = hair_mesh
	hair.material_override = _material(Color(0.10, 0.07, 0.045))
	hair.position = Vector3(0, 2.14, 0)
	add_child(hair)
	left_arm = _make_limb(Vector3(-0.31, 1.48, 0), shirt, skin, true)
	right_arm = _make_limb(Vector3(0.31, 1.48, 0), shirt, skin, true)
	left_leg = _make_leg(Vector3(-0.13, 0.91, 0), trousers, shoe)
	right_leg = _make_leg(Vector3(0.13, 0.91, 0), trousers, shoe)

func _make_limb(at: Vector3, upper: Material, lower: Material, _arm: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_capsule(pivot, 0.085, 0.43, upper, Vector3(0, -0.22, 0))
	var forearm := Node3D.new()
	forearm.position.y = -0.40
	pivot.add_child(forearm)
	_capsule(forearm, 0.07, 0.39, lower, Vector3(0, -0.19, 0))
	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.07
	hand_mesh.height = 0.13
	hand.mesh = hand_mesh
	hand.material_override = lower
	hand.position.y = -0.39
	forearm.add_child(hand)
	return pivot

func _make_leg(at: Vector3, trousers: Material, shoe: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_capsule(pivot, 0.105, 0.48, trousers, Vector3(0, -0.23, 0))
	var lower := Node3D.new()
	lower.position.y = -0.43
	pivot.add_child(lower)
	_capsule(lower, 0.085, 0.43, trousers, Vector3(0, -0.20, 0))
	var foot := MeshInstance3D.new()
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.18, 0.10, 0.28)
	foot.mesh = foot_mesh
	foot.material_override = shoe
	foot.position = Vector3(0, -0.42, -0.08)
	lower.add_child(foot)
	return pivot

func _physics_process(delta: float) -> void:
	if turn_pause > 0.0:
		turn_pause -= delta
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 4.0 * delta)
	else:
		var flat_target := Vector3(target.x, global_position.y, target.z)
		var offset := flat_target - global_position
		if offset.length() < 1.2:
			target = waypoint_a if target.distance_to(waypoint_b) < 0.1 else waypoint_b
			turn_pause = 0.25
			offset = target - global_position
		var direction := Vector3(offset.x, 0.0, offset.z).normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		if direction.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if moving:
		gait += delta * 7.0
	var swing := sin(gait) * (0.42 if moving else 0.0)
	left_arm.rotation.x = -swing
	right_arm.rotation.x = swing
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
