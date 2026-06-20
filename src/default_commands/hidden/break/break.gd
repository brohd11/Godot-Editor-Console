extends EditorConsoleSingleton.CommandBase

const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

static func get_command_name():
	return "break"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	for inh in ctx.get_inherited_ctxs():
		if inh.data.has(Execution._IS_LOOP_KEY):
			inh.data[Execution._LOOP_BREAK_KEY] = true
			return
	
	ctx.append_error("Cannot break when not in a loop.")
	ctx.exit_code = ExitCode.ERR
