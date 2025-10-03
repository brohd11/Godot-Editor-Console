const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")

const PopupKeys = UtilsRemote.PopupHelper.ParamKeys
const ParsePopupKeys = UtilsLocal.ParsePopupKeys
const ECKeys = UtilsLocal.ParsePopupKeys
const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const UNode = UtilsRemote.UNode
const UClassDetail = UtilsRemote.UClassDetail

static func register_commands():
	return {}

static func get_completion(raw_text, commands:Array, args:Array, editor_console:EditorConsole) -> Dictionary:
	var completion_data = {}
	if commands.size() == 1: ## Basic completion, if script is called, return commands
		return register_commands()
	return completion_data

static func parse(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1 or UtilsLocal.check_help(commands):
		print("Help Message")
		return
	## Basic call template
	var c_2 = commands[1]
	var script_commands = register_commands() 
	var command_data = script_commands.get(c_2)
	if not command_data:
		print("Unrecognized command: %s" % c_2)
		return
	var callable = command_data.get("callable")
	if callable:
		callable.call(commands, arguments, editor_console)
