extends EditorConsoleSingleton.CommandBase


const _HELP = \
"echo, similar to standard shell command."

var function_name:String

static func get_command_name():
	return "echo"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})


func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(ctx:CompletionContext):
	var string = ""
	for i in range(positional_args.size()):
		var p = positional_args[i]
		string += p
		if i < positional_args.size() - 1:
			string += " "
	
	ctx.append_output(string)
		
