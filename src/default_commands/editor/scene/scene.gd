extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Commands on the current edited scene (add/prop/tree/…). Path-selected scene files are file ops (see 'resource')."

static func get_command_name():
	return "scene"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
