extends "res://addons/addon_lib/gdsh/command_base.gd"
## GDSh command base with editor-only authoring helpers.
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UString = UtilsRemote.UString
const Pr = UtilsRemote.Pr
const ConsoleUndo = UtilsLocal.ConsoleUndo
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
	
	# Checks, conversion, and defaults are GDSh's; the editor supplies the current script
	# for Script parameters and reports the result.
	var outcome = Utils.Method.call_method(ctx, callable.get_object(), callable.get_method(), args,
			create_default_args, func(class_name_:String): return _editor_object_default(class_name_))
	if not outcome.ok:
		return false
	var result = outcome.result
	if result != null and not (result is Object and result.get_class() in _RESULTS_TO_SKIP):
		ctx.append_output("GDScript Method Call:")
		ctx.append_output(str(result))
	return true

static func _editor_object_default(class_name_:String):
	if class_name_ in ["GDScript", "Script"]:
		return EditorInterface.get_script_editor().get_current_script()
	return null


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
