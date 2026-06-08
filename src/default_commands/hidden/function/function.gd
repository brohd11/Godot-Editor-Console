extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Built in function command. Acts as glue between function and it's contents."

var function_name:String

static func get_command_name():
	return "__function__"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _consume_self(ctx:CompletionContext) -> ExitCode:
	function_name = _consume_token(ctx)
	return ExitCode.OK

func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(ctx:CompletionContext):
	
	var function_text = ctx.functions.get(function_name)
	positional_args.push_front(function_name)
	var new_ctx = CompletionContext.new()
	new_ctx.print = false
	new_ctx.add_to_hist = false
	new_ctx.set_positional_args(positional_args)
	EditorConsoleSingleton.Execution.execute_command_multiline(function_text, new_ctx)
	
	ctx.output = new_ctx.output
	ctx.error = new_ctx.error
	ctx.exit_code = new_ctx.exit_code
