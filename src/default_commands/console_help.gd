
static func parse(commands:Array, arguments, editor_console:EditorConsole):
	
	var available_commands = editor_console.scope_dict.keys()
	available_commands = "\n".join(available_commands).strip_edges()
	
	var help_text = \
"--- Godot Console ---
Enter command to get more info.
--- Available Commands ---
%s



" % available_commands
	print(help_text.strip_edges())
