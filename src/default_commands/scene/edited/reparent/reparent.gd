extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Reparent nodes under a target node (keeps global transform).
Targets come from stdin (node paths) or the selection.
Usage: ... | dev reparent <target_node_path>"

static func get_command_name() -> String:
	return "reparent"

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

	var target = root.get_node_or_null(positional_args[0])
	if not is_instance_valid(target):
		ctx.append_error("Target node not found: " + positional_args[0])
		return ExitCode.FAIL

	var nodes := _resolve_nodes(ctx, root)
	if nodes.is_empty():
		ctx.append_error("No target nodes (pipe node paths or select nodes).")
		return ExitCode.FAIL

	var count := 0
	for n:Node in nodes:
		if n == root:
			ctx.append_error("Cannot reparent the scene root.")
			continue
		if n == target or n.is_ancestor_of(target):
			ctx.append_error("Cannot reparent '%s' into itself or its own descendant." % n.name)
			continue
		n.reparent(target, true)
		n.set_owner(root)
		count += 1

	ctx.append_output("Reparented %s node(s) under %s." % [count, target.name])

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
