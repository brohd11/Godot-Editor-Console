extends EditorConsoleSingleton.CommandBase

static func get_command_name() -> String:
	return "config"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Adjust configuration of editor console.\nPass-through command — routes to its subcommands."
	})
