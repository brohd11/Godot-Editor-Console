extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Save the currently edited scene.
Usage: save [--as=res://path.tscn]
  --as=    save the scene to a new path"

var as_flag := ""

static func get_command_name() -> String:
	return "save"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--as=", {
		&"help": "Save the edited scene to a new path.",
		&"trailing_char": "",
		&"flag_completion": {"type": FlagType.FILE, "ext": ["tscn", "scn"]},
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag.begins_with("--as="):
		as_flag = _get_flag_value(flag)

func _execute(ctx:CompletionContext):
	var root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(root):
		ctx.append_error("No edited scene to save.")
		return ExitCode.FAIL

	var err:int
	if as_flag != "":
		EditorInterface.save_scene_as(as_flag)
	else:
		err = EditorInterface.save_scene()

	if err != OK:
		ctx.append_error("Save failed (error %s): %s" % [err, error_string(err)])
		return ExitCode.FAIL
	ctx.append_output("Saved scene: " + (as_flag if as_flag != "" else root.scene_file_path))
