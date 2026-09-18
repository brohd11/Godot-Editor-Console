extends EditorConsoleSingleton.CommandBase

static func get_command_name() -> String:
	return "global"

static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": "Configure global-class tools.\nPass-through command — routes to its subcommands."})
