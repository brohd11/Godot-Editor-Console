extends EditorConsoleSingleton.CommandBase


const _HELP = \
"These are utility commands, some mimic bash and some are for performing simple commands.
They can also be accessed without using the 'builtins' keyword."

static func get_command_name():
	return "builtins"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
