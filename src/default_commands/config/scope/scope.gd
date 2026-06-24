extends EditorConsoleSingleton.CommandBase


static func get_command_name() -> String:
	return "scope"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Adjust scope settings.\nPass-through command — routes to its subcommands."
	})
