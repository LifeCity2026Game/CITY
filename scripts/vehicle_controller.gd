extends CharacterBody3D
## LIFE CITY detailed procedural vehicle. Replaceable with licensed/imported meshes later.

@export var vehicle_name: String = "City Sedan"
@export var acceleration: float = 11.0
@export var brake_strength: float = 24.0
@export var max_forward_speed: float = 34.0
@export var max_reverse_speed: float = 9.0
@export var steering_speed: float = 1.65
@export var gravity: float = 22.0

var driver: CharacterBody3D
var occupied := false
var throttle := 0.0
var steering := 0.0
var current_speed := 0.0
var gear := "P"
var lights_on := false
var handbrake := false
var indicators := 0
var interior_camera_on := false
var vehicle_camera: Camera3D
var interior_camera: Camera3D
var player_camera: Camera3D
var speed_label: Label
var gear_label: Label
var enter_button: Button
var wheel_nodes: Array[Node3D] = []
var steering_wheel: Node3D
var left_door: Node3D
var right_door: Node3D
var headlamps: Array[SpotLight3D] = []
var tail_lamps: Array[MeshInstance3D] = []
var left_indicator_lamps: Array[MeshInstance3D] = []
var right_indicator_lamps: Array[MeshInstance3D] = []
var brake_material: StandardMaterial3D
var tail_material: StandardMaterial3D
var brake_lights_active := false
var dashboard_label: Label3D
var controls_layer: CanvasLayer
var controls_panel: PanelContainer

const VEHICLE_CATALOG := [
	{"name":"دنا","color":Color(0.12,0.30,0.66),"scale":Vector3(1.0,1.0,1.0),"speed":34.0,"accel":11.0,"style":"sedan"},
	{"name":"پژو ۲۰۷","color":Color(0.72,0.12,0.10),"scale":Vector3(0.92,0.94,0.82),"speed":31.0,"accel":12.0,"style":"hatch"},
	{"name":"لندکروزر","color":Color(0.16,0.23,0.18),"scale":Vector3(1.12,1.16,1.12),"speed":32.0,"accel":9.0,"style":"suv"},
	{"name":"لکسوس RX","color":Color(0.18,0.20,0.23),"scale":Vector3(1.08,1.08,1.04),"speed":36.0,"accel":10.5,"style":"luxury"},
	{"name":"فراری","color":Color(0.78,0.025,0.02),"scale":Vector3(1.02,0.78,1.08),"speed":49.0,"accel":17.0,"style":"sport"},
	{"name":"لامبورگینی","color":Color(0.82,0.66,0.02),"scale":Vector3(1.04,0.74,1.12),"speed":52.0,"accel":18.0,"style":"supercar"},
	{"name":"تیبا","color":Color(0.68,0.70,0.72),"scale":Vector3(0.91,0.90,0.94),"speed":28.0,"accel":8.5,"style":"compact"},
	{"name":"تیبا ۲","color":Color(0.08,0.36,0.24),"scale":Vector3(0.92,0.92,0.90),"speed":29.0,"accel":9.0,"style":"hatch"},
	{"name":"پراید","color":Color(0.80,0.80,0.76),"scale":Vector3(0.86,0.86,0.88),"speed":25.0,"accel":7.5,"style":"compact"}
]
var model_index := 0
var transmission_mode := "automatic"
var clutch_pressed := false
var climate_mode := "off"
var cabin_temperature := 22.0
var target_temperature := 22.0
var hood_hinge: Node3D
var trunk_hinge: Node3D
var hood_open := false
var trunk_open := false
var climate_label: Label
var transmission_label: Label

func _ready() -> void:
	_build_vehicle()
	_build_cameras()
	_build_controls()

func configure(player_node: CharacterBody3D) -> void:
	driver = player_node

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.42) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = _mat(color, metallic)
	item.position = pos
	parent.add_child(item)
	return item

func _cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = title
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.material_override = _mat(color, metallic)
	item.position = pos
	parent.add_child(item)
	return item

func _build_vehicle() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.05, 1.05, 4.35)
	collision.shape = shape
	collision.position.y = 0.56
	add_child(collision)

	# Exterior body, hood, trunk, bumpers, trim and glass.
	_box(self, "LowerChassis", Vector3(0, 0.54, 0), Vector3(1.92, 0.35, 3.95), Color(0.12, 0.13, 0.15), 0.55)
	_box(self, "BodyShell", Vector3(0, 0.78, 0), Vector3(2.0, 0.62, 4.0), Color(0.12, 0.30, 0.66), 0.62)
	var hood_static := _box(self, "HoodStatic", Vector3(0, 1.04, -1.32), Vector3(1.91, 0.18, 1.25), Color(0.15, 0.36, 0.76), 0.58)
	var trunk_static := _box(self, "TrunkStatic", Vector3(0, 1.00, 1.55), Vector3(1.88, 0.20, 0.82), Color(0.12, 0.30, 0.66), 0.58)
	hood_static.visible = false
	trunk_static.visible = false
	hood_hinge = Node3D.new()
	hood_hinge.name = "InteractiveHoodHinge"
	hood_hinge.position = Vector3(0, 1.04, -1.92)
	add_child(hood_hinge)
	_box(hood_hinge, "HoodPanel", Vector3(0, 0, 0.60), Vector3(1.91, 0.18, 1.25), Color(0.15, 0.36, 0.76), 0.58)
	trunk_hinge = Node3D.new()
	trunk_hinge.name = "InteractiveTrunkHinge"
	trunk_hinge.position = Vector3(0, 1.00, 1.96)
	add_child(trunk_hinge)
	_box(trunk_hinge, "TrunkPanel", Vector3(0, 0, -0.41), Vector3(1.88, 0.20, 0.82), Color(0.12, 0.30, 0.66), 0.58)
	_box(self, "Roof", Vector3(0, 1.78, 0.10), Vector3(1.62, 0.16, 1.92), Color(0.10, 0.25, 0.54), 0.55)
	_box(self, "FrontWindshield", Vector3(0, 1.48, -0.82), Vector3(1.52, 0.55, 0.055), Color(0.12, 0.22, 0.29), 0.25)
	_box(self, "RearWindshield", Vector3(0, 1.48, 1.08), Vector3(1.50, 0.52, 0.055), Color(0.12, 0.22, 0.29), 0.25)
	for side in [-1.0, 1.0]:
		_box(self, "SideWindow", Vector3(side * 0.81, 1.48, 0.12), Vector3(0.045, 0.48, 1.55), Color(0.12, 0.22, 0.29), 0.2)
		_box(self, "SideSkirt", Vector3(side * 0.96, 0.48, 0), Vector3(0.12, 0.20, 2.65), Color(0.08, 0.09, 0.11), 0.5)
		_box(self, "Mirror", Vector3(side * 1.02, 1.30, -0.67), Vector3(0.20, 0.14, 0.28), Color(0.10, 0.12, 0.15), 0.6)
	_box(self, "FrontBumper", Vector3(0, 0.48, -2.08), Vector3(2.02, 0.22, 0.18), Color(0.09, 0.10, 0.12), 0.45)
	_box(self, "RearBumper", Vector3(0, 0.48, 2.08), Vector3(2.02, 0.22, 0.18), Color(0.09, 0.10, 0.12), 0.45)
	_box(self, "FrontGrille", Vector3(0, 0.77, -2.035), Vector3(0.72, 0.22, 0.035), Color(0.025, 0.03, 0.04), 0.7)
	_box(self, "FrontPlate", Vector3(0, 0.48, -2.18), Vector3(0.55, 0.15, 0.025), Color(0.88, 0.88, 0.82))
	_box(self, "RearPlate", Vector3(0, 0.52, 2.18), Vector3(0.55, 0.15, 0.025), Color(0.88, 0.88, 0.82))

	# Four tires, alloy hubs and wheel rotation.
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			var wheel := Node3D.new()
			wheel.name = "Wheel_%s_%s" % [str(side), str(axle)]
			wheel.position = Vector3(side * 1.02, 0.43, axle * 1.32)
			add_child(wheel)
			var tire := _cylinder(wheel, "RubberTire", Vector3.ZERO, 0.39, 0.25, Color(0.025, 0.027, 0.03))
			tire.rotation.z = PI / 2.0
			var hub := _cylinder(wheel, "AlloyRim", Vector3(side * -0.13, 0, 0), 0.23, 0.035, Color(0.58, 0.60, 0.64), 0.85)
			hub.rotation.z = PI / 2.0
			wheel_nodes.append(wheel)

	# Detailed cabin: seats, dashboard, steering wheel, console and pedals.
	var cabin := Node3D.new()
	cabin.name = "CabinInterior"
	add_child(cabin)
	var dark := Color(0.055, 0.065, 0.075)
	var leather := Color(0.16, 0.17, 0.19)
	_box(cabin, "FloorCarpet", Vector3(0, 0.69, 0.12), Vector3(1.66, 0.08, 2.65), dark)
	_box(cabin, "Dashboard", Vector3(0, 1.22, -0.78), Vector3(1.62, 0.28, 0.35), dark)
	_box(cabin, "InstrumentCluster", Vector3(-0.38, 1.36, -0.59), Vector3(0.55, 0.13, 0.08), Color(0.015, 0.025, 0.035))
	_box(cabin, "CenterDisplay", Vector3(0.20, 1.37, -0.61), Vector3(0.38, 0.20, 0.045), Color(0.025, 0.12, 0.17))
	_box(cabin, "CenterConsole", Vector3(0.0, 0.91, -0.02), Vector3(0.40, 0.20, 1.0), Color(0.09, 0.10, 0.12), 0.35)
	for side in [-1.0, 1.0]:
		_box(cabin, "SeatBase", Vector3(side * 0.43, 0.91, 0.25), Vector3(0.57, 0.20, 0.72), leather)
		_box(cabin, "SeatBack", Vector3(side * 0.43, 1.27, 0.56), Vector3(0.57, 0.72, 0.20), leather)
		_box(cabin, "HeadRest", Vector3(side * 0.43, 1.72, 0.59), Vector3(0.38, 0.25, 0.18), leather)
		_box(cabin, "DoorCard", Vector3(side * 0.79, 1.02, 0.10), Vector3(0.06, 0.44, 1.42), dark)
	# Steering column and visible wheel ring approximation.
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = Vector3(-0.40, 1.40, -0.47)
	cabin.add_child(steering_wheel)
	var rim := _cylinder(steering_wheel, "SteeringRim", Vector3.ZERO, 0.22, 0.045, Color(0.025, 0.03, 0.035))
	rim.rotation.x = PI / 2.0
	_box(steering_wheel, "SteeringSpoke", Vector3(0, 0, 0), Vector3(0.04, 0.34, 0.035), Color(0.45, 0.46, 0.48), 0.6)
	_box(cabin, "GearSelector", Vector3(0.20, 1.07, 0.05), Vector3(0.10, 0.28, 0.10), Color(0.32, 0.33, 0.35), 0.7)
	for x in [-0.34, -0.12, 0.12]:
		_box(cabin, "Pedal", Vector3(x, 0.79, -0.60), Vector3(0.10, 0.045, 0.16), Color(0.35, 0.36, 0.38), 0.6)
	dashboard_label = Label3D.new()
	dashboard_label.text = "0 km/h   P"
	dashboard_label.font_size = 32
	dashboard_label.position = Vector3(-0.39, 1.43, -0.52)
	dashboard_label.modulate = Color(0.35, 0.95, 0.70)
	cabin.add_child(dashboard_label)

	# Hinged doors that can be opened while parked.
	left_door = _make_door(-1.0)
	right_door = _make_door(1.0)

	# Headlamps and brake/tail lamps.
	for side in [-1.0, 1.0]:
		_box(self, "HeadlampLens", Vector3(side * 0.69, 0.86, -2.06), Vector3(0.42, 0.20, 0.055), Color(0.92, 0.88, 0.68), 0.1)
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side * 0.69, 0.88, -2.02)
		lamp.rotation_degrees = Vector3(-8, 0, 0)
		lamp.spot_range = 28.0
		lamp.spot_angle = 34.0
		lamp.light_energy = 2.0
		lamp.visible = false
		add_child(lamp)
		headlamps.append(lamp)
		var tail := _box(self, "BrakeTailLamp", Vector3(side * 0.69, 0.86, 2.06), Vector3(0.42, 0.20, 0.055), Color(0.30, 0.025, 0.02))
		tail_lamps.append(tail)
		var front_indicator := _box(self, "FrontIndicator", Vector3(side * 0.91, 0.76, -2.075), Vector3(0.16, 0.10, 0.045), Color(1.0, 0.48, 0.04))
		var rear_indicator := _box(self, "RearIndicator", Vector3(side * 0.91, 0.76, 2.075), Vector3(0.16, 0.10, 0.045), Color(1.0, 0.48, 0.04))
		front_indicator.visible = false
		rear_indicator.visible = false
		if side < 0.0:
			left_indicator_lamps.append(front_indicator)
			left_indicator_lamps.append(rear_indicator)
		else:
			right_indicator_lamps.append(front_indicator)
			right_indicator_lamps.append(rear_indicator)
	tail_material = _mat(Color(0.30, 0.025, 0.02), 0.1)
	brake_material = _mat(Color(1.0, 0.025, 0.015), 0.1)
	# Exhaust outlet.
	_cylinder(self, "Exhaust", Vector3(0.62, 0.38, 2.12), 0.075, 0.18, Color(0.24, 0.25, 0.27), 0.8).rotation.x = PI / 2.0

func _make_door(side: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(side * 0.82, 1.0, -0.55)
	add_child(hinge)
	_box(hinge, "DoorPanel", Vector3(side * 0.40, 0, 0.48), Vector3(0.10, 0.56, 1.18), Color(0.12, 0.29, 0.62), 0.55)
	_box(hinge, "DoorWindow", Vector3(side * 0.40, 0.38, 0.48), Vector3(0.055, 0.34, 1.05), Color(0.12, 0.22, 0.29), 0.2)
	return hinge

func _build_cameras() -> void:
	vehicle_camera = Camera3D.new()
	vehicle_camera.name = "ChaseCamera"
	vehicle_camera.position = Vector3(0, 3.7, 8.2)
	add_child(vehicle_camera)
	vehicle_camera.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)
	vehicle_camera.current = false
	interior_camera = Camera3D.new()
	interior_camera.name = "DriverCamera"
	interior_camera.position = Vector3(-0.38, 1.62, -0.28)
	interior_camera.rotation_degrees = Vector3(-4, 0, 0)
	add_child(interior_camera)
	interior_camera.current = false

func _build_controls() -> void:
	controls_layer = CanvasLayer.new()
	controls_layer.name = "VehicleControls"
	add_child(controls_layer)
	controls_panel = PanelContainer.new()
	var panel := controls_panel
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250
	panel.offset_right = -10
	panel.offset_top = 125
	panel.offset_bottom = 560
	controls_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	enter_button = _button(col, "سوار خودرو", _toggle_vehicle)
	var row := HBoxContainer.new()
	col.add_child(row)
	_hold_button(row, "◀ فرمان", "left")
	_hold_button(row, "گاز", "accelerate")
	var row2 := HBoxContainer.new()
	col.add_child(row2)
	_hold_button(row2, "فرمان ▶", "right")
	_hold_button(row2, "ترمز", "brake")
	var row3 := HBoxContainer.new()
	col.add_child(row3)
	_hold_button(row3, "ترمز دستی", "handbrake")
	_button(row3, "دنده", _cycle_gear)
	_button(row3, "کلاچ", _toggle_clutch)
	var row4 := HBoxContainer.new()
	col.add_child(row4)
	_button(row4, "دوربین", _toggle_camera)
	_button(row4, "چراغ", _toggle_lights)
	var row5 := HBoxContainer.new()
	col.add_child(row5)
	_button(row5, "درها", _toggle_doors)
	_button(row5, "راهنما", _cycle_indicators)
	var row6 := HBoxContainer.new()
	col.add_child(row6)
	_button(row6, "کاپوت", _toggle_hood)
	_button(row6, "صندوق", _toggle_trunk)
	var row7 := HBoxContainer.new()
	col.add_child(row7)
	_button(row7, "کولر/بخاری", _cycle_climate)
	_button(row7, "گیربکس", _toggle_transmission)
	_button(row7, "مدل خودرو", _cycle_vehicle_model)
	climate_label = Label.new()
	climate_label.text = "تهویه: خاموش | دمای کابین: ۲۲°"
	col.add_child(climate_label)
	transmission_label = Label.new()
	transmission_label.text = "گیربکس: اتومات"
	col.add_child(transmission_label)
	speed_label = Label.new()
	speed_label.text = "سرعت: ۰ km/h"
	col.add_child(speed_label)
	gear_label = Label.new()
	gear_label.text = "دنده: P"
	col.add_child(gear_label)
	controls_panel.visible = false
	var model_button := Button.new()
	model_button.text = "انتخاب خودرو: دنا"
	model_button.name = "ModelSelector"
	model_button.position = Vector2(18, 82)
	model_button.custom_minimum_size = Vector2(190, 48)
	controls_layer.add_child(model_button)
	model_button.pressed.connect(_cycle_vehicle_model)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(100, 42)
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func _hold_button(parent: Node, caption: String, action: String) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(105, 48)
	parent.add_child(b)
	b.button_down.connect(_set_control.bind(action, true))
	b.button_up.connect(_set_control.bind(action, false))

func _set_control(action: String, pressed: bool) -> void:
	match action:
		"accelerate": throttle = 1.0 if pressed else 0.0
		"brake": throttle = -1.0 if pressed else 0.0
		"left": steering = -1.0 if pressed else 0.0
		"right": steering = 1.0 if pressed else 0.0
		"handbrake": handbrake = pressed


func _toggle_clutch() -> void:
	if not occupied or transmission_mode != "manual":
		return
	clutch_pressed = not clutch_pressed
	if speed_label:
		speed_label.text = "کلاچ گرفته شد" if clutch_pressed else "کلاچ رها شد"

func _toggle_transmission() -> void:
	if not occupied or absf(current_speed) > 0.5:
		return
	transmission_mode = "manual" if transmission_mode == "automatic" else "automatic"
	clutch_pressed = transmission_mode == "automatic"
	if transmission_label:
		transmission_label.text = "گیربکس: دستی" if transmission_mode == "manual" else "گیربکس: اتومات"
	if gear == "P":
		gear = "N"
	_update_gear_label()

func _cycle_climate() -> void:
	if not occupied:
		return
	var modes := ["off", "cool", "heat"]
	var idx := modes.find(climate_mode)
	climate_mode = modes[(idx + 1) % modes.size()]
	target_temperature = 22.0
	if climate_mode == "cool":
		target_temperature = 18.0
	elif climate_mode == "heat":
		target_temperature = 28.0
	_update_climate_label()

func _update_climate_label() -> void:
	if climate_label:
		var mode_text := "خاموش" if climate_mode == "off" else ("کولر" if climate_mode == "cool" else "بخاری")
		climate_label.text = "تهویه: %s | دمای کابین: %.1f°" % [mode_text, cabin_temperature]

func _toggle_hood() -> void:
	if not occupied or absf(current_speed) > 0.5:
		return
	hood_open = not hood_open
	hood_hinge.rotation.x = -0.82 if hood_open else 0.0

func _toggle_trunk() -> void:
	if not occupied or absf(current_speed) > 0.5:
		return
	trunk_open = not trunk_open
	trunk_hinge.rotation.x = 0.72 if trunk_open else 0.0

func _cycle_vehicle_model() -> void:
	if occupied or absf(current_speed) > 0.1:
		return
	model_index = (model_index + 1) % VEHICLE_CATALOG.size()
	var spec: Dictionary = VEHICLE_CATALOG[model_index]
	vehicle_name = str(spec.name)
	max_forward_speed = float(spec.speed)
	acceleration = float(spec.accel)
	var body := get_node_or_null("BodyShell") as MeshInstance3D
	if body:
		var material := body.material_override as StandardMaterial3D
		if material:
			material.albedo_color = spec.color
	var roof := get_node_or_null("Roof") as MeshInstance3D
	if roof:
		var roof_material := roof.material_override as StandardMaterial3D
		if roof_material:
			roof_material.albedo_color = spec.color.darkened(0.18)
	var body_scale: Vector3 = spec.scale
	if body:
		body.scale = body_scale
	var roof_node := get_node_or_null("Roof") as MeshInstance3D
	if roof_node:
		roof_node.scale = Vector3(body_scale.x, body_scale.y, body_scale.z)
	for wheel in wheel_nodes:
		wheel.scale = Vector3(body_scale.x, body_scale.y, body_scale.y)
	for part_name in ["HoodPanel", "TrunkPanel", "DoorPanel"]:
		for part in find_children(part_name, "MeshInstance3D", true, false):
			var part_material := part.material_override as StandardMaterial3D
			if part_material:
				part_material.albedo_color = spec.color
	var model_button := controls_layer.get_node_or_null("ModelSelector") as Button
	if model_button:
		model_button.text = "انتخاب خودرو: " + vehicle_name
	if speed_label:
		speed_label.text = "خودرو انتخاب شد: " + vehicle_name

func _toggle_vehicle() -> void:
	if driver == null:
		return
	if not occupied:
		if global_position.distance_to(driver.global_position) > 7.0:
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
		controls_panel.visible = true
	else:
		if absf(current_speed) > 1.0:
			speed_label.text = "برای پیاده شدن توقف کن"
			return
		occupied = false
		current_speed = 0.0
		velocity = Vector3.ZERO
		driver.global_position = global_position + global_transform.basis.x * 2.5 + Vector3(0, 0.25, 0)
		driver.show()
		driver.set_physics_process(true)
		vehicle_camera.current = false
		interior_camera.current = false
		if player_camera:
			player_camera.current = true
		enter_button.text = "سوار خودرو"
		controls_panel.visible = false
		throttle = 0.0
		steering = 0.0
		gear = "P"
		_update_gear_label()

func _cycle_gear() -> void:
	if not occupied or absf(current_speed) > 1.0:
		return
	if transmission_mode == "manual":
		if not clutch_pressed:
			if speed_label:
				speed_label.text = "برای تعویض دنده کلاچ بگیر"
			return
		var manual_gears := ["N", "1", "2", "3", "4", "5", "R"]
		var manual_idx := manual_gears.find(gear)
		gear = manual_gears[(manual_idx + 1) % manual_gears.size()]
	else:
		var automatic_gears := ["P", "R", "N", "D"]
		var automatic_idx := automatic_gears.find(gear)
		gear = automatic_gears[(automatic_idx + 1) % automatic_gears.size()]
	_update_gear_label()

func _update_gear_label() -> void:
	if gear_label:
		gear_label.text = "دنده: " + gear
	if dashboard_label:
		dashboard_label.text = "%d km/h   %s" % [int(absf(current_speed) * 3.6), gear]

func _toggle_camera() -> void:
	if not occupied:
		return
	interior_camera_on = not interior_camera_on
	vehicle_camera.current = not interior_camera_on
	interior_camera.current = interior_camera_on

func _toggle_lights() -> void:
	lights_on = not lights_on
	for lamp in headlamps:
		lamp.visible = lights_on

func _toggle_doors() -> void:
	if absf(current_speed) > 0.5:
		return
	var open_now := absf(left_door.rotation.y) < 0.1
	left_door.rotation.y = -0.95 if open_now else 0.0
	right_door.rotation.y = 0.95 if open_now else 0.0

func _cycle_indicators() -> void:
	indicators = (indicators + 1) % 3
	if speed_label:
		var suffix := "خاموش" if indicators == 0 else ("چپ" if indicators == 1 else "راست")
		speed_label.text = "راهنما: " + suffix

func _process(_delta: float) -> void:
	var blink_on := (Time.get_ticks_msec() / 450) % 2 == 0
	for lamp in left_indicator_lamps:
		lamp.visible = indicators == 1 and blink_on
	for lamp in right_indicator_lamps:
		lamp.visible = indicators == 2 and blink_on

func apply_impact(impact_speed: float) -> void:
	current_speed = move_toward(current_speed, 0.0, impact_speed * 1.8)
	if speed_label:
		speed_label.text = "تصادف! سرعت کاهش یافت"

func _physics_process(delta: float) -> void:
	if not occupied:
		return
	var key_throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_throttle = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_throttle = -1.0
	var active_throttle := key_throttle if key_throttle != 0.0 else throttle
	var key_steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_steer -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_steer += 1.0
	var active_steer := key_steer if key_steer != 0.0 else steering
	if gear == "P" or gear == "N" or handbrake:
		active_throttle = 0.0
	elif gear == "R":
		active_throttle = -absf(active_throttle)
	elif gear == "D" or gear in ["1", "2", "3", "4", "5"]:
		active_throttle = maxf(active_throttle, 0.0)
	if transmission_mode == "manual" and not clutch_pressed:
		active_throttle = 0.0
	if active_throttle > 0.0:
		var gear_limit := max_forward_speed
		if transmission_mode == "manual":
			var gear_number := int(gear)
			gear_limit = max_forward_speed * (0.22 + float(gear_number) * 0.16)
		current_speed = move_toward(current_speed, gear_limit, acceleration * delta)
	elif active_throttle < 0.0:
		if current_speed > 0.5:
			current_speed = move_toward(current_speed, 0.0, brake_strength * delta)
		else:
			current_speed = move_toward(current_speed, -max_reverse_speed, acceleration * 0.6 * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, (brake_strength if handbrake else 3.2) * delta)
	if absf(current_speed) > 0.12:
		rotation.y += active_steer * steering_speed * delta * clampf(absf(current_speed) / 7.0, 0.2, 1.0) * signf(current_speed)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	var speed_before_collision := absf(current_speed)
	move_and_slide()
	if get_slide_collision_count() > 0:
		for collision_index in range(get_slide_collision_count()):
			var impact := get_slide_collision(collision_index)
			if absf(impact.get_normal().y) < 0.65 and speed_before_collision > 3.0:
				current_speed = move_toward(current_speed, 0.0, maxf(brake_strength, speed_before_collision * 2.0) * delta * 3.0)
				if impact.get_collider() is CharacterBody3D:
					var other := impact.get_collider() as CharacterBody3D
					if other.has_method("apply_impact"):
						other.apply_impact(speed_before_collision)
				break
	for wheel in wheel_nodes:
		wheel.rotate_x(current_speed * delta / 0.39)
	if steering_wheel:
		steering_wheel.rotation.z = -active_steer * 0.65
	if climate_mode != "off":
		cabin_temperature = move_toward(cabin_temperature, target_temperature, delta * 0.22)
	else:
		cabin_temperature = move_toward(cabin_temperature, 22.0, delta * 0.035)
	if driver and driver.has_method("set_body_temperature"):
		driver.set_body_temperature(cabin_temperature)
	_update_climate_label()
	var braking := active_throttle < 0.0 or handbrake
	if braking != brake_lights_active:
		brake_lights_active = braking
		for tail in tail_lamps:
			tail.material_override = brake_material if braking else tail_material
	if speed_label:
		speed_label.text = "سرعت: %d km/h" % int(absf(current_speed) * 3.6)
	_update_gear_label()
