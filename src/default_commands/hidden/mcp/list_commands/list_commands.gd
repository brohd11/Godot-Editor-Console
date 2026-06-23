extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

static func get_command_name():
	return "list_commands"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var ins = EditorConsoleSingleton.get_instance()
	ctx.append_output(ins.get_command_list())
