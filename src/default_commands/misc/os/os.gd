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
	if positional_args.is_empty():
		return {}
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

func _execute(ctx:CompletionContext):
	var editor_console = EditorConsoleSingleton.get_instance()
	if positional_args.is_empty():
		editor_console.toggle_os_mode()
		return ExitCode.OK
	
	#var output_temp_path:String
	#if ctx.input != "":
		## 1. Write the output to a temporary file in Godot's safe user folder
		#var _hash = UtilsRemote.UString.hash_string(ctx.input_text).left(8)
		#var tmp_path = "user://addons/editor_console/tmp/stdin_%s.txt" % _hash
		#DirAccess.make_dir_recursive_absolute(tmp_path.get_base_dir())
		#var file = FileAccess.open(tmp_path, FileAccess.WRITE)
		#file.store_string(ctx.input)
		#file.close()
		#
		#output_temp_path = ProjectSettings.globalize_path(tmp_path)
		#var has_pipe = false
		#for p in positional_args:
			#if p.contains("|"):
				#has_pipe = true
				#break
		#if has_pipe:
			#positional_args.push_front("cat '%s' |" % output_temp_path)
		#else:
			## Feed the file into the command via standard input (<)
			#positional_args.push_back("<")
			#positional_args.push_back("'%s'" % [output_temp_path])
	
	var command_needs_scan = false # not being set?
	
	var trimmed_command = editor_console.last_command.trim_prefix("os").strip_edges()
	if trimmed_command.is_empty():
		trimmed_command = "os"
	
	#if ctx.print and not ctx.chained_command:
		#print_rich("%s %s" % [editor_console.os_string, trimmed_command])
	
	var cwd_check = _check_dir_exists_shell(editor_console.os_cwd)
	if cwd_check == "" or not editor_console.os_cwd.is_absolute_path():
		if ctx.print:
			ctx.append_output_rich("Sanity check, resetting cwd.")
		editor_console.os_cwd = ProjectSettings.globalize_path("res://")
		return ExitCode.FAIL
	
	var result = [""]
	if positional_args[0] in EMULATED_COMMANDS:
		result = _emulated_command(positional_args, ctx)
	else:
		result = _execute_wrapper(positional_args, ctx)
	
	var std_out = result[0]
	ctx.append_output(std_out)
	if ctx.print:
		ctx.append_output_rich(std_out)
	
	if result.size() == 2:
		ctx.append_error(result[1])
	
	#if output_temp_path != "" and FileAccess.file_exists(output_temp_path):
		#DirAccess.remove_absolute(output_temp_path)
	
	if command_needs_scan:
		EditorInterface.get_resource_filesystem().scan()
	
	return ExitCode.OK


static func _execute_wrapper(commands:Array, ctx:CompletionContext=null):
	
	var editor_console = EditorConsoleSingleton.get_instance()
	
	
	
	print(commands)
	var combined = ""
	if ctx != null:
		combined = ctx.raw_text.trim_prefix("os").strip_escapes()
		print("RAW:", combined)
	else:
		for i in range(commands.size()):
			var tok = commands[i]
			if tok.contains(" "):
				var quote_char = "'"
				if UtilsRemote.UString.is_string_or_string_name(tok):
					quote_char = tok[0]
					tok = UtilsRemote.UString.unquote(tok)
				tok = ConsoleTokenizer.shell_quote(tok, quote_char)
				commands[i] = tok
			combined = " ".join(commands)
	
	
	#if ctx != null and ctx.input != "":
		#var tmp_in_path = "user://addons/editor_console/tmp/stdin.txt"
		#var output_temp_path = ProjectSettings.globalize_path(tmp_in_path)
		#tmp_file(output_temp_path, ctx.input)
		#output_temp_path = ConsoleTokenizer.shell_quote(output_temp_path)
		#
		#if combined.contains("|"):
			#combined = "cat %s | " % output_temp_path + combined
		#else:
			#combined = combined + " < %s" % output_temp_path
	#
	#
	#
	#var shell_exe = ""
	#var execute_commands = []
	#var os_name := OS.get_name()
	#var cwd := ConsoleTokenizer.shell_quote(editor_console.os_cwd)
	#var tmp_args := "user://addons/editor_console/tmp/args2.sh"
	#var tmp_args_path := ConsoleTokenizer.shell_quote(ProjectSettings.globalize_path(tmp_args))
	#var shell_command:String
	#if os_name == _OS_LINUX:
		#shell_exe = "bash"
		#shell_command = '[ -f ~/.bashrc ] && source ~/.bashrc; cd %s && %s' % [cwd, combined]
	#elif os_name == _OS_MAC:
		#shell_exe = "zsh"
		#shell_command = '[ -f ~/.zshrc ] && source ~/.zshrc; cd %s && %s' % [cwd, combined]
	#elif os_name == _OS_WIN:
		#shell_exe = "cmd.exe"
		#shell_command = 'cd "%s" && %s' % [cwd, combined]
		#execute_commands = ["/C", tmp_args_path]
	#
	#if shell_command.is_empty():
		#ctx.append_error("What os is this???")
		#return [""]
	#
	#
	
	
	
	var os_name := OS.get_name()
	var is_win := os_name == _OS_WIN

	# Quote for embedding INSIDE the script text only.
	var q := func(s: String) -> String:
		if is_win:
			return '"' + s + '"'                     # cmd: double quotes
		return ConsoleTokenizer.shell_quote(s)       # posix: single-quote

	# --- stdin redirect ---
	if ctx != null and ctx.input != "":
		var stdin_abs := ProjectSettings.globalize_path("user://addons/editor_console/tmp/stdin.txt")
		tmp_file(stdin_abs, ctx.input)
		var stdin_q = q.call(stdin_abs)
		if combined.contains("|"):
			var feeder := "type %s | " if is_win else "cat %s | "
			combined = (feeder % stdin_q) + combined
		else:
			combined = combined + " < %s" % stdin_q

	# --- script + executor ---
	var cwd_q = q.call(editor_console.os_cwd)
	var ext := "bat" if is_win else "sh"
	var tmp_args_abs := ProjectSettings.globalize_path(
		"user://addons/editor_console/tmp/args2.%s" % ext)   # RAW path for the args array

	var shell_exe := ""
	var args := []
	var shell_command := ""

	if os_name == _OS_LINUX:
		shell_exe = "bash"
		shell_command = '[ -f ~/.bashrc ] && source ~/.bashrc; cd %s && %s' % [cwd_q, combined]
		args = [tmp_args_abs]
	elif os_name == _OS_MAC:
		shell_exe = "zsh"
		shell_command = '[ -f ~/.zshrc ] && source ~/.zshrc; cd %s && %s' % [cwd_q, combined]
		args = [tmp_args_abs]
	elif is_win:
		shell_exe = "cmd.exe"
		shell_command = "@echo off\r\ncd /d %s\r\n%s" % [cwd_q, combined]
		args = ["/C", tmp_args_abs]
	else:
		ctx.append_error("What os is this???")
		return [""]

	tmp_file(tmp_args_abs, shell_command)
	var output := []
	var exit := OS.execute(shell_exe, args, output, true)

	if exit == -1:
		var command_string = " ".join(commands).strip_edges()
		var err_str = "Failed to execute: %s" % command_string
		if output.size() == 1:
			output.append(err_str)
		elif output.size() == 2:
			output[1] += "\n" + err_str
		#printerr("Failed to execute: %s" % command_string)
		" $HOME - not a variable"
	#if print_result:
		#var formatted_result = "\n".join(output).strip_edges(false, true)
		#if formatted_result != "":
			#print(formatted_result)
	
	
	
	
	
	
	
	return output



static func _emulated_command(commands:Array, ctx:CompletionContext) -> Array:
	var c_1 = commands[0]
	if c_1 == "ls":
		return _ls(commands, ctx)
	elif c_1 == "cd":
		return _cd(commands)
	
	return [""]

static func _ls(commands:Array, ctx:CompletionContext):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2.begins_with("--"):
			#_execute_wrapper(commands)
			return _execute_wrapper(commands)
	
	var result = _execute_wrapper(commands)
	if ctx.print and ctx.command_statements.size() == 1:
		result[0] = _one_line_result(result[0])
	return result
 
static func _cd(commands:Array):
	var editor_console = EditorConsoleSingleton.get_instance()
	var target_dir = ""
	if commands.size() == 1:
		target_dir = ProjectSettings.globalize_path("res://")
	elif commands.size() == 2:
		var c_2 = commands[1]
		if c_2.begins_with("-") or c_2.begins_with("--"):
			var result = _execute_wrapper(commands)
			return result
		
		target_dir = ProjectSettings.globalize_path(c_2)
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
			return ["", "Current working dir not valid, resetting to 'res://'"]
		if target_dir.begins_with("/"):
			return ["", "Directory does not exist: %s" % target_dir]
		else:
			return ["", "Directory does not exist: %s" % editor_console.os_cwd.path_join(target_dir)]
		
	return [""]


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

static func tmp_file(path:String, content:String):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)   # your exact string, no extra escaping
	f.close()
