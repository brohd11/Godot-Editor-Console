extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Select nodes in the edited scene. Node paths come from stdin (one per line).
Usage: ... | editor scene select"

var add_flag:=false

static func get_command_name():
	return "select"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	
	var edited_root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_root):
		ctx.append_error("Could not get edited scene root.")
		return
	
	var editor_selection = EditorInterface.get_selection()
	if not add_flag:
		editor_selection.clear()
	
	var node_paths = ctx.stdin.split("\n", false)
	if node_paths.is_empty():
		ctx.append_error("No paths provided to select.")
		return
	
	for p in node_paths:
		var node = edited_root.get_node_or_null(p)
		if is_instance_valid(node):
			editor_selection.add_node(node)
		else:
			ctx.append_output("Could not find node: " + p)
