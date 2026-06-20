extends EditorConsoleSingleton.CommandBase
const Expr = preload("res://addons/editor_console/src/default_commands/hidden/expr/expr.gd")

const _HELP = \
"Run expression through Godot's Expression class.
This is functionally an alias for 'expr' command.
Accepts arguments as 1 string or seperated."

static func get_command_name():
	return "math"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1"
	})

func _execute(ctx:CompletionContext):
	Expr.run_expr(ctx, positional_args)
