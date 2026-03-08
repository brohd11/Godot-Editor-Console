extends EditorConsoleSingleton.ConsoleCommandBase

const UClassDetail = UtilsRemote.UClassDetail
const UNode = UtilsRemote.UNode
const UString = UtilsRemote.UString

const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const ConsoleScript = UtilsLocal.ConsoleScript


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
	return ConsoleScript.get_commands_static()

func _get_standard_call_command_index(commands:Array, arguments:Array):
	return 1 # for this script, this makes it always choose the 2nd command for executing

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
	return ConsoleScript.get_completion_static(completion_context, get_commands(), script)


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
	var global_class_name = commands[0]
	var global_class_script = ConsoleScript.resolve_script_member_access(commands, arguments)
	return ConsoleScript.get_standard_call_arguments_static(global_class_name, global_class_script, _selected_command, commands, arguments)

func _command_requires_arguments(selected_command:String) -> bool:
	return true
