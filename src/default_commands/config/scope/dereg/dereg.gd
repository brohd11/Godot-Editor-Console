extends EditorConsoleSingleton.CommandBase

const _HELP = \
"De-register scope or scope set from EditorConsole.
Usage: config scope dereg <options> <scope_name>"

var set_flag:= false

static func get_command_name() -> String:
	return "dereg"

static func get_self_option_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--set", {
		&"help": "--set flag - registers path as scope set."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--set":
		set_flag = true


func _execute(_ctx:CompletionContext):
	var scope_name = positional_args[0]
	if set_flag:
		EditorConsoleSingleton.remove_persistent_scope(scope_name)
	else:
		EditorConsoleSingleton.remove_persistent_scope(scope_name)
	return ExitCode.OK
