extends EditorConsoleSingleton.CommandBase

const _HELP = \
"Move files/directories to the OS trash (recoverable).
Paths come from arguments and/or stdin (one per line).
Usage: trash [res://path ...]"

static func get_command_name() -> String:
	return "trash"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _get_target_positional_count() -> int:
	return positional_args.size()

func _execute(ctx:CompletionContext):
	var paths := []
	paths.append_array(positional_args)
	if ctx.stdin.strip_edges() != "":
		for line in ctx.stdin.split("\n", false):
			var p = line.strip_edges()
			if p != "":
				paths.append(p)

	if paths.is_empty():
		ctx.append_error("No paths to trash (argument or stdin).")
		return ExitCode.FAIL

	var count := 0
	for path in paths:
		if not (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)):
			ctx.append_error("Path does not exist: " + path)
			continue
		var err = OS.move_to_trash(ProjectSettings.globalize_path(path))
		if err != OK:
			ctx.append_error("Could not trash (error %s): %s" % [err, path])
			continue
		count += 1

	if count > 0:
		EditorInterface.get_resource_filesystem().scan()
	ctx.append_output("Moved %s item(s) to trash." % count)
