extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Editor control commands (play, open, scan, …).
Pass-through command — routes to its subcommands."

static func get_command_name():
	return "editor"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
