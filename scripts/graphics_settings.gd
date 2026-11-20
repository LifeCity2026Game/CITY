extends CanvasLayer
## Adaptive mobile graphics controller for LIFE CITY.
## Starts with a safe device-based preset, then adjusts 3D quality using sustained FPS.

var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var settings_panel: PanelContainer
var player_node: CharacterBody3D
var sensitivity_slider: HSlider
var sensitivity_label: Label
var profile_label: Label

var quality_mode: String = "auto"
var current_quality: String = "medium"
var _sample_elapsed: float = 0.0
var _warmup_remaining: float = 10.0
var _low_fps_samples: int = 0
var _high_fps_samples: int = 0
var _last_fps: float = 0.0

const SAMPLE_INTERVAL := 3.0
const LOW_FPS_LIMIT := 29.0
const HIGH_FPS_LIMIT := 53.0

func configure(env_node: WorldEnvironment, sun_node: DirectionalLight3D, controlled_player: CharacterBody3D) -> void:
	world_environment = env_node
	sun_light = sun_node
	player_node = controlled_player
	_build_menu()
	_load_saved_settings()

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
	settings_panel.position = Vector2(-270, 76)
	settings_panel.anchor_left = 1.0
	settings_panel.anchor_right = 1.0
	settings_panel.custom_minimum_size = Vector2(250, 315)
	settings_panel.visible = false
	add_child(settings_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	settings_panel.add_child(column)

	var heading := Label.new()
	heading.text = "کیفیت هوشمند گرافیک"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	profile_label = Label.new()
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(profile_label)

	var auto_button := Button.new()
	auto_button.text = "خودکار | پیشنهاد شده"
	_style_button(auto_button)
	column.add_child(auto_button)
	auto_button.pressed.connect(set_auto_mode)

	_add_quality_button(column, "اقتصادی", "low")
	_add_quality_button(column, "متعادل", "medium")
	_add_quality_button(column, "کیفیت بالا", "high")

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
	_update_profile_label()

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

func _load_saved_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://graphics.cfg") == OK:
		quality_mode = str(config.get_value("graphics", "mode", "auto"))
		current_quality = str(config.get_value("graphics", "quality", "medium"))
	else:
		quality_mode = "auto"
		current_quality = _detect_starting_quality()
	if quality_mode == "auto":
		if current_quality not in ["low", "medium", "high"]:
			current_quality = _detect_starting_quality()
		_apply_quality_preset(current_quality)
	else:
		quality_mode = "manual"
		apply_quality(current_quality)
	_update_profile_label()

func _detect_starting_quality() -> String:
	# CPU core count is only an initial estimate; live frame-time feedback
	# corrects for GPU limits, thermal throttling and device-specific drivers.
	var cores := OS.get_processor_count()
	if OS.get_name() == "Android":
		if cores <= 4:
			return "low"
		return "medium"
	if cores <= 4:
		return "medium"
	return "high"

func set_auto_mode() -> void:
	quality_mode = "auto"
	_low_fps_samples = 0
	_high_fps_samples = 0
	_warmup_remaining = 8.0
	current_quality = _detect_starting_quality()
	_apply_quality_preset(current_quality)
	_save_graphics_settings()
	_update_profile_label()
	settings_panel.visible = false

func apply_quality(preset: String) -> void:
	if preset not in ["low", "medium", "high"]:
		return
	quality_mode = "manual"
	current_quality = preset
	_apply_quality_preset(preset)
	_save_graphics_settings()
	_update_profile_label()
	if settings_panel:
		settings_panel.visible = false

func _apply_quality_preset(preset: String) -> void:
	if world_environment == null or sun_light == null:
		return
	var viewport := get_viewport()
	match preset:
		"low":
			sun_light.shadow_enabled = false
			sun_light.light_energy = 0.98
			world_environment.environment.ambient_light_energy = 0.82
			viewport.scaling_3d_scale = 0.72
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		"medium":
			sun_light.shadow_enabled = true
			sun_light.light_energy = 1.08
			world_environment.environment.ambient_light_energy = 0.74
			viewport.scaling_3d_scale = 0.85
			viewport.msaa_3d = Viewport.MSAA_2X
		"high":
			sun_light.shadow_enabled = true
			sun_light.light_energy = 1.15
			world_environment.environment.ambient_light_energy = 0.68
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X
	current_quality = preset
	_update_profile_label()

func evaluate_performance_sample(fps: float) -> void:
	# Public and deterministic so CI can test the adaptive policy without a GPU.
	if quality_mode != "auto" or fps <= 0.0:
		return
	_last_fps = fps
	if fps < LOW_FPS_LIMIT:
		_low_fps_samples += 1
		_high_fps_samples = 0
	elif fps >= HIGH_FPS_LIMIT:
		_high_fps_samples += 1
		_low_fps_samples = 0
	else:
		_low_fps_samples = 0
		_high_fps_samples = 0

	if _low_fps_samples >= 2:
		_step_quality_down()
		_low_fps_samples = 0
	elif _high_fps_samples >= 3:
		_step_quality_up()
		_high_fps_samples = 0
	_update_profile_label()

func _step_quality_down() -> void:
	if current_quality == "high":
		_apply_quality_preset("medium")
	elif current_quality == "medium":
		_apply_quality_preset("low")

func _step_quality_up() -> void:
	if current_quality == "low":
		_apply_quality_preset("medium")
	elif current_quality == "medium":
		_apply_quality_preset("high")

func _process(delta: float) -> void:
	if quality_mode != "auto":
		return
	if _warmup_remaining > 0.0:
		_warmup_remaining = maxf(0.0, _warmup_remaining - delta)
		return
	_sample_elapsed += delta
	if _sample_elapsed < SAMPLE_INTERVAL:
		return
	_sample_elapsed = 0.0
	var fps := float(Engine.get_frames_per_second())
	if fps > 0.0:
		evaluate_performance_sample(fps)

func _save_graphics_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "mode", quality_mode)
	config.set_value("graphics", "quality", current_quality)
	config.save("user://graphics.cfg")

func _update_profile_label() -> void:
	if not is_instance_valid(profile_label):
		return
	var mode_text := "خودکار" if quality_mode == "auto" else "دستی"
	var quality_text := {"low": "اقتصادی", "medium": "متعادل", "high": "بالا"}.get(current_quality, current_quality)
	var fps_text := "در حال سنجش" if _last_fps <= 0.0 else "%.0f FPS" % _last_fps
	profile_label.text = "%s | %s\n%s" % [mode_text, quality_text, fps_text]

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
