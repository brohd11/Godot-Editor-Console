extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Returns ExitCode.FAIL"

static func get_command_name():
	return "false"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	ctx.exit_code = ExitCode.FAIL
