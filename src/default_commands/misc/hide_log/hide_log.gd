extends EditorConsoleSingleton.CommandBase

var adjust_size:=-1
var toggle_log:=false
var toggle_buttons:=false

static func get_command_name() -> String:
	return "hide_log"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": "Toggle the output log.",
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--size=", {
		&"help": "Adjust the minimum size of the editor log.",
		&"trailing_char": ""
	})
	options.add_option("--log", {
		&"help": "Toggle the log label."
	})
	options.add_option("--buttons", {
		&"help": "Toggle button container."
	})
	return options.get_options()

func _process_flag(flag:String):
	if flag.begins_with("--size="):
		var sz = _get_flag_value(flag)
		if sz.is_valid_float():
			adjust_size = int(sz.to_float())
		elif sz.is_valid_int():
			adjust_size = sz.to_int()
		else:
			adjust_size = -100
		
		if adjust_size < 0:
			adjust_size = -100
		
	elif flag == "--log":
		toggle_log = true
	elif flag == "--buttons":
		toggle_buttons = true

func _get_target_positional_count() -> int:
	#if adjust_size:
		#return 1
	return 0

func _execute(_ctx:CompletionContext):
	if adjust_size == -100:
		var flag = ""
		for c in consumed_tokens:
			if c.begins_with("--size="):
				flag = c
				break
		_ctx.append_error("Could not get size from flag: " + flag)
		return ExitCode.ERR
	
	var editor_log = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG)
	var vbox = editor_log.get_child(1).get_child(0) as VBoxContainer
	var label = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL)
	var buttons = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_BUTTON_CONTAINER)
	
	if not (toggle_buttons or toggle_log or adjust_size):
		var new_vis = not label.visible
		label.visible = new_vis
		buttons.visible = new_vis
		if new_vis:
			vbox.custom_minimum_size.y = 180 * EditorInterface.get_editor_scale()
		else:
			vbox.custom_minimum_size.y = 0
		return
	
	if adjust_size > -1:
		vbox.custom_minimum_size.y = max(0, adjust_size)
	
	if toggle_log:
		label.visible = not label.visible
	if toggle_buttons:
		buttons.visible = not buttons.visible
