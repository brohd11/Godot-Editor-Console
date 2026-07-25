extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Add the EditorConsole MCP to a coding agent."

static func get_command_name():
	return "add"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
