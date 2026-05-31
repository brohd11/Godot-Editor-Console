extends EditorConsoleSingleton.CommandBase

const EditorGDScriptParser = preload("uid://t2dewmuth0sy") #! resolve ALibEditor.Singleton.EditorGDScriptParser
const VarInsertType = preload("uid://ci11vn1timw1r") #! resolve ALibEditor.Utils.UGDScript.VarInsertType

const _HELP = \
"Attempt to infer the variable type of all variables declared in script.
Usage: script infer"

static func get_command_name() -> String:
	return "infer"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
	})

func _execute(_ctx:CompletionContext) -> ExitCode:
	format_script_type_hint()
	return ExitCode.OK

func format_script_type_hint() -> void:
	var parser:EditorGDScriptParser.GDScriptParser = EditorGDScriptParser.get_parser()
	var code_edit:CodeEdit = ScriptEditorRef.get_current_code_edit()
	VarInsertType.format_script(parser, code_edit)
	
