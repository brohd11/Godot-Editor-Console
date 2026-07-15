extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Instance a scene as a child of the selected node (or the scene root).
Usage: editor scene instance <res://scene.tscn> [--select]"

var select_flag := false

static func get_command_name() -> String:
	return "instance"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--select", {&"help": "Select the new instance."})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--select":
		select_flag = true

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	var scene_path = positional_args[0]
	if not FileAccess.file_exists(scene_path):
		ctx.append_error("Scene does not exist: " + scene_path)
		return ExitCode.FAIL
	var packed = load(scene_path)
	if not packed is PackedScene:
		ctx.append_error("Not a PackedScene: " + scene_path)
		return ExitCode.FAIL

	var node = packed.instantiate()
	if not is_instance_valid(node):
		ctx.append_error("Failed to instantiate: " + scene_path)
		return ExitCode.FAIL

	var selection = EditorInterface.get_selection()
	var selected = selection.get_selected_nodes()
	var parent:Node = selected[0] if not selected.is_empty() else root

	var a = ConsoleUndo.action("Instance %s" % scene_path.get_file())
	a.do_method(parent, &"add_child", [node])
	a.do_method(node, &"set_owner", [root])
	a.do_reference(node)
	a.undo_method(parent, &"remove_child", [node])
	a.commit()

	if select_flag:
		selection.clear()
		selection.add_node(node)

	ctx.append_output(str(root.get_path_to(node)))
