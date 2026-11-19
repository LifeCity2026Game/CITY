extends CanvasLayer
## Runtime graphics presets for LIFE CITY. Settings are saved locally on this device.

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var settings_panel: PanelContainer
var player_node: CharacterBody3D
var sensitivity_slider: HSlider
var sensitivity_label: Label

func configure(env_node: WorldEnvironment, sun_node: DirectionalLight3D, controlled_player: CharacterBody3D) -> void:
	world_environment = env_node
	sun_light = sun_node
	player_node = controlled_player
	_build_menu()
	_load_saved_quality()

func _build_menu() -> void:
	var open_button := Button.new()
	open_button.text = "گرافیک"
	open_button.position = Vector2(-150, 18)
	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.custom_minimum_size = Vector2(150, 50)
	_style_button(open_button)
	add_child(open_button)
	open_button.pressed.connect(_toggle_panel)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(-240, 76)
	settings_panel.anchor_left = 1.0
	settings_panel.anchor_right = 1.0
	settings_panel.custom_minimum_size = Vector2(220, 190)
	settings_panel.visible = false
	add_child(settings_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	settings_panel.add_child(column)

	var heading := Label.new()
	heading.text = "کیفیت گرافیک"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_add_quality_button(column, "اقتصادی", "low")
	_add_quality_button(column, "متعادل", "medium")
	_add_quality_button(column, "با کیفیت", "high")

	var camera_heading := Label.new()
	camera_heading.text = "حساسیت چرخش دوربین"
	camera_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(camera_heading)
	sensitivity_label = Label.new()
	sensitivity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sensitivity_label)
	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.1
	sensitivity_slider.max_value = 3.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = _load_camera_sensitivity()
	column.add_child(sensitivity_slider)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_on_sensitivity_changed(sensitivity_slider.value)

	var close_button := Button.new()
	close_button.text = "بستن"
	_style_button(close_button)
	column.add_child(close_button)
	close_button.pressed.connect(func(): settings_panel.visible = false)

func _add_quality_button(parent: VBoxContainer, caption: String, preset: String) -> void:
	var button := Button.new()
	button.text = caption
	_style_button(button)
	parent.add_child(button)
	button.pressed.connect(func(): apply_quality(preset))

func _load_camera_sensitivity() -> float:
	var config := ConfigFile.new()
	if config.load("user://camera.cfg") == OK:
		return clampf(float(config.get_value("camera", "sensitivity", 0.8)), 0.1, 3.0)
	return 0.8

func _on_sensitivity_changed(value: float) -> void:
	if player_node:
		player_node.set_camera_sensitivity(value)
	if sensitivity_label:
		sensitivity_label.text = "%.1fx" % value
	var config := ConfigFile.new()
	config.set_value("camera", "sensitivity", value)
	config.save("user://camera.cfg")

func _toggle_panel() -> void:
	settings_panel.visible = not settings_panel.visible

func apply_quality(preset: String) -> void:
	if world_environment == null or sun_light == null:
		return
	match preset:
		"low":
			sun_light.shadow_enabled = false
			sun_light.light_energy = 0.95
			world_environment.environment.ambient_light_energy = 0.85
		"medium":
			sun_light.shadow_enabled = true
			sun_light.light_energy = 1.05
			world_environment.environment.ambient_light_energy = 0.72
		"high":
			sun_light.shadow_enabled = true
			sun_light.light_energy = 1.15
			world_environment.environment.ambient_light_energy = 0.68
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", preset)
	config.save("user://graphics.cfg")
	settings_panel.visible = false

func _load_saved_quality() -> void:
	var config := ConfigFile.new()
	if config.load("user://graphics.cfg") == OK:
		apply_quality(str(config.get_value("graphics", "quality", "medium")))
	else:
		apply_quality("medium")

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2878d5")
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("3689e8")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1e5eaa")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 17)
