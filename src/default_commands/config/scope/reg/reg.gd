extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Register scope or scope set.
Usage: config scope reg <options> <scope_path>"


var set_flag:=false
var dir_flag:=false
var project_flag:=false

static func get_command_name() -> String:
	return "reg"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--set", {
		&"help": "--set <flag> - registers path as scope set."
	})
	options.add_option("--dir", {
		&"help": "--dir <flag> - register a directory that will be scanned for commands"
	})
	options.add_option("--project", {
		&"help": "Register to the project override config instead of global."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--set":
		set_flag = true
	elif flag == "--dir":
		dir_flag = true
	elif flag == "--project":
		project_flag = true

func _get_target_positional_count() -> int:
	if set_flag or dir_flag:
		return 1
	else:
		return 2

func _execute(ctx:CompletionContext):
	if int(set_flag) + int(dir_flag) > 1:
		ctx.append_error("Can only use one flag at a time.")
		ctx.exit_code = ExitCode.FAIL
		return
	
	if set_flag:
		var scope_path = positional_args[0]
		EditorConsoleSingleton.register_persistent_scope_set(scope_path, project_flag)
	elif dir_flag:
		var scope_path = positional_args[0]
		EditorConsoleSingleton.register_command_dir(scope_path, project_flag)
	else:
		var scope_name = positional_args[0]
		var scope_path = positional_args[1]
		EditorConsoleSingleton.register_persistent_scope(scope_name, scope_path, project_flag)
	
	
