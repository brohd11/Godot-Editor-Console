extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Run a gdsh script file in a subprocess.
Usage: run_gdsh <res://script.gdsh>"

static func get_command_name():
	return "run_gdsh"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_completions(ctx:CompletionContext):
	if positional_arg_index < 1:
		var extensions = ["txt", "gdsh", ""]
		var completions = EditorConsoleSingleton.get_file_paths()
		var options = Options.new()
		for c in completions:
			if c.get_extension() in extensions:
				options.add_option(c)
		
		return options.get_options()
	
	return {}

func _execute(ctx:CompletionContext):
	var file_path = positional_args[0]
	var out = EditorConsoleSingleton.run_gdsh(file_path)
	ctx.stdout = out.stdout
	ctx.stderr = out.stderr
	ctx.exit_code = out.exit_code
