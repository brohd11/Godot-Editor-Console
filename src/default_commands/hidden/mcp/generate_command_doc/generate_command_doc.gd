extends EditorConsoleSingleton.CommandBase


const _HELP = \
"Generate a markdown command-tree doc (commands.md style) and print it."

const NAMES_TO_SKIP = ["builtins", "plugin_exporter", "namespace"]

var write_flag:=false

static func get_command_name():
	return "generate_command_doc"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--write", {
		&"help": "Write to the commands.md file."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--write":
		write_flag = true

func _execute(ctx:CompletionContext):
	var ins = EditorConsoleSingleton.get_instance()
	var md := "The console ships with these commands:\n"

	# Top level scopes, one '## <scope>' section each, sorted for stable output.
	var scope_names = ins.scope_dict.keys()
	scope_names.sort()
	for scope_name in scope_names:
		var scope = ins.scope_dict[scope_name]
		var lines := []
		_render(scope.get("script").new(), 0, lines)
		md += "\n## %s\n\n```text\n%s\n```\n" % [scope_name, "\n".join(lines)]

	# Hidden builtins grouped under a single fenced block, each as a sibling root.
	var hidden_names = ins.hidden_scope_dict.keys()
	hidden_names.sort()
	var builtin_lines := []
	for scope_name in hidden_names:
		var scope = ins.hidden_scope_dict[scope_name]
		_render(scope.get("script").new(), 0, builtin_lines)
	md += "\n## Builtins\n\n```text\n%s\n```\n" % "\n".join(builtin_lines)
	
	if not write_flag:
		ctx.append_output(md)
	else:
		var plugin_path = "res://addons/editor_console/"
		if not DirAccess.dir_exists_absolute(plugin_path.path_join("export_ignore")):
			ctx.append_error("Export ignore does not exist. Is this exported?")
			return ExitCode.ERR
		
		var f = FileAccess.open(plugin_path.path_join("export_ignore/doc/commands.md"), FileAccess.WRITE)
		f.store_string(md)
	
	

func _render(cmd, depth:int, lines:Array):
	var name = cmd.get_command_name()
	if name in NAMES_TO_SKIP:
		return
	
	if name.begins_with("__"):
		return
	var help = cmd.get_help_string()
	if help != null and help.contains("\n"):
		help = help.get_slice("\n", 0)
	var line :String = ("\t".repeat(depth)) + ("└── " if depth > 0 else "") + name
	if help != null and help != "" and help != "Undocumented or namespace":
		line += " # " + help
	lines.append(line)
	var subs = cmd.get_commands()
	for k in subs.keys():
		var get_cmd = subs[k].get(&"get_command")
		if get_cmd != null:
			_render(get_cmd.call(), depth + 1, lines)
