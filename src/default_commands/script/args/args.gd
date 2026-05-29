extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")


var show_private:=false

static func get_command_name() -> String:
	return "args"


static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "List arguments of method in target script\nUsage: script args <options> <method_name>",
		&"positional_count": 1,
		&"get_command": func(): return new(),
	})

func _get_flags():
	var options = Options.new()
	options.add_option("--private")
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--private":
		show_private = true

func _get_completions(ctx:CompletionContext):
	var flags = get_flags(true)
	
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, false, false)
	if not ctx.unconsumed_tokens.is_empty():
		var current_name = ctx.unconsumed_tokens.pop_front()
		if current_name in methods:
			return {}
	
	methods.merge(flags)
	return methods

func _execute(ctx:CompletionContext):
	var method_name = positional_args[0]
	var script = ScriptUtil.get_script_from_ctx(ctx)
	var methods = ScriptUtil.get_methods_from_ctx(ctx, show_private, false, false)
	if not method_name in methods:
		print("Unrecognized method: ", method_name)
		return ExitCode.FAIL
	
	list_args(script, method_name)
	return ExitCode.OK


static func list_args(script:Script, method_name:String):
	var property_info = UClassDetail.get_member_info_by_path(script, method_name)
	if property_info is not Dictionary:
		print("Could not get method '%s' in script: %s" % [method_name, script])
		return
	var args_array = property_info.get("args", [])
	if args_array.is_empty():
		print("No args to list.")
		return
	
	var class_name_color = EditorColors.get_syntax_color(EditorColors.SyntaxColor.BASE_TYPE)
	var pr = Pr.new()
	for dict in args_array:
		var name = dict.get("name")
		var type = type_string(dict.get("type"))
		var color = class_name_color
		if type == "Nil":
			color = Colors.VAR_RED
		pr.append(name + ":").append(type, color).append("  ")
	pr.display()
