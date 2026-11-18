extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STAGE2_SCRIPT = preload("res://scripts/city_stage2.gd")
const NETWORK_SCRIPT = preload("res://scripts/network_manager.gd")
const LEDGER_SCRIPT = preload("res://scripts/ownership_ledger.gd")
var player: CharacterBody3D
var network_manager: Node
var ownership_ledger: Node

func _ready() -> void:
	_build_world()
	_build_player()
	_build_mobile_controls()
	_build_stage_two()
	_build_network()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
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
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.15
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
