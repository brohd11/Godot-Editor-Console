extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const LIST_COMMANDS_OPTIONS = ["--methods", "--signals", "--constants", "--properties", "--enums"]
const LIST_MODIFIER_OPTIONS = ["--lines", "--data", "--inherited"]


static func get_command_name() -> String:
	return "list"


static func get_self_option_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "List properties of target script\nUsage: script list <options>",
		&"get_command": func(): return new()
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	for cmd in LIST_COMMANDS_OPTIONS:
		options.add_option(cmd)
	
	#if options.size() < LIST_COMMANDS_OPTIONS.size():
	options.add_separator("Modifiers")
	for cmd in LIST_MODIFIER_OPTIONS:
		options.add_option(cmd)
	
	return options.get_options()




func _get_completions(ctx:CompletionContext):
	var flags = get_flags(true)
	var has_valid_flag = false
	for c in consumed_tokens:
		if c in LIST_COMMANDS_OPTIONS:
			has_valid_flag = true
			break
	if not has_valid_flag:
		for c in LIST_MODIFIER_OPTIONS:
			flags.erase(c)
	return flags

func _execute(ctx:CompletionContext):
	consumed_tokens.erase("list")
	if consumed_tokens.is_empty():
		_get_help_for_token("list")
		return
	if not ctx.unconsumed_tokens.is_empty():
		print("Unrecognized commands: ", ctx.unconsumed_tokens)
		return 1
	var script = ScriptUtil.get_script_from_ctx(ctx)
	var script_name = UClassDetail.get_global_class_name(script.resource_path)
	if script_name == "":
		script_name = script.resource_path.get_file()
	print_members(script_name, consumed_tokens, script)


static func print_members(script_name:String, flags:Array, script:Script):
	var print_data = LIST_MODIFIER_OPTIONS[1] in flags
	var print_lines = LIST_MODIFIER_OPTIONS[0] in flags
	var inherited = LIST_MODIFIER_OPTIONS[2] in flags
	for cmd in LIST_MODIFIER_OPTIONS:
		flags.erase(cmd)
	var valid = false
	for a in flags:
		if a in LIST_COMMANDS_OPTIONS:
			valid = true
	var flags_size = flags.size()
	if not valid:
		if flags_size > 0:
			print("'--data', '--lines', and '--inherited' should be passed with another argument.")
		else:
			print("Pass arguments for the list command.")
		return
	
	var pr = Pr.new()
	for i in range(flags_size):
		var command = flags[i]
		if command in LIST_COMMANDS_OPTIONS:
			var members = {}
			if command == LIST_COMMANDS_OPTIONS[0]: # methods
				if inherited:
					print("Printing class methods: %s" % script_name)
					members = UClassDetail.class_get_all_methods(script)
				else:
					print("Printing script methods: %s" % script_name)
					members = UClassDetail.script_get_all_methods(script)
			elif command == LIST_COMMANDS_OPTIONS[1]: # signals
				if inherited:
					print("Printing class signals: %s" % script_name)
					members = UClassDetail.class_get_all_signals(script)
				else:
					print("Printing script signals: %s" % script_name)
					members = UClassDetail.script_get_all_signals(script)
			elif command == LIST_COMMANDS_OPTIONS[2]: # constants
				if inherited:
					print("Printing class constants: %s" % script_name)
					members = UClassDetail.class_get_all_constants(script)
				else:
					print("Printing script constants: %s" % script_name)
					members = UClassDetail.script_get_all_constants(script)
			elif command == LIST_COMMANDS_OPTIONS[3]: # properties
				if inherited:
					print("Printing class properties: %s" % script_name)
					members = UClassDetail.class_get_all_properties(script)
				else:
					print("Printing script properties: %s" % script_name)
					members = UClassDetail.script_get_all_properties(script)
			elif command == LIST_COMMANDS_OPTIONS[4]: # enums
				if inherited:
					print("Printing class enums: %s" % script_name)
					members = UClassDetail.class_get_all_enums(script)
				else:
					print("Cannot get script enums, no API in ClassDB. Use '--inherited' option.")
					#members = UClassDetail.sc(script)
					pass
			
			if members.is_empty():
				pr.append("\tNone in script.", Colors.VAR_RED).display()
			else:
				if print_lines or print_data:
					for m in members.keys():
						pr.append("%s" % m, Colors.ACCENT_MUTE).display()
						if print_data:
							var data = members.get(m)
							if data == null:
								pr.append("\tNo data.").display()
							else:
								for key in data.keys():
									pr.append("\t%s - %s" % [key, data[key]], Colors.GRAY).display()
				else:
					pr.append("\t" + "  ".join(members.keys()), Colors.ACCENT_MUTE).display()
			if i < flags_size - 1:
				print("") # print blank line between sections
			continue
