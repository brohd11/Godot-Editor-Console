extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Get or set a property on nodes. Targets come from stdin (node paths, one per line);
if stdin is empty the current editor selection is used.
Usage:
  ... | prop <name>              print the property for each node
  ... | prop <name> <value>      set the property on each node
Value is converted to the property's current type (falls back to str_to_var).
Nested paths are supported, e.g. 'position:x'."

static func get_command_name() -> String:
	return "prop"

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

	var prop_name = positional_args[0]
	var has_value = positional_args.size() > 1

	var nodes := _resolve_nodes(ctx, root)
	if nodes.is_empty():
		ctx.append_error("No target nodes (pipe node paths via stdin or select nodes).")
		return ExitCode.FAIL

	var prop_path := NodePath(prop_name)
	for n:Node in nodes:
		var node_path = str(root.get_path_to(n))
		if has_value:
			var current = n.get_indexed(prop_path)
			var converted = _convert_value(positional_args[1], current)
			n.set_indexed(prop_path, converted)
			ctx.append_output("%s.%s = %s" % [node_path, prop_name, str(converted)])
		else:
			ctx.append_output("%s.%s = %s" % [node_path, prop_name, str(n.get_indexed(prop_path))])

func _convert_value(value_str:String, current):
	if current != null:
		var converted = ConsoleTokenizer.Var.auto_convert(value_str, typeof(current))
		if converted != null:
			return converted
	var parsed = str_to_var(value_str)
	if parsed != null:
		return parsed
	return value_str

func _resolve_nodes(ctx:CompletionContext, root:Node) -> Array:
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
	return nodes
