extends EditorConsoleSingleton.CommandBase

const Config = UtilsLocal.Config


const _HELP = \
"This is a command created with the 'new' command, define help for this command!"

var add_flag:bool= false
var project_flag:bool = false

static func get_command_name():
	return "startup"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--add", {
		&"help": "Add startup command"
	})
	options.add_option("--project", {
		&"help": "Add to project config."
	})
	
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--add":
		add_flag = true
	if flag == "--project":
		project_flag = true

func _get_completions(ctx:CompletionContext):
	if positional_args.size() == 0:
		return get_flags(true)
	
	if positional_arg_index <= 0: # and positional_args.size() == 1:
		var cmd = positional_args[0]
		var options = EditorConsoleSingleton.get_completion_for_input(cmd, {
			&"require_quotes": true,
			&"show_flags": true
		})
		if not options.is_empty():
			return options
		
		return get_flags(true)
	return {}

func _get_target_positional_count() -> int:
	if add_flag:
		if positional_args.size() == 1 or positional_args.size() == 2:
			return positional_args.size()
	
	return 0

func _unwrap_quotes():
	return 0

func _execute(ctx:CompletionContext):
	if add_flag:
		var target_cfg = 2 if project_flag else 1
		var config = _get_config(target_cfg)
		var start_up_data = config.get_section(Config.STARTUP, [])
		var cmd = positional_args[0]
		if UString.is_string_or_string_name(cmd) and cmd[0] == '"':
			cmd = UString.unquote(cmd)
		start_up_data.append(cmd)
		config.write()
		#OS.shell_show_in_file_manager(config.file_path)
