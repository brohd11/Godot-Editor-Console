extends EditorConsoleSingleton.CommandBase

const _HELP = \
"List files and directories under a project directory (one path per line).
Usage: dev ls [res://dir] [--recursive] [--ext=gd] [--dirs]
  --recursive   descend into subdirectories
  --ext=        only files with this extension
  --dirs        list directories only"

var recursive_flag := false
var dirs_flag := false
var ext_flag := ""

static func get_command_name() -> String:
	return "ls"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--recursive", {
		&"help": "Descend into subdirectories."
	})
	options.add_option("--dirs", {
		&"help": "List directories only."
	})
	options.add_option("--ext=", {
		&"help": "Only list files with this extension.",
		&"trailing_char": "",
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--recursive":
		recursive_flag = true
	elif flag == "--dirs":
		dirs_flag = true
	elif flag.begins_with("--ext="):
		ext_flag = _get_flag_value(flag).lstrip(".")

func _execute(ctx:CompletionContext):
	var dir := "res://"
	if not positional_args.is_empty():
		dir = positional_args[0]
	if not dir.ends_with("/"):
		dir += "/"
	if not DirAccess.dir_exists_absolute(dir):
		ctx.append_error("Directory does not exist: " + dir)
		return ExitCode.FAIL

	if recursive_flag:
		if dirs_flag:
			for d in EditorConsoleSingleton.get_dir_paths():
				if d.begins_with(dir):
					ctx.append_output(d)
		else:
			for f in EditorConsoleSingleton.get_file_paths():
				if f.begins_with(dir) and _ext_ok(f):
					ctx.append_output(f)
		return

	for d in DirAccess.get_directories_at(dir):
		ctx.append_output(dir.path_join(d) + "/")
	if dirs_flag:
		return
	for f in DirAccess.get_files_at(dir):
		var path = dir.path_join(f)
		if _ext_ok(path):
			ctx.append_output(path)

func _ext_ok(path:String) -> bool:
	return ext_flag == "" or path.get_extension() == ext_flag
