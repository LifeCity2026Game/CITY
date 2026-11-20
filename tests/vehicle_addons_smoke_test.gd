extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _fail(message: String) -> void:
	push_error("VEHICLE_ADDONS_SMOKE_TEST_FAIL: " + message)
	quit(1)
func _run() -> void:
	var paths := [
		"res://addons/lc_vehicle_modeling/plugin.cfg",
		"res://addons/lc_vehicle_interior/plugin.cfg",
		"res://addons/lc_vehicle_rigging/plugin.cfg",
		"res://addons/lc_vehicle_physics/plugin.cfg",
		"res://addons/lc_vehicle_damage_audio/plugin.cfg"
	]
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	for path in paths:
		if not FileAccess.file_exists(path):
			_fail("Missing plugin config: " + path)
			return
		if not enabled.has(path):
			_fail("Plugin is not enabled in project.godot: " + path)
			return
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			_fail("Could not parse plugin config: " + path)
			return
		var script_path := path.get_base_dir() + "/" + str(cfg.get_value("plugin", "script", ""))
		if not FileAccess.file_exists(script_path) or load(script_path) == null:
			_fail("Plugin script could not be loaded: " + script_path)
			return
	print("VEHICLE_ADDONS_SMOKE_TEST_PASS")
	quit(0)
