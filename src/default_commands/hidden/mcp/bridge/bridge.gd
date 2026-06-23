extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Control the external command bridge (loopback TCP listener for the Go MCP server / CLI).
Off by default; binds 127.0.0.1 only.
Usage:
  dev bridge start [port] [token]   start listening (default port 9510)
  dev bridge stop                   stop listening
  dev bridge status                 show listening state
If a token is given, clients must send a matching token (GODOT_CONSOLE_TOKEN)."

static func get_command_name() -> String:
	return "bridge"

func _get_completions(ctx:CompletionContext):
	var options = Options.new()
	for opt in ["start", "stop", "status"]:
		if opt in positional_args:
			continue
		options.add_option(opt)
	
	return options.get_options()

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:1,max:3",
	})

func _execute(ctx:CompletionContext):
	var action = positional_args[0]
	match action:
		"start":
			var port := 9510
			if positional_args.size() > 1:
				port = positional_args[1].to_int()
			var token := ""
			if positional_args.size() > 2:
				token = positional_args[2]
			var err = EditorConsoleSingleton.ConsoleBridge.start_bridge(port, token)
			if err != OK:
				ctx.append_error("Failed to start bridge on port %s (error %s): %s" % [port, err, error_string(err)])
				return ExitCode.FAIL
			var suffix = " (token required)" if token != "" else ""
			ctx.append_output("Bridge listening on 127.0.0.1:%s%s" % [port, suffix])
		"stop":
			EditorConsoleSingleton.ConsoleBridge.stop_bridge()
			ctx.append_output("Bridge stopped.")
		"status":
			var s = EditorConsoleSingleton.ConsoleBridge.bridge_status()
			if s.get("listening", false):
				var suffix = " (token required)" if s.get("token", false) else ""
				ctx.append_output("Bridge listening on 127.0.0.1:%s%s" % [s.get("port"), suffix])
			else:
				ctx.append_output("Bridge not listening.")
		_:
			ctx.append_error("Unknown action '%s' (expected start|stop|status)." % action)
			return ExitCode.FAIL
