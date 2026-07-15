extends EditorConsoleSingleton.CommandBase

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const _HELP = \
"Get the path of the current script-editor script
Usage: script get_path"

static func get_command_name():
	return "get_path"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	var script = ScriptUtil.get_script_from_ctx(ctx)
	if not is_instance_valid(script):
		ctx.append_error("Could not get script.")
		return ExitCode.FAIL
	if script.resource_path == "":
		ctx.append_output("No Path - Likely Inner Class")
	else:
		ctx.append_output(script.resource_path)
