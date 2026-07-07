extends EditorConsoleSingleton.CommandBase

const TestUtils = preload("res://addons/editor_console/src/default_commands/test/test_utils.gd")

const _HELP = \
"Run selected tests.
Usage: test run [--verbose] [optional: target_dir]"

var verbose_flag := false

static func get_command_name():
	return "run"

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
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--verbose":
		verbose_flag = true

func _execute(ctx:CompletionContext):
	var target_dir = ""
	if positional_args.size() > 0:
		target_dir = positional_args[0]

	var data = TestUtils.read_file()
	var scripts = data.get("scripts", [])
	var has_fail:= false
	var has_err:= false
	for path in scripts:
		var valid = true if target_dir == "" else path.begins_with(target_dir)
		if not valid:
			continue

		var script = load(path)
		var call_obj = script
		if "run_tests" in script:
			call_obj = script.new()
		if not "run_tests" in call_obj:
			has_err = true
			ctx.append_error("Could not run tests in: %s" % path)
			continue

		var res = call_obj.run_tests()
		var success = res.get("success", false)
		var pass_str = "PASS"
		if not success:
			has_fail = true
			pass_str = "FAIL"

		if verbose_flag:
			for line in res.get("output", []):
				ctx.append_output(line)

		ctx.append_output("Test: [%s] : %s" % [pass_str, path])
	
	if has_err:
		return ExitCode.ERR
	if has_fail:
		return ExitCode.FAIL
	return ExitCode.OK
