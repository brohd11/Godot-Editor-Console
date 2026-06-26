extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail

const CommandScript = preload("res://addons/editor_console/src/default_commands/script/script.gd")
const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const _HELP = \
"Execute command on global script, or on global class data."

var global_access_path:String = ""

static func get_command_name() -> String:
	return "global"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP
	})

func _consume_self(ctx:CompletionContext) -> ExitCode:
	var class_nm = _consume_token(ctx)
	if class_nm == "global":
		if ctx.tokens_empty_and_execute():
			return ExitCode.HELP
		elif ctx.tokens_empty() or ctx.unconsumed_tokens.front() in get_commands():
			return ExitCode.OK
		
		class_nm = _consume_token(ctx)
	
	var script = ScriptUtil.resolve_access_path(class_nm)
	if script != null:
		global_access_path = class_nm
		ctx.data["script"] = script
	
	if ctx.tokens_empty_and_execute():
		return ExitCode.HELP
	return ExitCode.OK

func _get_help(what:String):
	if global_access_path != "":
		_ctx_obj.append_output(get_self_command_data().get(&"help"))
		print_available_commands()
	else:
		_ctx_obj.append_error("Unrecognized command: " + what)

func _get_commands() -> Dictionary:
	if global_access_path != "":
		return CommandScript.get_commands_static()
	
	return _get_commands_in_dir()


func _get_completions(ctx:CompletionContext):
	var config = UtilsLocal.Config.get_merged_config()
	var registered_classes = config.get_section(config.GLOBAL_CLASSES, [])
	var global_classes = UClassDetail.get_all_global_class_paths()
	var valid_global_class_dict = {}
	var invalid_global_class_dict = {}
	for _name in registered_classes:
		if global_classes.has(_name):
			valid_global_class_dict[_name] = true
		else:
			invalid_global_class_dict[_name] = true
	
	var current_class_name = ""
	if global_access_path != "": # has been set in _consume_self
		var global_class_name = UtilsRemote.UString.get_member_access_front(global_access_path)
		if UClassDetail.get_global_class_path(global_class_name) != "":# global_class_name in global_class_names:
			current_class_name = global_class_name
	
	if current_class_name != "":
		return CommandScript.get_completion_static(self, ctx, global_access_path)
	
	var options = Options.new()
	options.merge(_get_commands())
	options.add_separator("Registered")
	#for name in registered_classes:
		#options.add_option(name)
	for name in valid_global_class_dict.keys():
		options.add_option(name)
	for name in invalid_global_class_dict.keys():
		options.add_separator(name + "[Not in Global Space]", false)
	
	return options.get_options()
