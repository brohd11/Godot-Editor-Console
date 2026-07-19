extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Discards stdout of previous command."

var out_flag:=false
var err_flag:=false

static func get_command_name():
	return "discard"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

#func _get_flags() -> Dictionary:
	#var options = Options.new()
	#options.add_option("--out", {
		#&"help": "Discards stdout."
	#})
	#options.add_option("--err", {
		#&"help": "Discards stderr."
	#})
	#return options.get_options()

func _process_flag(flag:String):
	if flag == "--out":
		out_flag = true
	elif flag == "--err":
		err_flag = true

func _execute(_ctx:CompletionContext):
	return
	#var both = (err_flag and out_flag) or not (err_flag and out_flag)
	#if both:
		#return
	#elif out_flag:
		#pass
