extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Manage groups on nodes. Targets come from stdin (node paths) or the selection.
Usage:
  ... | group add <name>      add nodes to a group (persistent)
  ... | group remove <name>   remove nodes from a group
  ... | group list            list each node's groups"

static func get_command_name() -> String:
	return "group"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1,max:2",
	})

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	var action = positional_args[0]
	if not action in ["add", "remove", "list"]:
		ctx.append_error("Unknown action '%s' (expected add|remove|list)." % action)
		return ExitCode.FAIL
	if action != "list" and positional_args.size() < 2:
		ctx.append_error("'%s' requires a group name." % action)
		return ExitCode.FAIL

	var nodes := _resolve_nodes(ctx, root)
	if nodes.is_empty():
		ctx.append_error("No target nodes (pipe node paths or select nodes).")
		return ExitCode.FAIL

	var group_name = positional_args[1] if positional_args.size() > 1 else ""
	for n:Node in nodes:
		var node_path = str(root.get_path_to(n))
		match action:
			"add":
				n.add_to_group(group_name, true)
				ctx.append_output("%s + [%s]" % [node_path, group_name])
			"remove":
				n.remove_from_group(group_name)
				ctx.append_output("%s - [%s]" % [node_path, group_name])
			"list":
				var groups := []
				for g in n.get_groups():
					if not str(g).begins_with("_"):
						groups.append(str(g))
				ctx.append_output("%s: %s" % [node_path, ", ".join(groups)])

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
