extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Misc commands."

static func get_command_name() -> String:
	return "misc"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP
	})
