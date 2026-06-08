extends EditorConsoleSingleton.ConsoleCommandSetBase

const HIDDEN_DIR = "res://addons/editor_console/src/default_commands/hidden/"

static func register_scopes():
	var paths = [
		"res://addons/editor_console/src/default_commands/script/script.gd",
		"res://addons/editor_console/src/default_commands/global/global.gd",
		"res://addons/editor_console/src/default_commands/scene/scene.gd",
		"res://addons/editor_console/src/default_commands/resource/resource.gd",
		"res://addons/editor_console/src/default_commands/config/config.gd",
		"res://addons/editor_console/src/default_commands/misc/misc/misc.gd",
	]
	var data = {}
	for p in paths:
		add_command_to_dict(p, data)
	
	return data


static func register_hidden_scopes():
	var data = {}
	for dir in DirAccess.get_directories_at(HIDDEN_DIR):
		var path = HIDDEN_DIR.path_join(dir).path_join(dir + ".gd")
		add_command_to_dict(path, data)
	
	var other_paths = [
		"res://addons/editor_console/src/default_commands/misc/clear/clear.gd",
		"res://addons/editor_console/src/default_commands/misc/help/help.gd",
		"res://addons/editor_console/src/default_commands/misc/os/os.gd",
	]
	for p in other_paths:
		add_command_to_dict(p, data)
	
	return data


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}
