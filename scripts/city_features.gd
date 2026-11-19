extends Node3D
## Procedural city systems: day/night, weather, traffic, facades and simple enterable interiors.

var player: CharacterBody3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var rain: GPUParticles3D
var traffic_cars: Array[Node3D] = []
var traffic_origins: Array[Vector3] = []
var interior_positions: Dictionary = {}
var inside_building := false
var previous_position := Vector3.ZERO
var pedestrians: Array[Node3D] = []
var pedestrian_origins: Array[Vector3] = []
var day_clock := 0.28
var weather_mode := "sunny"
var weather_panel: PanelContainer

const SERVICE_BUILDINGS := [
	{"name": "بانک مرکزی", "id": "central_bank", "color": Color(0.68, 0.59, 0.31)},
	{"name": "بانک شهری", "id": "city_bank", "color": Color(0.25, 0.48, 0.72)},
	{"name": "نمایشگاه خودرو", "id": "dealership", "color": Color(0.20, 0.57, 0.43)},
	{"name": "ساختمان دولت", "id": "government", "color": Color(0.36, 0.40, 0.52)},
	{"name": "وزارت اطلاعات", "id": "intelligence", "color": Color(0.25, 0.29, 0.38)},
	{"name": "کاخ ریاست جمهوری", "id": "palace", "color": Color(0.68, 0.57, 0.32)},
	{"name": "ستاد کل نیروهای مسلح", "id": "military", "color": Color(0.30, 0.39, 0.34)},
	{"name": "تعمیرگاه خودرو", "id": "repair_garage", "color": Color(0.34, 0.38, 0.42)},
	{"name": "دفتر املاک", "id": "real_estate", "color": Color(0.52, 0.42, 0.28)},
	{"name": "مرکز مخابرات", "id": "telecom", "color": Color(0.20, 0.46, 0.62)},
	{"name": "زندان مرکزی", "id": "prison", "color": Color(0.34, 0.30, 0.29)},
	{"name": "شهرداری", "id": "city_hall", "color": Color(0.48, 0.56, 0.43)},
	{"name": "محضر ازدواج", "id": "marriage_office", "color": Color(0.72, 0.62, 0.42)},
	{"name": "تالار عروسی", "id": "wedding_hall", "color": Color(0.72, 0.36, 0.48)}
]

func configure(player_node: CharacterBody3D, env_node: WorldEnvironment, sun_node: DirectionalLight3D) -> void:
	player = player_node
	world_environment = env_node
	sun = sun_node
	_build_traffic()
	_build_pedestrians()
	_build_interiors()
	_build_weather()
	_build_controls()

func _process(delta: float) -> void:
	day_clock = fposmod(day_clock + delta / 1440.0, 1.0)
	_update_day_night()
	for i in range(pedestrians.size()):
		var walker := pedestrians[i]
		walker.position.x += sin(Time.get_ticks_msec() * 0.0004 + float(i)) * delta * 0.7
		walker.position.z += delta * (0.45 + float(i % 2) * 0.2)
		if walker.position.z > 18.0:
			walker.position = pedestrian_origins[i]
	if rain:
		rain.emitting = weather_mode == "rain"

func _mat(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.7
	return material

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = _mat(color)
	item.position = pos
	parent.add_child(item)
	return item

func _build_facades() -> void:
	# Decorative windows and cornices on the seven public buildings.
	var positions := [
		Vector3(-29, 4, 28), Vector3(29, 4, 28), Vector3(0, 4, 50),
		Vector3(0, 4, -50), Vector3(-55, 4, -55), Vector3(55, 4, -55), Vector3(55, 4, 55),
		Vector3(-55, 4, 55), Vector3(-29, 4, -28), Vector3(29, 4, -28), Vector3(0, 4, 82)
	]
	for i in range(positions.size()):
		var p: Vector3 = positions[i]
		var facade := Node3D.new()
		facade.name = "FacadeDetails_%d" % i
		facade.position = p
		add_child(facade)
		for floor_index in range(1, 4):
			for window_index in range(4):
				var wx := -5.7 + float(window_index) * 3.8
				_box(facade, "FrontWindow", Vector3(wx, -2.0 + float(floor_index) * 1.75, 6.57), Vector3(1.35, 1.05, 0.10), Color(0.12, 0.25, 0.34))
				_box(facade, "WindowFrame", Vector3(wx, -2.0 + float(floor_index) * 1.75, 6.64), Vector3(1.48, 1.18, 0.05), Color(0.78, 0.76, 0.68))
		_box(facade, "EntranceCanopy", Vector3(0, -2.0, 7.15), Vector3(4.0, 0.25, 1.6), Color(0.18, 0.19, 0.22))

func _build_traffic() -> void:
	for i in range(4):
		var car := CharacterBody3D.new()
		car.name = "AmbientTraffic_%d" % i
		car.position = Vector3(-5.5 if i % 2 == 0 else 5.5, 0.65, -90.0 + float(i) * 48.0)
		var car_collision := CollisionShape3D.new()
		var car_shape := BoxShape3D.new()
		car_shape.size = Vector3(2.0, 1.25, 3.9)
		car_collision.shape = car_shape
		car.add_child(car_collision)
		car.set_meta("traffic_speed", 7.0 + float(i % 3) * 1.8)
		car.set_meta("traffic_blocked", false)
		add_child(car)
		var paints: Array[Color] = [Color(0.72, 0.12, 0.10), Color(0.12, 0.28, 0.66), Color(0.78, 0.78, 0.72), Color(0.12, 0.13, 0.14)]
		var paint: Color = paints[i]
		_box(car, "CarBody", Vector3.ZERO, Vector3(2.0, 0.72, 3.8), paint)
		_box(car, "Cabin", Vector3(0, 0.55, -0.2), Vector3(1.55, 0.72, 1.8), Color(0.12, 0.20, 0.27))
		for side in [-1.0, 1.0]:
			for axle in [-1.0, 1.0]:
				var wheel := MeshInstance3D.new()
				var wheel_mesh := CylinderMesh.new()
				wheel_mesh.top_radius = 0.34
				wheel_mesh.bottom_radius = 0.34
				wheel_mesh.height = 0.2
				wheel.mesh = wheel_mesh
				wheel.rotation.z = PI / 2.0
				wheel.position = Vector3(side * 1.02, -0.18, axle * 1.2)
				wheel.material_override = _mat(Color(0.035, 0.035, 0.04))
				car.add_child(wheel)
		traffic_cars.append(car)

func _physics_process(delta: float) -> void:
	for car in traffic_cars:
		if not is_instance_valid(car):
			continue
		var speed := float(car.get_meta("traffic_speed", 7.0))
		car.velocity = Vector3(0.0, -2.0, speed)
		var collision: KinematicCollision3D = car.move_and_collide(car.velocity * delta)
		if collision:
			car.velocity = Vector3.ZERO
			car.set_meta("traffic_blocked", true)

func _build_pedestrians() -> void:
	for i in range(6):
		var walker := Node3D.new()
		walker.name = "CityPedestrian_%d" % i
		var start := Vector3(-10.0 + float(i) * 3.8, 0.0, -16.0 - float(i % 2) * 2.0)
		walker.position = start
		add_child(walker)
		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.27
		body_mesh.height = 1.15
		body.mesh = body_mesh
		body.position.y = 0.95
		body.material_override = _mat([Color(0.15, 0.32, 0.62), Color(0.55, 0.22, 0.16), Color(0.18, 0.42, 0.28)][i % 3])
		walker.add_child(body)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.19
		head_mesh.height = 0.38
		head.mesh = head_mesh
		head.position.y = 1.68
		head.material_override = _mat(Color(0.72, 0.52, 0.39))
		walker.add_child(head)
		pedestrians.append(walker)
		pedestrian_origins.append(start)

func _add_floor_collision(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	body.position = pos
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)

func _build_interiors() -> void:
	for i in range(SERVICE_BUILDINGS.size()):
		var entry: Dictionary = SERVICE_BUILDINGS[i]
		var room_pos := Vector3(300.0 + float(i) * 24.0, 0.0, 0.0)
		interior_positions[str(entry.id)] = room_pos
		var room := Node3D.new()
		room.name = "Interior_" + str(entry.id)
		room.position = room_pos
		add_child(room)
		_box(room, "InteriorFloor", Vector3(0, -0.12, 0), Vector3(13, 0.24, 11), Color(0.42, 0.40, 0.36))
		_add_floor_collision(room, Vector3(0, -0.12, 0), Vector3(13, 0.24, 11))
		_add_floor_collision(room, Vector3(0, 2.0, -5.5), Vector3(13, 4.0, 0.25))
		_add_floor_collision(room, Vector3(-6.5, 2.0, 0), Vector3(0.25, 4.0, 11))
		_add_floor_collision(room, Vector3(6.5, 2.0, 0), Vector3(0.25, 4.0, 11))
		_box(room, "BackWall", Vector3(0, 2.0, -5.5), Vector3(13, 4.0, 0.25), Color(0.72, 0.70, 0.64))
		_box(room, "LeftWall", Vector3(-6.5, 2.0, 0), Vector3(0.25, 4.0, 11), Color(0.66, 0.66, 0.62))
		_box(room, "RightWall", Vector3(6.5, 2.0, 0), Vector3(0.25, 4.0, 11), Color(0.66, 0.66, 0.62))
		_box(room, "Ceiling", Vector3(0, 4.1, 0), Vector3(13, 0.2, 11), Color(0.82, 0.81, 0.76))
		_box(room, "ReceptionDesk", Vector3(0, 0.65, -2.6), Vector3(4.2, 1.3, 1.0), entry.color)
		_box(room, "DeskTop", Vector3(0, 1.34, -2.6), Vector3(4.4, 0.12, 1.1), Color(0.20, 0.18, 0.16))
		var sign := Label3D.new()
		sign.text = str(entry.name)
		sign.font_size = 30
		sign.position = Vector3(0, 2.8, -5.32)
		room.add_child(sign)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.3, 0)
		light.light_energy = 1.1
		light.omni_range = 14.0
		room.add_child(light)
		if str(entry.id) == "prison":
			for cell_index in range(3):
				var cell_x := -4.2 + float(cell_index) * 4.2
				_box(room, "PrisonCellBack_%d" % cell_index, Vector3(cell_x, 1.5, -4.0), Vector3(3.6, 3.0, 0.18), Color(0.25, 0.27, 0.29))
				for bar_index in range(6):
					_box(room, "PrisonBar_%d_%d" % [cell_index, bar_index], Vector3(cell_x - 1.5 + float(bar_index) * 0.6, 1.5, -2.0), Vector3(0.07, 3.0, 0.07), Color(0.12, 0.13, 0.14))
			_box(room, "PrisonGuardDesk", Vector3(0, 0.7, 2.6), Vector3(4.2, 1.4, 1.0), Color(0.22, 0.24, 0.27))
		elif str(entry.id) == "central_bank":
			_box(room, "CentralBankVault", Vector3(4.5, 1.4, -3.4), Vector3(2.8, 2.8, 2.2), Color(0.42, 0.43, 0.46))
			_box(room, "CentralBankVaultDoor", Vector3(4.5, 1.4, -2.25), Vector3(1.5, 2.2, 0.12), Color(0.70, 0.66, 0.52))
		elif str(entry.id) == "palace":
			_box(room, "PresidentialCouncilTable", Vector3(0, 0.55, 1.2), Vector3(5.2, 0.18, 2.0), Color(0.30, 0.19, 0.10))
		elif str(entry.id) == "military":
			_box(room, "MilitaryCommandMap", Vector3(0, 1.8, -4.7), Vector3(4.8, 2.5, 0.12), Color(0.12, 0.30, 0.22))
		elif str(entry.id) == "city_hall":
			_box(room, "CityHallCouncilDesk", Vector3(0, 0.65, -2.6), Vector3(5.0, 1.3, 1.1), Color(0.36, 0.30, 0.20))
			for chair_index in range(6):
				_box(room, "CityHallVisitorChair_%d" % chair_index, Vector3(-4.5 + float(chair_index % 3) * 4.5, 0.55, 1.5 + float(chair_index / 3) * 1.5), Vector3(0.8, 1.1, 0.8), Color(0.22, 0.25, 0.30))
		elif str(entry.id) == "marriage_office":
			_box(room, "MarriageDesk", Vector3(0, 0.72, -2.6), Vector3(4.8, 1.4, 1.0), Color(0.48, 0.31, 0.16))
			_box(room, "MarriageRegistryBook", Vector3(0, 1.48, -2.6), Vector3(1.1, 0.12, 0.8), Color(0.18, 0.32, 0.20))
			for side in [-1.0, 1.0]:
				_box(room, "MarriageWitnessChair", Vector3(side * 3.4, 0.55, -1.0), Vector3(0.9, 1.1, 0.9), Color(0.42, 0.28, 0.18))
			_box(room, "MarriageWallEmblem", Vector3(0, 2.8, -5.25), Vector3(1.5, 1.1, 0.12), Color(0.78, 0.65, 0.30))
		elif str(entry.id) == "wedding_hall":
			_box(room, "WeddingStage", Vector3(0, 0.35, -3.5), Vector3(6.0, 0.7, 2.2), Color(0.78, 0.69, 0.60))
			_box(room, "WeddingArchTop", Vector3(0, 2.6, -4.2), Vector3(5.0, 0.3, 0.35), Color(0.84, 0.70, 0.42))
			for side in [-1.0, 1.0]:
				_box(room, "WeddingArchPillar", Vector3(side * 2.35, 1.5, -4.2), Vector3(0.28, 2.7, 0.3), Color(0.88, 0.82, 0.72))
			for row in range(3):
				for side in [-1.0, 1.0]:
					_box(room, "WeddingGuestChair", Vector3(side * 4.2, 0.55, 1.0 + float(row) * 1.6), Vector3(0.9, 1.1, 0.9), Color(0.72, 0.55, 0.54))
			for flower_index in range(8):
				var flower := MeshInstance3D.new()
				var flower_mesh := SphereMesh.new()
				flower_mesh.radius = 0.22
				flower_mesh.height = 0.3
				flower.mesh = flower_mesh
				flower.material_override = _mat(Color(0.90, 0.70, 0.75))
				flower.position = Vector3(-3.5 + float(flower_index) * 1.0, 1.8, -4.0)
				room.add_child(flower)
		var door_marker := MeshInstance3D.new()
		var door_mesh := BoxMesh.new()
		door_mesh.size = Vector3(2.0, 2.8, 0.18)
		door_marker.mesh = door_mesh
		door_marker.material_override = _mat(Color(0.25, 0.16, 0.10))
		door_marker.position = Vector3(0, 1.3, 5.35)
		room.add_child(door_marker)

func _build_weather() -> void:
	rain = GPUParticles3D.new()
	rain.name = "RainParticles"
	rain.amount = 500
	rain.lifetime = 1.8
	rain.emitting = false
	rain.position = Vector3(0, 10, 0)
	rain.visibility_aabb = AABB(Vector3(-90, -5, -90), Vector3(180, 30, 180))
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.gravity = Vector3(0, -18, 0)
	particle_material.initial_velocity_min = 12.0
	particle_material.initial_velocity_max = 17.0
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(90, 8, 90)
	rain.process_material = particle_material
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.32, 0.025)
	var drop_material := _mat(Color(0.55, 0.68, 0.82))
	drop.material = drop_material
	rain.draw_pass_1 = drop
	add_child(rain)

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CityEnvironmentUI"
	add_child(layer)
	var weather_button := Button.new()
	weather_button.text = "آب‌وهوا"
	weather_button.position = Vector2(18, 18)
	weather_button.custom_minimum_size = Vector2(120, 46)
	layer.add_child(weather_button)
	weather_panel = PanelContainer.new()
	weather_panel.position = Vector2(18, 70)
	weather_panel.visible = false
	layer.add_child(weather_panel)
	var weather_column := VBoxContainer.new()
	weather_panel.add_child(weather_column)
	_add_weather_button(weather_column, "آفتابی", "sunny")
	_add_weather_button(weather_column, "ابری", "cloudy")
	_add_weather_button(weather_column, "بارانی", "rain")
	weather_button.pressed.connect(func(): weather_panel.visible = not weather_panel.visible)

	var enter_button := Button.new()
	enter_button.text = "ورود به ساختمان"
	enter_button.position = Vector2(150, 18)
	enter_button.custom_minimum_size = Vector2(160, 46)
	layer.add_child(enter_button)
	enter_button.pressed.connect(_enter_nearest_building)
	var exit_button := Button.new()
	exit_button.text = "خروج از ساختمان"
	exit_button.position = Vector2(318, 18)
	exit_button.custom_minimum_size = Vector2(150, 46)
	layer.add_child(exit_button)
	exit_button.pressed.connect(_exit_building)

func _add_weather_button(parent: VBoxContainer, caption: String, mode: String) -> void:
	var button := Button.new()
	button.text = caption
	parent.add_child(button)
	button.pressed.connect(func(): set_weather(mode))

func set_weather(mode: String) -> void:
	weather_mode = mode
	if world_environment == null:
		return
	var env := world_environment.environment
	match mode:
		"sunny":
			env.fog_enabled = false
			env.ambient_light_color = Color(0.62, 0.69, 0.8)
			env.ambient_light_energy = 0.75
		"cloudy":
			env.fog_enabled = true
			env.fog_light_color = Color(0.48, 0.53, 0.60)
			env.fog_density = 0.006
			env.ambient_light_color = Color(0.52, 0.56, 0.62)
			env.ambient_light_energy = 0.62
		"rain":
			env.fog_enabled = true
			env.fog_light_color = Color(0.38, 0.44, 0.52)
			env.fog_density = 0.012
			env.ambient_light_color = Color(0.42, 0.48, 0.56)
			env.ambient_light_energy = 0.48
	if weather_panel:
		weather_panel.visible = false

func _update_day_night() -> void:
	var angle := day_clock * TAU
	var daylight := clampf((sin(angle - PI / 2.0) + 0.18) * 1.15, 0.08, 1.0)
	sun.rotation_degrees = Vector3(-90.0 + day_clock * 360.0, -32.0, 0.0)
	sun.light_energy = daylight * (0.72 if weather_mode == "rain" else 1.15)
	sun.light_color = Color(1.0, 0.78, 0.57).lerp(Color(1.0, 0.97, 0.88), daylight)
	if weather_mode == "sunny":
		world_environment.environment.ambient_light_energy = 0.25 + daylight * 0.55

func _enter_nearest_building() -> void:
	if player == null or inside_building:
		return
	var nearest_id := ""
	var nearest_distance := 999999.0
	var positions := [
		Vector3(-29, 4, 28), Vector3(29, 4, 28), Vector3(0, 4, 50),
		Vector3(0, 4, -50), Vector3(-55, 4, -55), Vector3(55, 4, -55), Vector3(55, 4, 55),
		Vector3(-55, 4, 55), Vector3(-29, 4, -28), Vector3(29, 4, -28),
		Vector3(0, 4, 82), Vector3(55, 4, 92), Vector3(-55, 4, 92), Vector3(0, 4, -92)
	]
	for i in range(positions.size()):
		var distance := player.global_position.distance_to(positions[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(SERVICE_BUILDINGS[i].id)
	if nearest_distance > 24.0:
		return
	previous_position = player.global_position
	player.global_position = interior_positions[nearest_id] + Vector3(0, 1.2, 2.8)
	player.velocity = Vector3.ZERO
	inside_building = true

func _exit_building() -> void:
	if player == null or not inside_building:
		return
	player.global_position = previous_position if previous_position != Vector3.ZERO else Vector3(0, 1.2, 12)
	player.velocity = Vector3.ZERO
	inside_building = false
