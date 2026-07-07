extends EditorConsoleSingleton.CommandBase

const TestUtils = preload("res://addons/editor_console/src/default_commands/test/test_utils.gd")

const _HELP = \
"Manage tests registered in project tests file.
Usage: test [flags]"

var add_flag:=false
var rm_flag:=false

static func get_command_name():
	return "test"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func get_flags(_hide_consumed:=false) -> Dictionary:
	if add_flag or rm_flag:
		return {}
	return _get_flags()

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--add", {
		&"help": "Add the script to the registry."
	})
	options.add_option("--rm", {
		&"help": "Remove the script from the registry."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--add":
		add_flag = true
	elif flag == "--rm":
		rm_flag = true


func _execute(ctx:CompletionContext):
	if add_flag and rm_flag:
		ctx.append_error("Can not pass both add and rm flags.")
		return ExitCode.ERR
	
	var path = positional_args[0]
	var data = TestUtils.read_file()
	var scripts = data.get_or_add("scripts", [])
	if add_flag:
		if path in scripts:
			ctx.append_output("Path already in tests.")
			return ExitCode.FAIL
		scripts.append(path)
	elif rm_flag:
		if not path in scripts:
			ctx.append_output("Path not in scripts.")
			return ExitCode.FAIL
		scripts.erase(path)
	
	TestUtils.write_file(data)
