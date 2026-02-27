@tool
extends EditorPlugin

func _get_plugin_name() -> String:
	return "Editor Console"

func _enter_tree() -> void:
	EditorConsoleSingleton.register_node(self)

func _exit_tree() -> void:
	EditorConsoleSingleton.unregister_node(self)
