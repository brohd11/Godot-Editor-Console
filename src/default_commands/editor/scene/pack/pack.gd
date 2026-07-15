extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Pack the edited scene (or a subtree) into a PackedScene file.
Usage: editor scene pack <res://dest.tscn> [--from=node_path]
The destination path is written to stdout (pipe into 'open')."

var from_flag := ""

static func get_command_name() -> String:
	return "pack"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--from=", {&"help": "Node path of the subtree root to pack.", &"trailing_char": ""})
	return options.get_options()

func _process_flag(flag:String):
	if flag.begins_with("--from="):
		from_flag = _get_flag_value(flag)

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene open.")
		return ExitCode.FAIL

	var dest = positional_args[0]
	var target:Node = root

	if from_flag != "":
		target = root.get_node_or_null(from_flag)
	else:
		var selected = EditorInterface.get_selection().get_selected_nodes()
		if not selected.is_empty():
			target = selected[0]

	if not is_instance_valid(target):
		ctx.append_error("Subtree node not found: " + from_flag)
		return ExitCode.FAIL

	# Children must be owned by the subtree root to be included in the pack.
	if target != root:
		for child in _descendants(target):
			child.set_owner(target)

	var packed = PackedScene.new()
	var err = packed.pack(target)
	if err != OK:
		ctx.append_error("Pack failed (error %s): %s" % [err, error_string(err)])
		return ExitCode.FAIL
	err = ResourceSaver.save(packed, dest)
	if err != OK:
		ctx.append_error("Save failed (error %s): %s" % [err, error_string(err)])
		return ExitCode.FAIL

	EditorInterface.get_resource_filesystem().update_file(dest)
	ctx.append_output(dest)

func _descendants(node:Node) -> Array:
	var out := []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
