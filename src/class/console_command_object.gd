
const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Keys = UtilsLocal.ParsePopupKeys

var _command_dict:= {
	Keys.COMMAND_META: {}
}

static func get_arg_delimiter(dict:=true):
	if dict:
		return {" -- ": {}}
	else:
		return " -- "

func get_commands():
	return _command_dict

func add_command(cmd_name:String, add_arg_delim:=false, callable = null, icon=null):
	var param = Params.new(add_arg_delim, callable)
	param.icon = icon
	add_command_with_params(cmd_name, param)

func add_command_with_params(cmd_name:String, command_params:Params=null):
	var data = {}
	if command_params.callable != null:
		data[Keys.CALLABLE] = command_params.callable
	
	if command_params.icon != null:
		var icon
		if command_params.icon is String:
			icon = EditorInterface.get_editor_theme().get_icon(command_params.icon, "EditorIcons")
		elif command_params.icon is Texture2D:
			icon = command_params.icon
		else:
			print("Unrecognized Texture: %s" % command_params.icon)
		if is_instance_valid(icon):
			data[Keys.ICON] = [icon]
	
	command_params.metadata[Keys.ADD_ARGS] = command_params.add_argument_delimiter
	command_params.metadata[Keys.REPLACE_WORD] = command_params.replace_current_word
	
	if command_params.argument_count > -1:
		command_params.metadata[Keys.ARG_COUNT] = command_params.argument_count
	
	
	data[Keys.METADATA] = command_params.metadata
	_command_dict[cmd_name] = data

func show_variables():
	_command_dict[Keys.COMMAND_META][Keys.SHOW_VARIABLES] = true

class Params:
	var callable = null
	var icon = null
	var add_argument_delimiter:= false
	var replace_current_word:= false
	var argument_count:= -1
	var metadata = {}
	
	func _init(add_arg_delim:=false, _callable=null):
		add_argument_delimiter = add_arg_delim
		callable = _callable
