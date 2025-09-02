const UtilsLocal = preload("res://addons/godot_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/godot_console/src/utils/console_utils_remote.gd")

const PopupKeys = UtilsRemote.PopupHelper.ParamKeys
const ParsePopupKeys = UtilsLocal.ParsePopupKeys

static func get_completion(raw_text, commands:Array, args:Array, editor_console:EditorConsole) -> Dictionary:
	var completion_data = {}
	return completion_data

static func parse(commands:Array, arguments:Array, editor_console):
	pass
