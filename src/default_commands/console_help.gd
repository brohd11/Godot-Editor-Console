extends EditorConsoleSingleton.ConsoleCommandBase

const HELP_TEXT = \
"--- Godot Console ---
Enter command to get more info.
--- Available Commands ---
%s"

func parse(_commands:Array, _arguments):
	var available_commands = _get_singleton_instance().scope_dict.keys()
	available_commands = "\n".join(available_commands).strip_edges()
	
	print(HELP_TEXT.strip_edges() % available_commands)
