extends EditorConsoleSingleton.CommandBase

var clear_history:=false

static func get_command_name() -> String:
	return "clear"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": "Clear EditorLog\nUsage: clear <--history>"
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--history", {
		&"help": "Clear the prompt history."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--history":
		clear_history = true

func _execute(_ctx:CompletionContext):
	if clear_history:
		EditorConsoleSingleton.get_instance().previous_commands.clear()
		
	EditorConsoleSingleton.get_instance().clear_button.pressed.emit()
	
