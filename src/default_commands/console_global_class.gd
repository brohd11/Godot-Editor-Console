extends EditorConsoleSingleton.ConsoleCommandBase

const UClassDetail = UtilsRemote.UClassDetail
const UNode = UtilsRemote.UNode
const UString = UtilsRemote.UString

const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const ConsoleScript = UtilsLocal.ConsoleScript

const _PRINT_LIST = "print_list"
const _PRINT_LIST_OPTIONS = ["--tool", "--abstract", "--name=", "--lang=", "--base="]

const GLOBAL_COMMANDS = [_PRINT_LIST]


func _get_help_dict():
	var dict = ConsoleScript.HELP_DICT.duplicate(true)
	var script_dict = dict["script"]
	script_dict["m"] = "Perform actions on global scripts, available commands:"
	dict.erase("script")
	dict["global"] = {"m": "Optional keyword 'global' will provide registered classes in autocomplete.\n'global' can be subbed for any global class name."}
	
	for class_nm in UClassDetail.get_all_global_class_paths():
		dict[class_nm] = script_dict
	
	return dict

func get_commands() -> Dictionary:
	var script_commands = ConsoleScript.get_commands_static()
	var global_commands = Commands.new()
	global_commands.add_command(_PRINT_LIST, false, _print_list)
	global_commands._command_dict.merge(script_commands)
	return global_commands.get_commands()

func _get_standard_call_command_index(_commands:Array, _arguments:Array):
	var c_1 = _commands[0]
	if not c_1 in GLOBAL_COMMANDS:
		return 1 # for this script, this makes it always choose the 2nd command for executing
	if c_1 == _PRINT_LIST:
		return 0
	return 0 

func get_completion(completion_context:CompletionContext) -> Dictionary:
	var commands = completion_context.commands
	
	if commands[0] != "global":
		commands.push_front("global")
	
	var commands_obj = Commands.new()
	
	
	
	var registered_classes = UtilsLocal.get_registered_global_classes()
	
	var global_classes = UClassDetail.get_all_global_class_paths().keys()
	var valid_global_class_dict = {}
	var invalid_global_class_dict = {}
	for _name in registered_classes:
		if _name in global_classes:
			valid_global_class_dict[_name] = true
		else:
			invalid_global_class_dict[_name] = true
	
	var current_class_name = ""
	if commands.size() >= 2:
		var c_2 = commands[1]
		var c_2_stripped = UtilsRemote.UString.get_member_access_front(c_2)
		if UClassDetail.get_global_class_path(c_2_stripped) != "":# c_2_stripped in global_class_names:
			current_class_name = c_2_stripped
	
	if current_class_name == "":
		commands_obj.add_command(_PRINT_LIST, true)
		commands_obj.add_separator("Registered")
	
	if commands.size() == 2 and commands[1] in GLOBAL_COMMANDS:
		var c_2 = commands[1]
		if c_2 == _PRINT_LIST:
			if not completion_context.has_arg_delimiter:
				return {}
			var print_commands = Commands.new()
			for arg in _PRINT_LIST_OPTIONS:
				if not completion_context.arguments.has(arg):
					if arg.ends_with("="):
						print_commands.add_command_no_space(arg)
					else:
						print_commands.add_command(arg)
			
			return print_commands.get_commands()
		
		return {}
	
	if commands.size() <= 2 and current_class_name == "":
		for name in valid_global_class_dict.keys():
			commands_obj.add_command(name)
		for name in invalid_global_class_dict.keys():
			commands_obj.add_separator(name + "[Not in Global Space]", false)
		return commands_obj.get_commands()
	
	if current_class_name == "":
		return {}
	
	var script = UClassDetail.get_global_class_script(current_class_name)
	completion_context.commands.remove_at(0)
	var std_commands = get_commands()
	std_commands.erase(_PRINT_LIST) # don't want this at this point
	return ConsoleScript.get_completion_static(completion_context, std_commands, script)


func parse(completion_context:CompletionContext):
	if _display_help(completion_context):
		return
	var commands = completion_context.commands
	var c_1 = commands[0]
	if c_1 == "global":
		commands.remove_at(0)
	_call_standard_command(completion_context)

func _is_input_valid(completion_context:CompletionContext) -> bool:
	var commands = completion_context.commands
	var c_1 = commands[0]
	if c_1 == "global":
		if commands.size() == 1:
			return false
		commands.remove_at(0)
		c_1 = commands[0]
	
	if c_1 in GLOBAL_COMMANDS:
		if c_1 == _PRINT_LIST:
			return true
		
		return false
	
	var class_nm = UString.get_member_access_front(c_1)
	var global_classes = UClassDetail.get_all_global_class_paths()
	if not class_nm in global_classes:
		Pr.new().append("Could not find class: ", UtilsLocal.Colors.ERROR_RED).append(class_nm).display()
		return false
	if commands.size() == 1 and c_1.find(".") == -1:
		var pr = Pr.new()
		pr.append("Class valid: ").append(c_1, Color.WEB_GREEN).display()
		return false
	
	var script = ConsoleScript.resolve_script_member_access(commands, completion_context.arguments)
	if script == null:
		ConsolePrint.error("Could not resolve script path: %s" % commands[0])
		return false
	
	return _check_command_index_valid(commands, 1, get_commands().keys())


func _get_standard_call_arguments(_selected_command:String, commands:Array, arguments:Array) -> Array:
	if _is_global_command(_selected_command):
		if _selected_command == _PRINT_LIST:
			return [arguments] # return arguments as an array so can parse the flags
		return arguments
	
	var global_class_name = commands[0]
	var global_class_script = ConsoleScript.resolve_script_member_access(commands, arguments)
	return ConsoleScript.get_standard_call_arguments_static(global_class_name, global_class_script, _selected_command, commands, arguments)

func _command_requires_arguments(_selected_command:String) -> bool:
	if not _selected_command in GLOBAL_COMMANDS:
		return true
	if _selected_command == _PRINT_LIST:
		return false
	return true

func _is_global_command(_selected_command:String):
	if _selected_command in GLOBAL_COMMANDS:
		return true
	return false


# global commands
func _print_list(args:Array):
	var show_tools:=false
	var show_abstract:=false
	var target_name:String = "--"
	var target_language:String="GDScript"
	var target_base:String = "--"
	
	#print(args)
	
	while not args.is_empty():
		var arg:String = args.pop_front()
		if arg in ["-t", "--tool"]:
			show_tools = true
		elif arg in ["-a", "--abstract"]:
			show_abstract = true
		elif arg.begins_with("--name="):
			target_name = arg.get_slice("--name=", 1)
			target_name = UString.unquote(target_name)
		elif arg.begins_with("--lang="):
			target_language = arg.get_slice("--lang=", 1)
			target_language = UString.unquote(target_language)
		elif arg.begins_with("--base="):
			target_base = arg.get_slice("--base=", 1)
			target_base = UString.unquote(target_base)
		else:
			UtilsLocal.Print.error("Unrecognized argument: " + arg)
			return
	
	var name_check:TextCheck
	if target_name != "--":
		name_check = TextCheck.new(target_name)
	
	var base_check:TextCheck
	if target_base != "--":
		base_check = TextCheck.new(target_base)
	
	print("Printing global class list:")
	var pr = Pr.new()
	
	var global_class_list = ProjectSettings.get_global_class_list()
	for data:Dictionary in global_class_list:
		var name = data.get("class")
		var base = data.get("base")
		var language = data.get("language")
		var is_tool = data.get("is_tool")
		var is_abstract = data.get("is_abstract")
		
		if show_tools and not is_tool:
			continue
		if show_abstract and not is_abstract:
			continue
		if target_language != language:
			continue
		#prints(target_base, base)
		if is_instance_valid(name_check):
			if not name_check.check_text(name):
				continue
		if is_instance_valid(base_check):
			if not base_check.check_text(base):
				continue
		
		print("")
		pr.append(name, UtilsRemote.EditorColors.get_syntax_color(UtilsRemote.EditorColors.SyntaxColor.USER_TYPE)).display()
		for key:String in data.keys():
			pr.append("\t" + str(key), Colors.SCOPE).append(": ").append(str(data[key])).display()
		
		


class TextCheck:
	
	var target_text_raw:String
	var _target_text:String
	
	var check_begin:bool
	var check_end:bool
	
	func _init(target_text:String) -> void:
		target_text_raw = target_text
		check_begin = target_text_raw.ends_with("*")
		check_end = target_text_raw.begins_with("*")
		_target_text = target_text_raw.trim_prefix("*").trim_suffix("*")
	
	func check_text(text:String):
		var valid_text = false
		if check_begin and check_end:
			valid_text = text.contains(_target_text)
		elif check_begin:
			valid_text = text.begins_with(_target_text)
		elif check_end:
			valid_text = text.ends_with(_target_text)
		else:
			valid_text = _target_text == text
		return valid_text
		
		
