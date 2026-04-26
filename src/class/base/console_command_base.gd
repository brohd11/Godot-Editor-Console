
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const Pr = UtilsRemote.UString.PrintRich

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer
const Commands = UtilsLocal.ConsoleCommandObject
const CompletionContext = UtilsLocal.CompletionContext
const ConsolePrint = UtilsLocal.Print
const Colors = UtilsLocal.Colors

const _RESULTS_TO_SKIP = ["GDScriptFunctionState"]


static func _get_singleton_instance() -> EditorConsoleSingleton:
	return EditorConsoleSingleton.get_instance()

static func _convert_args_to_variables(arguments:Array):
	return _get_singleton_instance().tokenizer.get_arg_variables(arguments)


func get_commands() -> Dictionary:
	var commands = Commands.new()
	return commands.get_commands()

func _get_valid_commands_for_index(completion_context:CompletionContext, cmd_idx:int) -> Dictionary:
	var commands = completion_context.commands
	var help_dict = _get_help_dict()
	if help_dict.is_empty() or completion_context.execute:
		var registered = get_commands()
		return registered
		#if cmd_idx == 0: # old version
			#return get_commands()
		#return {}
	var cmd = commands[cmd_idx]
	var data = help_dict.get(cmd)
	if data is String:
		return {}
	if data is Dictionary:
		var commands_obj = Commands.new()
		for c in data.get("c", []):
			commands_obj.add_command(c)
		return commands_obj.get_commands()
	return {}

func get_completion(completion_context:CompletionContext) -> Dictionary:
	var commands = completion_context.commands
	if commands.size() == 1:
		return _get_valid_commands_for_index(completion_context, 0)
	for i in range(commands.size()):
		var valid_commands = _get_valid_commands_for_index(completion_context, i)
		if not _check_command_index_valid(commands, i + 1, valid_commands.keys()):
			#print("INVALID ", commands[i])
			return valid_commands
		if completion_context.word_before_cursor == commands[i + 1]:
			return {}
			
		#print("VALID ", commands[i + 1])
	return {}


func parse(completion_context:CompletionContext):
	if _display_help(completion_context):
		return
	_call_standard_command(completion_context)

func _call_standard_command(completion_context:CompletionContext):
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	## Basic call template
	var command_idx = _get_standard_call_command_index(commands, arguments)
	var target_command = commands[command_idx]
	var script_commands = _get_valid_commands_for_index(completion_context, command_idx - 1)
	#var script_commands = get_commands() 
	var command_data = script_commands.get(target_command)
	if not command_data:
		print("Standard call")
		_unrecognized_command(target_command)
		return
	var callable = command_data.get(Commands.Keys.CALLABLE)
	if callable == null:
		UtilsLocal.Print.error("No callable for command: %s" % target_command)
	else:
		var callable_args = _get_standard_call_arguments(target_command, commands, arguments)
		_call_method(callable, callable_args)


static func _call_method(callable:Callable, args:Array, create_default_args:=false):
	var callable_arg_count = callable.get_argument_count()
	if args.size() != callable_arg_count:
		if not create_default_args:
			UtilsLocal.Print.error_arg_count(callable, args)
			return
		
	var obj = callable.get_object()
	var method_name = callable.get_method()
	var property_info = UtilsRemote.UClassDetail.get_member_info_by_path(obj, method_name)
	if not (property_info is Dictionary and property_info.has("args")):
		ConsolePrint.error("Could not get method '%s' info in object: %s" % [method_name, obj])
		return
	var valid_args = true
	var callable_args = property_info.get("args")
	if create_default_args:
		var default_args = property_info.get("default_args", []) as Array
		for i in range(callable_args.size() - default_args.size()):
			default_args.push_front(null)
		var new_args = []
		for i in range(callable_args.size()):
			var arg_data = callable_args[i]
			var type:int = arg_data.get("type")
			if i < args.size():
				var passed = args[i]
				if type > 0 and typeof(passed) != type:
					var err:= true
					var pass_str = type_string(typeof(passed))
					if type != TYPE_OBJECT:
						var converted = ConsoleTokenizer.Var.auto_convert(passed, type)
						if converted != null:
							args[i] = converted
							print("Arg '%s' conversion: %s %s -> %s %s" % [arg_data.get("name"), pass_str, passed, type_string(type), converted])
							err = false
					if err:
						ConsolePrint.error("Arg '%s' type mismatch: %s passed, should be %s" % [arg_data.get("name"), pass_str, type_string(type)])
						valid_args = false
				continue
			
			var default_val = default_args[i]
			if default_val != null:
				new_args.append(default_val)
				continue
			if arg_data.get("class_name") != "":
				var _class = arg_data.get("class_name")
				if _class == "GDScript" or _class == "Script":
					new_args.append(EditorInterface.get_script_editor().get_current_script())
				continue
			else:
				var variant = type_convert(null, type)
				new_args.append(variant)
		
		if args.size() + new_args.size() != callable_arg_count:
			Pr.new().append("Could not create default args for method ", Colors.ERROR_RED).append("'%s'" % method_name)\
			.append(" in object: ", Colors.ERROR_RED).append(obj).display()
			Pr.new().append("Passed: ").append("%s" % [args], Colors.ACCENT_MUTE).append(" Created:").append("%s" % [new_args], Colors.ACCENT_MUTE).display()
			return
		
		args.append_array(new_args)
	
	if not valid_args:
		ConsolePrint.error("Invalid arguments.")
		return
	var result = callable.callv(args)
	if result != null:
		if result is Object:
			if result.get_class() in _RESULTS_TO_SKIP:
				return
		print(result)

func _get_standard_call_command_index(commands:Array, arguments:Array):
	return commands.size() - 1

func _get_standard_call_arguments(_selected_command:String, _commands:Array, arguments:Array) -> Array:
	var args = _convert_args_to_variables(arguments)
	return args

func _display_help(completion_context:CompletionContext):
	var commands = completion_context.commands
	var display_help = false
	if _has_help_command(completion_context, 1):
		display_help = true
	if _is_input_valid(completion_context):
		if _command_requires_arguments(commands[commands.size() - 1]) and completion_context.arguments.size() == 0:
			display_help = true
	else:
		display_help = true
	if display_help:
		var msg = get_help_message(completion_context)
		if msg != null:
			print(msg)
		return true
	return false

## Returns true if commands or arguments contains "--help" or "-h".
## If "commands_size" > -1 and commands array size is equal to the size, returns true.
static func _has_help_command(completion_context:CompletionContext, commands_size:int=-1):
	if commands_size > -1:
		if completion_context.commands.size() == commands_size:
			return true
	return UtilsLocal.check_help(completion_context.commands) or UtilsLocal.check_help(completion_context.arguments)

## Return false to abort parsing the input and display the help message.
func _is_input_valid(completion_context:CompletionContext) -> bool:
	return _check_commands_valid(completion_context)

func _check_commands_valid(completion_context:CompletionContext) -> bool:
	var commands = completion_context.commands.duplicate()
	var arguments = completion_context.arguments.duplicate()
	_remove_help_commands(commands, arguments)
	var commands_size = commands.size()
	for i in range(1, commands_size): # start at the second command, if you are at this point, the first is valid
		#if i == commands_size - 1: # not sure why I had this, but will stop the last command from being checked
			#break
		var valid_commands = _get_valid_commands_for_index(completion_context, i - 1) # get commands for the previous level, current level should be in them
		if not _check_command_index_valid(commands, i, valid_commands.keys()):
			return false
	return true

func _command_requires_arguments(selected_command:String) -> bool:
	return false

func _get_help_dict():
	return {}

func get_help_message(completion_context:CompletionContext):
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	_remove_help_commands(commands, arguments)
	var last_command = commands[commands.size() - 1]
	
	if not _check_commands_valid(completion_context):
		_unrecognized_command(last_command)
		last_command = commands[commands.size() - 2]
	
	var help_dict = _get_help_dict()
	if not help_dict.has(last_command):
		_unrecognized_command(last_command)
		return
	
	var data = help_dict.get(last_command)
	if data == null:
		return "No data configured for help: %s" % last_command
	if data is String:
		return "Command: " + last_command + " - " + data
	elif data is Dictionary:
		return _build_scope_help_message(help_dict, last_command)
	_unrecognized_command(last_command + " - " + str(data))


func _build_scope_help_message(dict:Dictionary, scope_name:String, commands:Array=[]):
	var data = dict.get(scope_name, {})
	var text = scope_name + " - " + data.get("m", "Available commands:")
	if commands.is_empty():
		commands = data.get("c", [])
	for i in range(commands.size()):
		var cmd_name = commands[i]
		var message = dict.get(cmd_name, "no description")
		text += "\n\t%s - %s" % [cmd_name, message]
	return text

## Check if the command at index exists or not, then if that command is in valid commands.
static func _check_command_index_valid(commands:Array, cmd_index:int, valid_commands:Array):
	if cmd_index >= commands.size():
		return false
	var cmd:String = commands[cmd_index]
	return cmd in valid_commands

static func _remove_help_commands(commands:Array, arguments:Array):
	for array in [commands, arguments]:
		if array.rfind("-h") > -1:
			array.remove_at(array.rfind("-h"))
		if array.rfind("--help") > -1:
			array.remove_at(array.rfind("--help"))


static func _unrecognized_command(command:String):
	UtilsLocal.Print.error(Pr.new().append("Unrecognized command - ").append(command, Colors.ACCENT_MUTE).get_string())
