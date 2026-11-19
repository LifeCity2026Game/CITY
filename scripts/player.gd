extends CharacterBody3D

@export var move_speed: float = 6.0
@export var gravity: float = 18.0
var mobile_direction := Vector2.ZERO
var camera_pivot: Node3D
var camera_yaw: float = 0.0
var camera_pitch: float = -0.12
var camera_sensitivity: float = 0.8
var is_remote := false
var target_position := Vector3.ZERO
var target_yaw := 0.0
var animation_clock := 0.0
var body_temperature := 22.0
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

func _ready() -> void:
	_build_humanoid()
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.82
	collider.shape = shape
	collider.position.y = 0.91
	add_child(collider)
	if not is_remote:
		_build_camera()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78
	return m

func _capsule(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.material_override = _mat(color)
	mesh_node.position = pos
	parent.add_child(mesh_node)
	return mesh_node

func _build_humanoid() -> void:
	var skin := _mat(Color(0.78, 0.57, 0.42))
	var shirt := _mat(Color(0.12, 0.32, 0.72))
	var pants := _mat(Color(0.10, 0.13, 0.20))
	var shoes := _mat(Color(0.035, 0.035, 0.04))
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.29
	torso_mesh.height = 0.82
	torso.mesh = torso_mesh
	torso.material_override = shirt
	torso.position.y = 1.28
	add_child(torso)
	_capsule(self, 0.105, 0.22, Color(0.78, 0.57, 0.42), Vector3(0, 1.78, 0))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.material_override = skin
	head.position.y = 2.04
	add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.225
	hair_mesh.height = 0.19
	hair.mesh = hair_mesh
	hair.material_override = _mat(Color(0.12, 0.075, 0.045))
	hair.position = Vector3(0, 2.17, 0)
	add_child(hair)
	left_arm = _make_limb(Vector3(-0.37, 1.55, 0), shirt, skin, true)
	right_arm = _make_limb(Vector3(0.37, 1.55, 0), shirt, skin, true)
	left_leg = _make_leg(Vector3(-0.17, 0.91, 0), pants, shoes)
	right_leg = _make_leg(Vector3(0.17, 0.91, 0), pants, shoes)

func _make_limb(pos: Vector3, upper_mat: Material, lower_mat: Material, arm: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_capsule(pivot, 0.115, 0.55, Color(0.12, 0.32, 0.72), Vector3(0, -0.27, 0))
	var elbow := Node3D.new()
	elbow.position.y = -0.52
	pivot.add_child(elbow)
	_capsule(elbow, 0.095, 0.48, Color(0.78, 0.57, 0.42), Vector3(0, -0.23, 0))
	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.105
	hand_mesh.height = 0.19
	hand.mesh = hand_mesh
	hand.material_override = _mat(Color(0.78, 0.57, 0.42))
	hand.position.y = -0.48
	elbow.add_child(hand)
	return pivot

func _make_leg(pos: Vector3, pants_mat: Material, shoe_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_capsule(pivot, 0.14, 0.62, Color(0.10, 0.13, 0.20), Vector3(0, -0.29, 0))
	var knee := Node3D.new()
	knee.position.y = -0.57
	pivot.add_child(knee)
	_capsule(knee, 0.115, 0.57, Color(0.10, 0.13, 0.20), Vector3(0, -0.26, 0))
	var foot := MeshInstance3D.new()
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.23, 0.13, 0.38)
	foot.mesh = foot_mesh
	foot.material_override = _mat(Color(0.035, 0.035, 0.04))
	foot.position = Vector3(0, -0.55, -0.12)
	knee.add_child(foot)
	return pivot

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.top_level = true
	camera_pivot.position = global_position + Vector3(0, 1.55, 0)
	add_child(camera_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 6.2)
	camera.current = true
	camera_pivot.add_child(camera)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func configure_remote() -> void:
	is_remote = true
	set_physics_process(true)

func set_remote_state(pos: Vector3, yaw: float) -> void:
	target_position = pos
	target_yaw = yaw

func set_body_temperature(value: float) -> void:
	body_temperature = clampf(value, 15.0, 35.0)

func set_camera_sensitivity(value: float) -> void:
	camera_sensitivity = clampf(value, 0.1, 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if camera_pivot == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	if event is InputEventScreenDrag and event.position.x > viewport_width * 0.32:
		camera_yaw -= event.relative.x * 0.004 * camera_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.004 * camera_sensitivity, -0.85, 0.55)
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.004 * camera_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.004 * camera_sensitivity, -0.85, 0.55)
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func set_mobile_direction(value: Vector2) -> void:
	mobile_direction = value.limit_length(1.0)

func set_mobile_axis(axis: String, pressed: bool) -> void:
	# Backward-compatible helper for legacy callers.
	match axis:
		"left": mobile_direction.x = -1.0 if pressed else 0.0
		"right": mobile_direction.x = 1.0 if pressed else 0.0
		"forward": mobile_direction.y = 1.0 if pressed else 0.0
		"back": mobile_direction.y = -1.0 if pressed else 0.0

func _physics_process(delta: float) -> void:
	if is_remote:
		global_position = global_position.lerp(target_position, min(1.0, delta * 12.0))
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, delta * 12.0))
		return
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y -= 1.0
	var direction := keyboard if keyboard.length() > 0.0 else mobile_direction
	direction = direction.normalized()
	var move := Vector3(direction.x, 0.0, -direction.y)
	# Keep touch movement aligned with the camera: pushing up always moves toward the view direction.
	move = move.rotated(Vector3.UP, camera_yaw)
	velocity.x = move.x * move_speed
	velocity.z = move.z * move_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if move.length() > 0.05:
		look_at(global_position + move, Vector3.UP)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.25
	if moving:
		animation_clock += delta * 8.0
	else:
		animation_clock = lerp(animation_clock, 0.0, delta * 5.0)
	var swing := sin(animation_clock) * (0.48 if moving else 0.0)
	left_arm.rotation.x = -swing
	right_arm.rotation.x = swing
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0, 1.55, 0)
