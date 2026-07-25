extends EditorConsoleSingleton.CommandBase

const Config = EditorConsoleSingleton.Config

const MCPUtil = preload("res://addons/editor_console/src/default_commands/hidden/mcp/mcp_util.gd")

const _HELP = \
"Set the exec path for the EditorConsole mcp server binary.
No argument will read the current setting.
Usage: mcp exec_path [--remove] [new_path]"

var remove_flag:=false

static func get_command_name():
	return "exec_path"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "max: 1"
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--remove", {
		&"help": "Remove the exec path overide"
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--remove":
		remove_flag = true

func _execute(ctx:CompletionContext):
	var config:Config = Config.get_global_config()
	var settings = config.get_section(Config.SETTINGS, {})
	if remove_flag:
		settings.erase(MCPUtil.SETTING_EXEC_PATH)
		config.write()
		ctx.append_output("Removed mcp exec path.")
	elif positional_args.size() == 0:
		var exec_path = settings.get(MCPUtil.SETTING_EXEC_PATH, MCPUtil.get_default_exec_path())
		if FileAccess.file_exists(exec_path):
			ctx.append_output("Valid: " + exec_path)
		else:
			ctx.append_output("Not Valid: " + exec_path)
	else:
		settings[MCPUtil.SETTING_EXEC_PATH] = positional_args[0]
		config.write()
		ctx.append_output("Added exec path: " + positional_args[0])
