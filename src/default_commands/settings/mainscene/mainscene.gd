extends EditorConsoleSingleton.CommandBase

const _SETTING = "application/run/main_scene"

const _HELP = \
"Get or set the project's main scene.
Usage: dev mainscene [res://scene.tscn]
  (no arg)   print the current main scene path (pipe into 'dev open')
  <path>     set it and save project.godot"

static func get_command_name() -> String:
	return "mainscene"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _execute(ctx:CompletionContext):
	if positional_args.is_empty():
		var current = ProjectSettings.get_setting(_SETTING, "")
		if current == "":
			ctx.append_error("No main scene set.")
			return ExitCode.FAIL
		ctx.append_output(current)
		return

	var path = positional_args[0]
	if not FileAccess.file_exists(path):
		ctx.append_error("Scene does not exist: " + path)
		return ExitCode.FAIL
	ProjectSettings.set_setting(_SETTING, path)
	var err = ProjectSettings.save()
	if err != OK:
		ctx.append_error("project.godot save failed (error %s)." % err)
		return ExitCode.FAIL
	ctx.append_output("Main scene set to: " + path)
