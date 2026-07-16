extends EditorConsoleSingleton.ConsoleCommandSetBase

const HIDDEN_DIR = "res://addons/editor_console/src/default_commands/hidden/"
const BUILTINS_DIR = "res://addons/editor_console/src/default_commands/misc/builtins/"
const TEMP_DIR = "res://temp_console/"

static func register_scopes():
	var paths = [
		"res://addons/editor_console/src/default_commands/script/script.gd",
		"res://addons/editor_console/src/default_commands/resource/resource.gd",
		"res://addons/editor_console/src/default_commands/editor/editor.gd",
		"res://addons/editor_console/src/default_commands/settings/settings.gd",
		"res://addons/editor_console/src/default_commands/config/config.gd",
		"res://addons/editor_console/src/default_commands/misc/misc.gd",
		
	]

	var data = {}
	for p in paths:
		add_command_to_dict(p, data)
	
	return data


static func register_hidden_scopes():
	var data = {}
	for cmd_dir in [HIDDEN_DIR, BUILTINS_DIR, TEMP_DIR]:
		if not DirAccess.dir_exists_absolute(cmd_dir):
			continue
		for dir in DirAccess.get_directories_at(cmd_dir):
			var path = cmd_dir.path_join(dir).path_join(dir + ".gd")
			add_command_to_dict(path, data)
	
	return data


static func register_variables():
	return {
		"$CURRENT_SCRIPT_PATH": func():
			if EditorInterface.get_script_editor().get_current_script():
				return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$CURRENT_SCRIPT": func(): return EditorInterface.get_script_editor().get_current_script()
	}
