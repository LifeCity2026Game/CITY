extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STAGE2_SCRIPT = preload("res://scripts/city_stage2.gd")
const NETWORK_SCRIPT = preload("res://scripts/network_manager.gd")
const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")
const GRAPHICS_SCRIPT = preload("res://scripts/graphics_settings.gd")
const CITY_FEATURES_SCRIPT = preload("res://scripts/city_features.gd")
const VEHICLE_SCRIPT = preload("res://scripts/vehicle_controller.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
const SERVICES_SCRIPT = preload("res://scripts/life_city_services.gd")
const MILITARY_SCRIPT = preload("res://scripts/military_command.gd")
const FIREBASE_SCRIPT = preload("res://scripts/firebase_client.gd")
var player: CharacterBody3D
var network_manager: Node
var ownership_ledger: Node
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var city_features: Node
var vehicle_controller: CharacterBody3D
var military_system: Node3D

func _ready() -> void:
	_build_world()
	_build_player()
	_build_vehicle()
	_build_city_features()
	_build_mobile_controls()
	_build_graphics_settings()
	_build_stage_two()
	_build_network()
	_build_firebase_client()
	_build_life_city_services()
	_build_military_command()

func _material(color: Color, roughness_value: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	return material

func _add_box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	if title.begins_with("Building_"):
		body.add_to_group("city_buildings")
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
	_add_box(self, "Ocean", Vector3(0, -0.02, 105), Vector3(230, 0.08, 20), Color(0.035, 0.22, 0.38), false)
	for wave_x in range(-100, 101, 20):
		_add_box(self, "OceanWave", Vector3(float(wave_x), 0.04, 105), Vector3(9, 0.025, 0.12), Color(0.18, 0.48, 0.62), false)
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
			_add_city_building(x, z, Vector3(px, 0.0, pz), width, height, color)
	_add_service("BANK CENTRAL", Vector3(-29, 4, 28), Color(0.72, 0.61, 0.25))
	_add_service("CITY BANK", Vector3(29, 4, 28), Color(0.2, 0.48, 0.76))
	_add_service("CAR DEALERSHIP", Vector3(0, 4, 50), Color(0.2, 0.62, 0.48))
	_add_service("GOVERNMENT", Vector3(0, 4, -50), Color(0.36, 0.4, 0.52))
	_add_service("MINISTRY OF INTELLIGENCE", Vector3(-55, 4, -55), Color(0.25, 0.29, 0.38))
	_add_service("PRESIDENTIAL PALACE", Vector3(55, 4, -55), Color(0.68, 0.57, 0.32))
	_add_service("ARMED FORCES HQ", Vector3(55, 4, 55), Color(0.30, 0.39, 0.34))
	_build_hq_personnel()
	_add_service("VEHICLE REPAIR GARAGE", Vector3(-55, 4, 55), Color(0.34, 0.38, 0.42))
	_add_service("REAL ESTATE OFFICE", Vector3(-29, 4, -28), Color(0.52, 0.42, 0.28))
	_add_service("TELECOM CENTER", Vector3(29, 4, -28), Color(0.20, 0.46, 0.62))
	_add_service("CENTRAL PRISON", Vector3(0, 4, 82), Color(0.34, 0.30, 0.29))
	_add_service("CITY HALL", Vector3(55, 4, 92), Color(0.48, 0.56, 0.43))
	_add_service("MARRIAGE REGISTRY", Vector3(-55, 4, 92), Color(0.72, 0.62, 0.42))
	_add_service("WEDDING HALL", Vector3(0, 4, -92), Color(0.72, 0.36, 0.48))
	_decorate_ceremony_building("MARRIAGE REGISTRY", Vector3(-55, 4, 92), Color(0.82, 0.72, 0.48), false)
	_decorate_ceremony_building("WEDDING HALL", Vector3(0, 4, -92), Color(0.88, 0.73, 0.76), true)
	_build_city_details()


func _add_city_building(grid_x: int, grid_z: int, pos: Vector3, width: float, height: float, facade_color: Color) -> void:
	var building := StaticBody3D.new()
	building.name = "Building_%d_%d" % [grid_x, grid_z]
	building.position = pos
	building.add_to_group("city_buildings")
	add_child(building)
	var body_mesh := MeshInstance3D.new()
	var body_shape := BoxMesh.new()
	body_shape.size = Vector3(width, height, 11.0)
	body_mesh.mesh = body_shape
	body_mesh.position.y = height * 0.5
	body_mesh.material_override = _material(facade_color)
	building.add_child(body_mesh)
	var collision := CollisionShape3D.new()
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(width, height, 11.0)
	collision.shape = collision_shape
	collision.position.y = height * 0.5
	building.add_child(collision)
	var floors := maxi(2, int(floor(height / 3.2)))
	var category_index: int = absi(grid_x * 7 + grid_z * 11) % 8
	var is_shop: bool = category_index == 1 or category_index == 6
	var is_apartment: bool = category_index == 0 or category_index == 5 or category_index == 7
	var trim := facade_color.darkened(0.28)
	var glass := Color(0.12, 0.27, 0.36)
	var frame := Color(0.83, 0.82, 0.75)
	# Ground-floor storefront and a clearly readable pedestrian entrance.
	if is_shop:
		_add_box(building, "ShopfrontGlass", Vector3(0, 1.65, 5.53), Vector3(width * 0.68, 2.65, 0.09), Color(0.16, 0.34, 0.42), false)
		_add_box(building, "ShopSignBoard", Vector3(0, 3.25, 5.62), Vector3(width * 0.82, 0.65, 0.22), trim, false)
		var shop_sign := Label3D.new()
		shop_sign.text = "MARKET" if category_index == 6 else "STORE"
		shop_sign.position = Vector3(0, 3.22, 5.78)
		shop_sign.font_size = 24
		building.add_child(shop_sign)
	else:
		_add_box(building, "EntranceDoor", Vector3(0, 1.2, 5.56), Vector3(1.35, 2.4, 0.12), Color(0.20, 0.15, 0.11), false)
		_add_box(building, "EntranceCanopy", Vector3(0, 2.55, 5.9), Vector3(2.5, 0.18, 1.0), trim, false)
	for floor_index in range(floors):
		var y := 3.6 + float(floor_index) * 3.05
		if y > height - 0.7:
			continue
		var columns := 3 if width < 12.0 else 4
		for window_index in range(columns):
			var wx := -width * 0.34 + float(window_index) * (width * 0.68 / float(columns - 1))
			var window_height := 1.35 if is_apartment else 1.15
			var window_width := 1.55 if is_apartment else 1.75
			_add_box(building, "WindowFrame", Vector3(wx, y, 5.56), Vector3(window_width + 0.18, window_height + 0.18, 0.10), frame, false)
			_add_box(building, "WindowGlass", Vector3(wx, y, 5.63), Vector3(window_width, window_height, 0.06), glass, false)
			if is_apartment and floor_index < floors - 1:
				_add_box(building, "BalconySlab", Vector3(wx, y - 0.95, 6.05), Vector3(2.0, 0.12, 1.0), trim, false)
				_add_box(building, "BalconyRail", Vector3(wx, y - 0.55, 6.48), Vector3(1.9, 0.65, 0.07), frame, false)
		# Side-facing windows break up the long blank elevations.
		for side in [-1.0, 1.0]:
			_add_box(building, "SideWindow", Vector3(side * (width * 0.5 + 0.06), y, -1.8), Vector3(0.08, 1.1, 1.6), glass, false)
	# Vertical pilasters, roof parapet, rooftop equipment and exterior AC units.
	for side in [-1.0, 1.0]:
		_add_box(building, "FacadePilaster", Vector3(side * (width * 0.46), height * 0.5, 5.57), Vector3(0.22, height, 0.18), trim, false)
		_add_box(building, "RoofParapet", Vector3(side * (width * 0.5 - 0.1), height + 0.35, 0), Vector3(0.2, 0.7, 11.0), trim, false)
		_add_box(building, "ExteriorAC", Vector3(side * (width * 0.31), 3.1, 5.8), Vector3(0.8, 0.48, 0.45), Color(0.70, 0.72, 0.73), false)
	_add_box(building, "RoofFrontParapet", Vector3(0, height + 0.35, 5.4), Vector3(width, 0.7, 0.2), trim, false)
	_add_box(building, "RoofRearParapet", Vector3(0, height + 0.35, -5.4), Vector3(width, 0.7, 0.2), trim, false)
	if height > 18.0:
		_add_cylinder(building, "RooftopWaterTank", Vector3(width * 0.25, height + 1.1, -3.3), 0.85, 1.7, Color(0.35, 0.40, 0.43))
		_add_box(building, "RooftopServiceRoom", Vector3(-width * 0.22, height + 0.65, -3.2), Vector3(2.2, 1.3, 2.4), facade_color.darkened(0.12), false)

func _add_service(label_text: String, pos: Vector3, color: Color) -> void:
	var building := Node3D.new()
	building.name = label_text.replace(" ", "_")
	building.add_to_group("city_buildings")
	building.position = pos
	add_child(building)
	_add_box(building, "ServiceFloor", Vector3(0, -3.82, 0), Vector3(17, 0.36, 13), Color(0.24, 0.25, 0.27))
	_add_box(building, "BackWall", Vector3(0, 0, -6.38), Vector3(17, 8, 0.24), color)
	_add_box(building, "LeftWall", Vector3(-8.38, 0, 0), Vector3(0.24, 8, 13), color)
	_add_box(building, "RightWall", Vector3(8.38, 0, 0), Vector3(0.24, 8, 13), color)
	_add_box(building, "Roof", Vector3(0, 3.9, 0), Vector3(17, 0.24, 13), color.darkened(0.18))
	# Front facade is split into pillars and lintels so the glass does not sit over an opaque wall.
	for x in [-7.5, -3.75, 0.0, 3.75, 7.5]:
		_add_box(building, "FacadePillar", Vector3(x, 0, 6.38), Vector3(0.30, 8, 0.28), color.darkened(0.22))
	for y in [-3.55, 3.55]:
		_add_box(building, "FacadeLintel", Vector3(0, y, 6.38), Vector3(17, 0.55, 0.28), color.darkened(0.12))
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.24, 0.62, 0.82, 0.30)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.roughness = 0.12
	for row in range(2):
		for column in range(4):
			var glass := MeshInstance3D.new()
			glass.name = "TransparentShopWindow"
			var pane := BoxMesh.new()
			pane.size = Vector3(3.25, 2.55, 0.07)
			glass.mesh = pane
			glass.material_override = glass_material
			glass.position = Vector3(-5.625 + float(column) * 3.75, -1.65 + float(row) * 3.25, 6.38)
			building.add_child(glass)
	_add_box(building, "ReceptionCounter", Vector3(0, -1.7, 1.6), Vector3(4.8, 1.1, 1.0), color.lightened(0.15), false)
	_add_box(building, "InteriorShelf", Vector3(-5.6, -1.6, -3.4), Vector3(1.1, 3.2, 0.5), Color(0.30, 0.22, 0.15), false)
	_add_box(building, "InteriorSofa", Vector3(5.1, -2.7, -2.2), Vector3(2.5, 0.9, 1.1), Color(0.20, 0.25, 0.30), false)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0, 4.9, 6.75)
	label.font_size = 32
	label.modulate = Color.WHITE
	building.add_child(label)

func _build_hq_personnel() -> void:
	var hq := get_node_or_null("ARMED_FORCES_HQ") as Node3D
	if hq == null:
		return
	# A staffed headquarters: a commander at the desk and four visible soldiers on duty.
	_add_hq_person(hq, "فرمانده ستاد کل", Vector3(0, -3.72, -2.8), Color(0.18, 0.25, 0.20), true)
	_add_hq_person(hq, "سرباز نگهبان", Vector3(-5.2, -3.72, 2.8), Color(0.24, 0.32, 0.25), false)
	_add_hq_person(hq, "سرباز نگهبان", Vector3(5.2, -3.72, 2.8), Color(0.24, 0.32, 0.25), false)
	_add_hq_person(hq, "افسر عملیات", Vector3(-4.6, -3.72, -2.6), Color(0.20, 0.29, 0.23), false)
	_add_hq_person(hq, "مسئول مخابرات", Vector3(4.6, -3.72, -2.6), Color(0.20, 0.29, 0.23), false)

func _add_hq_person(parent: Node3D, job_title: String, at: Vector3, uniform: Color, commander: bool) -> void:
	var person := Node3D.new()
	person.name = "HQ_" + job_title.replace(" ", "_")
	person.position = at
	person.add_to_group("hq_personnel")
	person.set_meta("npc_role", job_title)
	person.set_meta("interactive_npc", true)
	parent.add_child(person)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 1.15
	torso.mesh = torso_mesh
	var torso_mat := _material(uniform)
	torso.material_override = torso_mat
	torso.position.y = 0.78
	person.add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.material_override = _material(Color(0.76, 0.59, 0.45))
	head.position.y = 1.55
	person.add_child(head)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.18, 0.72, 0.22)
		arm.mesh = arm_mesh
		arm.material_override = _material(uniform.darkened(0.08))
		arm.position = Vector3(side * 0.43, 0.82, 0)
		person.add_child(arm)
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.22, 0.62, 0.25)
		leg.mesh = leg_mesh
		leg.material_override = _material(Color(0.12, 0.15, 0.13))
		leg.position = Vector3(side * 0.16, 0.18, 0)
		person.add_child(leg)
	var badge := MeshInstance3D.new()
	var badge_mesh := BoxMesh.new()
	badge_mesh.size = Vector3(0.13, 0.18, 0.035)
	badge.mesh = badge_mesh
	badge.material_override = _material(Color(0.82, 0.68, 0.25) if commander else Color(0.72, 0.75, 0.72))
	badge.position = Vector3(0.0, 1.02, 0.345)
	person.add_child(badge)
	var label := Label3D.new()
	label.text = job_title
	label.position = Vector3(0, 2.0, 0)
	label.font_size = 22
	label.modulate = Color.WHITE
	person.add_child(label)

func _decorate_ceremony_building(building_name: String, pos: Vector3, accent: Color, is_wedding_hall: bool) -> void:
	var decoration := Node3D.new()
	decoration.name = building_name.replace(" ", "_") + "_Architecture"
	decoration.position = pos
	add_child(decoration)
	for side in [-1.0, 1.0]:
		_add_box(decoration, "GrandEntrancePillar", Vector3(side * 5.8, 0.0, 7.0), Vector3(0.65, 7.2, 0.75), accent)
		_add_box(decoration, "PillarCapital", Vector3(side * 5.8, 3.7, 7.0), Vector3(1.05, 0.35, 1.05), accent.lightened(0.12))
		_add_box(decoration, "EntranceStep", Vector3(side * 2.0, -3.45, 7.6), Vector3(4.0, 0.25, 1.0), Color(0.62, 0.58, 0.52), false)
	_add_box(decoration, "CeremonySignPanel", Vector3(0, 3.1, 6.95), Vector3(5.2, 1.0, 0.25), accent.darkened(0.18), false)
	var sign := Label3D.new()
	sign.text = "تالار عروسی" if is_wedding_hall else "محضر ازدواج"
	sign.position = Vector3(0, 3.15, 7.12)
	sign.font_size = 34
	sign.modulate = Color.WHITE
	decoration.add_child(sign)
	if is_wedding_hall:
		var dome := MeshInstance3D.new()
		var dome_mesh := SphereMesh.new()
		dome_mesh.radius = 3.0
		dome_mesh.height = 2.2
		dome.mesh = dome_mesh
		dome.material_override = _material(accent)
		dome.position = Vector3(0, 4.4, -1.5)
		decoration.add_child(dome)
		for side in [-1.0, 1.0]:
			_add_box(decoration, "WeddingFlowerBed", Vector3(side * 9.5, -3.5, 5.0), Vector3(2.2, 0.7, 4.0), Color(0.22, 0.38, 0.24), false)
			_add_cylinder(decoration, "WeddingFlowerTop", Vector3(side * 9.5, -2.85, 5.0), 0.85, 0.45, accent)
	else:
		_add_box(decoration, "RegistryPediment", Vector3(0, 4.45, 6.8), Vector3(12.0, 0.5, 1.1), accent.darkened(0.12), false)
		for side in [-1.0, 1.0]:
			_add_cylinder(decoration, "RegistryDecorativeColumn", Vector3(side * 3.8, 0.0, 7.0), 0.34, 7.2, accent)

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
	if systems.panel:
		systems.panel.visible = false

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

func _build_life_city_services() -> void:
	var services := Node.new()
	services.name = "LifeCityServices"
	services.set_script(SERVICES_SCRIPT)
	add_child(services)
	services.configure(ownership_ledger, player, vehicle_controller, network_manager)

func _build_military_command() -> void:
	military_system = Node3D.new()
	military_system.name = "MilitaryCommand"
	military_system.set_script(MILITARY_SCRIPT)
	add_child(military_system)
	military_system.configure(player, ownership_ledger)

func _build_firebase_client() -> void:
	var firebase := Node.new()
	firebase.name = "FirebaseClient"
	firebase.set_script(FIREBASE_SCRIPT)
	add_child(firebase)
