@tool
extends EditorPlugin

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")



var editor_console

func _get_plugin_name() -> String:
	return "Godot Console"

func _enter_tree() -> void:
	editor_console = EditorConsole.register_plugin(self)



func _exit_tree() -> void:
	if is_instance_valid(editor_console):
		editor_console.clear_reference(self)
