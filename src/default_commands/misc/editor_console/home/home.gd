extends EditorConsoleSingleton.CommandBase

const _HELP = "Get user home dir."

static func get_command_name() -> String:
	return "home"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:Context) -> int:
	var home = UtilsRemote.UOs.get_home_dir()
	if DirAccess.dir_exists_absolute(home):
		ctx.append_output(home)
		return ExitCode.OK
	ctx.append_error("Home directory doesn't exist: " + home)
	return ExitCode.FAIL

func _get_completions(completion:Completion):
	return {}
