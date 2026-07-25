extends EditorConsoleSingleton.CommandBase


const MCPUtil = preload("res://addons/editor_console/src/default_commands/hidden/mcp/mcp_util.gd")

const _HELP = \
"Add mcp exec to Claude Code in the project directory.
Default path: ~/.local/bin; 'mcp_exec_path'
Usage: mcp add claude"


static func get_command_name():
	return "claude"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var exec_path = MCPUtil.get_mcp_exec_path()
	if not FileAccess.file_exists(exec_path):
		ctx.append_output("MCP binary not valid: " + exec_path)
		return ExitCode.FAIL
	
	# remove first
	MCPUtil.remove_mcp(get_command_name())
	
	var out = []
	var exit = OS.execute(get_command_name(), ["mcp", "add", MCPUtil.MCP_NAME, "--", exec_path], out, true)
	ctx.append_output(out[0])
	if out.size() > 1:
		ctx.append_error(out[1])
	
	return exit
