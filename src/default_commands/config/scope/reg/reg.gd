extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Register scope or scope set.
Usage: config scope reg <options> <scope_path>"


var set_flag:=false

static func get_command_name() -> String:
	return "reg"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
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

func _get_target_positional_count() -> int:
	if set_flag:
		return 1
	else:
		return 2

func _execute(_ctx:CompletionContext):
	if set_flag:
		var scope_path = positional_args[0]
		EditorConsoleSingleton.register_persistent_scope_set(scope_path)
	else:
		var scope_name = positional_args[0]
		var scope_path = positional_args[1]
		EditorConsoleSingleton.register_persistent_scope(scope_name, scope_path)
	
	
