extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Attach a script to nodes. Targets come from stdin (node paths) or the selection.
Usage: ... | attach <res://script.gd>"

static func get_command_name() -> String:
	return " scene edited attach"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	var script_path = positional_args[0]
	if not FileAccess.file_exists(script_path):
		ctx.append_error("Script does not exist: " + script_path)
		return ExitCode.FAIL
	var script = load(script_path)
	if not script is Script:
		ctx.append_error("Not a script: " + script_path)
		return ExitCode.FAIL

	var nodes := _resolve_nodes(ctx, root)
	if nodes.is_empty():
		ctx.append_error("No target nodes (pipe node paths or select nodes).")
		return ExitCode.FAIL

	var count := 0
	for n:Node in nodes:
		n.set_script(script)
		count += 1
	ctx.append_output("Attached %s to %s node(s)." % [script_path.get_file(), count])

func _resolve_nodes(ctx:CompletionContext, root:Node) -> Array:
	var nodes := []
	if ctx.stdin.strip_edges() != "":
		for line in ctx.stdin.split("\n", false):
			var p = line.strip_edges()
			if p == "":
				continue
			var node = root.get_node_or_null(p)
			if is_instance_valid(node):
				nodes.append(node)
			else:
				ctx.append_error("Node not found: " + p)
	else:
		nodes = EditorInterface.get_selection().get_selected_nodes()
	return nodes
