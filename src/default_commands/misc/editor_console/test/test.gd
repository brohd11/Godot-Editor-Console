extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Run selected tests in directory. '...' indicates recursive. A relative path whose first segment
isn't a dir in the cwd names a package, resolved to its _export_ignore/test/ (or export_ignore/test/).
Usage: test [--verbose] [--all] [optional: package[/subdir][/...]]"

const ENTRY_FUNCS = ["run", "run_test", "run_tests"]
const EXPORT_IGNORE_DIRS = EditorConsoleSingleton.EXPORT_IGNORE_DIRS
const TEST_DIR = "test"

var verbose_flag := false
var report_invalid_test_flag := false
var all_flag := false

var _resolve_err := ""

static func get_command_name():
	return "test"

static func get_self_command_data():
	return _command_data({
		&"discoverable": false,
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
	options.add_option("--all", {
		&"help": "Run every package's tests, recursively."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--verbose":
		verbose_flag = true
	elif flag == "--report-invalid":
		report_invalid_test_flag = true
	elif flag == "--all":
		all_flag = true

func _execute(ctx:Context):
	if all_flag:
		if positional_args.size() > 0:
			ctx.append_error("--all takes no target: " + positional_args[0])
			return ExitCode.ERR
		var all_files = []
		var packages = EditorConsoleSingleton.get_packages().packages
		for nm in packages:
			var dir = _package_test_dir(packages[nm])
			if dir != "":
				all_files.append_array(UtilsRemote.GetFiles.scan(dir, ["gd"]))
		return await _run_files(ctx, all_files, "any package")

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
			ctx.append_error(_resolve_err if _resolve_err != "" else "Directory not found: " + arg)
			return ExitCode.ERR

	target_dir = ProjectSettings.globalize_path(target_dir)
	if not target_dir.begins_with(ProjectSettings.globalize_path("res://")):
		ctx.append_error("Target directory not in project: " + target_dir)
		return ExitCode.ERR

	var search_dir = target_dir
	var files = []
	if target_provided and recurs:
		files = UtilsRemote.GetFiles.scan(search_dir, ["gd"])
	else:
		var names = DirAccess.get_files_at(search_dir)
		for n in names:
			if n.get_extension() == "gd":
				files.append(search_dir.path_join(n))
	return await _run_files(ctx, files, target_dir)


func _run_files(ctx:Context, files:Array, label:String) -> int:
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

		# Awaited: suites may wait for frames (synchronous entries return immediately).
		var res = await call_obj.call(test_func)
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
		ctx.append_output("No tests found in: " + label)

	if has_err:
		return ExitCode.ERR
	if has_fail:
		return ExitCode.FAIL
	return ExitCode.OK


## Resolves the test target: a cwd-relative dir if the first segment exists there, else a package name.
func _resolve_dir(ctx:Context, rel:String) -> String:
	_resolve_err = ""
	if rel.is_absolute_path():
		return rel
	if rel == "":
		return ctx.cwd
	var first = rel.get_slice("/", 0)
	if DirAccess.dir_exists_absolute(ctx.cwd.path_join(first)):
		return _complete_path(rel, ctx.cwd)
	var test_dir = _test_dir_for(first)
	if test_dir == "":
		return ""
	var candidate = test_dir.path_join(rel.trim_prefix(first)).simplify_path()
	candidate += "/" if rel.ends_with("/") else "" # simplify_path strips the trailing slash
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	return ""


## `name`'s package test dir, or "" with _resolve_err set.
func _test_dir_for(name:String) -> String:
	var found = EditorConsoleSingleton.get_packages()
	if found.ambiguous.has(name):
		_resolve_err = "Package name '%s' is ambiguous: %s" % [name, ", ".join(found.ambiguous[name])]
		return ""
	if not found.packages.has(name):
		_resolve_err = "No directory or package named: " + name
		return ""
	var test_dir = _package_test_dir(found.packages[name])
	if test_dir == "":
		_resolve_err = "Package '%s' has no tests in %s" % [name, " or ".join(EXPORT_IGNORE_DIRS.map(func(d): return d.path_join(TEST_DIR)))]
	return test_dir


## The package's test dir, or "". Empty ones don't count, since the test dir is auto-generated.
static func _package_test_dir(pkg_dir:String) -> String:
	for ignore in EXPORT_IGNORE_DIRS:
		var path = pkg_dir.path_join(ignore).path_join(TEST_DIR)
		if not DirAccess.dir_exists_absolute(path):
			continue
		if DirAccess.get_files_at(path).is_empty() and DirAccess.get_directories_at(path).is_empty():
			continue
		return path
	return ""


## start with package names, if token begins with "./" or token exists in cwd do real folders
func _get_completions(ctx:Completion):
	if not _positional_arg_index_valid():
		return {}
	var flag_completions = _get_flag_type_completions(ctx)
	if flag_completions != null:
		return flag_completions
	var token:String = ctx.token_before_cursor
	if token.begins_with("--"):
		return _get_completion_std_w_context(ctx)
	if token.is_absolute_path() or token.begins_with("./"):
		return _completion_rel_path(ctx.context, token)

	if token.contains("/"):
		var first = token.get_slice("/", 0)
		if DirAccess.dir_exists_absolute(ctx.context.cwd.path_join(first)):
			return _completion_rel_path(ctx.context, token)

		var test_dir = _test_dir_for(first)
		if test_dir == "":
			return {}
		var ends_slash = token.ends_with("/") # simplify path strips a trailing slash
		var dir = test_dir.path_join(token.trim_prefix(first)).simplify_path()
		if not ends_slash:
			dir = dir.get_base_dir()
		return _dir_options(dir)
	return _package_options()


static func _package_options() -> Dictionary:
	var options = Options.new()
	var packages = EditorConsoleSingleton.get_packages().packages
	var names = packages.keys()
	names.sort()
	for nm in names:
		if _package_test_dir(packages[nm]) != "":
			options.add_option(nm, {
				&"trailing_char": "/"
			})
	return options.get_options()


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
