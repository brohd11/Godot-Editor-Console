extends EditorConsoleSingleton.CommandBase
## The live script-editor buffer, which `editor script --text` cannot give: core reads a Script's
## source_code, so unsaved edits would not show.

const _HELP = \
"Write the open script-editor buffer to stdout, including unsaved edits.
Usage: format text"

static func get_command_name() -> String:
	return "text"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})

func _execute(ctx:Context):
	var code_edit:CodeEdit = ScriptEditorRef.get_current_code_edit()
	if not is_instance_valid(code_edit):
		ctx.append_error("No script open in the editor.")
		return ExitCode.FAIL
	ctx.write_output(code_edit.text)
	return ExitCode.OK
