extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Reloads default and current registered scopes.
Usage: config scope reload"

static func get_command_name() -> String:
	return "reload"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP
	})

func _execute(_ctx:CompletionContext):
	var success = EditorConsoleSingleton.get_instance()._load_default_commands()
	if success:
		print("Reloaded command sets.")
