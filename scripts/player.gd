extends CharacterBody3D

@export var move_speed: float = 6.0
@export var gravity: float = 18.0
var mobile_direction := Vector2.ZERO
var camera_pivot: Node3D

func _ready() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.48, 0.92)
	visual.material_override = material
	visual.position.y = 0.9
	add_child(visual)

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 3.2, 6.5)
	add_child(camera_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3.ZERO
	camera.current = true
	camera_pivot.add_child(camera)
	camera.look_at(global_position + Vector3(0, 1.2, 0), Vector3.UP)

func set_mobile_axis(axis: String, pressed: bool) -> void:
	match axis:
		"left": mobile_direction.x = -1.0 if pressed else 0.0
		"right": mobile_direction.x = 1.0 if pressed else 0.0
		"forward": mobile_direction.y = 1.0 if pressed else 0.0
		"back": mobile_direction.y = -1.0 if pressed else 0.0

func _physics_process(delta: float) -> void:
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y -= 1.0
	var direction := keyboard if keyboard.length() > 0.0 else mobile_direction
	direction = direction.normalized()
	var move := Vector3(direction.x, 0.0, -direction.y)
	velocity.x = move.x * move_speed
	velocity.z = move.z * move_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if move.length() > 0.05:
		look_at(global_position + move, Vector3.UP)
	move_and_slide()
	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0, 3.2, 6.5)
		camera_pivot.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)
