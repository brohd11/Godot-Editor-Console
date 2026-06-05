extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Reload config from files and default/registered commands.
Usage: config reload"

static func get_command_name():
	return "reload"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _execute(ctx:CompletionContext):
	UtilsLocal.Config.load_config()
	ctx.append_output("Config reloaded.")
	var success = EditorConsoleSingleton.get_instance()._load_default_commands()
	if success:
		ctx.append_output("Commands reloaded.")
	
	
