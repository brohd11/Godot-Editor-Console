extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Create a directory (recursively) in the project.
Usage: dev mkdir <res://dir>"

static func get_command_name() -> String:
	return "mkdir"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _execute(ctx:CompletionContext):
	var dir = positional_args[0]
	if DirAccess.dir_exists_absolute(dir):
		ctx.append_output("Directory already exists: " + dir)
		return
	var err = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		ctx.append_error("mkdir failed (error %s): %s" % [err, dir])
		return ExitCode.FAIL
	EditorInterface.get_resource_filesystem().scan()
	ctx.append_output(dir)
