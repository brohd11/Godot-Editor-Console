extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Commands for the Editor Console MCP server.
Pass-through command — routes to its subcommands."

static func get_command_name():
	return "mcp"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
