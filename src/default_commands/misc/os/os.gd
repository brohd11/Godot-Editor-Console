extends EditorConsoleSingleton.CommandBase

const UFile = UtilsRemote.UFile

const _OS_LINUX = "Linux"
const _OS_MAC = "macOS"
const _OS_WIN = "Windows"

const EMULATED_COMMANDS = ["cd", "ls"]
const COMMAND_NEED_SCAN = ["rm", "mkdir", "touch"]

static func get_command_name() -> String:
	return "os"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": ""
	})

static func get_os_string():
	var system = OS.get_name()
	if system == _OS_LINUX:
		var user = OS.get_environment("USER")
		var hostname = OS.get_environment("HOSTNAME")
		hostname = hostname.strip_edges()
		if hostname == "":
			var output = []
			var _exit = OS.execute("hostname",[], output)
			hostname = output[0].strip_edges()
			if hostname == "":
				hostname = "linux-pc"
		return "%s@%s" % [user, hostname]
		
	elif system == _OS_WIN:
		var user = OS.get_environment("USERNAME")
		var hostname = OS.get_environment("COMPUTERNAME")
		return "%s@%s" % [user, hostname]
	elif system == _OS_MAC:
		var user = OS.get_environment("USER")
		var hostname = OS.get_environment("HOSTNAME")
		hostname = hostname.strip_edges()
		if hostname == "":
			var output = []
			var _exit = OS.execute("hostname", [], output)
			hostname = output[0].strip_edges()
			if hostname == "":
				hostname = "mac"
		return "%s@%s" % [user, hostname]

static func get_os_home_dir():
	var system = OS.get_name()
	if system == _OS_LINUX:
		var home = OS.get_environment("HOME")
		return home
	elif system == _OS_MAC:
		var home = OS.get_environment("HOME")
		return home
	elif system == _OS_WIN:
		var home = OS.get_environment("USERPROFILE")
		return home

func _get_commands() -> Dictionary:
	return {}

func _get_os_commands() -> Dictionary:
	var options:Options = Options.new()
	for cmd:String in EMULATED_COMMANDS:
		options.add_option(cmd)
	#for cmd in COMMAND_NEED_SCAN: # Hiding these for now
		#commands_obj.add_option(cmd)
	return options.get_options()

func _consume_self(ctx:CompletionContext) -> ExitCode:
	consumed_tokens.append(_consume_token(ctx))
	while not ctx.unconsumed_tokens.is_empty():
		positional_args.append(_consume_token(ctx))
	return ExitCode.OK

func _get_help(_what:String):
	pass

func _get_completions(_ctx:CompletionContext) -> Dictionary:
	if not EditorConsoleSingleton.get_instance().os_mode:
		return {}
	
	#if positional_args.is_empty():
		#return _get_os_commands()
	
	var options = Options.new()
	if positional_args[0] == "cd":
		var target_dir = EditorConsoleSingleton.get_instance().os_cwd
		if positional_args.size() > 1:
			var next_dir = positional_args[1]
			if next_dir.ends_with("/"):
				pass
			elif next_dir.contains("/"):
				next_dir = next_dir.get_base_dir()
			else:
				next_dir = ""
			target_dir = target_dir.path_join(next_dir)
		if not DirAccess.dir_exists_absolute(target_dir):
			return {}
		var dirs = DirAccess.get_directories_at(target_dir)
		dirs = Array(dirs)
		dirs.push_front("..")
		for dir in dirs:
			options.add_option(dir, {
				&"trailing_char": "/"
			})
	
	return options.get_options()


func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(_ctx:CompletionContext):
	var editor_console = EditorConsoleSingleton.get_instance()
	if positional_args.is_empty():
		editor_console.toggle_os_mode()
		return ExitCode.OK
	
	var command_needs_scan = false # not being set?
	
	var trimmed_command = editor_console.last_command.trim_prefix("os").strip_edges()
	if trimmed_command.is_empty():
		trimmed_command = "os"
	print_rich("%s %s" % [editor_console.os_string, trimmed_command])
	
	var cwd_check = _check_dir_exists_shell(editor_console.os_cwd)
	if cwd_check == "" or not editor_console.os_cwd.is_absolute_path():
		print("Sanity check, resetting cwd.")
		editor_console.os_cwd = ProjectSettings.globalize_path("res://")
		return [""]
	
	var result
	if positional_args[0] in EMULATED_COMMANDS:
		result = _emulated_command(positional_args)
	else:
		result = _execute_wrapper(positional_args)
	
	var formatted_result = "\n".join(result).strip_edges()
	if formatted_result != "":
		print(formatted_result)
	
	if command_needs_scan:
		EditorInterface.get_resource_filesystem().scan()


static func _execute_wrapper(commands:Array, print_result:=false):
	
	var editor_console = EditorConsoleSingleton.get_instance()
	
	#print(commands)
	#for i in range(commands.size()):
		#var c = commands[i]
		#if c.contains(" "):
			#commands[i] = "'" + c + "'"
	
	#print(commands)
	var combined = " ".join(commands)
	#print(combined)
	var shell_exe = ""
	var execute_commands = []
	var os_name = OS.get_name()
	if os_name == _OS_LINUX:
		shell_exe = "bash"
		var shell_command = 'cd "%s" && %s' % [editor_console.os_cwd, combined]
		execute_commands = ["-c", shell_command]
	elif os_name == _OS_MAC:
		shell_exe = "zsh"
		var shell_command = 'cd "%s" && %s' % [editor_console.os_cwd, combined]
		execute_commands = ["-c", shell_command]
	elif os_name == _OS_WIN:
		shell_exe = "cmd.exe"
		var shell_command = 'cd "%s" && %s' % [editor_console.os_cwd, combined]
		execute_commands = ["/C", shell_command]
	
	
	var output = []
	var exit = OS.execute(shell_exe, execute_commands, output, true)
	if exit == -1:
		var command_string = " ".join(commands).strip_edges()
		printerr("Failed to execute: %s" % command_string)
	if print_result:
		var formatted_result = "\n".join(output).strip_edges()
		if formatted_result != "":
			print(formatted_result)
	
	return output


static func _emulated_command(commands:Array) -> Array:
	var c_1 = commands[0]
	if c_1 == "ls":
		return _ls(commands)
	elif c_1 == "cd":
		return _cd(commands)
	
	return [""]

static func _ls(commands:Array):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2.begins_with("--"):
			_execute_wrapper(commands)
			return [_execute_wrapper(commands)[0]]
	var result = _execute_wrapper(commands)
	var result_string:String = result[0]
	return [_one_line_result(result_string)]
 
static func _cd(commands:Array):
	var editor_console = EditorConsoleSingleton.get_instance()
	if commands.size() == 1:
		_execute_wrapper(commands, true)
		return [""]
	var c_2 = commands[1]
	if c_2.begins_with("--"):
		_execute_wrapper(commands, true)
		return [""]
	
	var target_dir = ProjectSettings.globalize_path(c_2)
	#var global_res = ProjectSettings.globalize_path("res://")
	if c_2.begins_with("..") or c_2.begins_with("."):
		target_dir = editor_console.os_cwd.path_join(c_2)
		target_dir = target_dir.simplify_path()
	
	var dir_exists = _check_dir_exists_shell(target_dir)
	if dir_exists:
		if not dir_exists.ends_with("/"):
			dir_exists += "/"
		editor_console.os_cwd = dir_exists
	else:
		var check_cwd = _check_dir_exists_shell(editor_console.os_cwd)
		if not check_cwd:
			editor_console.os_cwd = "res://"
			print("Current working dir not valid, resetting to 'res://'")
		if target_dir.begins_with("/"):
			return ["Directory does not exist: %s" % c_2]
		else:
			return ["Directory does not exist: %s" % editor_console.os_cwd.path_join(c_2)]
		
	return [""]

#static func _check_dir_exists_shell(dir):
	#var check_dir_command = []
	#var os_name = OS.get_name()
	#if os_name == _OS_LINUX or os_name == _OS_MAC:
		#check_dir_command = ["test -d '%s' && echo 'true' || echo 'false'" % dir]
	#elif os_name == _OS_WIN:
		#check_dir_command = ["if exist \"%s\" (echo true) else (echo false)" % dir]
	#var result = _execute_wrapper(check_dir_command)
	#return result[0].strip_edges() == "true"

static func _check_dir_exists_shell(dir):
	var check_dir_command = []
	var os_name = OS.get_name()
	if os_name == _OS_LINUX or os_name == _OS_MAC:
		check_dir_command = ['test -d "%s" && realpath "%s"' % [dir, dir]]
	elif os_name == _OS_WIN:
		check_dir_command = ["if exist \"%s\" (echo true) else (echo false)" % dir]
	var result = _execute_wrapper(check_dir_command)
	return result[0].strip_edges()

static func _one_line_result(result_string):
	var one_line = result_string.replace("\n", "  ").strip_edges()
	return one_line
