extends EditorConsoleSingleton.CommandBase

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const CONSOLE_METHODS = ["parse", "get_completion", "execute", "complete"]

var show_private:=false
var create_default:= false

static func get_command_name() -> String:
	return "call"


static func get_self_option_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Call a static function in target script\nUsage: script call <options> <method> -- <...args>",
		&"positional_count": 1,
	})


func _get_flags():
	var commands = Commands.new()
	commands.add_command("--private")
	commands.add_command("--default")
	return commands.get_commands()

func _process_flag(flag:String):
	if flag == "--private":
		show_private = true
	elif flag == "--default":
		create_default = true

func _get_completions(ctx:CompletionContext):
	var flags = get_flags(true)
	
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, true)
	if not ctx.unconsumed_tokens.is_empty():
		var current_name = ctx.unconsumed_tokens.pop_front()
		if current_name in methods:
			return {}
	
	methods.merge(flags)
	return methods

func _execute(ctx:CompletionContext):
	if not _correct_positional_count(1):
		print(positional_args)
		return ExitCode.FAIL
	
	var method_name = positional_args[0]
	var script = ScriptUtil.get_script_from_ctx(ctx)
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, true)
	if not method_name in methods:
		print("Unrecognized method: ", method_name)
		return 1
	
	call_method(script, method_name, ctx.arguments)


func call_method(script:Script, method_name:String, args:Array):
	if not script.has_method(method_name):
		print("Static method '%s' not in script." % method_name)
		return
	var callable = script.get(method_name)
	_call_method(callable, args, create_default)


static func test(arg1:int):
	print("ARGS::", arg1)
	return "YER"
