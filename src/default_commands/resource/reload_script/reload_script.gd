extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Reload the passed scripts resources
Usage: dev reload_script <path> - Can also pass paths as stdin, will be split by newlines."

static func get_command_name() -> String:
	return "reload_script"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _get_target_positional_count() -> int:
	if _ctx_obj.stdin == "":
		return 1
	return 0

func _execute(ctx:CompletionContext):
	var paths = []
	if positional_args.size() == 1:
		paths.append(positional_args[0])
	else:
		paths = ctx.stdin.split("\n", false)
	
	for p in paths:
		var script = load(p)
		if not script is Script:
			ctx.append_error("Resource not a script: " + p)
			continue
		
		script.reload()
		ctx.append_output("Reloaded script: " + p)
