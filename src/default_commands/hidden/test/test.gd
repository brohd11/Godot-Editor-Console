extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Run selected tests in directory. '...' indicates recursive. Relative paths fall back to
res://tests/ when their first segment isn't a dir in the cwd.
Usage: test [--verbose] [optional: target_dir/...]"

const ENTRY_FUNCS = ["run", "run_test", "run_tests"]
const TESTS_ROOT = "res://tests/"

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
	var recurs = false
	if positional_args.size() > 0:
		target_provided = true
		var arg:String = positional_args[0]
		recurs = arg.get_file() == "..."
		# strip the recursion suffix before resolving, so the probe tests a real directory
		target_dir = _resolve_dir(ctx, arg.trim_suffix("..."))
		if target_dir == "":
			ctx.append_error("Directory not found: " + arg)
			return ExitCode.ERR

	target_dir = ProjectSettings.globalize_path(target_dir)
	if not target_dir.begins_with(ProjectSettings.globalize_path("res://")):
		ctx.append_error("Target directory not in project: " + target_dir)
		return ExitCode.ERR

	var search_dir = target_dir
	var files = []
	if target_provided and recurs:
		files = UtilsRemote.UFile.GetFiles.scan(search_dir, ["gd"])
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


## resolves the test target: tests/<addon_name>/ <- initial search location
func _resolve_dir(ctx:CompletionContext, rel:String) -> String:
	if rel.is_absolute_path():
		return rel
	if rel == "":
		return ctx.cwd
	var first = rel.get_slice("/", 0)
	if DirAccess.dir_exists_absolute(ctx.cwd.path_join(first)):
		return _complete_path(rel, ctx.cwd)
	var tests_candidate = TESTS_ROOT.path_join(rel).simplify_path()
	tests_candidate += "/" if rel.ends_with("/") else "" # simplify_path strips the trailing slash
	if DirAccess.dir_exists_absolute(tests_candidate):
		return tests_candidate
	return ""


## start with tests/ folder, if token begins with "./" or token exists in cwd do real folders
func _get_completions(ctx:CompletionContext):
	if not _positional_arg_index_valid():
		return {}
	var flag_completions = _get_flag_type_completions(ctx)
	if flag_completions != null:
		return flag_completions
	var token:String = ctx.token_before_cursor
	if token.begins_with("--"):
		return _get_completion_std_w_context(ctx)
	if token.is_absolute_path() or token.begins_with("./"):
		return _completion_rel_path(ctx, token)

	if token.contains("/"):
		var first = token.get_slice("/", 0)
		if DirAccess.dir_exists_absolute(ctx.cwd.path_join(first)):
			return _completion_rel_path(ctx, token)
		
		var ends_slash = token.ends_with("/") # simplify path strips a trailing slash
		var dir = TESTS_ROOT.path_join(token).simplify_path()
		if not ends_slash:
			dir = dir.get_base_dir()
		return _dir_options(dir)
	return _dir_options(TESTS_ROOT)


static func _dir_options(dir_a:String, dir_b:String = "") -> Dictionary:
	var options = Options.new()
	var seen := {}
	for base in [dir_a, dir_b]:
		if base == "":
			continue
		var dirs = Array(DirAccess.get_directories_at(base))
		dirs.push_front("..")
		for dir in dirs:
			if seen.has(dir):
				continue
			seen[dir] = true
			options.add_option(dir, {
				&"trailing_char": "/"
			})
	return options.get_options()
