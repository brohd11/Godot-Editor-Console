extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Toggle whether command output appears in the console as it is produced.
When on, a running command's output streams to the transcript line by line. When off,
nothing appears until the command finishes. Only affects display: piped output, `$(...)`,
redirected files and MCP bridge results are identical either way.
Usage:
  config stream           print current state
  config stream on|off    enable/disable streaming"

static func get_command_name() -> String:
	return "stream"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0,max:1",
	})

func _execute(ctx:Context):
	var inst = EditorConsoleSingleton.get_instance()
	if inst == null or not is_instance_valid(inst):
		ctx.append_error("Console singleton unavailable.")
		return ExitCode.FAIL

	if positional_args.is_empty():
		ctx.append_output("output streaming: %s" % _state_str(inst.stream_output))
		return ExitCode.OK

	match positional_args[0].to_lower():
		"on", "true", "1":
			inst.stream_output = true
		"off", "false", "0":
			inst.stream_output = false
		_:
			ctx.append_error("Expected 'on' or 'off', got '%s'." % positional_args[0])
			return ExitCode.FAIL

	ctx.append_output("output streaming: %s" % _state_str(inst.stream_output))
	return ExitCode.OK

func _state_str(on:bool) -> String:
	return "on" if on else "off"
