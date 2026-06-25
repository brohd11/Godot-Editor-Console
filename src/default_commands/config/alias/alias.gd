extends EditorConsoleSingleton.CommandBase

const Config = UtilsLocal.Config

const _HELP = \
"Manage aliases in .gdrc file.
Usage: config alias {--add, --rm} <alias_name> <alias_value>"

var add_flag:=false
var remove_flag:=false
var project_flag:=false

static func get_command_name():
	return "alias"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})
	
func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--add", {
		&"help": "Add an alias to .gdrc file"
	})
	options.add_option("--rm", {
		&"help": "Remove an alias from .gdrc file"
	})
	options.add_option("--project", {
		&"help": "Add to project overide file."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--add":
		add_flag = true
	elif flag == "--rm":
		remove_flag = true
	elif flag == "--project":
		project_flag = true

func _get_completions(ctx:CompletionContext):
	if positional_args.size() > 1 and positional_arg_index == 1:
		var pos_arg = positional_args[positional_arg_index]
		if add_flag and UString.is_string_or_string_name(pos_arg):
			return EditorConsoleSingleton.get_completion_for_input(positional_args[positional_arg_index], {
				&"require_quotes": true,
				&"inherited_ctx": ctx,
			})
	var options = Options.new()
	options.merge(get_commands())
	
	if positional_arg_index < 1:
		options.merge(get_flags(true))
		if add_flag or remove_flag:
			options.remove_option("--add")
			options.remove_option("--rm")
	
	if remove_flag and positional_arg_index < 1:
		var target_config = _get_target_config()
		var alias_data = target_config.get_section(Config.ALIAS)
		for a in alias_data.keys():
			options.add_option("/" + a)
	
	return options.get_options()

func _unwrap_quotes():
	return 0

func _get_target_positional_count() -> int:
	if add_flag:
		return 2
	elif remove_flag:
		return 1
	else:
		return 1

func _execute(ctx:CompletionContext):
	if add_flag and remove_flag:
		ctx.append_error("--add and --rm flags are mutually exclusive.")
		return ExitCode.FAIL
	
	var file_path = EditorConsoleSingleton.UtilsLocal.ConsoleOS.get_os_home_dir().path_join(".gdrc")
	if not FileAccess.file_exists(file_path):
		FileAccess.open(file_path, FileAccess.WRITE)
	
	
	var target_alias_name = positional_args[0].trim_prefix("/")
	
	var target_config:Config = _get_target_config()
	var alias_data:Dictionary = target_config.get_section(Config.ALIAS)
	var exists = alias_data.has(target_alias_name)
	
	if add_flag:
		if exists:
			ctx.append_error("Alias already exists: " + alias_data.get(target_alias_name))
			return ExitCode.FAIL
		
		var is_literal = false
		var value = positional_args[1]
		if UString.is_string_or_string_name(value):
			if value[0] == '"':
				value = UString.unquote(value)
			elif value[0] == "'":
				is_literal = true
				value = "@literal" + value
				
		alias_data[target_alias_name] = value
		target_config.write()
		
		if is_literal:
			target_config = _get_target_config()
			alias_data = target_config.get_section(Config.ALIAS)
			
			var reloaded = alias_data.get(target_alias_name)
			reloaded = ConsoleTokenizer.clean_alias_token(reloaded)
			ctx.append_output("Single quote wrapped string prefixed with '@literal' in yaml.\nContents will be requoted on de-serialization.")
			ctx.append_output(reloaded)
		
	elif remove_flag:
		if not exists:
			ctx.append_error("Alias doesn't exist: " + target_alias_name)
			return ExitCode.FAIL
		
		alias_data.erase(target_alias_name)
		target_config.write()
	else:
		if not exists:
			ctx.append_output("Alias doesn't exist: " + target_alias_name)
		else:
			ctx.append_output("Alias exists: " + alias_data.get(target_alias_name))

func _get_target_config() -> Config:
	if project_flag:
		return Config.get_project_config()
	else:
		return Config.get_global_config()
