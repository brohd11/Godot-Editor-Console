extends EditorConsoleSingleton.CommandBase

const Config = EditorConsoleSingleton.Config

const _HELP = \
"Add mcp exec to Claude Code in the project directory.
Requires 'mcp_exec_path' to be set via mcp exec_path.
Usage: mcp add_to_claude"

const MCP_NAME = "godot-editor-console"

static func get_command_name():
	return "add_to_claude"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var config:Config = Config.get_global_config()
	var settings = config.get_section(Config.SETTINGS, {})
	var exec_path = settings.get(&"mcp_exec_path", "")
	if exec_path == "" or not FileAccess.file_exists(exec_path):
		ctx.append_output("MCP binary not valid: " + exec_path)
		return ExitCode.FAIL
	
	# remove first
	var rem_out = []
	OS.execute("claude", ["mcp", "remove", MCP_NAME, "2>/dev/null", "||", "true"], rem_out)
	#ctx.append_output(rem_out[0]) # can print, but don't really need to
	
	var out = []
	var exit = OS.execute("claude", ["mcp", "add", MCP_NAME, "--", exec_path], out, true)
	ctx.append_output(out[0])
	if out.size() > 1:
		ctx.append_error(out[1])
	
	return exit
