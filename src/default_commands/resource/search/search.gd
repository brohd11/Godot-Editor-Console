extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

const _READABLE_EXTS = ["gd", "gdshader", "tres", "tscn", "cs","md", "cfg", "ini", "txt"]

var content_flag:=false
var dir_flag:=""

static func get_command_name():
	return "search"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--content", {
		&"help": ""
	})
	options.add_option("--dir=", {
		&"help": "",
		&"trailing_char": "",
		&"flag_completion": {"type": FlagType.DIR}
	})
	
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--content":
		content_flag = true
	elif flag.begins_with("--dir="):
		dir_flag = _get_flag_value(flag)

func _execute(ctx:CompletionContext):
	var search_term = positional_args[0]
	
	if dir_flag == "":
		dir_flag = "res://"
	
	elif not DirAccess.dir_exists_absolute(dir_flag):
		ctx.append_error("Directory doesn't exist: " + dir_flag)
		ctx.exit_code = ExitCode.FAIL
		return
	
	var resources = UtilsRemote.UFile.scan_for_files(dir_flag, [])
	for f in resources:
		if content_flag:
			if not f.get_extension() in _READABLE_EXTS:
				continue
			var file_as_string = FileAccess.get_file_as_string(f)
			if file_as_string.contains(search_term):
				ctx.append_output(f)
		elif search_term.is_subsequence_ofn(f):
			ctx.append_output(f)
	
	ctx.exit_code = ExitCode.OK
