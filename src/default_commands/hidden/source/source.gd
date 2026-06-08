extends EditorConsoleSingleton.CommandBase


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

static func get_command_name():
	return "source"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _execute(ctx:CompletionContext):
	var path = positional_args[0]
	var source_history = ctx.data.get_or_add("source_history", {})
	if source_history.has(path):
		return
	source_history[path] = true
	EditorConsoleSingleton.Execution.source_file(path, ctx)
	
