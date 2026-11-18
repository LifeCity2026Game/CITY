extends CharacterBody3D
## First playable drivable city vehicle prototype for LIFE CITY.

@export var acceleration: float = 13.0
@export var brake_strength: float = 22.0
@export var max_forward_speed: float = 25.0
@export var max_reverse_speed: float = 8.0
@export var steering_speed: float = 1.55
@export var gravity: float = 18.0

var driver: CharacterBody3D
var occupied := false
var throttle := 0.0
var steering := 0.0
var current_speed := 0.0
var vehicle_camera: Camera3D
var player_camera: Camera3D
var speed_label: Label
var enter_button: Button
var wheel_nodes: Array[Node3D] = []

func _ready() -> void:
	_build_vehicle()
	_build_camera()
	_build_controls()

func configure(player_node: CharacterBody3D) -> void:
	driver = player_node

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	return material

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = _material(color)
	item.position = pos
	parent.add_child(item)
	return item

func _build_vehicle() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.05, 1.05, 4.1)
	collision.shape = shape
	collision.position.y = 0.72
	add_child(collision)
	_box(self, "VehicleBody", Vector3(0, 0.72, 0), Vector3(2.0, 0.68, 4.0), Color(0.68, 0.12, 0.09))
	_box(self, "VehicleHood", Vector3(0, 1.02, -1.25), Vector3(1.88, 0.24, 1.25), Color(0.74, 0.16, 0.12))
	_box(self, "VehicleCabin", Vector3(0, 1.34, 0.15), Vector3(1.58, 0.78, 1.9), Color(0.10, 0.18, 0.24))
	_box(self, "FrontGlass", Vector3(0, 1.48, -0.78), Vector3(1.42, 0.48, 0.06), Color(0.28, 0.43, 0.52))
	_box(self, "RearGlass", Vector3(0, 1.48, 1.08), Vector3(1.42, 0.48, 0.06), Color(0.24, 0.38, 0.46))
	_box(self, "FrontBumper", Vector3(0, 0.48, -2.04), Vector3(2.04, 0.2, 0.16), Color(0.16, 0.17, 0.18))
	_box(self, "RearBumper", Vector3(0, 0.48, 2.04), Vector3(2.04, 0.2, 0.16), Color(0.16, 0.17, 0.18))
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.39
			wheel_mesh.bottom_radius = 0.39
			wheel_mesh.height = 0.24
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(side * 1.02, 0.42, axle * 1.28)
			wheel.material_override = _material(Color(0.035, 0.035, 0.04))
			add_child(wheel)
			wheel_nodes.append(wheel)
	for side in [-1.0, 1.0]:
		var headlight := _box(self, "Headlight", Vector3(side * 0.68, 0.82, -2.03), Vector3(0.42, 0.18, 0.06), Color(1.0, 0.88, 0.58))
		headlight.material_override.emission_enabled = true
		headlight.material_override.emission = Color(1.0, 0.82, 0.48)
		_box(self, "TailLight", Vector3(side * 0.68, 0.82, 2.03), Vector3(0.38, 0.18, 0.06), Color(0.72, 0.035, 0.025))

func _build_camera() -> void:
	vehicle_camera = Camera3D.new()
	vehicle_camera.name = "VehicleCamera"
	vehicle_camera.position = Vector3(0, 3.3, 7.8)
	add_child(vehicle_camera)
	vehicle_camera.look_at(global_position + Vector3(0, 0.9, 0), Vector3.UP)
	vehicle_camera.current = false

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VehicleControls"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -210
	panel.offset_right = -12
	panel.offset_top = 210
	panel.offset_bottom = 470
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	enter_button = Button.new()
	enter_button.text = "سوار خودرو"
	enter_button.custom_minimum_size = Vector2(180, 44)
	column.add_child(enter_button)
	enter_button.pressed.connect(_toggle_vehicle)
	var row_one := HBoxContainer.new()
	column.add_child(row_one)
	_add_drive_button(row_one, "چپ", "left")
	_add_drive_button(row_one, "گاز", "accelerate")
	var row_two := HBoxContainer.new()
	column.add_child(row_two)
	_add_drive_button(row_two, "راست", "right")
	_add_drive_button(row_two, "ترمز / عقب", "brake")
	speed_label = Label.new()
	speed_label.text = "سرعت: ۰"
	column.add_child(speed_label)

func _add_drive_button(parent: HBoxContainer, caption: String, action: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(86, 54)
	parent.add_child(button)
	button.button_down.connect(_set_control.bind(action, true))
	button.button_up.connect(_set_control.bind(action, false))

func _set_control(action: String, pressed: bool) -> void:
	match action:
		"accelerate": throttle = 1.0 if pressed else 0.0
		"brake": throttle = -1.0 if pressed else 0.0
		"left": steering = -1.0 if pressed else 0.0
		"right": steering = 1.0 if pressed else 0.0

func _toggle_vehicle() -> void:
	if driver == null:
		return
	if not occupied:
		if global_position.distance_to(driver.global_position) > 7.0:
			if speed_label:
				speed_label.text = "برای سوار شدن نزدیک خودرو شو"
			return
		var pivot: Node3D = driver.get("camera_pivot")
		if pivot and pivot.get_child_count() > 0:
			player_camera = pivot.get_child(0) as Camera3D
			if player_camera:
				player_camera.current = false
		driver.set_physics_process(false)
		driver.hide()
		occupied = true
		vehicle_camera.current = true
		enter_button.text = "پیاده شدن"
		throttle = 0.0
		steering = 0.0
	else:
		occupied = false
		current_speed = 0.0
		velocity = Vector3.ZERO
		driver.global_position = global_position + global_transform.basis.x * 2.4 + Vector3(0, 0.25, 0)
		driver.show()
		driver.set_physics_process(true)
		vehicle_camera.current = false
		if player_camera:
			player_camera.current = true
		enter_button.text = "سوار خودرو"
		throttle = 0.0
		steering = 0.0

func _physics_process(delta: float) -> void:
	if not occupied:
		return
	var keyboard_throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard_throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard_throttle -= 1.0
	var active_throttle := keyboard_throttle if keyboard_throttle != 0.0 else throttle
	var keyboard_steering := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard_steering -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard_steering += 1.0
	var active_steering := keyboard_steering if keyboard_steering != 0.0 else steering
	if active_throttle > 0.0:
		current_speed = move_toward(current_speed, max_forward_speed, acceleration * delta)
	elif active_throttle < 0.0:
		if current_speed > 0.5:
			current_speed = move_toward(current_speed, 0.0, brake_strength * delta)
		else:
			current_speed = move_toward(current_speed, -max_reverse_speed, acceleration * 0.55 * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, 3.5 * delta)
	if absf(current_speed) > 0.15:
		rotation.y += active_steering * steering_speed * delta * clampf(absf(current_speed) / 7.0, 0.25, 1.0) * signf(current_speed)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	for wheel in wheel_nodes:
		wheel.rotate_x(current_speed * delta / 0.39)
	if speed_label:
		speed_label.text = "سرعت: %d km/h" % int(absf(current_speed) * 3.6)
