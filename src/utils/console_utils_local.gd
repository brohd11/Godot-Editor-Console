
const EditorConsoleSingleton = preload("res://addons/editor_console/src/editor_console.gd")

const ConsoleCommandBase = preload("uid://d2x2726tmgnq0") # console_command_base.gd
const ConsoleCommandSetBase = preload("uid://bu27r1hpnfinp") # console_command_set_base.gd

const DefaultCommands = preload("res://addons/editor_console/src/default_commands/scope_set/default.gd")
const ConsoleCfg = preload("res://addons/editor_console/src/default_commands/console_cfg.gd")
const ConsoleHelp = preload("res://addons/editor_console/src/default_commands/console_help.gd")
const ConsoleOS = preload("res://addons/editor_console/src/default_commands/console_os.gd")
const ConsoleMisc = preload("res://addons/editor_console/src/default_commands/console_misc.gd")

const ConsoleGlobalClass = preload("res://addons/editor_console/src/default_commands/console_global_class.gd")
const ConsoleScript = preload("res://addons/editor_console/src/default_commands/console_script.gd")

const SyntaxHl = preload("res://addons/editor_console/src/utils/console_syntax.gd")

const ConsoleCommandObject = preload("res://addons/editor_console/src/class/console_command_object.gd")

const ConsoleLineContainer = preload("res://addons/editor_console/src/utils/console_line_container.gd")
const ConsoleTokenizer = preload("res://addons/editor_console/src/utils/console_tokenizer.gd")

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const Pr = UtilsRemote.UString.PrintRich


const EDITOR_CONSOLE_SCOPE_PATH = "res://.addons/editor_console/scope_data.json" #! ignore-remote

static func get_scope_data():
	return UtilsRemote.UFile.read_from_json(EDITOR_CONSOLE_SCOPE_PATH)

static func save_scope_data(new_data:Dictionary):
	UtilsRemote.UFile.write_to_json(new_data, EDITOR_CONSOLE_SCOPE_PATH)

static func pr_arg_size_err(expected_size:int, arg_size:int):
	printerr("EditorConsole - Expected %s arguments, received %s" % [expected_size, arg_size])


class ScopeDataKeys:
	const global_classes = "global_classes"
	const sets = "sets"
	const scopes = "scopes"

class ParsePopupKeys extends UtilsRemote.PopupHelper.ParamKeys:
	const ADD_ARGS = &"ADD_ARGS"
	const REPLACE_WORD = &"REPLACE_WORD"
	const ARG_COUNT = &"ARG_COUNT"
	
	const COMMAND_META = &"COMMAND_META"
	const SHOW_VARIABLES = &"SHOW_VARIABLES"


static func get_global_class_list() -> Array:
	var class_names_array = []
	var classes = ProjectSettings.get_global_class_list()
	for data in classes:
		var _class = data.get("class")
		class_names_array.append(_class)
	return class_names_array

static func check_help(commands):
	if "-h" in commands or "--help" in commands:
		return true
	return false


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
	
	const ACCENT_MUTE = Color(0.302, 0.5059, 0.6039, 1.0)
	
	const ERROR_RED = Color(0.651, 0.071, 0.004, 1.0)
	
	const GRAY = Color.GRAY
	
	class Editor:
		enum EditorColors {
			ENGINE_TYPE
		}
		static func get_color(color:EditorColors):
			var ed_settings = EditorInterface.get_editor_settings()
			var setting = ""
			if color == EditorColors.ENGINE_TYPE:
				setting = "text_editor/theme/highlighting/engine_type_color"
			if setting == "":
				return null
			return ed_settings.get_setting(setting)


class Print:
	static func error_arg_count(callable:Callable, args:Array):
		Pr.new().append("EditorConsole - Callable: ", Colors.ERROR_RED).append(callable.get_method())\
		.append("\n\tExpected %s arguments, received %s" % [callable.get_argument_count(), args.size()], Colors.ERROR_RED)\
		.append("\n\tArguments: ").append("  ".join(args), Colors.ACCENT_MUTE).display()
