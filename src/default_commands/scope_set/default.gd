extends EditorConsoleSingleton.ConsoleCommandSetBase

static func register_scopes():
	return {
		"script": {
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/script/script.gd")
		},
		"global":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/global/global.gd")
		},
		"scene":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/scene/scene.gd")
		},
		"config":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/config/config.gd")
		},
		"misc":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/misc/misc/misc.gd")
		},
	}


static func register_hidden_scopes():
	return {
		"clear":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/misc/clear/clear.gd")
		},
		"help": {
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/misc/help/help.gd")
		},
		"os":{
			ScopeDataKeys.SCRIPT: load("res://addons/editor_console/src/default_commands/misc/os/os.gd")
		},
	}


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}
