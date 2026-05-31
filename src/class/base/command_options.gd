
const SELF = preload("res://addons/editor_console/src/class/base/command_options.gd")

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")

const ARG_DELIMITER = "--"


var _option_dict:= {
	Keys.COMMAND_META: {}
}

func get_options():
	return _option_dict

func set_options(option_dict:Dictionary):
	_option_dict = option_dict

func merge(options, overwrite:=false):
	if options is Dictionary:
		_option_dict.merge(options, overwrite)
	elif options is SELF:
		_option_dict.merge(options.get_options(), overwrite)
	else:
		printerr("Unhandled options merge: ", options, " -> ", _option_dict)

func size():
	return _option_dict.size() - 1 # -1 to account for meta section

func add_separator(text:="", add_decorators:=true):
	if text != "" and add_decorators:
		text = "── " + text + " ──"
	Keys.add_separator(_option_dict, text)

func remove_option(option_name:String):
	_option_dict.erase(option_name)

#! keys name:String help:String positional_count:int trailing_char:String icon:Variant
#! keys get_command:Callable priority:int metadata:Dictionary arg_count:int insert:String
func add_option(option_name:String, params:={}):
	_option_dict[option_name] = get_single_option_dict(option_name, params)

#! keys i-add_option;
static func get_single_option_dict(option_name:String, params:={}) -> Dictionary:
	params.option_name = option_name # this param is not used any where, really was just for undefined 'help'
	return process_option_dict(params)

#! keys i-add_option;
static func process_option_dict(params:={}) -> Dictionary:
	var data = {}
	data.help = params.get(&"help", "No help defined for: %s" % params.get(&"option_name", "Unamed"))
	data.positional_count = params.get(&"positional_count", 0)
	data.priority = params.get(&"priority", 1000)
	
	if params.has(&"icon"):
		if params.icon is String:
			data.icon = UtilsRemote.EditorIcons.get_icon_white(params.icon)
		elif params.icon is Texture2D:
			data.icon = params.icon
		else:
			print("Unrecognized Texture: %s" % params.icon)
	
	data[Keys.METADATA] = params.get(&"metadata", {})
	
	if params.has(&"insert"):
		data[Keys.METADATA][Keys.INSERT] = params.insert
	#data[Keys.METADATA][Keys.ARG_COUNT] = params.get(&"arg_count", -1)
	data[Keys.METADATA][Keys.TRAILING_CHAR] = params.get(&"trailing_char", " ")
	data[Keys.METADATA][Keys.ADD_ARGS] = params.get(&"add_arg_delim", false)
	data[Keys.METADATA][Keys.REPLACE_WORD] = params.get(&"replace_current_word", true)
	
	if params.has(&"get_command"):
		#data[Keys.METADATA].get_command = params.get_command
		data.get_command = params.get_command
	
	return data

func add_command_script(command):
	add_command_script_to_dict(command, _option_dict)

static func add_command_script_to_dict(command, dict:Dictionary):
	var data = command.get_self_command_data()
	if not data.has(&"get_command"):
		data[&"get_command"] = func():
			command = EditorConsoleSingleton.ensure_fresh_script(command)
			return command.new()
	dict[command.get_command_name()] = data



func show_variables():
	add_show_variables_to_dict(_option_dict)

static func add_show_variables_to_dict(dict:Dictionary):
	if not dict.has(Keys.COMMAND_META):
		dict[Keys.COMMAND_META] = {}
	dict[Keys.COMMAND_META][Keys.SHOW_VARIABLES] = true

static func add_key_to_meta(dict:Dictionary, key:StringName, value=true):
	var meta = dict.get_or_add(Keys.METADATA)
	meta[key] = value


class Keys extends UtilsRemote.PopupHelper.ParamKeys:
	const INSERT = &"INSERT"
	const ADD_ARGS = &"ADD_ARGS"
	const REPLACE_WORD = &"REPLACE_WORD"
	const TRAILING_CHAR = &"TRAILING_CHAR"
	const ARG_COUNT = &"ARG_COUNT"
	
	const COMMAND_META = &"COMMAND_META"
	const SHOW_VARIABLES = &"SHOW_VARIABLES"
