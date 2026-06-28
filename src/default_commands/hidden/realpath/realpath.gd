extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Convert relative path to full path, globalized or local.
Usage: realpath [--global] [file path]"

var global_flag:=false

static func get_command_name():
	return "realpath"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--global", {
		&"help": "Convert the path to globalized"
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--global":
		global_flag = true

func _execute(ctx:CompletionContext):
	var converted = complete_path(positional_args[0])
	if global_flag:
		converted = ProjectSettings.globalize_path(converted)
	ctx.append_output(converted)
