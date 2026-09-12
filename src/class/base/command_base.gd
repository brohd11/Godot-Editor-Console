extends "res://addons/addon_lib/gdsh/command_base.gd"
## GDSh command base with editor-only authoring helpers.
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UString = UtilsRemote.UString
const Pr = UtilsRemote.Pr
const ConsoleUndo = UtilsLocal.ConsoleUndo
const Value = preload("res://addons/editor_console/src/utils/value_conversion.gd")
const Colors = UtilsLocal.Colors
const _RESULTS_TO_SKIP = ["GDScriptFunctionState"]

static func _call_method(ctx:Context, callable:Callable, args:Array, create_default_args:=false):
	# convert variables to $VAR
	var editor_console = EditorConsoleSingleton.get_instance() if EditorConsoleSingleton.instance_valid() else null
	for i in range(args.size()):
		var arg_str = args[i]
		if is_instance_valid(editor_console):
			args[i] = editor_console.working_variable_dict.get(arg_str, arg_str)
	# end
	
	var callable_arg_count = callable.get_argument_count()
	if args.size() != callable_arg_count:
		if not create_default_args:
			ctx.append_error("Arg count mismatch: %s - expected %s, got %s" % [callable.get_method(), callable_arg_count, args.size()])
			return
		
	var obj = callable.get_object()
	var script = obj
	if not obj is GDScript:
		script = obj.get_script()
	
	var method_name = callable.get_method()
	var property_info = UtilsRemote.UClassDetail.get_member_info_by_path(script, method_name)
	if not (property_info is Dictionary and property_info.has("args")):
		ctx.append_error("Could not get method '%s' info in object: %s" % [method_name, obj])
		return
	var valid_args = true
	var callable_args = property_info.get("args")
	if create_default_args or args.size() == callable_arg_count:
		var default_args = property_info.get("default_args", []) as Array
		for i in range(callable_args.size() - default_args.size()):
			default_args.push_front(null)
		var new_args = []
		for i in range(callable_args.size()):
			var arg_data = callable_args[i]
			var type:int = arg_data.get("type")
			if i < args.size():
				var passed = args[i]
				if type > 0 and typeof(passed) != type:
					var err:= true
					var pass_str = type_string(typeof(passed))
					if type != TYPE_OBJECT:
						var converted = Value.Var.auto_convert(passed, type)
						if converted != null:
							args[i] = converted
							ctx.append_output("Arg '%s' conversion: %s %s -> %s %s" % [arg_data.get("name"), pass_str, passed, type_string(type), converted])
							err = false
					if err:
						ctx.append_error("Arg '%s' type mismatch: %s passed, should be %s" % [arg_data.get("name"), pass_str, type_string(type)])
						valid_args = false
				continue
			
			var default_val = default_args[i]
			if default_val != null:
				new_args.append(default_val)
				continue
			if arg_data.get("class_name") != "":
				var _class = arg_data.get("class_name")
				if _class == "GDScript" or _class == "Script":
					new_args.append(EditorInterface.get_script_editor().get_current_script())
				continue
			else:
				var variant = type_convert(null, type)
				new_args.append(variant)
		
		if args.size() + new_args.size() != callable_arg_count:
			var err_pr = Pr.new()
			err_pr.append("Could not create default args for method ", Colors.ERROR_RED).append("'%s'" % method_name)\
			.append(" in object: ", Colors.ERROR_RED).append(obj)
			ctx.append_error(err_pr.get_raw_string())
			ctx.append_output(err_pr.get_string(true))
			
			err_pr.append("Passed: ").append("%s" % [args], Colors.ACCENT_MUTE).append(" Created:").append("%s" % [new_args], Colors.ACCENT_MUTE)
			ctx.append_error(err_pr.get_raw_string())
			ctx.append_output(err_pr.get_string(true))
			
			
			Pr.new().append("Could not create default args for method ", Colors.ERROR_RED).append("'%s'" % method_name)\
			.append(" in object: ", Colors.ERROR_RED).append(obj).display()
			Pr.new().append("Passed: ").append("%s" % [args], Colors.ACCENT_MUTE).append(" Created:").append("%s" % [new_args], Colors.ACCENT_MUTE).display()
			return
		
		args.append_array(new_args)
	
	if not valid_args:
		ctx.append_error("Invalid arguments")
		return
	var result = callable.callv(args)
	if result != null:
		if result is Object:
			if result.get_class() in _RESULTS_TO_SKIP:
				return
		ctx.append_output("GDScript Method Call:")
		ctx.append_output(str(result))


func _get_config(type:int=0):
	if type == 0:
		return UtilsLocal.Config.get_merged_config()
	elif type == 1:
		return UtilsLocal.Config.get_global_config()
	elif type == 2:
		return UtilsLocal.Config.get_project_config()
	else:
		_ctx_obj.append_error("Unrecognized config type: %s; 0=Merged, 1=Global, 2=Project\nReturning merged data.")
		return UtilsLocal.Config.get_merged_config()
