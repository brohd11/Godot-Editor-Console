extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Get or set an editor setting (EditorSettings).
Usage: dev setting <name> [value]
  (no value)   print the current value
  <value>      set it (converted to the setting's current type)"

static func get_command_name() -> String:
	return "setting"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1,max:2",
	})

func _get_completions(ctx:CompletionContext):
	if not _positional_arg_index_valid():
		return {}
	var settings = EditorInterface.get_editor_settings()
	var options = Options.new()
	for p in settings.get_property_list():
		var name = p.get("name", "")
		if settings.has_setting(name):
			options.add_option(name, {&"trailing_char": " "})
	return options.get_options()

func _execute(ctx:CompletionContext):
	var settings = EditorInterface.get_editor_settings()
	var name = positional_args[0]
	if not settings.has_setting(name):
		ctx.append_error("No such editor setting: " + name)
		return ExitCode.FAIL

	if positional_args.size() == 1:
		ctx.append_output(str(settings.get_setting(name)))
		return

	var current = settings.get_setting(name)
	var converted = _convert_value(positional_args[1], current)
	settings.set_setting(name, converted)
	ctx.append_output("%s = %s" % [name, str(converted)])

func _convert_value(value_str:String, current):
	if current != null:
		var converted = ConsoleTokenizer.Var.auto_convert(value_str, typeof(current))
		if converted != null:
			return converted
	var parsed = str_to_var(value_str)
	if parsed != null:
		return parsed
	return value_str
