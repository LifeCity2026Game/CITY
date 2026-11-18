extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D

const VEHICLES := [
	{"name":"DENA","length":4.6,"width":1.78,"height":1.48,"color":Color(0.12,0.22,0.34)},
	{"name":"PEUGEOT 207","length":4.0,"width":1.75,"height":1.48,"color":Color(0.72,0.12,0.10)},
	{"name":"LAND CRUISER","length":4.95,"width":1.98,"height":1.9,"color":Color(0.18,0.2,0.17)},
	{"name":"VXR","length":4.7,"width":1.85,"height":1.42,"color":Color(0.76,0.72,0.58)},
	{"name":"FERRARI","length":4.5,"width":1.95,"height":1.2,"color":Color(0.82,0.035,0.025)},
	{"name":"LAMBORGHINI","length":4.55,"width":2.0,"height":1.16,"color":Color(0.88,0.68,0.025)},
	{"name":"TIBA","length":3.9,"width":1.64,"height":1.45,"color":Color(0.68,0.7,0.72)},
	{"name":"TIBA 2","length":4.0,"width":1.66,"height":1.48,"color":Color(0.12,0.35,0.62)},
	{"name":"PRIDE","length":3.75,"width":1.6,"height":1.42,"color":Color(0.78,0.78,0.74)}
]

func _ready() -> void:
	_build_world()
	_build_player()
	_build_vehicle_showroom()
	_build_npcs()
	_build_mobile_controls()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
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

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.69, 0.8)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.7, 0.78)
	env.fog_density = 0.0018
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)

	_add_box(self, "City Ground", Vector3(0, -0.3, 0), Vector3(230, 0.5, 230), Color(0.22, 0.34, 0.25))
	_add_box(self, "Main Road", Vector3(0, 0.0, 0), Vector3(18, 0.08, 230), Color(0.075, 0.085, 0.1), false)
	_add_box(self, "Cross Road", Vector3(0, 0.01, 0), Vector3(230, 0.08, 18), Color(0.075, 0.085, 0.1), false)
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

func _build_npcs() -> void:
	var positions := [Vector3(-12,0,5),Vector3(12,0,8),Vector3(-24,0,25),Vector3(25,0,22),Vector3(7,0,35),Vector3(-8,0,-18)]
	for i in range(positions.size()):
		var npc := Node3D.new()
		npc.name = "NPC_%02d" % i
		npc.position = positions[i]
		add_child(npc)
		var skin_colors := [Color(0.72,0.49,0.34),Color(0.88,0.68,0.52),Color(0.48,0.31,0.22)]
		var skin := _material(skin_colors[i % skin_colors.size()])
		var clothes := _material([Color(0.16,0.32,0.55),Color(0.35,0.22,0.16),Color(0.12,0.42,0.28)][i % 3])
		var pants := _material(Color(0.12,0.14,0.19))
		_add_npc_capsule(npc,"Torso",0.25,0.68,Vector3(0,1.05,0),clothes)
		_add_npc_sphere(npc,"Head",0.17,Vector3(0,1.62,0),skin)
		for side in [-1.0,1.0]:
			_add_npc_capsule(npc,"Arm",0.085,0.58,Vector3(side*0.31,1.06,0),clothes)
			_add_npc_capsule(npc,"Leg",0.105,0.68,Vector3(side*0.13,0.42,0),pants)
			_add_box(npc,"Shoe",Vector3(side*0.13,0.08,-0.04),Vector3(0.18,0.12,0.28),Color(0.035,0.035,0.04),false)
		var label := Label3D.new()
		label.text = ["Reza","Sara","Arman","Nika","Farhad","Mina"][i]
		label.position = Vector3(0,2.05,0)
		label.font_size = 20
		label.modulate = Color(1,1,1)
		npc.add_child(label)

func _add_npc_capsule(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)

func _add_npc_sphere(parent: Node3D, label: String, radius: float, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)

func _build_vehicle_showroom() -> void:
	for i in range(VEHICLES.size()):
		var data: Dictionary = VEHICLES[i]
		var car := Node3D.new()
		car.name = String(data.name).replace(" ","_")
		car.position = Vector3(-20.0 + float(i % 3) * 20.0, 0.0, 64.0 + float(i / 3) * 9.0)
		add_child(car)
		_build_car_model(car, data)
		var label := Label3D.new()
		label.text = "%s  |  %s" % [data.name, _format_price(i)]
		label.position = Vector3(0, float(data.height) + 1.0, 0)
		label.font_size = 22
		label.modulate = Color.WHITE
		car.add_child(label)

func _format_price(index: int) -> String:
	var prices := ["1,250,000","950,000","4,800,000","3,600,000","18,000,000","22,000,000","420,000","480,000","350,000"]
	return prices[index] + " $"

func _build_car_model(root: Node3D, data: Dictionary) -> void:
	var length: float = data.length
	var width: float = data.width
	var height: float = data.height
	var paint: Color = data.color
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(width, 0.48, length)
	body.mesh = body_mesh
	body.material_override = _material(paint,0.55,0.28)
	body.position.y = 0.68
	root.add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(width*0.78,height*0.48,length*0.48)
	cabin.mesh = cabin_mesh
	cabin.material_override = _material(paint.lightened(0.12),0.35,0.3)
	cabin.position = Vector3(0,0.68+height*0.42,-0.12)
	root.add_child(cabin)
	var glass := _material(Color(0.055,0.12,0.17,0.82),0.25,0.12)
	_add_box(root,"Front windshield",Vector3(0,1.02,-length*0.17),Vector3(width*0.73,0.34,0.045),Color(0.06,0.13,0.18),false)
	_add_box(root,"Rear windshield",Vector3(0,1.02,length*0.2),Vector3(width*0.73,0.32,0.045),Color(0.06,0.13,0.18),false)
	for side in [-1.0,1.0]:
		_add_box(root,"Side glass",Vector3(side*width*0.395,1.02,-0.12),Vector3(0.035,0.34,length*0.42),Color(0.06,0.13,0.18),false)
		for zpos in [-length*0.32,length*0.32]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.22
			wheel.mesh = wheel_mesh
			wheel.material_override = _material(Color(0.025,0.025,0.03),0.05,0.9)
			wheel.position = Vector3(side*(width*0.5+0.04),0.4,zpos)
			wheel.rotation.z = PI/2.0
			root.add_child(wheel)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.17
			hub_mesh.bottom_radius = 0.17
			hub_mesh.height = 0.235
			hub.mesh = hub_mesh
			hub.material_override = _material(Color(0.62,0.65,0.68),0.8,0.22)
			hub.position = wheel.position
			hub.rotation.z = PI/2.0
			root.add_child(hub)
	for side in [-1.0,1.0]:
		_add_box(root,"Headlight",Vector3(side*width*0.34,0.72,-length*0.505),Vector3(0.32,0.14,0.045),Color(0.92,0.94,0.82),false)
		_add_box(root,"Tail light",Vector3(side*width*0.34,0.72,length*0.505),Vector3(0.28,0.18,0.045),Color(0.7,0.035,0.02),false)
	_add_box(root,"Front grille",Vector3(0,0.62,-length*0.51),Vector3(width*0.34,0.2,0.04),Color(0.035,0.04,0.045),false)
	# Simplified visible cabin details: seats, dashboard, steering wheel and center console.
	for side in [-1.0,1.0]:
		_add_box(root,"Front seat",Vector3(side*0.25,0.88,-0.2),Vector3(0.34,0.42,0.32),Color(0.12,0.12,0.13),false)
	_add_box(root,"Dashboard",Vector3(0,0.94,-0.68),Vector3(width*0.72,0.16,0.2),Color(0.055,0.06,0.07),false)
	_add_box(root,"Center console",Vector3(0,0.82,-0.08),Vector3(0.18,0.18,0.62),Color(0.09,0.09,0.1),false)

func _build_mobile_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := HBoxContainer.new()
	panel.position = Vector2(24, -112)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_constant_override("separation", 8)
	layer.add_child(panel)
	_add_control_button(panel, "◀", "left")
	_add_control_button(panel, "▲", "forward")
	_add_control_button(panel, "▼", "back")
	_add_control_button(panel, "▶", "right")

func _add_control_button(parent: HBoxContainer, caption: String, axis: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(66, 66)
	button.add_theme_font_size_override("font_size", 25)
	parent.add_child(button)
	button.button_down.connect(func(): player.set_mobile_axis(axis, true))
	button.button_up.connect(func(): player.set_mobile_axis(axis, false))
