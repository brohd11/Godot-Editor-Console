extends EditorConsoleSingleton.CommandBase

const UFile = UtilsRemote.UFile

const CDCmd = preload("res://addons/editor_console/src/default_commands/hidden/cd/cd.gd")

const _OS_LINUX = "Linux"
const _OS_MAC = "macOS"
const _OS_WIN = "Windows"

const EMULATED_COMMANDS = ["cd", "ls"]
const COMMAND_NEED_SCAN = ["rm", "mkdir", "touch"]

static func get_command_name() -> String:
	return "os"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "All commands after the 'os' prefix are ran via OS.execute with stdin if piped."
	})

static func get_os_user() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC: return OS.get_environment("USER")
		_OS_WIN: return OS.get_environment("USERNAME")
		_: return "user"

static func get_os_host() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC:
			var hostname = OS.get_environment("HOSTNAME").strip_edges()
			if hostname == "":
				var output = []
				var _exit = OS.execute("hostname",[], output)
				hostname = output[0].strip_edges()
				if hostname == "":
					if system == _OS_LINUX:
						hostname = "linux-pc"
					else:
						hostname = "mac"
			return hostname
		_OS_WIN:
			return OS.get_environment("COMPUTERNAME")
		_: return "Unrecongnized"

static func get_os_string():
	return "%s@%s" % [get_os_user(), get_os_host()]

static func get_os_home_dir() -> String:
	var system = OS.get_name()
	match system:
		_OS_LINUX, _OS_MAC: return OS.get_environment("HOME")
		_OS_WIN: return OS.get_environment("USERPROFILE")
		_: return "NO HOME"

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

func _get_completions(ctx:CompletionContext) -> Dictionary:
	#if positional_args.is_empty():
		#return _get_os_commands()
	if positional_args.is_empty():
		return {}
	var options = Options.new()
	if positional_args[0] == "cd":
		var split_args = positional_args.slice(1)
		return CDCmd.get_completion_static(ctx, split_args)
		#var target_dir = ctx.cwd
		#if positional_args.size() > 1:
			#var next_dir = positional_args[1]
			#if next_dir.ends_with("/"):
				#pass
			#elif next_dir.contains("/"):
				#next_dir = next_dir.get_base_dir()
			#else:
				#next_dir = ""
			#target_dir = target_dir.path_join(next_dir)
		#if not DirAccess.dir_exists_absolute(target_dir):
			#return {}
		#var dirs = DirAccess.get_directories_at(target_dir)
		#dirs = Array(dirs)
		#dirs.push_front("..")
		#for dir in dirs:
			#options.add_option(dir, {
				#&"trailing_char": "/"
			#})
	
	return options.get_options()


func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(ctx:CompletionContext):
	if positional_args.is_empty():
		return ExitCode.OK
	
	var command_needs_scan = false # not being set?
	
	var result = [""]
	if positional_args[0] in EMULATED_COMMANDS:
		if positional_args[0] == "cd":
			var split_args = positional_args.slice(1)
			return CDCmd.execute_static(ctx, split_args)
		
		result = _emulated_command(positional_args, ctx)
	else:
		result = _execute_wrapper(positional_args, ctx)
	
	var std_out = result[0]
	ctx.append_output(std_out)
	
	if result.size() == 2:
		ctx.append_error(result[1])
	
	
	if command_needs_scan:
		EditorInterface.get_resource_filesystem().scan()
	
	return ExitCode.OK


static func _execute_wrapper(commands:Array, ctx:CompletionContext=null):
	var combined = " ".join(commands)
	
	var os_name := OS.get_name()
	var is_win := os_name == _OS_WIN

	# Quote for embedding INSIDE the script text only.
	var q := func(s: String) -> String:
		if is_win:
			return '"' + s + '"'                     # cmd: double quotes
		return ConsoleTokenizer.shell_quote(s)       # posix: single-quote

	# stdin redirect
	if ctx != null and ctx.stdin != "":
		var stdin_abs := ProjectSettings.globalize_path("user://addons/editor_console/tmp/stdin.txt")
		tmp_file(stdin_abs, ctx.stdin)
		var stdin_q = q.call(stdin_abs)
		if combined.contains("|"):
			var feeder := "type %s | " if is_win else "cat %s | "
			combined = (feeder % stdin_q) + combined
		else:
			combined = combined + " < %s" % stdin_q

	# script + executor
	var cwd_q = q.call(ctx.cwd)
	var ext := "bat" if is_win else "sh"
	var tmp_args_abs := ProjectSettings.globalize_path(
		"user://addons/editor_console/tmp/args.%s" % ext)   # RAW path for the args array

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

	tmp_file(tmp_args_abs, shell_command) # no escaping for shell command
	var output := []
	var exit := OS.execute(shell_exe, args, output, true)

	if exit == -1:
		var command_string = " ".join(commands).strip_edges()
		var err_str = "Failed to execute: %s" % command_string
		if output.size() == 1:
			output.append(err_str)
		elif output.size() == 2:
			output[1] += "\n" + err_str
	
	
	return output


static func _emulated_command(commands:Array, ctx:CompletionContext) -> Array:
	var c_1 = commands[0]
	if c_1 == "ls":
		return _ls(commands, ctx)
	
	return [""]

static func _ls(commands:Array, ctx:CompletionContext):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2.begins_with("--"):
			#_execute_wrapper(commands)
			return _execute_wrapper(commands, ctx)
	
	var result = _execute_wrapper(commands, ctx)
	if ctx.command_statements.size() == 1:
		result[0] = _one_line_result(result[0])
	return result
 

static func _one_line_result(result_string):
	var one_line = result_string.replace("\n", "  ").strip_edges()
	return one_line

static func tmp_file(path:String, content:String):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
