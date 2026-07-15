extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail
const ScopeDataKeys = UtilsLocal.ScopeDataKeys

const _HELP = \
"Manage classes that show in autocomplete.
Usage: global registry {--add|--rm} <class_name>"

var add:=false
var remove:=false
var global_flag:=false

static func get_command_name() -> String:
	return "registry"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict( get_command_name(), {
		&"help": _HELP,
		&"positional_count": "min: 1",
		&"priority": 10
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--add", {
		&"help": "Add class to registered classes."
	})
	options.add_option("--rm", {
		&"help": "Remove class from registered classes."
	})
	options.add_option("--global", {
		&"help": "Add/remove from the global config file."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--add":
		add = true
	elif flag == "--rm":
		remove = true
	elif flag == "--global":
		global_flag = true

func _get_completions(_ctx:CompletionContext):
	var options = Options.new()
	if add:
		var global_class_list = UClassDetail.get_all_global_class_paths().keys()
		var registered = _get_registered_classes()
		for name in global_class_list:
			if name not in registered and name not in positional_args:
				options.add_option(name)
		return options.get_options()
	elif remove:
		var registered = _get_registered_classes()
		for name in registered:
			if name not in positional_args:
				options.add_option(name)
		return options.get_options()
		
	var flags = get_flags(true)
	return flags


func _execute(ctx:CompletionContext):
	if add and remove:
		ctx.append_error("Cannot use --add and --rm flag at the same time.")
		return ExitCode.ERR
	var target_class = positional_args[0]
	var config = UtilsLocal.Config.get_target_config(not global_flag)
	var registered_classes = config.get_section(config.GLOBAL_CLASSES, [])
	var has_fail = false
	for nm in positional_args:
		if add:
			if nm in registered_classes:
				ctx.append_error("Class already registered: %s" % nm)
				has_fail = true
				continue
			registered_classes.append(nm)
		elif remove:
			if not nm in registered_classes:
				ctx.append_error("Class not registered: %s" % nm)
				has_fail = true
				continue
			var idx = registered_classes.find(nm)
			registered_classes.remove_at(idx)
		else:
			if UClassDetail.get_global_class_path(nm) == "":
				ctx.append_output("Class not in global class list: %s" % nm)
			else:
				ctx.append_output("Class '%s' registered: %s" % [nm, nm in registered_classes])
	
	if add or remove:
		config.write()
		
	if has_fail:
		return ExitCode.ERR
	return ExitCode.OK


func _get_registered_classes():
	var config = UtilsLocal.Config.get_target_config(not global_flag)
	return config.get_section(UtilsLocal.Config.GLOBAL_CLASSES, [])
