const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")

const Commands = UtilsLocal.ConsoleCommandObject
const Pr = UtilsRemote.UString.PrintRich



static func _get_singleton_instance() -> EditorConsoleSingleton:
	return EditorConsoleSingleton.get_instance()

static func _convert_args_to_variables(arguments:Array):
	return _get_singleton_instance().tokenizer.get_arg_variables(arguments)


func get_commands() -> Dictionary:
	var commands = Commands.new()
	return commands.get_commands()

func get_completion(_raw_text, commands:Array, _args:Array) -> Dictionary:
	var completion_data = {}
	if commands.size() == 1: ## Basic completion, if script is called, return commands
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
	var metadata = command_data.get(Commands.Keys.METADATA, {})
	
	if not callable:
		print("No callable for command: %s" % c_2)
	else:
		callable = callable as Callable
		var callable_args = _get_standard_call_arguments(c_2, commands, arguments)
		#var arg_count = metadata.get(Commands.Keys.ARG_COUNT, callable_args.size()) # dont think I need this actually..
		#var callable_arg_count = callable.get_argument_count()
		_call_method(callable, callable_args)

static func _call_method(callable:Callable, args:Array):
	var callable_arg_count = callable.get_argument_count()
	if args.size() != callable_arg_count:
		UtilsLocal.Print.error_arg_count(callable, args)
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
