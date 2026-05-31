extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Reload config from files."

static func get_command_name():
	return "reload"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _execute(_ctx:CompletionContext):
	UtilsLocal.Config.load_config()
