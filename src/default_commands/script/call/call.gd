extends EditorConsoleSingleton.CommandBase

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const CONSOLE_METHODS = ["parse", "get_completion", "execute", "complete"]

var show_private:=false
var create_default:= false

static func get_command_name() -> String:
	return "call"


static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Call a static function in target script\nUsage: script call <options> <method> -- <...args>",
		&"positional_count": 1,
	})


func _get_flags():
	var options = Options.new()
	options.add_option("--private", {
		&"help": "Display private members during autocompletion."
	})
	options.add_option("--default", {
		&"help": "Create default value arguments when calling the GDScript method."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--private":
		show_private = true
	elif flag == "--default":
		create_default = true

func _get_completions(ctx:CompletionContext):
	if ctx.in_arguments():
		var dict = {} # possibly add something to check arg types?
		Options.add_show_variables_to_dict(dict)
		return dict
	
	if not _positional_arg_index_valid():
		return {}
	
	if not is_instance_valid(ScriptUtil.get_script_from_ctx(ctx)):
		return {}
	
	var flags = get_flags(true)
	
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, true)
	if not ctx.unconsumed_tokens.is_empty():
		var current_name = ctx.unconsumed_tokens.pop_front()
		if current_name in methods:
			return {}
	
	for m in methods.keys():
		var meta = methods[m].get_or_add(Options.Keys.METADATA, {})
		if meta.get(Options.Keys.ARG_COUNT, 0) > 0:
			meta[Options.Keys.ADD_ARGS] = true
	
	methods.merge(flags)
	
	
	
	return methods

func _execute(ctx:CompletionContext):
	var method_name = positional_args[0]
	var script = ScriptUtil.get_script_from_ctx(ctx)
	if not is_instance_valid(script):
		ctx.append_error("Could not get script.")
		return ExitCode.FAIL
	
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, true)
	if not method_name in methods:
		ctx.append_error("Unrecognized method: " + method_name)
		return ExitCode.FAIL
	
	return call_method(ctx, script, method_name)


func call_method(ctx:CompletionContext, script:Script, method_name:String):
	if not script.has_method(method_name):
		ctx.append_error("Static method '%s' not in script." % method_name)
		return ExitCode.ERR
	var callable = script.get(method_name)
	_call_method(ctx, callable, ctx.arguments, create_default)
	return ExitCode.OK
