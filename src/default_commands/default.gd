extends "res://addons/godot_console/src/class/console_command_set_base.gd"

static func register_scopes():
	return {
		
		"script": {
			"script": UtilsLocal.ConsoleScript
		},
		"global":{
			"script": UtilsLocal.ConsoleGlobalClass
		},
		"config":{
			"script": UtilsLocal.ConsoleCfg
		},
		"misc":{
			"script":UtilsLocal.ConsoleMisc
		},
		"os":{
			"script": UtilsLocal.ConsoleOS
		},
	}


static func register_hidden_scopes():
	return {
		"clear":{
			"script": UtilsLocal.ConsoleCfg,
		},
		"help": {
			"script": UtilsLocal.ConsoleHelp,
		},
	}


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}





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
