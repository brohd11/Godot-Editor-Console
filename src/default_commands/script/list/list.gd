extends EditorConsoleSingleton.CommandBase

const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

const ScriptUtil = preload("res://addons/editor_console/src/default_commands/script/script_util.gd")

const LIST_COMMANDS_OPTIONS = ["--methods", "--signals", "--constants", "--properties", "--enums"]
const LIST_MODIFIER_OPTIONS = ["--data", "--inherited", "--pretty"]

const LIST_OPTION_HELP = {
	"--methods":{
		"help":"List the script's methods.",
		"prop": &"method_flag",
	},
	"--signals": {
		"help": "List the script's signals.",
		"prop": &"signal_flag",
		},
	"--constants": {
		"help":"List the script's constants.",
		"prop": &"const_flag"
		},
	"--properties": {
		"help":"List the script's properties.",
		"prop": &"prop_flag"
		},
	"--enums": {
		"help":"List the script's enums (requires --inherited).",
		"prop": &"enum_flag"
		},
	"--data": {
		"help":"Print each member's details.",
		"prop": &"data_flag"
		},
	"--inherited": {
		"help":"Include inherited members from the base class.",
		"prop":&"inh_flag"
		},
	"--pretty": {
		"help":"Print on a single line rather than new-lines.",
		"prop": &"pretty_flag"
		},
}

var target_all_flag:=true
var method_flag:=false
var signal_flag:=false
var const_flag:=false
var prop_flag:=false
var enum_flag:=false

var inh_flag:=false
var data_flag:=false
var pretty_flag:=false

static func get_command_name() -> String:
	return "list"


static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": ScriptUtil.get_usage_string(
			"List properties of target script",
			"list <options>"
		),
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	for cmd in LIST_COMMANDS_OPTIONS:
		options.add_option(cmd, {
			&"help": LIST_OPTION_HELP.get(cmd, {}).get("help", "")
		})

	#if options.size() < LIST_COMMANDS_OPTIONS.size():
	options.add_separator("Modifiers")
	for cmd in LIST_MODIFIER_OPTIONS:
		options.add_option(cmd, {
			&"help": LIST_OPTION_HELP.get(cmd, {}).get("help", "")
		})
	
	return options.get_options()

func _process_flag(flag:String):
	var prop = LIST_OPTION_HELP.get(flag, {}).get("prop")
	set(prop, true)
	if flag in LIST_COMMANDS_OPTIONS:
		target_all_flag = false


func _execute(ctx:CompletionContext):
	var script = ScriptUtil.get_script_from_ctx(ctx)
	var script_name = UClassDetail.get_global_class_name(script.resource_path)
	if script_name == "":
		script_name = script.resource_path.get_file()
	return list_members(ctx, script_name, script)


func list_members(ctx:CompletionContext, script_name:String, script:Script) -> int:
	var print_pretty = pretty_flag
	var print_data = data_flag
	var inherited = inh_flag
	
	
	var pr = Pr.new()
	for flag in LIST_OPTION_HELP.keys():
		if not flag in LIST_COMMANDS_OPTIONS:
			continue
		var prop = LIST_OPTION_HELP.get(flag).get("prop")
		if not (get(prop) == true or target_all_flag):
			continue
		
		var flag_raw = flag.trim_prefix("--")
		var members = _get_members(script, flag, inherited)
		if inherited:
			ctx.append_output("Class %s:" % [flag_raw])
		else:
			if flag == "--enums":
				if not target_all_flag:
					ctx.append_output("\tCannot get 'Script' enums, no API in ClassDB. Use '--inherited' option.")
				continue
			ctx.append_output("Script %s:" % [flag_raw])
			
		
		_add_to_members_to_output(ctx, members, pr)
	
	ctx.strip_output_newlines()
	return ExitCode.OK

static func _get_members(script:GDScript, flag:String, inherited:bool):
	match flag:
		LIST_COMMANDS_OPTIONS[0]: # methods
			if inherited:
				return UClassDetail.class_get_all_methods(script)
			else:
				return UClassDetail.script_get_all_methods(script)
		LIST_COMMANDS_OPTIONS[1]: # signals
			if inherited:
				return UClassDetail.class_get_all_signals(script)
			else:
				return UClassDetail.script_get_all_signals(script)
		LIST_COMMANDS_OPTIONS[2]: # constants
			if inherited:
				return UClassDetail.class_get_all_constants(script)
			else:
				return UClassDetail.script_get_all_constants(script)
		LIST_COMMANDS_OPTIONS[3]: # properties
			if inherited:
				return UClassDetail.class_get_all_properties(script)
			else:
				return UClassDetail.script_get_all_properties(script)
		LIST_COMMANDS_OPTIONS[4]: # enums
			if inherited:
				return UClassDetail.class_get_all_enums(script)
			else:
				return {}


func _add_to_members_to_output(ctx:CompletionContext, members:Dictionary, pr:Pr):
	if members.is_empty():
		var err_color = Colors.VAR_RED if pretty_flag else Color.TRANSPARENT
		pr.append("\tNone in script.", err_color)
		ctx.append_output(pr.get_string(true))
	else:
		if pretty_flag and not data_flag:
			pr.append("\t" + "  ".join(members.keys()), Colors.ACCENT_MUTE)
			ctx.append_output(pr.get_string(true))
		
		else:
			for m in members.keys():
				var member_string = "%s" % m
				var member_color = Colors.ACCENT_MUTE if pretty_flag else Color.TRANSPARENT
				pr.append("\t%s" % m, member_color)
				ctx.append_output(pr.get_string(true))
				if data_flag:
					var data = members.get(m)
					if data == null:
						pr.append("\t\tNo data.")
						ctx.append_output(pr.get_string(true))
					elif data is String:
						ctx.append_output("\t\t" + data)
					elif data is Dictionary:
						for key in data.keys():
							pr.append("\t\t%s - %s" % [key, data[key]])
							ctx.append_output(pr.get_string(true))
					else:
						ctx.append_output("\t\t" + str(data))
	
	ctx.append_output("")
