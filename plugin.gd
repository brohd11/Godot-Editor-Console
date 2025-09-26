@tool
extends EditorPlugin

var editor_console

func _get_plugin_name() -> String:
	return "Godot Console"

func _enter_tree() -> void:
	editor_console = EditorConsole.register_plugin(self)

func _exit_tree() -> void:
	if is_instance_valid(editor_console):
		editor_console.unregister_node(self)
