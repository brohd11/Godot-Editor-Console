extends EditorConsoleSingleton.ConsoleCommandBase

const ScopeDataKeys = UtilsLocal.ScopeDataKeys

const UClassDetail = UtilsRemote.UClassDetail

const SCOPE_COMMAND = "scope"

const REG_SCOPE = "reg-scope"
const REG_SET = "reg-set"
const DEREG_SCOPE = "dereg-scope"
const DEREG_SET = "dereg-set"
const RELOAD = "reload"

const GLOBAL_COMMAND = "global-class"

const GLOBAL_REG = "reg"
const GLOBAL_DEREG = "dereg"

func get_commands() -> Dictionary:
	var commands = Commands.new()
	commands.add_command(SCOPE_COMMAND, false, _scope)
	commands.add_command(GLOBAL_COMMAND, false, _global)
	return commands.get_commands()

const CFG_HELP = \
"Available commands:
	%s - manage registered commands
	%s - manage global classes that appear in autocomplete"

const _CFG_CMDS = [SCOPE_COMMAND, GLOBAL_COMMAND]

const SCOPE_HELP = \
"Manage commands available to the console.
	%s - register script -- <scope name, script path>
	%s - register script to be scanned for scopes and variables -- <script path>
	%s - deregister scope -- <scope name>
	%s - deregister set -- <script path>
	%s - reload scripts default and manually registered scopes"

const _SCOPE_CMDS = [REG_SCOPE, REG_SET, DEREG_SCOPE, DEREG_SET, RELOAD]

const GLOBAL_HELP = \
"Manage classes that will appear in autocomplete.
	%s - register class -- <class name>
	%s - deregister class -- <class name>"

const _GLOBAL_CMDS = [GLOBAL_REG, GLOBAL_DEREG]

const CLEAR_HELP = \
"Clear ouput text box.
	--history - Clear command history."

func get_help_message(_commands:Array, _arguments:Array):
	return CFG_HELP % _CFG_CMDS

func get_completion(completion_context:CompletionContext) -> Dictionary:
	var raw_text = completion_context.input_text
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	var commands_obj = Commands.new()
	var registered_commands = get_commands()
	var registered_command_names = registered_commands.keys()
	if not _check_command_index_valid(commands, 1, registered_command_names):
		if commands[0] == "clear":
			commands_obj.add_command("--history")
			return commands_obj.get_commands()
		return registered_commands
	
	var c_2 = commands[1]
	if c_2 == SCOPE_COMMAND:
		return _get_scope_completion(raw_text, commands, arguments)
	elif c_2 == GLOBAL_COMMAND:
		return _get_global_completion(raw_text, commands, arguments)
	
	
	return commands_obj.get_commands()

func parse(commands:Array, arguments:Array):
	if _display_help(commands, arguments):
		return
	var c_2 = commands[1]
	if c_2 == SCOPE_COMMAND:
		return _scope(commands, arguments)
	elif c_2 == GLOBAL_COMMAND:
		return _global(commands, arguments)

static func _scope(commands:Array, arguments:Array):
	if _has_help_command(commands, 2):
		print(SCOPE_HELP.strip_edges() % _SCOPE_CMDS)
		return
	var c_3 = commands[2]
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
		_unrecognized_command(c_3)

static func _get_scope_completion(raw_text:String, commands:Array, _arguments:Array):
	var commands_obj = Commands.new()
	if not _check_command_index_valid(commands, 2, [REG_SCOPE, REG_SET, DEREG_SCOPE, DEREG_SET, RELOAD]):
		commands_obj.add_command(REG_SCOPE, true)
		commands_obj.add_command(REG_SET, true)
		commands_obj.add_command(DEREG_SCOPE, true)
		commands_obj.add_command(DEREG_SET, true)
		commands_obj.add_command(RELOAD)
		return commands_obj.get_commands()
	
	var c_3 = commands[2]
	if raw_text.find(" --") > -1:
		if c_3 == DEREG_SCOPE:
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


static func _global(commands:Array, arguments:Array):
	if _has_help_command(commands, 2):
		print(GLOBAL_HELP % _GLOBAL_CMDS)
		return
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
	

static func _get_global_completion(raw_text:String, commands:Array, arguments:Array):
	var commands_obj = Commands.new()
	if not _check_command_index_valid(commands, 2, [GLOBAL_REG, GLOBAL_DEREG]):
	#if commands.size() < 3:
		commands_obj.add_command(GLOBAL_REG, true)
		commands_obj.add_command(GLOBAL_DEREG, true)
		return commands_obj.get_commands()
	
	if raw_text.find(Commands.ARG_DELIMITER) == -1:
		return {}
	
	var c_3 = commands[2]
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
	return commands_obj.get_commands()

static func clear_console(commands:Array, _arguments:Array): # this is a "parse" callable
	if _has_help_command(commands):
		print(CLEAR_HELP)
		return
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "--history":
			EditorConsoleSingleton.get_instance().previous_commands.clear()
	
	EditorConsoleSingleton.get_instance().clear_button.pressed.emit()
