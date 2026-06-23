extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Delete nodes from the edited scene. Node paths come from stdin (one per line),
or the current selection if stdin is empty.
Usage: ... | delete"

static func get_command_name() -> String:
	return "delete"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
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
				ctx.append_error("Node not found: " + p)
	else:
		nodes = EditorInterface.get_selection().get_selected_nodes()

	if nodes.is_empty():
		ctx.append_error("No target nodes to delete.")
		return ExitCode.FAIL

	var count := 0
	for n:Node in nodes:
		if n == root:
			ctx.append_error("Refusing to delete the scene root.")
			continue
		n.set_owner(null)
		n.get_parent().remove_child(n)
		n.queue_free()
		count += 1

	ctx.append_output("Deleted %s node(s)." % count)
