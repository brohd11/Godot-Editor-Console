
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
	
	const SCRIPT = &"script"
	const CALLABLE = &"callable"


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
		
