extends Node3D
## Fictional, game-only military command systems for LIFE CITY.
signal report_changed(message: String)

var player: CharacterBody3D
var ledger: Node
var panel: PanelContainer
var status_label: Label
var target_picker: OptionButton
var units: Array[Node3D] = []
var active_missions: Array[Dictionary] = []
var targets: Array[Node3D] = []
var mission_clock := 0.0
var next_unit_id := 1
var missile_active := false
var missile_node: Node3D
var missile_from := Vector3.ZERO
var missile_to := Vector3.ZERO
var missile_progress := 0.0
var explosion_nodes: Array[Node3D] = []
var destroyed_buildings: Dictionary = {}
var selected_department := "نیروی زمینی"

const DEPARTMENTS := ["نیروی زمینی", "نیروی هوایی", "نیروی دریایی", "گارد ساحلی", "تفنگداران دریایی", "نیروی فضایی", "گارد ملی"]
const COLORS := [Color(0.28,0.36,0.29), Color(0.34,0.42,0.52), Color(0.25,0.34,0.43), Color(0.20,0.43,0.54), Color(0.31,0.38,0.32), Color(0.20,0.28,0.42), Color(0.42,0.36,0.27)]

func configure(player_node: CharacterBody3D, ledger_node: Node) -> void:
	player = player_node
	ledger = ledger_node

func _ready() -> void:
	_build_targets()
	_build_interface()

func _process(delta: float) -> void:
	mission_clock += delta
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var destination: Vector3 = unit.get_meta("destination", unit.position)
		var speed := float(unit.get_meta("speed", 4.0))
		if unit.position.distance_to(destination) > 0.6:
			unit.position = unit.position.move_toward(destination, speed * delta)
			unit.look_at(Vector3(destination.x, unit.position.y, destination.z), Vector3.UP)
		else:
			if bool(unit.get_meta("patrol", false)):
				var phase := float(unit.get_meta("phase", 0.0)) + delta
				unit.set_meta("phase", phase)
				var center: Vector3 = unit.get_meta("center", unit.position)
				var radius := float(unit.get_meta("radius", 12.0))
				var next_pos := center + Vector3(cos(phase * 0.25) * radius, 0.0, sin(phase * 0.25) * radius)
				unit.set_meta("destination", next_pos)
	if missile_active:
		_update_missile(delta)
	for fx in explosion_nodes:
		if is_instance_valid(fx):
			fx.scale *= 1.0 + delta * 0.75

func _can_command() -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return true
	var peer_id := multiplayer.get_unique_id()
	return ledger != null and ledger.can_access_permission(peer_id, "command_military")

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MilitaryCommandUI"
	add_child(layer)
	var toggle := Button.new()
	toggle.text = "فرماندهی ارتش"
	toggle.position = Vector2(12, 610)
	toggle.custom_minimum_size = Vector2(190, 48)
	toggle.pressed.connect(_toggle_panel)
	layer.add_child(toggle)
	panel = PanelContainer.new()
	panel.position = Vector2(12, 70)
	panel.size = Vector2(350, 520)
	panel.visible = false
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 500)
	panel.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	var title := Label.new()
	title.text = "ستاد کل | عملیات هفت نیرو"
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)
	status_label = Label.new()
	status_label.text = "برای شروع، شاخه و مأموریت را انتخاب کن."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	target_picker = OptionButton.new()
	target_picker.add_item("ساختمان بانک مرکزی")
	target_picker.add_item("کاخ ریاست جمهوری")
	target_picker.add_item("ستاد کل ارتش")
	target_picker.add_item("وزارت اطلاعات")
	target_picker.add_item("ساختمان دولت")
	target_picker.add_item("ساختمان تجاری شمال")
	layout.add_child(target_picker)
	for i in range(DEPARTMENTS.size()):
		_add_button(layout, DEPARTMENTS[i], "department", DEPARTMENTS[i])
	_add_button(layout, "گشت شهری نیروی زمینی", "ground_patrol")
	_add_button(layout, "محاصره ساختمان انتخاب‌شده", "perimeter")
	_add_button(layout, "انتقال تجهیزات زمینی", "ground_logistics")
	_add_button(layout, "گشت بالگرد و هلیکوپتر", "air_patrol")
	_add_button(layout, "شلیک موشک آزمایشی به مقصد انتخاب‌شده", "missile")
	_add_button(layout, "گشت ناو و انتقال دریایی", "naval")
	_add_button(layout, "گشت گارد ساحلی و مقابله با دزدان دریایی", "coast")
	_add_button(layout, "عملیات آبی‌ـ‌خاکی تفنگداران", "marines")
	_add_button(layout, "ماهواره، اینترنت و هشدار فضایی", "space")
	_add_button(layout, "گشت و امنیت شهری گارد ملی", "national_guard")
	_add_button(layout, "نمایش یگان‌ها و مأموریت‌ها", "status")
	_add_button(layout, "بستن", "close")

func _add_button(parent: VBoxContainer, caption: String, action: String, arg: String = "") -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(300, 40)
	b.pressed.connect(_on_action.bind(action, arg))
	parent.add_child(b)

func _toggle_panel() -> void:
	panel.visible = not panel.visible

func _target_position() -> Vector3:
	var choices := [Vector3(-29,0,28), Vector3(55,0,-55), Vector3(55,0,55), Vector3(-55,0,-55), Vector3(0,0,-50), Vector3(72,0,24)]
	return choices[clampi(target_picker.selected, 0, choices.size()-1)]

func _on_action(action: String, arg: String = "") -> void:
	if action == "close":
		panel.visible = false
		return
	if action == "department":
		selected_department = arg
		status_label.text = "شاخه انتخاب‌شده: " + arg
		return
	if not _can_command():
		status_label.text = "این فرمان فقط برای سازنده یا فرمانده دارای مجوز است."
		return
	match action:
		"ground_patrol":
			_spawn_unit("خودروی گشت زمینی", Vector3(0,0.6,12), COLORS[0], 5.0, true, 15.0)
			_spawn_unit("نفربر گشت", Vector3(3,0.6,12), COLORS[0].darkened(0.12), 4.0, true, 18.0)
			_log("گشت زمینی در مسیرهای شهر آغاز شد.")
		"perimeter":
			_create_perimeter(_target_position())
			_log("محاصره حفاظتی پیرامون ساختمان انتخاب‌شده مستقر شد.")
		"ground_logistics":
			_spawn_logistics(Vector3(-12,0.4,8), _target_position())
			_log("کاروان انتقال تجهیزات به مقصد حرکت کرد.")
		"air_patrol":
			_spawn_aircraft("بالگرد گشت", Vector3(-12,12,0), COLORS[1], true)
			_spawn_aircraft("هلیکوپتر پشتیبانی", Vector3(12,15,0), COLORS[2], true)
			_log("گشت هوایی فعال شد.")
		"missile":
			_launch_missile(_target_position())
		"naval":
			_spawn_ship(Vector3(-88,0.2,78), "ناو پشتیبانی")
			_spawn_aircraft("جنگنده ناونشین", Vector3(-78,13,70), COLORS[1], true)
			_spawn_logistics(Vector3(-82,0.5,82), Vector3(-25,0,35))
			_log("ناو و کاروان پشتیبانی دریایی اعزام شدند.")
		"coast":
			_spawn_ship(Vector3(-92,0.2,62), "شناور گارد ساحلی")
			_spawn_unit("قایق گشت دریایی", Vector3(-88,0.4,58), COLORS[3], 6.0, true, 10.0)
			_log("گشت ساحلی؛ رویداد دزدی دریایی شبیه‌سازی و رهگیری شد.")
		"marines":
			_spawn_ship(Vector3(-90,0.2,45), "شناور آبی‌خاکی")
			_spawn_unit("نفربر آبی‌خاکی", Vector3(-86,0.5,42), COLORS[4], 4.5, false, 0.0)
			_log("یگان تفنگداران از دریا به ساحل منتقل شد.")
		"space":
			_spawn_satellite()
			_log("ماهواره ارتباطی فعال؛ اینترنت نقشه و هشدار رهگیری فضایی فعال شد.")
		"national_guard":
			_spawn_unit("خودروی گارد ملی", Vector3(0,0.6,16), COLORS[6], 4.5, true, 12.0)
			_create_perimeter(_target_position())
			_log("گارد ملی برای امنیت شهری و مدیریت رویدادهای بازی اعزام شد.")
		"status":
			_log("یگان‌های فعال: %d | مأموریت‌های ثبت‌شده: %d | ساختمان‌های آسیب‌دیده: %d" % [units.size(), active_missions.size(), destroyed_buildings.size()])

func _spawn_unit(label: String, at: Vector3, paint: Color, speed: float, patrol: bool, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "MilitaryUnit_%d" % next_unit_id
	next_unit_id += 1
	root.position = at
	root.set_meta("destination", at + Vector3(0,0,-24))
	root.set_meta("speed", speed)
	root.set_meta("patrol", patrol)
	root.set_meta("center", at)
	root.set_meta("radius", radius)
	root.set_meta("phase", 0.0)
	add_child(root)
	_box(root, "Chassis", Vector3(0,0.55,0), Vector3(2.1,0.75,3.3), paint)
	_box(root, "Cabin", Vector3(0,1.15,-0.25), Vector3(1.65,0.65,1.45), paint.lightened(0.15))
	for x in [-0.9,0.9]:
		for z in [-1.05,1.05]:
			_cylinder(root, Vector3(x,0.32,z), 0.34, 0.22, Color(0.07,0.07,0.07))
	units.append(root)
	return root

func _spawn_logistics(at: Vector3, destination: Vector3) -> void:
	var truck := _spawn_unit("کامیون تجهیزات", at, Color(0.36,0.39,0.31), 7.0, false, 0.0)
	_box(truck, "Cargo", Vector3(0,1.35,-0.8), Vector3(1.7,0.9,1.6), Color(0.48,0.42,0.30))
	truck.set_meta("destination", destination)

func _spawn_aircraft(label: String, at: Vector3, paint: Color, patrol: bool) -> void:
	var craft := Node3D.new()
	craft.name = label
	craft.position = at
	craft.set_meta("center", at)
	craft.set_meta("phase", 0.0)
	craft.set_meta("patrol", patrol)
	craft.set_meta("speed", 7.0)
	craft.set_meta("radius", 20.0)
	craft.set_meta("destination", at + Vector3(18,0,0))
	add_child(craft)
	_box(craft, "Fuselage", Vector3(0,0,0), Vector3(0.8,0.65,3.5), paint)
	_box(craft, "Wings", Vector3(0,0,0), Vector3(6.0,0.16,1.1), paint.darkened(0.1))
	_box(craft, "Tail", Vector3(0,0.65,-1.35), Vector3(0.16,0.9,0.8), paint)
	if label.contains("بالگرد") or label.contains("هلیکوپتر"):
		_box(craft, "Rotor", Vector3(0,0.6,0), Vector3(5.2,0.06,0.12), Color(0.08,0.08,0.08))
	units.append(craft)

func _spawn_ship(at: Vector3, label: String) -> void:
	var ship := Node3D.new()
	ship.name = label
	ship.position = at
	ship.set_meta("destination", at + Vector3(0,0,-20))
	ship.set_meta("speed", 2.5)
	ship.set_meta("patrol", true)
	ship.set_meta("center", at)
	ship.set_meta("radius", 12.0)
	ship.set_meta("phase", 0.0)
	add_child(ship)
	_box(ship, "Hull", Vector3(0,0.5,0), Vector3(3.4,0.8,8.0), Color(0.18,0.25,0.31))
	_box(ship, "Bridge", Vector3(0,1.4,-1), Vector3(2.0,1.2,2.0), Color(0.68,0.7,0.72))
	_box(ship, "Deck", Vector3(0,1.0,1.6), Vector3(3.0,0.12,3.8), Color(0.3,0.34,0.36))
	units.append(ship)

func _spawn_satellite() -> void:
	var satellite := Node3D.new()
	satellite.name = "CommunicationsSatellite"
	satellite.position = Vector3(0,45,0)
	add_child(satellite)
	_box(satellite, "SatelliteBody", Vector3.ZERO, Vector3(1.8,0.7,1.0), Color(0.72,0.72,0.78))
	_box(satellite, "SolarLeft", Vector3(-2.5,0,0), Vector3(3.2,0.08,1.2), Color(0.12,0.22,0.48))
	_box(satellite, "SolarRight", Vector3(2.5,0,0), Vector3(3.2,0.08,1.2), Color(0.12,0.22,0.48))
	_log("ماهواره در مدار نمایشی مستقر شد؛ سرویس اینترنت نقشه برقرار است.")

func _create_perimeter(center: Vector3) -> void:
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var at := center + Vector3(cos(angle)*12.0,0,sin(angle)*12.0)
		var barrier := _box(self, "SecurityBarrier", at + Vector3(0,0.65,0), Vector3(2.8,1.3,0.35), Color(0.76,0.62,0.22))
		barrier.rotation.y = -angle
		_spawn_unit("گشتی محافظ", at, COLORS[0], 3.5, true, 4.0)
	
func _launch_missile(destination: Vector3) -> void:
	if missile_active:
		_log("یک موشک دیگر در حال پرواز است.")
		return
	missile_from = (player.global_position if player else Vector3(0,1,12)) + Vector3(0,2,0)
	missile_to = destination + Vector3(0,1.5,0)
	missile_progress = 0.0
	missile_active = true
	missile_node = Node3D.new()
	missile_node.name = "GameMissile"
	add_child(missile_node)
	_box(missile_node, "MissileBody", Vector3.ZERO, Vector3(0.35,0.35,1.8), Color(0.72,0.72,0.68))
	_log("موشک آزمایشی به سمت نقطه انتخاب‌شده شلیک شد.")

func _update_missile(delta: float) -> void:
	missile_progress += delta * 0.28
	var t := clampf(missile_progress,0.0,1.0)
	var pos := missile_from.lerp(missile_to,t)
	pos.y += sin(t*PI)*16.0
	missile_node.position = pos
	if t >= 1.0:
		missile_active = false
		missile_node.queue_free()
		_create_explosion(missile_to)
		_damage_target(_target_position())
		_log("انفجار ثبت شد؛ ساختمان مقصد آسیب دید.")

func _create_explosion(at: Vector3) -> void:
	var fx := Node3D.new()
	fx.name = "GameExplosion"
	fx.position = at
	add_child(fx)
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 2.0
	mesh.height = 4.0
	sphere.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0,0.32,0.06,0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0,0.12,0.01)
	sphere.material_override = material
	fx.add_child(sphere)
	var smoke := GPUParticles3D.new()
	smoke.amount = 36
	smoke.lifetime = 2.8
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0,1,0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 7.0
	particle_mat.gravity = Vector3(0,1.5,0)
	smoke.process_material = particle_mat
	smoke.emitting = true
	fx.add_child(smoke)
	explosion_nodes.append(fx)
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(_remove_explosion.bind(fx))

func _damage_target(center: Vector3) -> void:
	var best: Node3D
	var best_distance := 24.0
	for candidate in get_tree().get_nodes_in_group("city_buildings"):
		if not is_instance_valid(candidate):
			continue
		var d := candidate.global_position.distance_to(center)
		if d < best_distance:
			best_distance = d
			best = candidate
	if best:
		var hp := int(best.get_meta("military_health",100)) - 60
		best.set_meta("military_health",hp)
		destroyed_buildings[best.name] = hp
		if hp <= 0:
			for child in best.get_children():
				if child is CollisionObject3D:
					child.set_collision_layer_value(1,false)
					child.set_collision_mask_value(1,false)
				if child is MeshInstance3D:
					child.visible = false
			best.visible = false
			_log("ساختمان %s تخریب شد؛ برای بازسازی به شهرداری مراجعه کن." % best.name)
		else:
			_log("ساختمان %s آسیب دید؛ سلامت باقی‌مانده: %d" % [best.name,hp])
	else:
		_log("انفجار در محدوده مقصد ثبت شد؛ ساختمان قابل تخریب نزدیک پیدا نشد.")

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh_node.material_override = material
	mesh_node.position = pos
	parent.add_child(mesh_node)
	return mesh_node

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = at
	parent.add_child(node)

func _log(message: String) -> void:
	status_label.text = message
	active_missions.append({"time": Time.get_ticks_msec(), "department": selected_department, "report": message})
	report_changed.emit(message)

func _remove_explosion(fx: Node3D) -> void:
	if is_instance_valid(fx):
		fx.queue_free()
