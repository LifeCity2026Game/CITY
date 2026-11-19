extends Node3D
## Fictional, game-only military command systems for LIFE CITY.
signal report_changed(message: String)

var player: CharacterBody3D
var ledger: Node
var panel: PanelContainer
var status_label: Label
var target_picker: OptionButton
var target_x_input: LineEdit
var target_z_input: LineEdit
var active_projectile_nuclear := false
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

func _build_targets() -> void:
	targets.clear()
	for node in get_tree().get_nodes_in_group("city_buildings"):
		if node is Node3D:
			targets.append(node)

func _process(delta: float) -> void:
	mission_clock += delta
	for unit in units:
		if not is_instance_valid(unit):
			continue
		_update_unit_ai(unit, delta)
		var destination: Vector3 = unit.get_meta("destination", unit.position)
		var speed := float(unit.get_meta("speed", 4.0))
		if unit.position.distance_to(destination) > 0.6:
			unit.position = unit.position.move_toward(destination, speed * delta)
			var look_target := Vector3(destination.x, unit.position.y, destination.z)
			if unit.position.distance_to(look_target) > 0.1:
				unit.look_at(look_target, Vector3.UP)
		elif bool(unit.get_meta("patrol", false)) and bool(unit.get_meta("ai_enabled", false)):
			_choose_ai_patrol_destination(unit)
	if missile_active:
		_update_missile(delta)
	for fx in explosion_nodes:
		if is_instance_valid(fx):
			fx.scale *= 1.0 + delta * 0.75

func _update_unit_ai(unit: Node3D, delta: float) -> void:
	if not bool(unit.get_meta("ai_enabled", false)):
		return
	var department := str(unit.get_meta("department", "نیروی زمینی"))
	var timer := float(unit.get_meta("ai_decision_timer", 0.0)) + delta
	unit.set_meta("ai_decision_timer", timer)
	# Branch-specific movement constraints keep units inside believable game-world domains.
	match department:
		"نیروی هوایی":
			var altitude := 15.0 + sin(mission_clock * 0.7 + float(unit.get_instance_id() % 17)) * 2.0
			if bool(unit.get_meta("patrol", false)):
				unit.position.y = lerpf(unit.position.y, altitude, minf(delta * 0.8, 1.0))
			var target: Vector3 = unit.get_meta("destination", unit.position)
			target.y = maxf(target.y, 12.0)
			unit.set_meta("destination", target)
		"نیروی دریایی":
			unit.position.y = 0.2
			var sea_target: Vector3 = unit.get_meta("destination", unit.position)
			sea_target.x = clampf(sea_target.x, -108.0, 108.0)
			sea_target.z = clampf(sea_target.z, 72.0, 120.0)
			unit.set_meta("destination", sea_target)
		"گارد ساحلی":
			unit.position.y = 0.35
			var coast_target: Vector3 = unit.get_meta("destination", unit.position)
			coast_target.x = clampf(coast_target.x, -108.0, 108.0)
			coast_target.z = clampf(coast_target.z, 82.0, 116.0)
			unit.set_meta("destination", coast_target)
		"تفنگداران دریایی":
			var amphibious_target: Vector3 = unit.get_meta("destination", unit.position)
			if unit.position.z > 88.0:
				unit.set_meta("movement_phase", "sea_approach")
				amphibious_target.z = clampf(amphibious_target.z, 72.0, 94.0)
			else:
				unit.set_meta("movement_phase", "shore_advance")
				amphibious_target.y = 0.6
			unit.set_meta("destination", amphibious_target)
		"نیروی فضایی":
			unit.rotate_y(delta * 0.22)
			unit.position.y = 45.0 + sin(mission_clock * 0.18) * 2.0
		"گارد ملی":
			unit.position.y = 0.6
			if timer >= 8.0 and bool(unit.get_meta("patrol", false)):
				unit.set_meta("ai_decision_timer", 0.0)
				unit.set_meta("ai_state", "urban_security_scan")
		_:
			unit.position.y = 0.6
			if timer >= 10.0 and bool(unit.get_meta("patrol", false)):
				unit.set_meta("ai_decision_timer", 0.0)
				unit.set_meta("ai_state", "road_patrol")

func _choose_ai_patrol_destination(unit: Node3D) -> void:
	var department := str(unit.get_meta("department", "نیروی زمینی"))
	var center: Vector3 = unit.get_meta("center", unit.position)
	var phase := float(unit.get_meta("phase", 0.0)) + 0.9
	unit.set_meta("phase", phase)
	var radius := float(unit.get_meta("radius", 12.0))
	var next_pos := center
	match department:
		"نیروی هوایی":
			next_pos = center + Vector3(cos(phase * 0.25) * radius * 1.5, 0.0, sin(phase * 0.25) * radius)
			next_pos.y = maxf(center.y, 15.0)
			unit.set_meta("ai_state", "air_patrol_orbit")
		"نیروی دریایی":
			next_pos = center + Vector3(cos(phase * 0.2) * radius * 1.7, 0.0, sin(phase * 0.12) * 3.0)
			next_pos.z = clampf(next_pos.z, 72.0, 120.0)
			unit.set_meta("ai_state", "sea_lane_patrol")
		"گارد ساحلی":
			next_pos = center + Vector3(cos(phase * 0.3) * radius, 0.0, sin(phase * 0.2) * radius * 0.45)
			next_pos.z = clampf(next_pos.z, 82.0, 116.0)
			unit.set_meta("ai_state", "coastal_patrol")
		"تفنگداران دریایی":
			next_pos = center + Vector3(cos(phase * 0.2) * radius, 0.0, sin(phase * 0.2) * radius)
			unit.set_meta("ai_state", "amphibious_patrol")
		"گارد ملی":
			next_pos = center + Vector3(round(cos(phase * 0.2) * radius / 6.0) * 6.0, 0.0, round(sin(phase * 0.2) * radius / 6.0) * 6.0)
			unit.set_meta("ai_state", "urban_security_patrol")
		_:
			next_pos = center + Vector3(round(cos(phase * 0.2) * radius / 6.0) * 6.0, 0.0, round(sin(phase * 0.2) * radius / 6.0) * 6.0)
			unit.set_meta("ai_state", "ground_road_patrol")
	unit.set_meta("destination", next_pos)


func _can_command() -> bool:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return true
	var peer_id: int = multiplayer.get_unique_id()
	var services: Node = get_parent().get_node_or_null("LifeCityServices")
	if services != null:
		var role_name: String = str(services.roles.get(peer_id, ""))
		if role_name == "فرمانده کل ارتش" or role_name == "فرمانده " + selected_department:
			return true
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
	target_x_input = LineEdit.new()
	target_x_input.placeholder_text = "مختصات X مقصد (مثلاً ۳۰)"
	target_x_input.text = ""
	target_x_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	layout.add_child(target_x_input)
	target_z_input = LineEdit.new()
	target_z_input.placeholder_text = "مختصات Z مقصد (مثلاً -۴۰)"
	target_z_input.text = ""
	target_z_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	layout.add_child(target_z_input)
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
	_add_button(layout, "دستور حرکت یگان شاخه انتخابی به مختصات", "move_to_target")
	_add_button(layout, "دستور حمله بازی‌محور به مختصات", "attack_target")
	_add_button(layout, "رژه یگان در نقطه انتخابی", "parade_target")
	_add_button(layout, "حمله جنگنده با بمب معمولی", "fighter_attack")
	_add_button(layout, "حمله جنگنده با بمب هسته‌ای خیالی", "nuclear_attack")
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
	var x_text := target_x_input.text.strip_edges() if is_instance_valid(target_x_input) else ""
	var z_text := target_z_input.text.strip_edges() if is_instance_valid(target_z_input) else ""
	if not x_text.is_empty() and not z_text.is_empty() and x_text.is_valid_float() and z_text.is_valid_float():
		return Vector3(clampf(float(x_text), -105.0, 105.0), 0.0, clampf(float(z_text), -105.0, 105.0))
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
			selected_department = "نیروی زمینی"
			_spawn_unit("خودروی گشت زمینی", Vector3(0,0.6,12), COLORS[0], 5.0, true, 15.0)
			_spawn_unit("نفربر گشت", Vector3(3,0.6,12), COLORS[0].darkened(0.12), 4.0, true, 18.0)
			_log("گشت زمینی در مسیرهای شهر آغاز شد.")
		"perimeter":
			_create_perimeter(_target_position())
			_log("محاصره حفاظتی پیرامون ساختمان انتخاب‌شده مستقر شد.")
		"ground_logistics":
			selected_department = "نیروی زمینی"
			_spawn_logistics(Vector3(-12,0.4,8), _target_position())
			_log("کاروان انتقال تجهیزات به مقصد حرکت کرد.")
		"air_patrol":
			selected_department = "نیروی هوایی"
			_spawn_aircraft("بالگرد گشت", Vector3(-12,12,0), COLORS[1], true)
			_spawn_aircraft("هلیکوپتر پشتیبانی", Vector3(12,15,0), COLORS[2], true)
			_log("گشت هوایی فعال شد.")
		"missile":
			_launch_missile(_target_position())
		"naval":
			selected_department = "نیروی دریایی"
			_spawn_ship(Vector3(-88,0.2,104), "ناو پشتیبانی")
			_spawn_aircraft("جنگنده ناونشین", Vector3(-78,13,96), COLORS[1], true)
			_spawn_logistics(Vector3(-82,0.5,104), Vector3(-25,0,35))
			_log("ناو و کاروان پشتیبانی دریایی اعزام شدند.")
		"coast":
			selected_department = "گارد ساحلی"
			_spawn_ship(Vector3(-92,0.2,102), "شناور گارد ساحلی")
			_spawn_unit("قایق گشت دریایی", Vector3(-88,0.4,101), COLORS[3], 6.0, true, 10.0)
			_log("گشت ساحلی؛ رویداد دزدی دریایی شبیه‌سازی و رهگیری شد.")
		"marines":
			selected_department = "تفنگداران دریایی"
			_spawn_ship(Vector3(-90,0.2,100), "شناور آبی‌خاکی")
			_spawn_unit("نفربر آبی‌خاکی", Vector3(-86,0.5,96), COLORS[4], 4.5, false, 0.0)
			_log("یگان تفنگداران از دریا به ساحل منتقل شد.")
		"space":
			selected_department = "نیروی فضایی"
			_spawn_satellite()
			_log("ماهواره ارتباطی فعال؛ اینترنت نقشه و هشدار رهگیری فضایی فعال شد.")
		"national_guard":
			selected_department = "گارد ملی"
			_spawn_unit("خودروی گارد ملی", Vector3(0,0.6,16), COLORS[6], 4.5, true, 12.0)
			_create_perimeter(_target_position())
			_log("گارد ملی برای امنیت شهری و مدیریت رویدادهای بازی اعزام شد.")
		"move_to_target":
			_order_selected_units(_target_position(), "move")
		"attack_target":
			_order_selected_units(_target_position(), "attack")
		"parade_target":
			_order_selected_units(_target_position(), "parade")
		"fighter_attack":
			_order_fighter_attack(_target_position(), false)
		"nuclear_attack":
			_order_fighter_attack(_target_position(), true)
		"status":
			_log("یگان‌های فعال: %d | مأموریت‌های ثبت‌شده: %d | ساختمان‌های آسیب‌دیده: %d" % [units.size(), active_missions.size(), destroyed_buildings.size()])

func _spawn_unit(label: String, at: Vector3, paint: Color, speed: float, patrol: bool, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "MilitaryUnit_%d" % next_unit_id
	next_unit_id += 1
	root.position = at
	root.set_meta("department", selected_department)
	root.set_meta("unit_label", label)
	root.set_meta("destination", at + Vector3(0,0,-24))
	root.set_meta("speed", speed)
	root.set_meta("patrol", patrol)
	root.set_meta("center", at)
	root.set_meta("radius", radius)
	root.set_meta("phase", 0.0)
	root.set_meta("ai_enabled", true)
	root.set_meta("ai_state", "idle")
	root.set_meta("ai_decision_timer", 0.0)
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
	craft.set_meta("is_aircraft", true)
	craft.position = at
	craft.set_meta("department", selected_department)
	craft.set_meta("center", at)
	craft.set_meta("phase", 0.0)
	craft.set_meta("patrol", patrol)
	craft.set_meta("speed", 7.0)
	craft.set_meta("radius", 20.0)
	craft.set_meta("destination", at + Vector3(18,0,0))
	craft.set_meta("ai_enabled", true)
	craft.set_meta("ai_state", "air_patrol")
	craft.set_meta("ai_decision_timer", 0.0)
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
	ship.set_meta("department", selected_department)
	ship.set_meta("destination", at + Vector3(0,0,-20))
	ship.set_meta("speed", 2.5)
	ship.set_meta("patrol", true)
	ship.set_meta("center", at)
	ship.set_meta("radius", 12.0)
	ship.set_meta("phase", 0.0)
	ship.set_meta("ai_enabled", true)
	ship.set_meta("ai_state", "sea_patrol")
	ship.set_meta("ai_decision_timer", 0.0)
	add_child(ship)
	_box(ship, "Hull", Vector3(0,0.5,0), Vector3(3.4,0.8,8.0), Color(0.18,0.25,0.31))
	_box(ship, "Bridge", Vector3(0,1.4,-1), Vector3(2.0,1.2,2.0), Color(0.68,0.7,0.72))
	_box(ship, "Deck", Vector3(0,1.0,1.6), Vector3(3.0,0.12,3.8), Color(0.3,0.34,0.36))
	units.append(ship)

func _spawn_satellite() -> void:
	var satellite := Node3D.new()
	satellite.name = "CommunicationsSatellite"
	satellite.position = Vector3(0,45,0)
	satellite.set_meta("department", "نیروی فضایی")
	satellite.set_meta("ai_enabled", true)
	satellite.set_meta("ai_state", "orbital_stationkeeping")
	satellite.set_meta("ai_decision_timer", 0.0)
	units.append(satellite)
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
	
func _launch_missile(destination: Vector3, nuclear: bool = false, origin: Vector3 = Vector3.ZERO) -> void:
	if missile_active:
		_log("یک موشک دیگر در حال پرواز است.")
		return
	missile_from = (origin if origin != Vector3.ZERO else (player.global_position if player else Vector3(0,1,12))) + Vector3(0,2,0)
	missile_to = destination + Vector3(0,1.5,0)
	active_projectile_nuclear = nuclear
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
		_create_explosion(missile_to, active_projectile_nuclear)
		_damage_target(missile_to, active_projectile_nuclear)
		_log("انفجار هسته‌ای نمایشی ثبت شد؛ محدوده وسیع شهر در بازی آسیب دید." if active_projectile_nuclear else "انفجار ثبت شد؛ محدوده مقصد آسیب دید.")

func _create_explosion(at: Vector3, nuclear: bool = false) -> void:
	var fx := Node3D.new()
	fx.name = "GameExplosion"
	fx.position = at
	add_child(fx)
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 5.0 if nuclear else 2.0
	mesh.height = 10.0 if nuclear else 4.0
	sphere.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0,0.32,0.06,0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0,0.12,0.01)
	sphere.material_override = material
	fx.add_child(sphere)
	var smoke := GPUParticles3D.new()
	smoke.amount = 120 if nuclear else 36
	smoke.lifetime = 8.0 if nuclear else 2.8
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0,1,0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 7.0
	particle_mat.gravity = Vector3(0,1.5,0)
	smoke.process_material = particle_mat
	smoke.emitting = true
	fx.add_child(smoke)
	if nuclear:
		fx.scale = Vector3(7.0, 4.0, 7.0)
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.72, 0.32)
		flash.light_energy = 8.0
		flash.omni_range = 85.0
		fx.add_child(flash)
	explosion_nodes.append(fx)
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(_remove_explosion.bind(fx))

func _damage_target(center: Vector3, nuclear: bool = false) -> void:
	var radius: float = 65.0 if nuclear else 24.0
	var damaged: int = 0
	for candidate in get_tree().get_nodes_in_group("city_buildings"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var building: Node3D = candidate as Node3D
		var distance_to_impact: float = building.global_position.distance_to(center)
		if distance_to_impact > radius:
			continue
		var damage: int = 100 if nuclear else 60
		var hp: int = int(building.get_meta("military_health", 100)) - damage
		building.set_meta("military_health", hp)
		destroyed_buildings[building.name] = hp
		damaged += 1
		if hp <= 0:
			for child in building.get_children():
				if child is CollisionObject3D:
					child.set_collision_layer_value(1, false)
					child.set_collision_mask_value(1, false)
				if child is VisualInstance3D:
					child.visible = false
			building.visible = false
	if damaged > 0:
		_log("انفجار هسته‌ای نمایشی؛ %d ساختمان در شعاع بازی آسیب دید یا تخریب شد." % damaged if nuclear else "%d ساختمان در محدوده انفجار آسیب دید." % damaged)
	else:
		_log("انفجار در مختصات انتخابی ثبت شد؛ ساختمان شهری در شعاع اثر نبود.")


func _order_selected_units(destination: Vector3, mode: String) -> void:
	var matched: int = 0
	for unit in units:
		if not is_instance_valid(unit) or str(unit.get_meta("department", "")) != selected_department:
			continue
		matched += 1
		unit.set_meta("destination", destination + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0)))
		if mode == "parade":
			unit.set_meta("center", destination)
			unit.set_meta("patrol", true)
			unit.set_meta("radius", 14.0)
		else:
			unit.set_meta("patrol", false)
	if matched == 0:
		if selected_department == "نیروی هوایی":
			_spawn_aircraft("جنگنده فرماندهی", Vector3(0, 16, 12), COLORS[1], false)
		elif selected_department == "نیروی دریایی" or selected_department == "گارد ساحلی" or selected_department == "تفنگداران دریایی":
			_spawn_ship(Vector3(-88, 0.2, 70), "شناور فرماندهی")
		else:
			_spawn_unit("یگان فرماندهی", Vector3(0, 0.6, 12), COLORS[0], 5.0, false, 0.0)
		matched = 1
		for unit in units:
			if is_instance_valid(unit) and str(unit.get_meta("department", "")) == selected_department:
				unit.set_meta("destination", destination)
				unit.set_meta("center", destination)
				unit.set_meta("patrol", mode == "parade")
				unit.set_meta("radius", 14.0)
	if mode == "attack":
		var origin: Vector3 = player.global_position if player else Vector3(0, 12, 0)
		for unit in units:
			if is_instance_valid(unit) and str(unit.get_meta("department", "")) == selected_department:
				origin = unit.global_position
				break
		_launch_missile(destination, false, origin)
	_log("دستور %s برای %s به مختصات X=%.1f و Z=%.1f صادر شد؛ %d یگان." % [mode, selected_department, destination.x, destination.z, matched])

func _order_fighter_attack(destination: Vector3, nuclear: bool) -> void:
	var fighter: Node3D
	for unit in units:
		if is_instance_valid(unit) and str(unit.get_meta("department", "")) == "نیروی هوایی" and bool(unit.get_meta("is_aircraft", false)):
			fighter = unit
			break
	if fighter == null:
		var previous_department: String = selected_department
		selected_department = "نیروی هوایی"
		_spawn_aircraft("Aircraft_Fighter", Vector3(0, 18, 12), COLORS[1], false)
		selected_department = previous_department
		fighter = units.back()
	_launch_missile(destination, nuclear, fighter.global_position)
	_log("جنگنده به مختصات انتخابی حمله کرد." if not nuclear else "جنگنده بمب هسته‌ای خیالی را در بازی رها کرد؛ اثر بزرگ نمایشی فعال شد.")

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
