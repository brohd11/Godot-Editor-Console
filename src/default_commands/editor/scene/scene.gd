extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Edited scene commands (new/save/reload/root/select). For node commands, pipe 'editor scene root' or 'editor scene select' into 'tree'."

static func get_command_name():
	return "scene"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
