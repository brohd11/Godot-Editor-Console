extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Passes stdin as arguments to the following command(s).
Usage: xargs command --flags (stdin goes here)"

static func get_command_name():
	return "xargs"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(ctx:CompletionContext):
	var split_stdin = UString.string_safe_split_multi(ctx.stdin, [" ", "\t", "\n"])
	positional_args.append_array(split_stdin)
	var new_command = " ".join(positional_args)
	Execution.execute_command(new_command, {
		&"parent_ctx": ctx
	})
	
