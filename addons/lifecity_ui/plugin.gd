@tool
extends EditorPlugin

const AUTOLOAD_NAME := "LifeCityUI"
const AUTOLOAD_PATH := "res://addons/lifecity_ui/ui_manager.gd"

func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	# Keep the runtime singleton configured in project.godot.
	pass
