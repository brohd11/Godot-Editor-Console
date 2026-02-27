extends EditorConsoleSingleton.ConsoleCommandBase

const UClassDetail = UtilsRemote.UClassDetail
const UNode = UtilsRemote.UNode
const PrintRich = UtilsRemote.UString.PrintRich

const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const ConsoleScript = UtilsLocal.ConsoleScript

const _CLASS_VALID_MSG = \
"Class valid: %s\n" + ConsoleScript.SCRIPT_HELP

func get_completion(raw_text, commands:Array, args:Array) -> Dictionary:
	if commands[0] != "global":
		commands.push_front("global")
	
	var commands_obj = Commands.new()
	var scope_data = UtilsLocal.get_scope_data()
	var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
	
	var global_classes = UClassDetail.get_all_global_class_paths()
	var valid_global_class_dict = {}
	for _name in global_classes:
		if _name not in registered_classes:
			continue
		valid_global_class_dict[_name] = global_classes.get(_name)
	
	var global_class_names = valid_global_class_dict.keys()
	var c_2
	var has_class = false
	var current_class_name = ""
	if commands.size() >= 2:
		c_2 = commands[1]
		if c_2 in global_class_names:
			has_class = true
			current_class_name = c_2
	
	if commands.size() <= 2 and not has_class:
		if c_2:
			for name in global_class_names:
				if name.to_lower().begins_with(c_2.to_lower()):
					var param = Commands.Params.new()
					param.replace_current_word = true
					commands_obj.add_command_with_params(name, param)
		else:
			for name in global_class_names:
				commands_obj.add_command(name)
		return commands_obj.get_commands()
	
	if not has_class:
		return {}
	
	var script = UClassDetail.get_global_class_script(current_class_name)
	if raw_text.find(" -- ") == -1:
		var script_commands = ConsoleScript.get_commands_static()
		for cmd in script_commands:
			if cmd in commands:
				return Commands.get_arg_delimiter()
		return ConsoleScript.get_valid_commands(commands, script_commands)
	
	var c_3 = commands[2]
	if args.size() == 0:
		var show_private = false
		if "--private" in commands or "-p" in commands:
			show_private = true
		if c_3 == ConsoleScript.CALL_COMMAND and raw_text.find(" --") > -1:
			return ConsoleScript.get_method_completions(script, args, show_private)
		elif c_3 == ConsoleScript.ARG_COMMAND and raw_text.find(" --") > -1:
			if args.size() == 0:
				return ConsoleScript.get_method_completions(script, args, show_private)
	
	if c_3 == ConsoleScript.LIST_COMMAND and raw_text.find(" --") > -1:
		return ConsoleScript.get_list_commands(args)
	
	if raw_text.find(" --") > -1:
		if UNode.has_static_method_compat("get_completion", script):
			return script.get_completion(raw_text, commands, args)
		else:
			return {}
	
	return commands_obj.get_commands()


func parse(commands:Array, arguments:Array):
	if _display_help(commands, arguments):
		return
	
	var c_1 = commands[0]
	if c_1 == "global":
		commands.remove_at(0)
	
	_call_standard_command(commands, arguments)

func get_commands() -> Dictionary:
	return ConsoleScript.get_commands_static()

func _get_standard_call_arguments(_selected_command:String, commands:Array, arguments:Array) -> Array:
	var global_class_name = commands[0]
	var global_class_script = UClassDetail.get_global_class_script(global_class_name)
	return ConsoleScript.get_standard_call_arguments_static(global_class_name, global_class_script, _selected_command, commands, arguments)


func _is_input_valid(commands:Array, arguments:Array) -> bool:
	var c_2 = commands[1]
	var global_classes = UClassDetail.get_all_global_class_paths()
	if not c_2 in global_classes:
		print("Could not find class: '%s'" % c_2)
		return false
	if commands.size() < 3:
		var pr = PrintRich.new()
		pr.append("Class valid: ").append(c_2, Color.WEB_GREEN).display().append(ConsoleScript.SCRIPT_HELP).display()
		
		return false
	
	return _is_command_valid(commands[2], commands, arguments)

func get_help_message(commands:Array, _arguments:Array):
	var c_1 = commands[0]
	if c_1 == "global":
		if commands.size() == 1:
			return "Hit ctrl + space to get global class list with 'global' command."
	
