const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const UClassDetail = UtilsRemote.UClassDetail

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer
const Options = UtilsLocal.Options
const CompletionContext = UtilsLocal.CompletionContext

const CONSOLE_METHODS = ["parse", "get_completion", "execute", "complete"]


static func resolve_access_path(access_path:String):
	var current_script = EditorInterface.get_script_editor().get_current_script()
	if access_path == "script":
		return current_script
	var front = UString.get_member_access_front(access_path)
	if front != "script":
		var global_script = UClassDetail.get_global_class_script(front)
		if global_script == null:
			return
		current_script = global_script
	
	if not access_path.contains("."):
		return current_script
	access_path = UString.trim_member_access_front(access_path)
	
	var final_script = current_script
	var parts = access_path.split(".", false)
	for i in range(parts.size()):
		var part = parts[i]
		var script_check = UClassDetail.get_member_info_by_path(final_script, part)
		if script_check != null:
			final_script = script_check
		else:
			if i != parts.size() - 1:
				return null
			break
	return final_script


static func get_methods_from_ctx(ctx:CompletionContext, show_private:bool, static_only:=false, hide_console_methods:=true):
	return get_method_completions(ctx.data.get("script"),  show_private, static_only, hide_console_methods)
	
static func get_method_completions(script:Script, show_private:bool, static_only:=false, hide_console_methods:=true):
	var options = Options.new()
	var method_list = script.get_script_method_list()
	
	for method in method_list:
		var name = method.get("name")
		if hide_console_methods and name in CONSOLE_METHODS:
			continue
		if not show_private:
			if name.begins_with("_"):
				continue
		if not static_only:
			options.add_option(name)
		else:
			var flags = method.get("flags")
			if flags & METHOD_FLAG_STATIC:
				options.add_option(name)
	
	return options.get_options()

static func get_script_from_ctx(ctx:CompletionContext):
	return ctx.data.get("script")
