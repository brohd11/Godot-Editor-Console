extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Manage EditorConsole commands.
Pass-through command — routes to its subcommands."

static func get_command_name() -> String:
	return "command"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP
	})
