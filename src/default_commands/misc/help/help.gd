extends EditorConsoleSingleton.CommandBase

const HELP_TEXT = \
"--- Godot Console ---
Enter command to get more info.
--- Available Commands ---
%s"

static func get_command_name() -> String:
	return "help"

func _execute(ctx:CompletionContext):
	var available_commands =  EditorConsoleSingleton.get_instance().scope_dict.keys()
	available_commands = "\n".join(available_commands).strip_edges()
	print(HELP_TEXT.strip_edges() % available_commands)
	return ExitCode.OK
