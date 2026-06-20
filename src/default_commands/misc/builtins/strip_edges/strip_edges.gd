extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Strip edges of stdin."

var left_flag:= false
var right_flag:= false

static func get_command_name():
	return "strip_edges"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--left")
	options.add_option("--right")
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--left":
		left_flag = true
	elif flag == "--right":
		right_flag = true

func _execute(ctx:CompletionContext):
	if not (left_flag and right_flag):
		left_flag = true
		right_flag = true
	#ctx.stdout = ctx.stdin.strip_edges(left_flag, right_flag)

	ctx.append_output(ctx.stdin.strip_edges(left_flag, false))
	if right_flag:
		ctx.stdout = ctx.stdout.strip_edges(false, true)
