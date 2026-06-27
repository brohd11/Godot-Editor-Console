extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Open config files:
Usage: config open <flag>"

var project_flag:=false
var global_flag:=false

static func get_command_name():
	return "open"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--project", {
		&"help": ""
	})
	options.add_option("--global", {
		&"help": ""
	})
	return options.get_options()

func _process_flag(flag:String):
	match flag:
		"--project": project_flag = true
		"--global": global_flag = true

func _get_completions(_ctx:CompletionContext):
	if project_flag or global_flag:
		return {}
	return get_flags(true)

func _execute(_ctx:CompletionContext):
	if project_flag:
		_open(UtilsLocal.Config.get_project_config().file_path)
	if global_flag:
		_open(UtilsLocal.Config.get_global_config_path())

func _open(path:String):
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))
