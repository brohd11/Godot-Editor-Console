extends EditorConsoleSingleton.CommandBase


const UClassDetail = UtilsRemote.UClassDetail

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const Call = preload("res://addons/editor_console/src/default_commands/script/call/call.gd")
const List = preload("res://addons/editor_console/src/default_commands/script/list/list.gd")
const Args = preload("res://addons/editor_console/src/default_commands/script/args/args.gd")

const Format = preload("res://addons/editor_console/src/default_commands/script/format/format.gd")

const _HELP = \
"Execute command on current script."

var script_access_path:String
var text_flag:=false

static func get_command_name() -> String:
	return "script"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
	})

func _get_commands():
	var options = {}
	if script_access_path == "script":
		Options.add_command_script_to_dict(Format, options)
	options.merge(get_commands_static())
	return options

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--text", {
		&"help": ""
	})
	options.add_option("--path=", {
		&"help": "",
		&"trailing_char": "",
		&"flag_completion": {"type": FlagType.FILE, "ext": ["gd"]},
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--text":
		text_flag = true
	elif flag.begins_with("--path="):
		var val = _get_flag_value(flag)
		_set_script_access_path(val)

func _consume_self(ctx:CompletionContext) -> ExitCode:
	script_access_path = _consume_token(ctx)
	if ctx.stdin != "":
		script_access_path = ctx.stdin.strip_edges()
	
	ctx.data["script"] = ScriptUtil.resolve_access_path(script_access_path)
	return ExitCode.OK

func _set_script_access_path(new_path:String):
	script_access_path = new_path
	_ctx_obj.data["script"] = ScriptUtil.resolve_access_path(script_access_path)

func _get_completions(ctx:CompletionContext):
	var options = Options.new()
	var flag_completion = _get_flag_type_completions(ctx)
	if flag_completion != null:
		return flag_completion
	
	if "--text" in consumed_tokens:
		return {}
	
	var cursor_on_access = ctx.token_before_cursor == script_access_path and ctx.char_before_cursor != " "
	#print(ctx.token_before_cursor)
	#print(cursor_on_access, ":", ctx.char_before_cursor,":")
	#print(ctx.word_before_cursor)
	if not cursor_on_access:
		var commands = get_commands(true)
		commands.merge(get_flags(true))
		if ctx.current_command_statement_index > 0:
			commands.erase("format") # assumes something piping in, remove format
		return commands
	options.merge(get_completion_static(self, ctx, script_access_path))
	return options.get_options()

static func get_completion_static(command_obj, ctx:CompletionContext, target_access_path): # command_obj not used, should be ok to remove?
	var options = Options.new()
	var cursor_on_access = ctx.token_before_cursor == target_access_path and ctx.char_before_cursor != " "
	
	var target_script = ScriptUtil.get_script_from_ctx(ctx)
	if not is_instance_valid(target_script):
		if not cursor_on_access:
			return {}
		var access_path = UString.trim_member_access_back(target_access_path)
		target_script = ScriptUtil.resolve_access_path(access_path)
	
	if is_instance_valid(target_script):
		if not cursor_on_access:
			return get_commands_static()
		else:
			var preloads = UClassDetail.script_get_preloads(target_script, false, true)
			for _name in preloads:
				options.add_option(_name, {&"trailing_char": ""})
			return options.get_options()
	return {}

static func get_commands_static():
	var opt = Options.new()
	for command in [Call, List, Args]:
		opt.add_command_script(command)
	return opt.get_options()

func _execute(ctx:CompletionContext):
	if text_flag:
		if script_access_path == "script":
			var current_editor = ScriptEditorRef.get_current_code_edit()
			ctx.stdout = current_editor.text
		else:
			var script = ScriptUtil.get_script_from_ctx(ctx)
			if is_instance_valid(script):
				ctx.stdout = script.source_code
			else:
				ctx.append_error("Could not get script: " + script_access_path)
		return ExitCode.OK
	
	_get_help_for_token(get_command_name())
