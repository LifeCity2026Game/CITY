extends CharacterBody3D

@export var move_speed: float = 6.0
@export var gravity: float = 18.0
@export var camera_sensitivity: float = 0.008
var mobile_direction := Vector2.ZERO
var camera_pivot: Node3D
var camera: Camera3D
var body_visual: Node3D
var limbs: Array[Node3D] = []
var walk_phase := 0.0
var dragging_camera := false

func _ready() -> void:
	_build_humanoid()
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.0, 6.5)
	camera.current = true
	camera_pivot.add_child(camera)
	camera_pivot.rotation.x = deg_to_rad(-8.0)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	return m

func _capsule(parent: Node3D, name_text: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	parent.add_child(node)
	return node

func _build_humanoid() -> void:
	body_visual = Node3D.new()
	body_visual.name = "HumanoidCharacter"
	add_child(body_visual)
	var skin := Color(0.78, 0.57, 0.42)
	var shirt := Color(0.12, 0.28, 0.62)
	var pants := Color(0.10, 0.13, 0.20)
	_capsule(body_visual, "Torso", 0.28, 0.72, Vector3(0, 1.12, 0), shirt)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.material_override = _mat(skin)
	head.position = Vector3(0, 1.72, 0)
	body_visual.add_child(head)
	_capsule(body_visual, "Neck", 0.09, 0.18, Vector3(0, 1.52, 0), skin)
	for side in [-1.0, 1.0]:
		var arm := _capsule(body_visual, "Arm", 0.095, 0.62, Vector3(side * 0.36, 1.12, 0), shirt)
		arm.rotation.z = side * deg_to_rad(-10)
		limbs.append(arm)
		var hand := MeshInstance3D.new()
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.085
		hand_mesh.height = 0.16
		hand.mesh = hand_mesh
		hand.material_override = _mat(skin)
		hand.position = Vector3(side * 0.39, 0.78, 0)
		body_visual.add_child(hand)
		var leg := _capsule(body_visual, "Leg", 0.12, 0.72, Vector3(side * 0.14, 0.48, 0), pants)
		limbs.append(leg)
		var shoe := MeshInstance3D.new()
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.19, 0.11, 0.31)
		shoe.mesh = shoe_mesh
		shoe.material_override = _mat(Color(0.045, 0.045, 0.05))
		shoe.position = Vector3(side * 0.14, 0.09, -0.06)
		body_visual.add_child(shoe)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.85
	collider.shape = shape
	collider.position.y = 0.93
	add_child(collider)

func set_mobile_axis(axis: String, pressed: bool) -> void:
	match axis:
		"left": mobile_direction.x = -1.0 if pressed else 0.0
		"right": mobile_direction.x = 1.0 if pressed else 0.0
		"forward": mobile_direction.y = 1.0 if pressed else 0.0
		"back": mobile_direction.y = -1.0 if pressed else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		camera_pivot.rotation.y -= event.relative.x * camera_sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * camera_sensitivity, deg_to_rad(-35), deg_to_rad(28))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_pivot.rotation.y -= event.relative.x * camera_sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * camera_sensitivity, deg_to_rad(-35), deg_to_rad(28))

func _physics_process(delta: float) -> void:
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y -= 1.0
	var direction := keyboard if keyboard.length() > 0.0 else mobile_direction
	direction = direction.normalized()
	var move := Vector3(direction.x, 0.0, -direction.y)
	var basis_move := camera_pivot.global_transform.basis * move
	basis_move.y = 0.0
	basis_move = basis_move.normalized() if basis_move.length() > 0.01 else Vector3.ZERO
	velocity.x = basis_move.x * move_speed
	velocity.z = basis_move.z * move_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if basis_move.length() > 0.05:
		look_at(global_position + basis_move, Vector3.UP)
		walk_phase += delta * 8.0
		limbs[0].rotation.z = sin(walk_phase) * 0.35
		limbs[1].rotation.x = sin(walk_phase) * 0.55
		limbs[2].rotation.x = -sin(walk_phase) * 0.55
		limbs[3].rotation.x = sin(walk_phase) * 0.55
	else:
		for limb in limbs:
			limb.rotation = limb.rotation.lerp(Vector3.ZERO, delta * 8.0)
	move_and_slide()
