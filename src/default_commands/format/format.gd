extends EditorConsoleSingleton.CommandBase
## Script-editor text tools. These rewrite the live CodeEdit buffer, so they stay editor-side
## rather than moving to GDSh core with the rest of the `script` command.

static func get_command_name() -> String:
	return "format"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Formatting tools for the script open in the editor.\nPass-through command — routes to its subcommands."
	})
