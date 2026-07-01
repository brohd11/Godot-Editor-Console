extends EditorConsoleSingleton.CommandBase

const UOs = UtilsRemote.UOs

const _HELP = \
"Launch a terminal with gdaddon running.
Usage: gdaddon"

static func get_command_name():
	return "gdaddon"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
	})

func _execute(_ctx:CompletionContext):
	
	UOs.launch_term("gdaddon")
