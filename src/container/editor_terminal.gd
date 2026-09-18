extends "res://addons/addon_lib/gdsh/src/ui/terminal_console.gd"
## Editor adapter for the optional floating terminal view.

var dock_button:Button

func _init() -> void:
	dock_button = Button.new()
	add_child(dock_button)
	dock_button.hide.call_deferred()
	
	super()
	output_bbcode = true
	echo_values = true
	context_factory = _build_context
	execution_handler = _execute_submission
	_syntax.highlight_globals = true


func _ready() -> void:
	
	
	super()
	if EditorConsoleSingleton.instance_valid():
		EditorConsoleSingleton.get_instance().terminal_consoles.append(self)
		reset_context()
	if Engine.is_editor_hint():
		var log_control = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL, false)
		if is_instance_valid(log_control):
			add_font_override(log_control.get_theme_font("normal_font"))
			output.add_theme_stylebox_override("normal", log_control.get_theme_stylebox("normal"))
	focus_input.call_deferred()


func _exit_tree() -> void:
	super()
	if EditorConsoleSingleton.instance_valid():
		EditorConsoleSingleton.get_instance().terminal_consoles.erase(self)


func _build_context() -> Context:
	var ctx = EditorConsoleSingleton.get_main_ctx()
	ctx.host_data["console"] = weakref(self)
	ctx.host_data["clear_callback"] = _clear_from_command
	return ctx


func _execute_submission(text:String, ctx:Context) -> void:
	await EditorConsoleSingleton.run_serialized(func():
		if not _leaving_tree:
			await Execute.execute_command_multiline(text, ctx))


func _stream_enabled() -> bool:
	return super() and (not EditorConsoleSingleton.instance_valid() or EditorConsoleSingleton.get_instance().stream_output)
