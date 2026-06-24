extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Add a new node to the edited scene.
Parent is the first selected node, or the scene root if nothing is selected.
Usage: scene edited add <ClassName> [name] [--select]"

var select_flag := false

static func get_command_name() -> String:
	return "add"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1,max:2",
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--select", {
		&"help": "Select the newly created node."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--select":
		select_flag = true

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	var type = positional_args[0]
	if not ClassDB.class_exists(type) or not ClassDB.can_instantiate(type):
		ctx.append_error("Cannot instantiate class: " + type)
		return ExitCode.FAIL

	var node = ClassDB.instantiate(type)
	if not node is Node:
		ctx.append_error("Class is not a Node: " + type)
		if node is Object and not node is RefCounted:
			node.free()
		return ExitCode.FAIL

	if positional_args.size() > 1:
		node.name = positional_args[1]

	var selection = EditorInterface.get_selection()
	var selected = selection.get_selected_nodes()
	var parent:Node = selected[0] if not selected.is_empty() else root

	parent.add_child(node)
	node.set_owner(root)

	if select_flag:
		selection.clear()
		selection.add_node(node)

	ctx.append_output(str(root.get_path_to(node)))
