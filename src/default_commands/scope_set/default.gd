extends EditorConsoleSingleton.ConsoleCommandSetBase

static func register_scopes():
	return {
		"script": {
			"script": UtilsLocal.ConsoleScript.new()
		},
		"global":{
			"script": UtilsLocal.ConsoleGlobalClass.new()
		},
		"config":{
			"script": UtilsLocal.ConsoleCfg.new()
		},
		"misc":{
			"script" :UtilsLocal.ConsoleMisc.new()
		},
	}


static func register_hidden_scopes():
	return {
		"clear":{
			"script": UtilsLocal.ConsoleCfg.new(),
		},
		"help": {
			"script": UtilsLocal.ConsoleHelp.new(),
		},
		"os":{
			"script": UtilsLocal.ConsoleOS.new()
		},
	}


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}
