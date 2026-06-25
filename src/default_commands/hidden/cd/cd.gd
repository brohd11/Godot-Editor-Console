extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Change directory in console or os mode.
Usage: cd <rel or abs path>"

static func get_command_name():
	return "cd"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})

func _get_completions(ctx:CompletionContext) -> Dictionary:
	return get_completion_static(ctx, positional_args)

static func get_completion_static(ctx:CompletionContext, pos_args:Array) -> Dictionary:
	var options = Options.new()
	var current_dir = ctx.cwd
	var target_dir = ctx.cwd
	
	if pos_args.size() == 1:
		var next_dir = pos_args[0]
		if next_dir.is_absolute_path():
			target_dir = next_dir
		else:
			target_dir = target_dir.path_join(next_dir)
	
		if target_dir.ends_with("/"):
				pass
		elif target_dir.contains("/"):
			target_dir = target_dir.get_base_dir()
	
	if not DirAccess.dir_exists_absolute(target_dir):
		return {}
	
	var dirs = DirAccess.get_directories_at(target_dir)
	dirs = Array(dirs)
	dirs.push_front("..")
	for dir in dirs:
		options.add_option(dir, {
			&"trailing_char": "/"
		})
	
	return options.get_options()


func _execute(ctx:CompletionContext):
	return execute_static(ctx, positional_args)


static func execute_static(ctx:CompletionContext, pos_args:Array):
	var current_cwd = ctx.cwd
	var target = pos_args[0]
	
	if target.is_relative_path():
		target = current_cwd.path_join(target).simplify_path()
	
	target = ProjectSettings.globalize_path(target)
	if DirAccess.dir_exists_absolute(target):
		ctx.propogate(CompletionContext.Propagate.PROPERTY, "cwd", target)
	else:
		ctx.append_error("Directory does not exist: " + target)
		return ExitCode.ERR
