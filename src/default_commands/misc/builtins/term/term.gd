extends EditorConsoleSingleton.CommandBase

const UOs = UtilsRemote.UOs

const _HELP = \
"Launch an OS terminal in a project directory.
Usage: term [{path:ctx.cwd}]"

static func get_command_name() -> String:
	return "term"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _execute(ctx:CompletionContext):
	var dir := ctx.cwd
	if not positional_args.is_empty():
		dir = _complete_path(positional_args[0], ctx.cwd)
	var globalized := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(globalized):
		ctx.append_error("Directory does not exist: " + dir)
		return ExitCode.FAIL
	UOs.launch_term("", dir)
