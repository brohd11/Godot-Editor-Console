
const SELF = preload("res://addons/editor_console/src/class/base/command_options.gd")

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Keys = UtilsLocal.ParsePopupKeys

const ARG_DELIMITER = "--"


var _option_dict:= {
	Keys.COMMAND_META: {}
}

static func get_arg_delimiter_command():
	return {ARG_DELIMITER: {}}

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

func add_arg_delimiter(replace_current_word:=true):
	var params = Params.new()
	params.replace_current_word = replace_current_word
	add_command_with_params(ARG_DELIMITER, params)

#! keys i-add_option_with_params;
func add_option(option_name:String, params:={}):
	add_option_with_params(option_name, params)

#! keys name:String help:String positional_count:int token_count:int trailing_char:String arg_count:int icon:Variant
#! keys add_arg_delim:bool replace_current_word:bool metadata:Dictionary get_command:Callable priority:int callable:Callable
func add_option_with_params(option_name:String, params:={}):
	#var data = {}
	#data.help = params.get(&"help", "No help defined for: %s" % option_name)
	#data.token_count = params.get(&"token_count", 1)
	#
	#if params.has(&"callable"):
		#data.callable = params.get(&"callable")
	#if params.has(&"icon"):
		#if params.icon is String:
			#data.icon = UtilsRemote.EditorIcons.get_icon_white(params.icon)
		#elif params.icon is Texture2D:
			#data.icon = params.icon
		#else:
			#print("Unrecognized Texture: %s" % params.icon)
	#
	#data[Keys.METADATA] = params.get(&"metadata", {})
	#
	#data[Keys.METADATA][Keys.ARG_COUNT] = params.get(&"arg_count", -1)
	#data[Keys.METADATA][Keys.TRAILING_CHAR] = params.get(&"trailing_char", " ")
	#data[Keys.METADATA][Keys.ADD_ARGS] = params.get(&"add_arg_delim", false)
	#data[Keys.METADATA][Keys.REPLACE_WORD] = params.get(&"replace_current_word", true)
	#
	#if params.has(&"get_command"):
		##data[Keys.METADATA].get_command = params.get_command
		#data.get_command = params.get_command
	
	_option_dict[option_name] = get_single_option_dict(option_name, params)

#! keys i-add_option_with_params;
static func get_single_option_dict(option_name:String, params:={}) -> Dictionary:
	var data = {}
	data.name = option_name
	data.help = params.get(&"help", "No help defined for: %s" % option_name)
	data.positional_count = params.get(&"positional_count", 0)
	data.token_count = params.get(&"token_count", 1)
	data.priority = params.get(&"priority", 1000)
	
	if params.has(&"callable"):
		data.callable = params.get(&"callable")
	if params.has(&"icon"):
		if params.icon is String:
			data.icon = UtilsRemote.EditorIcons.get_icon_white(params.icon)
		elif params.icon is Texture2D:
			data.icon = params.icon
		else:
			print("Unrecognized Texture: %s" % params.icon)
	
	data[Keys.METADATA] = params.get(&"metadata", {})
	
	data[Keys.METADATA][Keys.ARG_COUNT] = params.get(&"arg_count", -1)
	data[Keys.METADATA][Keys.TRAILING_CHAR] = params.get(&"trailing_char", " ")
	data[Keys.METADATA][Keys.ADD_ARGS] = params.get(&"add_arg_delim", false)
	data[Keys.METADATA][Keys.REPLACE_WORD] = params.get(&"replace_current_word", true)
	
	if params.has(&"get_command"):
		#data[Keys.METADATA].get_command = params.get_command
		data.get_command = params.get_command
		
	
	#
	#command_params.metadata[Keys.ADD_ARGS] = command_params.add_argument_delimiter
	#command_params.metadata[Keys.REPLACE_WORD] = command_params.replace_current_word
	#command_params.metadata[Keys.TRAILING_CHAR] = command_params.trailing_char
	#
	#if command_params.argument_count > -1:
		#command_params.metadata[Keys.ARG_COUNT] = command_params.argument_count
	#
	#
	#data[Keys.METADATA] = command_params.metadata
	return data

func add_command(command):
	add_command_to_dict(command, _option_dict)

static func add_command_to_dict(command, dict:Dictionary):
	var data = command.get_self_option_data()
	if not data.has(&"get_command"):
		data[&"get_command"] = func(): return command.new()
	dict[command.get_command_name()] = data

func add_command_no_space(cmd_name:String, add_arg_delim:=false, callable = null, icon=null):
	var param = Params.new(add_arg_delim, callable)
	param.icon = icon
	param.replace_current_word = true
	param.trailing_char = ""
	add_command_with_params(cmd_name, param)

func add_command_with_params(cmd_name:String, command_params:Params=null):
	var data = {}
	if command_params.callable != null:
		data[Keys.CALLABLE] = command_params.callable
	
	if command_params.icon != null:
		var icon
		if command_params.icon is String:
			icon = UtilsRemote.EditorIcons.get_icon_white(command_params.icon)
		elif command_params.icon is Texture2D:
			icon = command_params.icon
		else:
			print("Unrecognized Texture: %s" % command_params.icon)
		if is_instance_valid(icon):
			data[Keys.ICON] = [icon]
	
	command_params.metadata[Keys.ADD_ARGS] = command_params.add_argument_delimiter
	command_params.metadata[Keys.REPLACE_WORD] = command_params.replace_current_word
	command_params.metadata[Keys.TRAILING_CHAR] = command_params.trailing_char
	
	if command_params.argument_count > -1:
		command_params.metadata[Keys.ARG_COUNT] = command_params.argument_count
	
	
	data[Keys.METADATA] = command_params.metadata
	_option_dict[cmd_name] = data

func show_variables():
	_option_dict[Keys.COMMAND_META][Keys.SHOW_VARIABLES] = true



class Params:
	var callable = null
	var icon = null
	var add_argument_delimiter:= false
	var replace_current_word:= false
	var trailing_char:= " " # default to a space
	var argument_count:= -1
	var metadata = {}
	
	func _init(add_arg_delim:=false, _callable=null):
		add_argument_delimiter = add_arg_delim
		callable = _callable
