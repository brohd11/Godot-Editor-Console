extends EditorConsoleSingleton.CommandBase

const UNode = UtilsRemote.UNode

const _HELP = \
"Print the node tree of the edited scene.
Default output is one node path per line (pipe into 'prop', 'delete', etc).
Usage: scene edited tree [--ignore-owner] [--pretty] [--type=ClassName] [--script=res://path.gd]"

var pretty_flag := false
var type_flag := ""
var script_flag := ""
var ignore_owner_flag := false

var scene_root:Node

static func get_command_name() -> String:
	return "tree"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--pretty", {
		&"help": "Indented, colored tree (display only)."
	})
	options.add_option("--type=", {
		&"help": "Filter to nodes of this class.",
		&"trailing_char": "",
	})
	options.add_option("--script=", {
		&"help": "Filter to nodes using this script.",
		&"trailing_char": "",
		&"flag_completion": {"type": FlagType.FILE, "ext": ["gd"]},
	})
	options.add_option("--ignore-owner", {
		&"help": "Also list nodes not owned by the scene root. Includes nested packed scene nodes."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--pretty":
		pretty_flag = true
	elif flag.begins_with("--type="):
		type_flag = _get_flag_value(flag)
	elif flag.begins_with("--script="):
		script_flag = UString.unquote(_get_flag_value(flag))
	elif flag == "--ignore-owner":
		ignore_owner_flag = true

func _execute(ctx:CompletionContext):
	scene_root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	if script_flag != "" and not script_flag.is_absolute_path():
		var global_check = UtilsRemote.UClassDetail.get_global_class_path(script_flag)
		if global_check != "":
			script_flag = global_check

	if pretty_flag:
		_print_pretty(ctx, scene_root, 0)
		return

	for n in UNode.recursive_get_nodes(scene_root):
		if not _passes_filter(n):
			continue
		ctx.append_output(str(scene_root.get_path_to(n)))

func _passes_filter(n:Node) -> bool:
	if type_flag != "" and not ClassDB.is_parent_class(n.get_class(), type_flag):
		return false
	if script_flag != "":
		var script = n.get_script()
		if not is_instance_valid(script) or script.resource_path != script_flag:
			return false
	if not ignore_owner_flag:
		if n != scene_root and n.owner != scene_root:
			return false
	return true

func _print_pretty(ctx:CompletionContext, node:Node, depth:int):
	if _passes_filter(node):
		var pr = Pr.new()
		pr.append("  ".repeat(depth))
		pr.append(node.name, Colors.SCOPE)
		pr.append("  " + node.get_class(), Colors.VAR_GREY)
		var script = node.get_script()
		if is_instance_valid(script):
			pr.append("  " + script.resource_path.get_file(), Colors.ACCENT_MUTE)
		ctx.append_output(pr.get_string())
	for child in node.get_children():
		_print_pretty(ctx, child, depth + 1)
