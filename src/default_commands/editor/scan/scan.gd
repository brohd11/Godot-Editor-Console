extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Rescan the project filesystem (picks up files added/removed outside the editor).
Usage: editor scan"

static func get_command_name() -> String:
	return "scan"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var fs = EditorInterface.get_resource_filesystem()
	if not is_instance_valid(fs):
		ctx.append_error("Could not access the resource filesystem.")
		return ExitCode.FAIL
	fs.scan()
	ctx.append_output("Filesystem rescan started.")
