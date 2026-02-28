extends EditorConsoleSingleton.ConsoleCommandBase


const Colors = UtilsLocal.Colors

const UClassDetail = UtilsRemote.UClassDetail
const UNode = UtilsRemote.UNode

const _ARG_CLASS_COLOR_SETTING = "text_editor/theme/highlighting/base_type_color"

const CONSOLE_METHODS = ["parse", "get_completion"]

const CALL_COMMAND = "call"
const PRIVATE_COMMAND = "private"
const ARG_COMMAND = "args"
const LIST_COMMAND = "list"

const LIST_COMMANDS_OPTIONS = ["--methods", "--signals", "--constants", "--properties",
"--enums"]
const LIST_MODIFIER_OPTIONS = ["--lines", "--data", "--inherited"]

const SCRIPT_HELP=\
"Call static methods on current script, or create an instance.
	call - call method -- <method_name, arg1, arg2, ... >
	args - list arguments for method -- <method_name>
	list - list members of script -- <list_flags> (--methods, --signals, --constants,\
--properties, --enums, --inherited, --lines)"

static func get_commands_static():
	var commands = Commands.new()
	commands.add_command(CALL_COMMAND, false, call_method)
	commands.add_command(ARG_COMMAND, false, list_args)
	commands.add_command(LIST_COMMAND, true, print_members)
	return commands.get_commands()

func get_commands() -> Dictionary: 
	return get_commands_static()


func get_completion(completion_context:CompletionContext) -> Dictionary:
	var registered = get_commands()
	var script = EditorInterface.get_script_editor().get_current_script()
	return get_completion_static(completion_context, registered, script)
	
static func get_completion_static(completion_context:CompletionContext, registered_commands:Dictionary, script:GDScript) -> Dictionary:
	var commands = completion_context.commands
	var args = completion_context.arguments
	var word_before_cursor = completion_context.word_before_cursor
	
	if word_before_cursor == completion_context.ARG_DELIMITER:
		return {}
	
	
	var has_registered = false
	for cmd in registered_commands:
		if cmd in commands:
			has_registered = true
			break
	
	var commands_obj = Commands.new()
	var has_arg_delim = completion_context.has_arg_delimiter
	if not has_arg_delim:
		
		if commands.size() <= 2 and not has_registered:
			return registered_commands
		
		var main_command = commands[1]
		if main_command == CALL_COMMAND or main_command == ARG_COMMAND:
			if word_before_cursor != main_command:
				if not "private" in commands:
					commands_obj.add_command("private")
		
		if word_before_cursor == "":
			commands_obj.add_arg_delimiter()
		return commands_obj.get_commands()
	
	elif has_arg_delim:
		if not has_registered:
			return {}
		if commands.size() > 1:
			var main_command = commands[1]
			var show_private = false
			if "private" in commands:
				show_private = true
			if main_command == CALL_COMMAND:
				return get_method_completions(script, args, show_private)
			elif main_command == ARG_COMMAND:
				if args.size() == 0:
					return get_method_completions(script, args, show_private)
			elif main_command == LIST_COMMAND:
				return get_list_commands(args)
	
	return commands_obj.get_commands()


static func call_method(script:Script, args:Array):
	if args.size() < 1:
		print("Need method name to call.")
		return
	var method_name = args[0]
	args.remove_at(0)
	if not UNode.has_static_method_compat(method_name, script):
		print("Static method not in script.")
		return
	var callable = script.get(method_name)
	_call_method(callable, args) # will this work in < 4.4? compat ^^
	
	#if args.size() != script.get_method_argument_count(method_name):
		#print("Argument count=%s, called with %s." % [script.get_method_argument_count(method_name), args.size()])
		#return
	#var result = script.callv(method_name, args)
	#if result != null:
		#print(result)


static func list_args(script:Script, args:Array):
	if args.size() < 1:
		print("Need method name to list args.")
		return
	var method_name = args[0]
	if not method_name in script:
		print("Static method not in script.")
		return
	var args_array = []
	var method_list = script.get_script_method_list()
	for method_dict in method_list:
		var name = method_dict.get("name")
		if name != method_name:
			continue
		args_array = method_dict.get("args", [])
		break
	
	if args_array.is_empty():
		print("No args to list.")
		return
	
	var class_name_color = EditorInterface.get_editor_settings().get_setting(_ARG_CLASS_COLOR_SETTING)
	var pr = Pr.new()
	for dict in args_array:
		var name = dict.get("name")
		var type = type_string(dict.get("type"))
		var color = class_name_color
		if type == "Nil":
			color = Colors.VAR_RED
		pr.append(name + ":").append(type, color).append("  ")
	pr.display()


static func get_valid_commands(current_commands:Array, command_obj_dict:Dictionary):
	for cmd in command_obj_dict.keys():
		if cmd in current_commands:
			command_obj_dict.erase(cmd)
			continue
	return command_obj_dict


static func get_list_commands(current_args:Array):
	var commands_obj = Commands.new()
	for cmd in LIST_COMMANDS_OPTIONS:
		if cmd not in current_args:
			commands_obj.add_command(cmd)
	
	if commands_obj.size() < LIST_COMMANDS_OPTIONS.size():
		commands_obj.add_separator("Modifiers")
		for cmd in LIST_MODIFIER_OPTIONS:
			if cmd not in current_args:
				commands_obj.add_command(cmd)
	
	return commands_obj.get_commands()


static func get_method_completions(script:Script, current_args:Array, show_private:bool):
	var commands_obj = Commands.new()
	var method_list = script.get_script_method_list()
	for method in method_list:
		var name = method.get("name")
		if not show_private:
			if name in CONSOLE_METHODS or name.begins_with("_"):
				continue
		if UNode.has_static_method_compat(name, script):
			commands_obj.add_command(name)
		if name in current_args:
			return {}
	commands_obj.show_variables()
	return commands_obj.get_commands()



static func print_members(script_name:String, args:Array, script:Script):
	var print_data = LIST_MODIFIER_OPTIONS[1] in args
	var print_lines = LIST_MODIFIER_OPTIONS[0] in args
	var inherited = LIST_MODIFIER_OPTIONS[2] in args
	var valid = false
	for a in args:
		if a in LIST_COMMANDS_OPTIONS:
			valid = true
	var args_size = args.size()
	if not valid:
		if args_size > 0:
			print("'--data', '--lines', and '--inherited' should be passed with another argument.")
		else:
			print("Pass arguments for the list command.")
		return
	
	var pr = Pr.new()
	for i in range(args_size):
		var command = args[i]
		if command in LIST_COMMANDS_OPTIONS:
			var members = {}
			if command == LIST_COMMANDS_OPTIONS[0]: # methods
				if inherited:
					print("Printing class methods: %s" % script_name)
					members = UClassDetail.class_get_all_methods(script)
				else:
					print("Printing script methods: %s" % script_name)
					members = UClassDetail.script_get_all_methods(script)
			elif command == LIST_COMMANDS_OPTIONS[1]: # signals
				if inherited:
					print("Printing class signals: %s" % script_name)
					members = UClassDetail.class_get_all_signals(script)
				else:
					print("Printing script signals: %s" % script_name)
					members = UClassDetail.script_get_all_signals(script)
			elif command == LIST_COMMANDS_OPTIONS[2]: # constants
				if inherited:
					print("Printing class constants: %s" % script_name)
					members = UClassDetail.class_get_all_constants(script)
				else:
					print("Printing script constants: %s" % script_name)
					members = UClassDetail.script_get_all_constants(script)
			elif command == LIST_COMMANDS_OPTIONS[3]: # properties
				if inherited:
					print("Printing class properties: %s" % script_name)
					members = UClassDetail.class_get_all_properties(script)
				else:
					print("Printing script properties: %s" % script_name)
					members = UClassDetail.script_get_all_properties(script)
			elif command == LIST_COMMANDS_OPTIONS[4]: # enums
				if inherited:
					print("Printing class enums: %s" % script_name)
					members = UClassDetail.class_get_all_enums(script)
				else:
					print("Cannot get script enums, no API in ClassDB. Use '--inherited' option.")
					#members = UClassDetail.sc(script)
					pass
			
			if members.is_empty():
				pr.append("\tNone in script.", Colors.VAR_RED).display()
			else:
				if print_lines or print_data:
					for m in members.keys():
						pr.append("%s" % m, Colors.ACCENT_MUTE).display()
						if print_data:
							var data = members.get(m)
							if data == null:
								pr.append("\tNo data.").display()
							else:
								for key in data.keys():
									pr.append("\t%s - %s" % [key, data[key]], Colors.GRAY).display()
				else:
					pr.append("\t" + "  ".join(members.keys()), Colors.ACCENT_MUTE).display()
			if i < args_size - 1:
				print("")
			continue


func _get_standard_call_arguments(selected_command:String, commands:Array, arguments:Array) -> Array:
	var script = EditorInterface.get_script_editor().get_current_script()
	var script_name = script.resource_path.get_file()
	return get_standard_call_arguments_static(script_name, script, selected_command, commands, arguments)

static func get_standard_call_arguments_static(script_name:String, script:GDScript, selected_command:String, _commands:Array, arguments:Array) -> Array:
	var converted_args = _convert_args_to_variables(arguments)
	match selected_command:
		CALL_COMMAND:
			return [script, converted_args]
		ARG_COMMAND:
			return [script, converted_args]
		LIST_COMMAND:
			return [script_name, arguments, script]
	return converted_args

func get_help_message(_commands:Array, _arguments:Array):
	return SCRIPT_HELP
