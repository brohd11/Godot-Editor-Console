
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const Pr = UtilsRemote.UString.PrintRich

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Commands = UtilsLocal.ConsoleCommandObject
const CompletionContext = UtilsLocal.CompletionContext
const ConsolePrint = UtilsLocal.Print
const Colors = UtilsLocal.Colors



static func _get_singleton_instance() -> EditorConsoleSingleton:
	return EditorConsoleSingleton.get_instance()

static func _convert_args_to_variables(arguments:Array):
	return _get_singleton_instance().tokenizer.get_arg_variables(arguments)


func get_commands() -> Dictionary:
	var commands = Commands.new()
	return commands.get_commands()

func get_completion(completion_context:CompletionContext) -> Dictionary:
	var completion_data = {}
	if completion_context.commands.size() == 1: ## Basic completion, if script is called, return commands
		return get_commands()
	return completion_data


func parse(commands:Array, arguments:Array):
	if _display_help(commands, arguments):
		return
	_call_standard_command(commands, arguments)

func _call_standard_command(commands:Array, arguments:Array):
	## Basic call template
	var c_2 = commands[1]
	var script_commands = get_commands() 
	var command_data = script_commands.get(c_2)
	if not command_data:
		print("Unrecognized command: %s" % c_2)
		return
	var callable = command_data.get(Commands.Keys.CALLABLE)
	if callable == null:
		print("No callable for command: %s" % c_2)
	else:
		var callable_args = _get_standard_call_arguments(c_2, commands, arguments)
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
			var type = arg_data.get("type")
			if i < args.size():
				var passed = args[i]
				if type > 0 and typeof(passed) != type:
					var pass_str = type_string(typeof(passed))
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
			#if args.is_empty():
				#args = ["Empty."]
			#if new_args.is_empty():
				#new_args = ["Empty."]
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
		print(result)

func _get_standard_call_arguments(_selected_command:String, _commands:Array, arguments:Array) -> Array:
	var args = _convert_args_to_variables(arguments)
	return args

func _display_help(commands:Array, arguments:Array):
	if commands.size() == 1 or UtilsLocal.check_help(commands):
		var msg = get_help_message(commands, arguments)
		if msg != null:
			print(msg)
		return true
	if not _is_input_valid(commands, arguments):
		return true
	return false

static func _has_help_command(commands:Array, commands_size:int=-1):
	if commands_size > -1:
		if commands.size() == commands_size:
			return true
	return UtilsLocal.check_help(commands)

## Return false to abort parsing the input
func _is_input_valid(commands:Array, arguments:Array) -> bool:
	return _is_command_valid(commands[1], commands, arguments)

func _is_command_valid(selected_command:String, commands, arguments) -> bool:
	var script_commands = get_commands() 
	var command_data = script_commands.get(selected_command)
	if command_data:
		return true
	else:
		var msg = get_invalid_command_message(commands[1], commands, arguments)
		if msg != null:
			print_rich(msg)
		return false

func get_help_message(_commands:Array, _arguments:Array):
	return "Overide 'get_help_message' to customize."

func get_invalid_command_message(selected_command, _commands:Array, _arguments:Array):
	var msg = "Unrecognized command: %s" % selected_command
	var commands = get_commands()
	if commands.is_empty():
		msg += "\nNo valid commands."
		return msg
	msg += "\nValid commands are:"
	for cmd in commands.keys():
		msg += "\n\t- %s" % cmd
	return msg


static func _check_command_index_valid(commands:Array, cmd_index:int, valid_commands:Array):
	if cmd_index >= commands.size():
		return false
	var cmd:String = commands[cmd_index]
	return cmd in valid_commands

static func _unrecognized_command(command:String):
	UtilsLocal.Print.error(Pr.new().append("Unrecognized command - ").append(command, Colors.ACCENT_MUTE).get_string())
