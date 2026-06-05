extends EditorConsoleSingleton.CommandBase

const Reg = preload("res://addons/editor_console/src/default_commands/config/scope/reg/reg.gd")

static func get_command_name() -> String:
	return "scope"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Adjust scope settings."
	})
