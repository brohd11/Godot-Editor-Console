extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Run expression through Godot's Expression class.
Accepts arguments as 1 string or seperated."

static func get_command_name():
	return "expr"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1"
	})

func _execute(ctx:CompletionContext):
	run_expr(ctx, positional_args)

static func run_expr(ctx:CompletionContext, args:Array):
	var expression = " ".join(args)
	if EditorConsoleSingleton.PRINT_DEBUG:
		print("IN EXPR::", expression)
	var expr = Expression.new()
	var err = expr.parse(expression)
	if err != OK:
		ctx.append_error("Could not parse math: %s" % expression)
		ctx.exit_code = ExitCode.ERR
		return
	
	var val = expr.execute([], RefCounted.new(), false, true)
	ctx.append_output(str(val))
