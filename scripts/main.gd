extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STAGE2_SCRIPT = preload("res://scripts/city_stage2.gd")
const NETWORK_SCRIPT = preload("res://scripts/network_manager.gd")
const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")
const GRAPHICS_SCRIPT = preload("res://scripts/graphics_settings.gd")
const CITY_FEATURES_SCRIPT = preload("res://scripts/city_features.gd")
const VEHICLE_SCRIPT = preload("res://scripts/vehicle_controller.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
var player: CharacterBody3D
var network_manager: Node
var ownership_ledger: Node
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var city_features: Node
var vehicle_controller: CharacterBody3D

func _ready() -> void:
	_build_world()
	_build_player()
	_build_vehicle()
	_build_city_features()
	_build_mobile_controls()
	_build_graphics_settings()
	_build_stage_two()
	_build_network()

func _material(color: Color, roughness_value: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material

func _add_box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	body.position = pos
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

func _add_cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = title
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(color)
	mesh_node.position = pos
	parent.add_child(mesh_node)
	return mesh_node

func _add_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "StreetTree"
	tree.position = pos
	add_child(tree)
	_add_cylinder(tree, "TreeTrunk", Vector3(0, 1.0, 0), 0.18, 2.0, Color(0.30, 0.18, 0.10))
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.05
	crown_mesh.height = 2.0
	crown.mesh = crown_mesh
	crown.material_override = _material(Color(0.12, 0.34, 0.16))
	crown.position.y = 2.35
	tree.add_child(crown)

func _add_streetlight(pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "StreetLight"
	lamp.position = pos
	add_child(lamp)
	_add_cylinder(lamp, "LampPole", Vector3(0, 2.5, 0), 0.075, 5.0, Color(0.16, 0.17, 0.19))
	_add_box(lamp, "LampArm", Vector3(0.45, 4.85, 0), Vector3(0.95, 0.09, 0.09), Color(0.16, 0.17, 0.19), false)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.18
	bulb_mesh.height = 0.25
	bulb.mesh = bulb_mesh
	var glow := _material(Color(1.0, 0.83, 0.48))
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.66, 0.28)
	glow.emission_energy_multiplier = 1.4
	bulb.material_override = glow
	bulb.position = Vector3(0.85, 4.75, 0)
	lamp.add_child(bulb)
	var lamp_light := OmniLight3D.new()
	lamp_light.position = Vector3(0.85, 4.55, 0)
	lamp_light.light_color = Color(1.0, 0.78, 0.48)
	lamp_light.light_energy = 0.65
	lamp_light.omni_range = 8.0
	lamp.add_child(lamp_light)

func _build_city_details() -> void:
	# Raised pedestrian paths alongside the two main roads.
	_add_box(self, "Sidewalk_North", Vector3(11.2, 0.12, 0), Vector3(3.8, 0.24, 230), Color(0.48, 0.49, 0.47), false)
	_add_box(self, "Sidewalk_South", Vector3(-11.2, 0.12, 0), Vector3(3.8, 0.24, 230), Color(0.48, 0.49, 0.47), false)
	_add_box(self, "Sidewalk_East", Vector3(0, 0.12, 11.2), Vector3(230, 0.24, 3.8), Color(0.48, 0.49, 0.47), false)
	_add_box(self, "Sidewalk_West", Vector3(0, 0.12, -11.2), Vector3(230, 0.24, 3.8), Color(0.48, 0.49, 0.47), false)
	for i in range(-90, 91, 30):
		_add_streetlight(Vector3(14.0, 0.0, float(i)))
		_add_streetlight(Vector3(-14.0, 0.0, float(i)))
		_add_streetlight(Vector3(float(i), 0.0, 14.0))
		_add_streetlight(Vector3(float(i), 0.0, -14.0))
	for i in range(-84, 85, 28):
		_add_tree(Vector3(16.5, 0.0, float(i)))
		_add_tree(Vector3(-16.5, 0.0, float(i)))
		_add_tree(Vector3(float(i), 0.0, 16.5))
		_add_tree(Vector3(float(i), 0.0, -16.5))
	# Small public seating areas beside the central avenue.
	for side in [-1.0, 1.0]:
		var bench_pos := Vector3(side * 20.0, 0.0, 0.0)
		_add_box(self, "ParkBenchSeat", bench_pos + Vector3(0, 0.55, 0), Vector3(1.8, 0.16, 0.55), Color(0.34, 0.20, 0.10), false)
		_add_box(self, "ParkBenchBack", bench_pos + Vector3(0, 0.95, -0.22), Vector3(1.8, 0.65, 0.12), Color(0.34, 0.20, 0.10), false)

func _build_world() -> void:
	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.69, 0.8)
	env.ambient_light_energy = 0.7
	world_environment.environment = env
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	_add_box(self, "City Ground", Vector3(0, -0.3, 0), Vector3(230, 0.5, 230), Color(0.22, 0.34, 0.25))
	_add_box(self, "Main Road", Vector3(0, 0.0, 0), Vector3(18, 0.08, 230), Color(0.11, 0.12, 0.14), false)
	_add_box(self, "Cross Road", Vector3(0, 0.01, 0), Vector3(230, 0.08, 18), Color(0.11, 0.12, 0.14), false)
	for i in range(-96, 97, 12):
		_add_box(self, "Road Marking", Vector3(0, 0.06, i), Vector3(0.18, 0.025, 4.5), Color(0.92, 0.88, 0.62), false)
		_add_box(self, "Road Marking", Vector3(i, 0.06, 0), Vector3(4.5, 0.025, 0.18), Color(0.92, 0.88, 0.62), false)
	var colors := [Color(0.55, 0.61, 0.68), Color(0.68, 0.58, 0.48), Color(0.46, 0.57, 0.65), Color(0.64, 0.67, 0.58)]
	for x in range(-4, 5):
		for z in range(-4, 5):
			if abs(x) < 2 and abs(z) < 2:
				continue
			var px := float(x) * 24.0
			var pz := float(z) * 24.0
			var height := float(9 + ((abs(x * 7 + z * 11) * 13) % 20))
			var width := 10.0 + float((abs(x + z) % 3) * 1.5)
			var color: Color = colors[abs(x * 3 + z * 5) % colors.size()]
			_add_box(self, "Building_%d_%d" % [x, z], Vector3(px, height / 2.0, pz), Vector3(width, height, 11), color)
	_add_service("BANK CENTRAL", Vector3(-29, 4, 28), Color(0.72, 0.61, 0.25))
	_add_service("CITY BANK", Vector3(29, 4, 28), Color(0.2, 0.48, 0.76))
	_add_service("CAR DEALERSHIP", Vector3(0, 4, 50), Color(0.2, 0.62, 0.48))
	_add_service("GOVERNMENT", Vector3(0, 4, -50), Color(0.36, 0.4, 0.52))
	_add_service("MINISTRY OF INTELLIGENCE", Vector3(-55, 4, -55), Color(0.25, 0.29, 0.38))
	_add_service("PRESIDENTIAL PALACE", Vector3(55, 4, -55), Color(0.68, 0.57, 0.32))
	_add_service("ARMED FORCES HQ", Vector3(55, 4, 55), Color(0.30, 0.39, 0.34))
	_add_service("VEHICLE REPAIR GARAGE", Vector3(-55, 4, 55), Color(0.34, 0.38, 0.42))
	_build_city_details()

func _add_service(label_text: String, pos: Vector3, color: Color) -> void:
	_add_box(self, label_text, pos, Vector3(17, 8, 13), color)
	var label := Label3D.new()
	label.text = label_text
	label.position = pos + Vector3(0, 5.2, 6.7)
	label.font_size = 32
	label.modulate = Color.WHITE
	add_child(label)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.2, 12)
	add_child(player)

func _build_mobile_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CharacterControls"
	add_child(layer)
	var joystick := Control.new()
	joystick.name = "CharacterJoystick"
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick.custom_minimum_size = Vector2(176, 176)
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 28.0
	joystick.offset_top = -204.0
	joystick.offset_right = 204.0
	joystick.offset_bottom = -28.0
	layer.add_child(joystick)
	joystick.vector_changed.connect(player.set_mobile_direction)

func _build_city_features() -> void:
	city_features = Node3D.new()
	city_features.name = "CityFeatures"
	city_features.set_script(CITY_FEATURES_SCRIPT)
	add_child(city_features)
	city_features.configure(player, world_environment, sun)

func _build_graphics_settings() -> void:
	var graphics_layer := CanvasLayer.new()
	graphics_layer.name = "GraphicsSettings"
	graphics_layer.set_script(GRAPHICS_SCRIPT)
	add_child(graphics_layer)
	graphics_layer.configure(world_environment, sun, player)

func _build_stage_two() -> void:
	ownership_ledger = Node.new()
	ownership_ledger.name = "OwnershipLedger"
	ownership_ledger.set_script(LEDGER_SCRIPT)
	add_child(ownership_ledger)
	var systems := Node.new()
	systems.name = "Stage2Systems"
	systems.set_script(STAGE2_SCRIPT)
	add_child(systems)
	systems.set_ownership_ledger(ownership_ledger)

func _build_network() -> void:
	network_manager = Node.new()
	network_manager.name = "NetworkManager"
	network_manager.set_script(NETWORK_SCRIPT)
	add_child(network_manager)
	network_manager.set_local_player(player)

func _build_vehicle() -> void:
	vehicle_controller = CharacterBody3D.new()
	vehicle_controller.name = "CityVehicle"
	vehicle_controller.set_script(VEHICLE_SCRIPT)
	vehicle_controller.position = Vector3(4.0, 0.2, 7.0)
	add_child(vehicle_controller)
	vehicle_controller.configure(player)

func _style_mobile_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2878d5")
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color("9bc8f5")
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("3689e8")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1e5eaa")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
