extends CanvasLayer
## Runtime graphics presets for LIFE CITY. Settings are saved locally on this device.

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var settings_panel: PanelContainer

func configure(env_node: WorldEnvironment, sun_node: DirectionalLight3D) -> void:
	world_environment = env_node
	sun_light = sun_node
	_build_menu()
	_load_saved_quality()

func _build_menu() -> void:
	var open_button := Button.new()
	open_button.text = "گرافیک"
	open_button.position = Vector2(-150, 18)
	open_button.anchor_left = 1.0
	open_button.anchor_right = 1.0
	open_button.custom_minimum_size = Vector2(130, 48)
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

	var close_button := Button.new()
	close_button.text = "بستن"
	column.add_child(close_button)
	close_button.pressed.connect(func(): settings_panel.visible = false)

func _add_quality_button(parent: VBoxContainer, caption: String, preset: String) -> void:
	var button := Button.new()
	button.text = caption
	parent.add_child(button)
	button.pressed.connect(func(): apply_quality(preset))

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
