extends SceneTree

const ADDONS := ["lc_military_hq", "lc_military_branches", "lc_military_ranks", "lc_military_logistics", "lc_military_operations"]
const DATA_FILES := {
	"res://data/military/headquarters.json": ["departments", 7],
	"res://data/military/branches.json": ["branches", 7],
	"res://data/military/ranks.json": ["ranks", 6],
	"res://data/military/logistics.json": ["inventory_categories", 4],
	"res://data/military/operations_schema.json": ["required_fields", 8]
}

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("MILITARY_ADDONS_SMOKE_TEST_FAIL: " + message)
	quit(1)

func _run() -> void:
	var project_text := FileAccess.get_file_as_string("res://project.godot")
	for addon in ADDONS:
		var cfg_path := "res://addons/%s/plugin.cfg" % addon
		var script_path := "res://addons/%s/plugin.gd" % addon
		if not FileAccess.file_exists(cfg_path) or not FileAccess.file_exists(script_path):
			_fail("Military add-on files are missing: " + addon)
			return
		var config := ConfigFile.new()
		if config.load(cfg_path) != OK or str(config.get_value("plugin", "script", "")) != "plugin.gd":
			_fail("Military add-on config is invalid: " + addon)
			return
		if not project_text.contains(cfg_path):
			_fail("Military add-on is not enabled in project.godot: " + addon)
			return
	for data_path in DATA_FILES:
		var file := FileAccess.open(data_path, FileAccess.READ)
		if file == null:
			_fail("Military data file is missing: " + data_path)
			return
		var parsed = JSON.parse_string(file.get_as_text())
		var key: String = DATA_FILES[data_path][0]
		var minimum: int = DATA_FILES[data_path][1]
		if not parsed is Dictionary or not parsed.has(key) or not parsed[key] is Array or parsed[key].size() < minimum:
			_fail("Military data validation failed: " + data_path)
			return
	var branch_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/military/branches.json"))
	if branch_data.branches.size() != 7:
		_fail("Exactly seven military branches must be registered")
		return
	var rank_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/military/ranks.json"))
	if not bool(rank_data.security.get("server_validation_required", false)) or not bool(rank_data.security.get("client_ui_is_not_authority", false)):
		_fail("Military rank permissions must require server-side validation")
		return
	print("MILITARY_ADDONS_SMOKE_TEST_PASS")
	quit(0)
