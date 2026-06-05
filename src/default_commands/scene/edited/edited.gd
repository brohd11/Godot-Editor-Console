extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Commands related to current edited scene."

var tree_flag:=false

static func get_command_name():
	return "edited"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--tree", {
		&"help": ""
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--tree":
		tree_flag = true


func _execute(ctx:CompletionContext):
	if tree_flag:
		var edited_root = EditorInterface.get_edited_scene_root()
		if not is_instance_valid(edited_root):
			return
		var nodes = []
		for c in edited_root.get_children():
			nodes.append_array(ALibRuntime.Utils.UNode.recursive_get_nodes(c))
		
		for n:Node in nodes:
			var path = edited_root.get_path_to(n)
			path = edited_root.name.path_join(path)
			ctx.append_output(path)
