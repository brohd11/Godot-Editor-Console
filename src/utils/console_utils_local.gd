
const ConsoleCommandSetBase = preload("uid://bu27r1hpnfinp") # console_command_set_base.gd

const CommandBase = preload("res://addons/editor_console/src/class/base/command_base.gd")
const Options = preload("res://addons/editor_console/src/class/base/command_options.gd")


const DefaultCommands = preload("res://addons/editor_console/src/default_commands/scope_set/default.gd")
const ConsoleOS = preload("res://addons/editor_console/src/default_commands/misc/os/os.gd")


const SyntaxHl = preload("res://addons/editor_console/src/utils/console_syntax.gd")

const ConsoleLineContainer = preload("res://addons/editor_console/src/utils/console_line_container.gd")
const CompletionContext = preload("res://addons/editor_console/src/class/completion_context.gd")
const ConsoleTokenizer = preload("res://addons/editor_console/src/utils/console_tokenizer.gd")

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const Pr = UtilsRemote.UString.PrintRich


const EDITOR_CONSOLE_SCOPE_PATH = "res://.addons/editor_console/scope_data.json" #! ignore-remote

# deprecate these
static func get_scope_data():
	return UtilsRemote.UFile.read_from_json(EDITOR_CONSOLE_SCOPE_PATH)

static func get_registered_global_classes():
	var scope_data = get_scope_data()
	return scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])

static func save_scope_data(new_data:Dictionary):
	UtilsRemote.UFile.write_to_json(new_data, EDITOR_CONSOLE_SCOPE_PATH)



class ScopeDataKeys:
	const global_classes = "global_classes"
	const sets = "sets"
	const scopes = "scopes"
	
	const GLOBAL_CLASSES = &"scope_data_keys.global_classes"
	const SETS = &"scope_data_keys.sets"
	const SCOPES = &"scope_data_keys.scopes"
	const COMMAND_DIRS = &"scope_data_keys.command_dirs"
	
	const SCRIPT = &"script"
	const CALLABLE = &"callable"


class GDSHKeys:
	const GDCONF = "user://addons/editor_console/gdsh.cfg"
	
	const ALIAS = &"gdsh_keys.alias"

class Colors:
	
	class Strings:
		const OS_USER = "88e134"
		const OS_PATH = "659cce"

		const VAR_GREEN = "96f442"
		const VAR_RED = "cc000c"
		const VAR_GREY = "6d6d6d"
		const ACCENT_MUTE = "4d819a"
		
		const GRAY = "bebebe"
	
	const OS_USER = Color(0.5333, 0.8824, 0.2039, 1.0)
	const OS_PATH = Color(0.3961, 0.6118, 0.8078, 1.0)

	const VAR_GREEN = Color(0.5882, 0.9569, 0.2588, 1.0)
	const VAR_RED = Color(0.8, 0.0, 0.0471, 1.0)
	const VAR_GREY = Color(0.4275, 0.4275, 0.4275, 1.0)
	
	const SCOPE = Color.SKY_BLUE
	
	const ACCENT_MUTE = Color(0.302, 0.5059, 0.6039, 1.0)
	
	const ERROR_RED = Color(0.651, 0.071, 0.004, 1.0)
	
	const GRAY = Color.GRAY
	
	


class Print:
	static func error_arg_count(callable:Callable, args:Array):
		var message = "Callable - '%s'" % callable.get_method()
		error_arg_count_int(callable.get_argument_count(), args, message)
	
	static func error_arg_count_int(desired_count:int, args:Array, message:=""):
		error(message)
		Pr.new().append("\tExpected %s arguments, received %s" % [desired_count, args.size()], Colors.ERROR_RED)\
		.append("\n\tArguments: ").append("  ".join(args), Colors.ACCENT_MUTE).display()
	
	
	static func error(message):
		Pr.new().append("EditorConsole: ", Colors.ERROR_RED).append(message).display()


class Config:
	const PROJECT_PATH = "res://.addons/editor_console/config.yml"  #! ignore-remote
	
	const ALIAS = &"config.alias"
	const STARTUP = &"config.startup"
	const SCOPE = &"config.scope"
	const SCOPE_SET = &"config.scope_set"
	const COMMAND_DIRS = &"config.command_dirs"
	const GLOBAL_CLASSES = &"config.global_classes"
	
	static var _merged_config:Config
	
	var file_path:String
	var data:Dictionary
	
	#! arg_location section:Config
	func get_section(section:StringName, default={}) -> Variant:
		return data.get_or_add(section, default)
	
	func write():
		_write_config(data, file_path)
	
	static func get_merged_config() -> Config:
		if not is_instance_valid(_merged_config):
			load_config()
		return _merged_config
	
	static func get_target_config(project:bool=false) -> Config:
		if project:
			return get_project_config()
		else:
			return get_global_config()
	
	static func get_global_config() -> Config:
		var cfg:Config = new()
		cfg.file_path = get_global_config_path()
		cfg.data = _get_global_config_data()
		return cfg
	
	static func get_project_config() -> Config:
		var cfg:Config = new()
		cfg.file_path = PROJECT_PATH
		cfg.data = _get_project_config_data()
		return cfg
	
	static func get_global_config_path() -> String:
		var paths:EditorPaths = EditorInterface.get_editor_paths()
		return paths.get_config_dir().path_join("addons/editor_console/config.yml")
	
	static func _get_global_config_data():
		return _get_config_data(get_global_config_path())
	
	static func _get_project_config_data():
		return _get_config_data(PROJECT_PATH)
	
	static func _get_config_data(path:String) -> Dictionary:
		if not FileAccess.file_exists(path):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			return {}
		var content = FileAccess.get_file_as_string(path)
		var parser = YAMLParser.new()
		var parse_data:Variant = parser.parse(content)
		if parse_data == null:
			return {}
		return parse_data
	
	static func _write_config(new_data:Dictionary, path:String, reload:=true):
		var dumped = YAMLParser.dump(new_data)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var fa = FileAccess.open(path, FileAccess.WRITE)
		fa.store_string(dumped)
		fa.close()
		if reload:
			load_config()
	
	static func load_config():
		_merged_config = new()
		var project_data = _get_project_config_data()
		var global_data = _get_global_config_data()
		_recursive_merge(project_data, global_data)
		_merged_config.data = project_data
	
	static func _recursive_merge(dict_a:Dictionary, dict_b:Dictionary):
		for key in dict_a.keys():
			var a_value = dict_a[key]
			var b_value = dict_b.get(key)
			if b_value == null:
				continue
			if a_value is Dictionary and b_value is Dictionary:
				_recursive_merge(a_value, b_value)
			elif a_value is Array and b_value is Array:
				for a in b_value:
					if not a in a_value:
						a_value.append(a)
			elif typeof(a_value) != typeof(b_value):
				print("EditorConsole config - incompatible types: ", a_value, " - ", b_value)
		
		dict_a.merge(dict_b)
		
		pass
