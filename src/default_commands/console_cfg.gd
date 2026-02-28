extends EditorConsoleSingleton.ConsoleCommandBase

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
	var registered_commands = get_commands()
	if commands.size() == 1:
		return registered_commands
	
	var c_2 = commands[1]
	if c_2 == SCOPE_COMMAND:
		return _get_scope_completion(raw_text, commands, arguments)
	elif c_2 == GLOBAL_COMMAND:
		return _get_global_completion(raw_text, commands, arguments)
	
	var commands_obj = Commands.new()
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
	if commands.size() == 2 or UtilsLocal.check_help(commands):
		print(SCOPE_HELP.strip_edges() % _SCOPE_CMDS)
		return
	var c_3 = commands[2]
	var arg_size = arguments.size()
	if c_3 == REG_SCOPE:
		if arg_size != 2:
			UtilsLocal.pr_arg_size_err(2, arg_size)
			#printerr("Expected 2 arguments, received %s" % arg_size)
			return
		var scope_name = arguments[0]
		var script_path = arguments[1]
		EditorConsoleSingleton.register_persistent_scope(scope_name, script_path)
	elif c_3 == REG_SET:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var script_path = arguments[0]
		EditorConsoleSingleton.register_persistent_scope_set(script_path)
	elif c_3 == DEREG_SCOPE:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var scope_data = UtilsLocal.get_scope_data()
		var scopes = scope_data.get("scopes", {})
		var scope_name = arguments[0]
		if scope_name not in scopes.keys():
			print("Can't remove this command: %s" % scope_name)
		else:
			EditorConsoleSingleton.remove_persistent_scope(scope_name)
	elif c_3 == DEREG_SET:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var script_path = arguments[0]
		EditorConsoleSingleton.remove_persistent_scope_set(script_path)
	elif c_3 == RELOAD:
		var success = EditorConsoleSingleton.get_instance()._load_default_commands()
		if success:
			print("Reloaded command sets.")

static func _get_scope_completion(raw_text:String, commands:Array, _arguments:Array):
	var commands_obj = Commands.new()
	if commands.size() < 3:
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
			var scopes = scope_data.get(ScopeDataKeys.scopes, {})
			for scope_name in scopes.keys():
				commands_obj.add_command(scope_name)
			return commands_obj.get_commands()
		elif c_3 == DEREG_SET:
			var scope_data = UtilsLocal.get_scope_data()
			var sets = scope_data.get(ScopeDataKeys.sets, [])
			for path in sets:
				commands_obj.add_command(path)
			return commands_obj.get_commands()
	return commands_obj.get_commands()


static func _global(commands:Array, arguments:Array):
	if commands.size() == 2 or UtilsLocal.check_help(commands):
		print(GLOBAL_HELP % _GLOBAL_CMDS)
		return
	var c_3 = commands[2]
	var arg_size = arguments.size()
	if c_3 == GLOBAL_REG:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			return
		var desired_class = arguments[0]
		var global_class_list = UtilsLocal.get_global_class_list()
		if not desired_class in global_class_list:
			print("Class not in global class list: %s" % desired_class)
			return
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
		if desired_class in registered_classes:
			print("Class already registered: %s" % desired_class)
			return
		registered_classes.append(desired_class)
		scope_data[ScopeDataKeys.global_classes] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	elif c_3 == GLOBAL_DEREG:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			return
		var desired_class = arguments[0]
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
		if not desired_class in registered_classes:
			print("Class not registered: %s" % desired_class)
			return
		var idx = registered_classes.find(desired_class)
		registered_classes.remove_at(idx)
		scope_data[ScopeDataKeys.global_classes] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	

static func _get_global_completion(raw_text:String, commands:Array, _arguments:Array):
	var commands_obj = Commands.new()
	if commands.size() < 3:
		commands_obj.add_command(GLOBAL_REG, true)
		commands_obj.add_command(GLOBAL_DEREG, true)
		return commands_obj.get_commands()
	
	if not raw_text.find(" --") > -1:
		return commands_obj.get_commands()
	
	var c_3 = commands[2]
	var scope_data = UtilsLocal.get_scope_data()
	var global_classes = scope_data.get(ScopeDataKeys.global_classes, [])
	var global_class_list = UtilsLocal.get_global_class_list()
	for _class in global_class_list:
		if c_3 == GLOBAL_REG:
			if not _class in global_classes:
				commands_obj.add_command(_class)
		elif c_3 == GLOBAL_DEREG:
			if _class in global_classes:
				commands_obj.add_command(_class)
	return commands_obj.get_commands()

static func clear_console(commands:Array, _arguments:Array):
	if UtilsLocal.check_help(commands):
		print(CLEAR_HELP)
		return
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "--history":
			EditorConsoleSingleton.get_instance().previous_commands.clear()
	
	EditorConsoleSingleton.get_instance().clear_button.pressed.emit()
