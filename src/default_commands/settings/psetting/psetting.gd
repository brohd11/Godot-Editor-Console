extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Get or set a project setting (ProjectSettings).
Usage: settings psetting <name> [value]
  (no value)   print the current value
  <value>      set it (converted to the setting's current type) and save project.godot"

static func get_command_name() -> String:
	return "psetting"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1,max:2",
	})

func _execute(ctx:CompletionContext):
	var name = positional_args[0]

	if positional_args.size() == 1:
		if not ProjectSettings.has_setting(name):
			ctx.append_error("No such project setting: " + name)
			return ExitCode.FAIL
		ctx.append_output(str(ProjectSettings.get_setting(name)))
		return

	var current = ProjectSettings.get_setting(name, null)
	var converted = _convert_value(positional_args[1], current)
	ProjectSettings.set_setting(name, converted)
	var err = ProjectSettings.save()
	if err != OK:
		ctx.append_error("Saved setting but project.godot save failed (error %s)." % err)
		return ExitCode.FAIL
	ctx.append_output("%s = %s" % [name, str(converted)])

func _convert_value(value_str:String, current):
	var parsed = str_to_var(value_str)
	if parsed != null:
		return parsed
	return value_str
