extends EditorConsoleSingleton.CommandBase

const UFile = UtilsRemote.UFile

const _HELP = \
"Convert data between: json <-> yaml <-> binary
Usage: convert_data [--to-yaml|--to-json|--to-bin=ext] [--from-bin] <data file> <optional:write path>
Only one 'to flag' can be active per operation. No scan flag will
not trigger the EditorInterface scan when finished."

var overwrite_flag:=false
var no_scan_flag:=false

var json_flag:=false
var yaml_flag:=false

var bin_flag:=false
var bin_ext:=""

var from_bin_flag:=false

static func get_command_name():
	return "convert_data"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "max: 2"
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--overwrite", {
		&"help": "Overwrite export file."
	})
	options.add_option("--no-scan", {
		&"help": "Don't trigger editor scan after writing files."
	})
	options.add_option("--to-json", {
		&"help": "Convert to JSON"
	})
	options.add_option("--to-yaml", {
		&"help": "Convert to YAML"
	})
	options.add_option("--to-bin=", {
		&"help": "Convert to Binary, value of flag is extension.",
		&"trailing_char": ""
	})
	options.add_option("--from-bin", {
		&"help": "Flag file as binary, must be a dictionary or array as root."
	})
	
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--to-json":
		json_flag = true
	elif flag == "--to-yaml":
		yaml_flag = true
	elif flag.begins_with("--to-bin="):
		bin_flag = true
		bin_ext = _get_flag_value(flag)
	elif flag == "--from-bin":
		from_bin_flag = true
	elif flag == "--overwrite":
		overwrite_flag = true
	elif flag == "--no-scan":
		no_scan_flag = true

func _get_completions(_ctx:CompletionContext):
	var flags = get_flags(true)
	if _count_flags() > 0:
		for f in flags.keys():
			if f.begins_with("--to-"):
				flags.erase(f)
	return flags

func _count_flags():
	var count = 0
	for flag in [yaml_flag, json_flag, bin_flag]:
		if flag:
			count += 1
	return count

func _execute(ctx:CompletionContext):
	if _count_flags() > 1:
		ctx.append_error("Cannot pass more than one 'to flag'.")
		return ExitCode.ERR
	
	var paths = []
	if positional_args.is_empty():
		if ctx.stdin.is_empty():
			ctx.append_error("Need file path")
		else:
			paths = ctx.stdin.split("\n", false)
	elif positional_args.size() == 1:
		paths.append(positional_args[0])
	elif positional_args.size() == 2:
		var from = complete_path(positional_args[0])
		var to = complete_path(positional_args[1])
		if not FileAccess.file_exists(from):
			ctx.append_error("File doesn't exist: " + from)
			return ExitCode.FAIL
		return _process_file(ctx, from, to)
		
	
	var last_status:ExitCode
	
	for p:String in paths:
		p = complete_path(p)
		if not FileAccess.file_exists(p):
			ctx.append_error("File doesn't exist: " + p)
			last_status = ExitCode.FAIL
			continue
		
		var basename = p.get_basename()
		var export_file = ""
		if json_flag:
			export_file = basename + ".json"
		elif yaml_flag:
			export_file = basename + ".yml"
		elif bin_flag:
			export_file = UString.dot_join(basename, bin_ext)
		
		if export_file == "":
			ctx.append_error("Could not get export path for: " + p)
			last_status = ExitCode.FAIL
			continue
		
		var stat = _process_file(ctx, p, export_file)
		if last_status == ExitCode.OK:
			last_status = stat
	
	
	if not no_scan_flag:
		EditorInterface.get_resource_filesystem().scan()
	
	return last_status

func _process_file(ctx:CompletionContext, data_file:String, export_file:String):
	if FileAccess.file_exists(export_file) and not overwrite_flag:
		ctx.append_error("File already exists: " + export_file)
		return ExitCode.FAIL
	
	var ext = data_file.get_extension().to_lower()
	match ext:
		"json":
			if json_flag:
				ctx.append_error("File already json: " + data_file)
				return ExitCode.FAIL
			var data = UFile.read_from_json(data_file)
			return _convert_data(data, data_file, export_file, ctx)
	
		"yml", "yaml":
			if yaml_flag:
				ctx.append_error("File already yaml: " + data_file)
				return ExitCode.FAIL
			var as_string = FileAccess.get_file_as_string(data_file)
			var parser = YAMLParser.new()
			var data = parser.parse(as_string)
			return _convert_data(data, data_file, export_file, ctx)
		
		_:
			if not from_bin_flag:
				ctx.append_error("Unrecognized extension:" + ext)
				return ExitCode.FAIL
			var f = FileAccess.open(data_file, FileAccess.READ)
			var data = f.get_var()
			return _convert_data(data, data_file, export_file, ctx)


func _convert_data(data:Variant, data_file:String, export_file:String, ctx:CompletionContext):
	var success = false
	if json_flag:
		success = UFile.write_to_json(data, export_file)
	elif yaml_flag:
		var yaml = YAMLParser.dump(data)
		var f = FileAccess.open(export_file, FileAccess.WRITE)
		success = f.store_string(yaml)
	elif bin_flag:
		var f = FileAccess.open(export_file, FileAccess.WRITE)
		success = f.store_var(data)
	
	if success:
		ctx.append_output("File converted: %s -> %s" %[data_file, export_file.get_file()])
		return ExitCode.OK
	else:
		ctx.append_error("Failed to convert: %s -> %s" %[data_file, export_file.get_file()])
		return ExitCode.FAIL
