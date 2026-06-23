extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Rename a node. The target node path comes from stdin (or the single selected node).
Usage: ... | rename <new_name>"

static func get_command_name() -> String:
	return "rename"

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

	var nodes := []
	var stdin = ctx.stdin.strip_edges()
	if stdin != "":
		for line in ctx.stdin.split("\n", false):
			var p = line.strip_edges()
			if p == "":
				continue
			var node = root.get_node_or_null(p)
			if is_instance_valid(node):
				nodes.append(node)
	else:
		nodes = EditorInterface.get_selection().get_selected_nodes()

	if nodes.size() != 1:
		ctx.append_error("rename expects exactly one target node, got %s." % nodes.size())
		return ExitCode.FAIL

	var new_name = positional_args[0]
	var node:Node = nodes[0]
	var old_name = node.name
	node.name = new_name
	ctx.append_output("Renamed '%s' -> '%s'" % [old_name, node.name])
