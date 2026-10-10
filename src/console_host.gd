extends "res://addons/_lib/gdsh/src/core/host.gd"
## The console's commands, main ctx (aliases, .gdrc, undo, editor hooks) and serial queue for
## outside callers such as mcp-sh-godot. Make one with EditorConsoleSingleton.create_host().
## Requests keep their own working directory and node, apart from the console prompt's.


func _get_scopes() -> Dictionary:
	return EditorConsoleSingleton.get_instance().get_current_scope_data()


func _create_root_ctx():
	return EditorConsoleSingleton.get_main_ctx()


func _run_serialized(work:Callable):
	return await EditorConsoleSingleton.run_serialized(work)
