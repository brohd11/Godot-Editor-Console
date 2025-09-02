
const EditorConsole = preload("res://addons/godot_console/src/editor_console.gd")

const DefaultCommands = preload("res://addons/godot_console/src/default_commands/default.gd")
const ConsoleCfg = preload("res://addons/godot_console/src/default_commands/console_cfg.gd")
const ConsoleHelp = preload("res://addons/godot_console/src/default_commands/console_help.gd")
const ConsoleOS = preload("res://addons/godot_console/src/default_commands/console_os.gd")
const ConsoleMisc = preload("res://addons/godot_console/src/default_commands/console_misc.gd")

const ConsoleGlobalClass = preload("res://addons/godot_console/src/default_commands/console_global_class.gd")
const ConsoleScript = preload("res://addons/godot_console/src/default_commands/console_script.gd")

const SyntaxHl = preload("res://addons/godot_console/src/utils/console_syntax.gd")

const ConsoleLineContainer = preload("res://addons/godot_console/src/utils/console_line_container.gd")
const ConsoleTokenizer = preload("res://addons/godot_console/src/utils/console_tokenizer.gd")

class ParsePopupKeys:
	const ADD_ARGS = "add_args"
	const REPLACE_WORD = "replace_word"
	
	pass

static func check_help(commands):
	if "-h" in commands or "--help" in commands:
		return true
	return false
