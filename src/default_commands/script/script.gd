extends EditorConsoleSingleton.CommandBase

const UString = UtilsRemote.UString
const UClassDetail = UtilsRemote.UClassDetail

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const Call = preload("res://addons/editor_console/src/default_commands/script/call/call.gd")
const List = preload("res://addons/editor_console/src/default_commands/script/list/list.gd")
const Args = preload("res://addons/editor_console/src/default_commands/script/args/args.gd")

const Infer = preload("res://addons/editor_console/src/default_commands/script/infer/infer.gd")

const _HELP = \
"Execute command on current script."

var script_access_path:String

static func get_command_name() -> String:
	return "script"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
	})

func _get_commands():
	var options = {}
	Options.add_command_script_to_dict(Infer, options)
	options.merge(get_commands_static())
	return options

func _consume_self(ctx:CompletionContext) -> ExitCode:
	script_access_path = _consume_token(ctx)
	ctx.data["script"] = ScriptUtil.resolve_access_path(script_access_path)
	return ExitCode.OK

func _get_completions(ctx:CompletionContext):
	var options = Options.new()
	if script_access_path == "script" and not ctx.input_text.left(ctx.caret_col).ends_with(script_access_path):
		return get_commands(true)
	options.merge(get_completion_static(self, ctx, script_access_path))
	return options.get_options()

static func get_completion_static(command_obj, ctx:CompletionContext, target_access_path): # command_obj not used, should be ok to remove?
	var options = Options.new()
	var cursor_on_access = ctx.input_text.left(ctx.caret_col).ends_with(target_access_path)
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
