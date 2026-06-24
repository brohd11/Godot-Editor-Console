extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Run its argument as a console command (pass-through).
Usage: passthru <command>"

static func get_command_name():
	return "passthru"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:CompletionContext):
	if positional_args.size() == 1:
		return EditorConsoleSingleton.get_completion_for_input(positional_args[0])
	return {}


func _execute(ctx:CompletionContext):
	print(positional_arg_index)
	print(positional_args)
	return ExitCode.OK
	
	EditorConsoleSingleton.Execution.execute_command(positional_args[0], {
		&"parent_ctx": ctx
	})
