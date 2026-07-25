extends EditorConsoleSingleton.CommandBase

const MCPUtil = preload("res://addons/editor_console/src/default_commands/hidden/mcp/mcp_util.gd")


const _HELP = \
"Remove mcp from Kimi Code in the project directory.
Usage: mcp remove kimi"

static func get_command_name():
	return "kimi"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	MCPUtil.remove_mcp(get_command_name())
