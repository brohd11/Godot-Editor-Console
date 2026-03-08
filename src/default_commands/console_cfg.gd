extends EditorConsoleSingleton.ConsoleCommandBase

const UClassDetail = UtilsRemote.UClassDetail

const ScopeDataKeys = UtilsLocal.ScopeDataKeys

const SCOPE_COMMAND = "scope"

const REG_SCOPE = "reg-scope"
const REG_SET = "reg-set"
const DEREG_SCOPE = "dereg-scope"
const DEREG_SET = "dereg-set"
const RELOAD = "reload"

const GLOBAL_COMMAND = "global-class"

const GLOBAL_REG = "reg"
const GLOBAL_DEREG = "dereg"


const _CFG_CMDS = [SCOPE_COMMAND, GLOBAL_COMMAND]
const _SCOPE_CMDS = [REG_SCOPE, REG_SET, DEREG_SCOPE, DEREG_SET, RELOAD]
const _GLOBAL_CMDS = [GLOBAL_REG, GLOBAL_DEREG]

const CLEAR_HELP = \
"Clear output text box.
	--history - Clear command history."

const _HELP_DICT = {
	"config":{
		"c": _CFG_CMDS,
	},
	SCOPE_COMMAND:{
		"m":"Manage commands available to the console.",
		"c": _SCOPE_CMDS
	},
	REG_SCOPE: "register script -- <scope name, script path>",
	REG_SET: "register script to be scanned for scopes and variables -- <script path>",
	DEREG_SCOPE: "deregister scope -- <scope name>",
	DEREG_SET: "deregister set -- <script path>",
	RELOAD: "reload scripts default and manually registered scopes",
	
	GLOBAL_COMMAND:{
		"m":"Manage classes that will appear in autocomplete.",
		"c": _GLOBAL_CMDS
	},
	GLOBAL_REG: "register class -- <class name>",
	GLOBAL_DEREG: "deregister class -- <class name>",
	
}

func _get_help_dict():
	return _HELP_DICT



#func _is_input_valid(commands:Array, _arguments:Array) -> bool:
	#if not _check_command_index_valid(commands, 1, _CFG_CMDS):
		#return false
	#return _valid_sub_command(commands[1], commands)


#func _valid_sub_command(selected_command:String, commands:Array):
	#match selected_command:
		#SCOPE_COMMAND: return _check_command_index_valid(commands, 2, _SCOPE_CMDS)
		#GLOBAL_COMMAND: return _check_command_index_valid(commands, 2, _GLOBAL_CMDS)
	#return false


#func get_commands() -> Dictionary:
	#var commands = Commands.new()
	#commands.add_command(SCOPE_COMMAND, false, _scope)
	#commands.add_command(GLOBAL_COMMAND, false, _global)
	#return commands.get_commands()


func _get_valid_commands_for_index(completion_context:CompletionContext, cmd_idx:int) -> Dictionary:
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	
	var commands_obj = Commands.new()
	var current_command = commands[cmd_idx]
	match current_command:
		"clear": commands_obj.add_command("--history")
		"config":
			commands_obj.add_command(SCOPE_COMMAND)
			commands_obj.add_command(GLOBAL_COMMAND)
		SCOPE_COMMAND:
			for cmd_name in _SCOPE_CMDS:
				commands_obj.add_command(cmd_name, cmd_name != RELOAD)
		GLOBAL_COMMAND:
			for cmd_name in _GLOBAL_CMDS:
				commands_obj.add_command(cmd_name, true)
		_:
			if current_command in _SCOPE_CMDS:
				return _get_scope_completion(completion_context)
			elif current_command in _GLOBAL_CMDS:
				return _get_global_completion(completion_context)
	
	return commands_obj.get_commands()



static func _get_scope_completion(completion_context:CompletionContext):
	if not completion_context.has_arg_delimiter:
		return Commands.get_arg_delimiter_command()
	if completion_context.arguments.size() > 0:
		return {}
	
	var commands_obj = Commands.new()
	var c_3 = completion_context.commands[2]
	if c_3 == REG_SET or c_3 == REG_SCOPE:
		commands_obj.show_variables()
	elif c_3 == DEREG_SCOPE:
		var scope_data = UtilsLocal.get_scope_data()
		var scopes = scope_data.get(ScopeDataKeys.SCOPES, {})
		for scope_name in scopes.keys():
			commands_obj.add_command(scope_name)
		return commands_obj.get_commands()
	elif c_3 == DEREG_SET:
		var scope_data = UtilsLocal.get_scope_data()
		var sets = scope_data.get(ScopeDataKeys.SETS, [])
		for path in sets:
			commands_obj.add_command(path)
		return commands_obj.get_commands()
	return commands_obj.get_commands()

static func _get_global_completion(completion_context:CompletionContext):
	if not completion_context.has_arg_delimiter:
		return Commands.get_arg_delimiter_command()
	
	var arguments = completion_context.arguments
	var commands_obj = Commands.new()
	var c_3 = completion_context.commands[2]
	var scope_data = UtilsLocal.get_scope_data()
	var global_classes = scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])
	var global_class_list = UClassDetail.get_all_global_class_paths().keys()
	
	for _class in global_class_list:
		if _class in arguments:
			continue
		if c_3 == GLOBAL_REG:
			if not _class in global_classes:
				commands_obj.add_command(_class)
		elif c_3 == GLOBAL_DEREG:
			if _class in global_classes:
				commands_obj.add_command(_class)
	
	if c_3 == GLOBAL_DEREG:
		commands_obj.add_separator("No Global Class")
		for registered_class in global_classes:
			if registered_class in arguments:
				continue
			if not registered_class in global_class_list:
				commands_obj.add_command(registered_class)
			
	return commands_obj.get_commands()


func _command_requires_arguments(selected_command:String):
	if selected_command == RELOAD:
		return false
	return true

func parse(completion_context:CompletionContext):
	if _display_help(completion_context):
		return
	var c_2 = completion_context.commands[1]
	if c_2 == SCOPE_COMMAND:
		return _scope(completion_context)
	elif c_2 == GLOBAL_COMMAND:
		return _global(completion_context)

static func _scope(completion_context:CompletionContext):
	var arguments = completion_context.arguments
	var c_3 = completion_context.commands[2]
	if c_3 == REG_SCOPE:
		_call_method(EditorConsoleSingleton.register_persistent_scope, arguments)
	elif c_3 == REG_SET:
		_call_method(EditorConsoleSingleton.register_persistent_scope_set, arguments)
	elif c_3 == DEREG_SCOPE:
		_call_method(EditorConsoleSingleton.remove_persistent_scope, arguments)
	elif c_3 == DEREG_SET:
		_call_method(EditorConsoleSingleton.remove_persistent_scope_set, arguments)
	elif c_3 == RELOAD:
		var success = EditorConsoleSingleton.get_instance()._load_default_commands()
		if success:
			print("Reloaded command sets.")
	else:
		pass
		#_unrecognized_command(c_3)

static func _global(completion_context:CompletionContext):
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	var c_3 = commands[2]
	if c_3 == GLOBAL_REG:
		if arguments.is_empty():
			print("Provide global class names.")
			return
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])
		for desired_class in arguments:
			if UClassDetail.get_global_class_path(desired_class) == "":
				print("Class not in global class list: %s" % desired_class)
				continue
			if desired_class in registered_classes:
				print("Class already registered: %s" % desired_class)
				continue
			registered_classes.append(desired_class)
		scope_data[ScopeDataKeys.GLOBAL_CLASSES] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	elif c_3 == GLOBAL_DEREG:
		if arguments.is_empty():
			print("Provide global class names.")
			return
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])
		for desired_class in arguments:
			if not desired_class in registered_classes:
				print("Class not registered: %s" % desired_class)
				continue
			var idx = registered_classes.find(desired_class)
			registered_classes.remove_at(idx)
		scope_data[ScopeDataKeys.GLOBAL_CLASSES] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	else:
		_unrecognized_command(c_3)
	



static func clear_console(completion_context:CompletionContext): # this is a "parse" callable
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	
	if _has_help_command(commands, arguments):
		print(CLEAR_HELP)
		return
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "--history":
			EditorConsoleSingleton.get_instance().previous_commands.clear()
	
	EditorConsoleSingleton.get_instance().clear_button.pressed.emit()
