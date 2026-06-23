extends EditorConsoleSingleton.CommandBase

const _HELP = \
"List the properties of a node or resource.
Source is, in order: the argument or stdin (a node path like '.' / 'Path/To/Node',
or a res:// resource path), else the editor selection, else the inspector object.
Usage: dev inspect [target] [--methods]
  --methods    also list the object's methods"

var methods_flag := false

static func get_command_name() -> String:
	return "inspect"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--methods", {
		&"help": "Also list the object's methods."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--methods":
		methods_flag = true

func _execute(ctx:CompletionContext):
	var obj = _resolve_object(ctx)
	if not is_instance_valid(obj):
		ctx.append_error("Nothing to inspect (provide a path, pipe one in, or select an object in the inspector).")
		return ExitCode.FAIL

	ctx.append_output(Pr.new().append(obj.get_class(), Colors.SCOPE).get_string())

	for p in obj.get_property_list():
		var usage:int = p.get("usage", 0)
		if usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			continue
		if not (usage & PROPERTY_USAGE_EDITOR) and not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var name = p.get("name", "")
		if name == "":
			continue
		var pr = Pr.new()
		pr.append("  " + name, Colors.ACCENT_MUTE).append(" = ").append(str(obj.get(name)))
		ctx.append_output(pr.get_string())

	if methods_flag:
		ctx.append_output(Pr.new().append("methods:", Colors.SCOPE).get_string())
		for m in obj.get_method_list():
			ctx.append_output("  " + m.get("name", ""))

func _resolve_object(ctx:CompletionContext):
	var path := ""
	if not positional_args.is_empty():
		path = positional_args[0]
	elif ctx.stdin.strip_edges() != "":
		for line in ctx.stdin.split("\n", false):
			if line.strip_edges() != "":
				path = line.strip_edges()
				break

	if path != "":
		# A target string is a node path (resolved against the edited scene root,
		# matching 'dev tree'/'dev prop'), falling back to a res:// resource path.
		var root = EditorInterface.get_edited_scene_root()
		if is_instance_valid(root):
			var node = root.get_node_or_null(path)
			if is_instance_valid(node):
				return node
		if FileAccess.file_exists(path):
			return load(path)
		ctx.append_error("Not a node or resource: " + path)
		return null

	# No target: prefer the editor selection (consistent with the node commands),
	# then the object currently open in the inspector.
	var selected = EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty():
		return selected[0]

	var inspector = EditorInterface.get_inspector()
	if is_instance_valid(inspector):
		return inspector.get_edited_object()
	return null
