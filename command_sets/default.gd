extends "res://addons/godot_console/src/class/console_command_set_base.gd"

static func register_commands():
	return {
	"os":{
		"script": UtilsLocal.ConsoleOS
	},
	#"clear":{
		#"Callable":clear_console,
	#},
	"help": {
		"script": UtilsLocal.ConsoleHelp,
	},
	"script": {
		"script": UtilsLocal.ConsoleScript
	},
	"global":{
		"script": UtilsLocal.ConsoleGlobalClass
	},
	"config":{
		"script": UtilsLocal.ConsoleCfg,
	},
	
	"color": {"callable": _color}
}

static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}



static func _color(commands, arg, editor_console:EditorConsole):
	var win = Window.new()
	var color = ColorPicker.new()
	win.size = Vector2i(400,600)
	win.add_child(color)
	win.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color.can_add_swatches = false
	color.deferred_mode = true
	color.color_changed.connect(_color_changed)
	win.close_requested.connect(_on_color_close_requested.bind(win))
	EditorInterface.get_base_control().add_child(win)
	win.title = "Color Picker"
	win.show()

static func _color_changed(color):
	DisplayServer.clipboard_set(color.to_html())
	
	pass

static func _on_color_close_requested(window) -> void:
	window.queue_free()
	pass

static func clear_console(commands:Array, arguments:Array, editor_console:EditorConsole):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "-h" or c_2 == "-help":
			print("Clear ouput text box.\n-hist - Clear command history.")
			return
		if c_2 == "-hist":
			editor_console.previous_commands.clear()
	var line = editor_console.console_line_edit
	var editor_log = line.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent()
	var clear_button = editor_log.get_child(2).get_child(1).get_child(0)
	clear_button.pressed.emit()
