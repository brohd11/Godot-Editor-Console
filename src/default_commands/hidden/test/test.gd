extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Run selected tests in directory. '...' indicates recursive.
Usage: test [--verbose] [optional: target_dir/...]"

const ENTRY_FUNCS = ["run", "run_test", "run_tests"]

var verbose_flag := false
var report_invalid_test_flag := false

static func get_command_name():
	return "test"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "max: 1",
		&"allow_positional_paths": true,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--verbose", {
		&"help": "Print the full test report, not just PASS/FAIL."
	})
	options.add_option("--report-invalid", {
		&"help": "Report tests that have *_test.gd name, but don't have any test entry funcs."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--verbose":
		verbose_flag = true
	elif flag == "--report-invalid":
		report_invalid_test_flag = true

func _execute(ctx:CompletionContext):
	var target_dir = ctx.cwd
	var target_provided = false
	if positional_args.size() > 0:
		target_provided = true
		target_dir = complete_path(positional_args[0])
	
	target_dir = ProjectSettings.globalize_path(target_dir)
	if not target_dir.begins_with(ProjectSettings.globalize_path("res://")):
		ctx.append_error("Target directory not in project: " + target_dir)
		return ExitCode.ERR
	
	var recurs = target_dir.get_file() == "..."
	var search_dir = target_dir.trim_suffix("...")
	var files = []
	if target_provided and recurs:
		files = UtilsRemote.UFile.scan_for_files(search_dir, ["gd"])
	else:
		var names = DirAccess.get_files_at(search_dir)
		for n in names:
			if n.get_extension() == "gd":
				files.append(search_dir.path_join(n))
	
	
	var ran_test:= false
	var has_fail:= false
	var has_err:= false
	for path in files:
		if not path.ends_with("_test.gd"):
			continue
		
		var script:GDScript = load(path)
		var method_list = script.get_script_method_list()
		
		var call_obj = script
		
		var test_func = ""
		var is_static = false
		for dict in method_list:
			if dict.name in ENTRY_FUNCS:
				test_func = dict.name
				is_static = bool(dict.flags & METHOD_FLAG_STATIC)
				break
		
		if test_func == "":
			if report_invalid_test_flag:
				has_err = true
				ctx.append_error("Could not run tests in: %s" % path)
			continue
		
		ran_test = true
		if not is_static:
			call_obj = script.new()
		
		var res = call_obj.call(test_func)
		var exit = res.get("result", false)
		if res.has("success"):
			exit = res["success"]
		
		var pass_str = "FAIL"
		if exit is bool:
			if exit:
				pass_str = "PASS"
			else:
				has_fail = true
		elif exit is int:
			if exit == 0:
				pass_str = "PASS"
			else:
				has_fail = true
		
		ctx.append_output("Test: [%s] : %s" % [pass_str, path])
		if verbose_flag:
			for line in res.get("output", []):
				ctx.append_output("\t" + line)
	
	if not ran_test:
		ctx.append_output("No tests found in: " + target_dir)
	
	if has_err:
		return ExitCode.ERR
	if has_fail:
		return ExitCode.FAIL
	return ExitCode.OK
