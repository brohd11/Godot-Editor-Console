
const HELP_TEXT = \
"--- Godot Console ---
Enter command to get more info.
--- Available Commands ---
%s"

static func parse(commands:Array, arguments, editor_console:EditorConsole):
	var available_commands = editor_console.scope_dict.keys()
	available_commands = "\n".join(available_commands).strip_edges()
	
	print(HELP_TEXT.strip_edges() % available_commands)
