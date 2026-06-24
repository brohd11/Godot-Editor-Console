extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Commands related to the scene tree.
Pass-through command — routes to its subcommands."

static func get_command_name():
	return "scene"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
