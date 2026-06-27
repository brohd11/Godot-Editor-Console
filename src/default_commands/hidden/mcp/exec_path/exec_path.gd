extends EditorConsoleSingleton.CommandBase

const Config = EditorConsoleSingleton.Config

const _HELP = \
"Set the exec path for the EditorConsole mcp server binary.
No argument will read the current setting.
Usage: mcp exec_path [new_path]"

static func get_command_name():
	return "exec_path"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "max: 1"
	})

func _execute(ctx:CompletionContext):
	var config:Config = Config.get_global_config()
	var settings = config.get_section(Config.SETTINGS, {})
	
	if positional_args.size() == 0:
		var exec_path = settings.get(&"mcp_exec_path", "")
		if exec_path != "" and FileAccess.file_exists(exec_path):
			ctx.append_output("Valid: " + exec_path)
		else:
			if exec_path == "":
				exec_path = "Not set"
			ctx.append_output("Not Valid: " + exec_path)
	else:
		settings[&"mcp_exec_path"] = positional_args[0]
		config.write()
		ctx.append_output("Added exec path: " + positional_args[0])
