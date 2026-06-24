extends EditorConsoleSingleton.CommandBase

const _HELP = \
"De-register scope or scope set from EditorConsole.
Usage: config scope dereg <options> <scope_name>"

var set_flag:= false
var dir_flag:=false
var project_flag:=false

static func get_command_name() -> String:
	return "dereg"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--set", {
		&"help": "--set flag - registers path as scope set."
	})
	options.add_option("--dir", {
		&"help": "--dir <flag> - register a directory that will be scanned for commands"
	})
	options.add_option("--project", {
		&"help": "De-register from the project override config instead of global."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--set":
		set_flag = true
	elif flag == "--project":
		project_flag = true
	elif flag == "--dir":
		dir_flag = true


func _get_completions(_ctx:CompletionContext):
	var target_config = UtilsLocal.Config.get_target_config(project_flag)
	var options = Options.new()
	var existing = []
	if set_flag:
		existing = target_config.get_section(UtilsLocal.Config.SCOPE_SET, [])
	elif dir_flag:
		existing = target_config.get_section(UtilsLocal.Config.COMMAND_DIRS, [])
	else:
		existing = target_config.get_section(UtilsLocal.Config.SCOPE, {}).keys()
	
	for e in existing:
		options.add_option(e, {
			&"help": "Existing scope/set: %s" % e
		})
	options.merge(get_flags(true))
	return options.get_options()

func _execute(ctx:CompletionContext):
	if int(set_flag) + int(dir_flag) > 1:
		ctx.append_error("Can only use one flag at a time.")
		ctx.exit_code = ExitCode.FAIL
		return
	
	var scope_name = positional_args[0]
	if set_flag:
		EditorConsoleSingleton.remove_persistent_scope_set(scope_name, project_flag)
	elif dir_flag:
		EditorConsoleSingleton.remove_command_dir(scope_name, project_flag)
	else:
		EditorConsoleSingleton.remove_persistent_scope(scope_name, project_flag)
	
	ctx.exit_code = ExitCode.OK
