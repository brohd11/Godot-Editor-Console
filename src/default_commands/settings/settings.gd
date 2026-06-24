extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Get or set editor/project settings.
Pass-through command — routes to its subcommands."

static func get_command_name():
	return "settings"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
