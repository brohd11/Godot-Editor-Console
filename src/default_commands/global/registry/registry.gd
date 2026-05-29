extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail
const ScopeDataKeys = UtilsLocal.ScopeDataKeys

const _HELP = \
"Manage classes that show in autocomplete.
Usage: global registry {--add|--rm} <class_name>"

var add:=false
var remove:=false

static func get_command_name() -> String:
	return "registry"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict( get_command_name(), {
		&"help": _HELP,
		&"positional_count": 1,
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
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--add":
		add = true
	elif flag == "--rm":
		remove = true

func _get_completions(_ctx:CompletionContext):
	var options = Options.new()
	if add:
		var global_class_list = UClassDetail.get_all_global_class_paths().keys()
		var registered = _get_registered_classes()
		for name in global_class_list:
			if name not in registered:
				options.add_option(name)
		return options.get_options()
	elif remove:
		var registered = _get_registered_classes()
		for name in registered:
			options.add_option(name)
		return options.get_options()
		
	var flags = get_flags(true)
	return flags


func _execute(_ctx:CompletionContext):
	if add and remove:
		print("Cannot use --add and --rm flag at the same time.")
		return ExitCode.FAIL
	var target_class = positional_args[0]
	var scope_data = UtilsLocal.get_scope_data()
	var registered_classes = scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])
	if add:
		if target_class in registered_classes:
			print("Class already registered: %s" % target_class)
			return ExitCode.FAIL
		registered_classes.append(target_class)
	elif remove:
		if not target_class in registered_classes:
			print("Class not registered: %s" % target_class)
			return ExitCode.FAIL
		var idx = registered_classes.find(target_class)
		registered_classes.remove_at(idx)
	else:
		if UClassDetail.get_global_class_path(target_class) == "":
			print("Class not in global class list: %s" % target_class)
		else:
			print("Class '%s' registered: %s" % [target_class, target_class in registered_classes])
	
	if add or remove:
		scope_data[ScopeDataKeys.GLOBAL_CLASSES] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
		
	return ExitCode.OK


func _get_registered_classes():
	var scope_data = UtilsLocal.get_scope_data()
	return scope_data.get(ScopeDataKeys.GLOBAL_CLASSES, [])
