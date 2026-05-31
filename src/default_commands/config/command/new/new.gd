extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Create a new sub command for an existing command."

var register_flag:=false
var open_flag:= false

static func get_command_name() -> String:
	return "new"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 2
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--reg", {
		&"help": "Register the script as a scope after creation."
	})
	options.add_option("--edit", {
		&"help": "Edit the script on creation. Outside project files will be navigated to in file manager."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--reg":
		register_flag = true
	elif flag == "--edit":
		open_flag = true

func _get_completions(_ctx:CompletionContext):
	if positional_arg_index <= 0: # and positional_args.size() == 1:
		var path = ""
		if positional_args.size() > 0:
			path = positional_args[0]
		return EditorConsoleSingleton.get_completion_for_input(path, true, self)
		
		var first = path.get_slice(" ", 0)
		var console = EditorConsoleSingleton.get_instance()
		var scope_script = console.get_scope_script(first)
		if not is_instance_valid(scope_script):
			var options = Options.new()
			for s in console.scope_dict.keys():
				options.add_option(s)
			
			options.merge(get_flags(true))
			return options.get_options()
		var ins = scope_script.new()
		var new_ctx = CompletionContext.new(path)
		new_ctx.parse()
		var completion = ins.complete(new_ctx)
		for option in completion.keys():
			var data = completion[option]
			if not data.has(&"get_command"):
				completion.erase(option)
		return completion


func _execute(_ctx:CompletionContext):
	
	var new_command_name:String = positional_args[1]
	if new_command_name.get_extension() != "":
		new_command_name = new_command_name.get_basename()
	if not new_command_name.is_valid_filename():
		print("Not a valid file name: ", new_command_name)
		return
	
	var command_path:String = positional_args[0].strip_edges()
	var target_command_dir:String
	if command_path.is_absolute_path():
		target_command_dir = command_path
	else:
		target_command_dir = _get_new_command_dir()
	
	if target_command_dir == "":
		print("Could not get new command dir: ", command_path)
		return
	
	
	if DirAccess.dir_exists_absolute(target_command_dir):
		var dirs = DirAccess.get_directories_at(target_command_dir)
		for d in dirs:
			if d == new_command_name:
				print("Command already in directory.")
				print(target_command_dir)
				return
	
	var new_command_dir = target_command_dir.path_join(new_command_name)
	var new_command_path = new_command_dir.path_join(new_command_name + ".gd")
	
	DirAccess.make_dir_recursive_absolute(new_command_dir)
	var f = FileAccess.open(new_command_path, FileAccess.WRITE)
	
	var template = _get_template() % new_command_name
	f.store_string(template)
	f.close()
	
	EditorInterface.get_resource_filesystem().scan()
	
	if FileAccess.file_exists(new_command_path):
		print("New command created at: ", new_command_path)
		var new_script = load(new_command_path)
		if open_flag:
			if UtilsRemote.UFile.path_in_res(new_command_path):
				EditorInterface.edit_script(new_script)
			else:
				var globalized = ProjectSettings.globalize_path(new_command_path)
				OS.shell_show_in_file_manager(globalized)
		
		if register_flag:
			EditorConsoleSingleton.register_persistent_scope(new_command_name, new_command_path)


func _get_new_command_dir():
	var command_path:String = positional_args[0].strip_edges()
	var console = EditorConsoleSingleton.get_instance()
	
	var path_parts = [command_path]
	if command_path.contains(" "):
		path_parts = command_path.split(" ", false)
	
	var command_object = null
	var current_command = console.get_scope_script(path_parts[0])
	if current_command == null:
		print("Could not retrieve command: ", command_path)
		return
	
	command_object = current_command.new()
	path_parts.remove_at(0)
	
	for p in path_parts:
		var commands = command_object.get_commands()
		var next_command_data = commands.get(p)
		if next_command_data == null or not next_command_data.has(&"get_command"):
			print("Could not retrieve command: ", command_path)
			return
		
		var get_com_func = next_command_data[&"get_command"]
		var next_command_obj = get_com_func.call()
		if not is_instance_valid(next_command_obj):
			print("Could not retrieve command: ", command_path)
			return
		command_object = next_command_obj
	
	if not is_instance_valid(command_object):
		print("Could not resolve command object path: ", command_path)
		return
	
	var current_command_path = command_object.get_script().resource_path
	var command_dir = current_command_path.get_base_dir()
	return command_dir


func _get_template():
	return """extends EditorConsoleSingleton.CommandBase


const _HELP = \\
"This is a command created with the 'new' command, define help for this command!"

static func get_command_name():
	return "%s"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})
"""
