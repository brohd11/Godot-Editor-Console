extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Utility commands, all subcommands also accessible directly by name.
Pass-through command — routes to its subcommands."

static func get_command_name():
	return "builtins"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
