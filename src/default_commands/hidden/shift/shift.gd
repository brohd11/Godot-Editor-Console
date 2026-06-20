extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

static func get_command_name():
	return "shift"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	if is_instance_valid(ctx.parent_ctx):
		ctx.parent_ctx.positional_args.pop_front()
