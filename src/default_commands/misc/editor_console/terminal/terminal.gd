extends EditorConsoleSingleton.CommandBase


static func get_command_name() -> String:
	return "terminal"


static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Open a floating GDSh terminal with rich-text input and selectable scrollback.\nUsage: editor_console terminal",
		&"positional_count": 0,
	})


func _execute(ctx:Context) -> int:
	if not Engine.is_editor_hint() or not EditorConsoleSingleton.instance_valid():
		ctx.append_error("terminal: an active editor console is required")
		return ExitCode.FAIL
	EditorConsoleSingleton.new_terminal_console()
	return ExitCode.OK
