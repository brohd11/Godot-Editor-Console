extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

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
	var command = positional_args[0]
	var new_ctx = CompletionContext.new(command)
	new_ctx.print = false
	new_ctx.add_to_hist = false
	#new_ctx.execute_parse() # handled inside should be
	EditorConsoleSingleton.get_instance().parse_input(new_ctx)
