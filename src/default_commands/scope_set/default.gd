extends EditorConsoleSingleton.ConsoleCommandSetBase

static func register_scopes():
	return {
		"script": {
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleScript.new()
		},
		"global":{
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleGlobalClass.new()
		},
		"config":{
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleCfg.new()
		},
		"misc":{
			ScopeDataKeys.SCRIPT :UtilsLocal.ConsoleMisc.new()
		},
	}


static func register_hidden_scopes():
	return {
		"clear":{
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleCfg.new(),
		},
		"help": {
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleHelp.new(),
		},
		"os":{
			ScopeDataKeys.SCRIPT: UtilsLocal.ConsoleOS.new()
		},
	}


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}
