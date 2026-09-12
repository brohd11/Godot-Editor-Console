extends "res://addons/addon_lib/gdsh/command_base.gd"
## Adapter for plugin registrations that supply a Callable(Context).
var callback:Callable

func _init(value:Callable):
	callback = value

func execute(ctx:Context):
	_consume_token(ctx)
	var result = callback.call(ctx)
	if result is int: ctx.exit_code = result
	return ctx.exit_code

func complete(_completion:Completion):
	return {}
