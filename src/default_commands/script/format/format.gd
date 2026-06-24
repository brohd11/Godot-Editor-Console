extends EditorConsoleSingleton.CommandBase

static func get_command_name() -> String:
	return "format"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Formatting tools for the current script.\nPass-through command — routes to its subcommands."
	})
