extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

var path_flag:=""

static func get_command_name():
	return "resource"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _get_commands() -> Dictionary:
	for c in consumed_tokens:
		if c.begins_with("--path="):
			return {}
	return _get_commands_in_dir(true)

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--path=", {
		&"help": "",
		&"trailing_char": "",
		&"flag_completion": {
			"type": FlagType.FILE,
		},
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag.begins_with("--path="):
		path_flag = _get_flag_value(flag)

func _execute(ctx:CompletionContext):
	if FileAccess.file_exists(path_flag):
		ctx.append_output(path_flag)
	else:
		ctx.append_error("File doesn't exist: " + path_flag)
