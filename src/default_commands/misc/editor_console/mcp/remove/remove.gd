extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Remove the EditorConsole MCP from coding agent"

static func get_command_name():
	return "remove"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
