extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Manage plugins in addons folder."

static func get_command_name():
	return "plugin"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
