extends EditorConsoleSingleton.CommandBase

const UNode = UtilsRemote.UNode

const _HELP = \
"Get nodes in the edited scene.
Usage: scene edited nodes <flags>"

var type_flag:=""
var inherited_flag:=false

var script_flag:=""

var selected_flag:=false

static func get_command_name():
	return "get_nodes"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--type=", {
		&"help": "Get nodes of type.",
		&"trailing_char": "",
	})
	options.add_option("--script=", {
		&"help": "Get nodes with script.",
		&"trailing_char": "",
	})
	options.add_option("--inherits", {
		&"help": "Check nodes inherit"
	})
	options.add_option("--selected", {
		&"help": ""
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag.begins_with("--type="):
		type_flag = _get_flag_value(flag)
	elif flag.begins_with("--script="):
		script_flag = _get_flag_value(flag)
		script_flag = UString.unquote(script_flag)
	elif flag == "--inherits":
		inherited_flag = true
	elif flag == "--selected":
		selected_flag = true


func _execute(ctx:CompletionContext):
	var edited_root = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(edited_root):
		return
	#var nodes = []
	#for c in edited_root.get_children():
		#nodes.append_array(UNode.recursive_get_nodes(c))
	
	var nodes = UNode.recursive_get_nodes(edited_root)
	
	var editor_selection = EditorInterface.get_selection()
	var sel_nodes = editor_selection.get_selected_nodes()
	
	if not script_flag.is_absolute_path():
		var global_check = UtilsRemote.UClassDetail.get_global_class_path(script_flag)
		if global_check != "":
			script_flag = global_check
	
	for n:Node in nodes:
		if type_flag != "":
			var cls = n.get_class()
			if inherited_flag:
				if not ClassDB.is_parent_class(cls, type_flag):
					continue
			else:
				if cls != type_flag:
					continue
		
		if script_flag != "":
			var script = n.get_script()
			if not is_instance_valid(script):
				continue
			if script.resource_path != script_flag:
				continue
		
		if selected_flag:
			if not n in sel_nodes:
				continue
		
		var path = edited_root.get_path_to(n)
		#path = edited_root.name.path_join(path)
		ctx.append_output(path)
