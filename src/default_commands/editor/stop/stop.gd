extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Stop the running project.
Usage: stop"

static func get_command_name() -> String:
	return "stop"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:CompletionContext):
	if not EditorInterface.is_playing_scene():
		ctx.append_output("No scene is currently playing.")
		return
	EditorInterface.stop_playing_scene()
	ctx.append_output("Stopped playing scene.")
