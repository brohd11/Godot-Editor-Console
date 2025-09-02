extends "res://addons/godot_console/src/class/console_command_base.gd"


static func register_commands() -> Dictionary:
	return {
	"scope":{
		"callable":_scope
	}, 
	
}

const CMD_HELP = \
"Manage commands available to the console.
-reload - reload scripts in command sets dir
-reg - register script <command name, script path>
-dereg - unregister script <command name>


"

static func get_completion(raw_text:String, commands:Array, arguments:Array, editor_console:EditorConsole):
	var registered_commands = register_commands()
	if commands.size() == 1:
		return registered_commands
	var c_2 = commands[1]
	if c_2 == "scope":
		if commands.size() < 3:
			return {
				"-reg":{PopupKeys.METADATA_KEY: {ParsePopupKeys.ADD_ARGS:true}},
				"-dereg":{PopupKeys.METADATA_KEY: {ParsePopupKeys.ADD_ARGS:true}},
				"-reload":{},
			}
		
	
	



static func parse(commands:Array, arguments:Array, editor_console:EditorConsole):
	var c_2 = commands[1]
	var script_commands = register_commands()
	var command_data = script_commands.get(c_2)
	if not command_data:
		print("Unrecognized command: %s" % c_2)
		return
	var callable = command_data.get("callable")
	if callable:
		callable.call(commands, arguments, editor_console)
	
	

static func _scope(commands:Array, arguments:Array, editor_console:EditorConsole):
	if commands.size() == 2 or UtilsLocal.check_help(commands):
		print(CMD_HELP.strip_edges())
		return
	var c_3 = commands[2]
	var arg_size = arguments.size()
	if c_3 == "-reg":
		if arg_size != 2:
			printerr("Expected 2 arguments, received %s" % arg_size)
			return
		editor_console.load_cmd_set(arguments[0], arguments[1])
		pass
	if c_3 == "-dereg":
		if arg_size != 1:
			printerr("Expected 1 arguments, received %s" % arg_size)
		if arguments[0] in register_commands().keys():
			print("Can't remove this command: %s" % arguments[0])
		
		editor_console.rm_cmd_set(arguments[0])
	elif c_3 == "-reload":
		var success = editor_console._load_default_commands()
		if success:
			print("Reloaded command sets.")


static func clear_console(commands:Array, arguments:Array, editor_console:EditorConsole):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "-h" or c_2 == "-help":
			print("Clear ouput text box.\n-hist - Clear command history.")
			return
		if c_2 == "-hist":
			editor_console.previous_commands.clear()
	var line = editor_console.console_line_edit
	var editor_log = line.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent()
	var clear_button = editor_log.get_child(2).get_child(1).get_child(0)
	clear_button.pressed.emit()
