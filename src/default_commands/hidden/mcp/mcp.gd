extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Commands for the Editor Console MCP server."

static func get_command_name():
	return "mcp"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
