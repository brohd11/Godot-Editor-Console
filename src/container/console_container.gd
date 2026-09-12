extends HBoxContainer
## Editor chrome around GDSh's prompt, input, history, and optional transcript.
const Sh = preload("res://addons/addon_lib/gdsh/gdsh.gd")
const Prompt = preload("res://addons/editor_console/src/container/editor_prompt.gd")
const OSCompletion = preload("res://addons/editor_console/src/container/os_completion.gd")
const Adapter = preload("res://addons/editor_console/src/utils/os_adapter.gd")
const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")

var console:Prompt
var console_panel:Control
var line_edit:CodeEdit
var console_button:Button
var console_ctx:Sh.Context
var is_editor:bool = false
var os_mode:bool = false
var rich_text_label:RichTextLabel
var _normal_highlighter:SyntaxHighlighter
var _os_user:String

func _ready() -> void:
	console = Prompt.new()
	console.host = weakref(self)
	console.execution_handler = _execute_submission
	console.echo_values = true
	console.prompt_formatter = func(_ctx): return get_console_label_string(os_mode)
	console.input.completion_factory = _make_completion
	console_panel = console
	line_edit = console.input
	add_child(console)
	if not is_editor:
		console.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rich_text_label = console.create_output()
	_normal_highlighter = Sh.Console.Highlighter.new()
	_normal_highlighter.highlight_globals = true
	console.set_highlighter(_normal_highlighter)
	new_ctx()
	if is_editor:
		console.hide()
		line_edit.hide()
		console_button = Button.new()
		console_button.icon = EditorInterface.get_editor_theme().get_icon("Terminal", &"EditorIcons")
		console_button.focus_mode = Control.FOCUS_NONE
		console_button.flat = true
		add_child(console_button)
	apply_editor_styles()
	custom_minimum_size.y = 28 * EditorInterface.get_editor_scale()
	EditorConsoleSingleton.get_instance().console_containers.append(self)

func _exit_tree() -> void:
	if EditorConsoleSingleton.instance_valid():
		EditorConsoleSingleton.get_instance().console_containers.erase(self)

func apply_editor_styles() -> void:
	var log_control = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL)
	if is_instance_valid(log_control):
		console.add_font_override(log_control.get_theme_font("normal_font"))
	line_edit.add_theme_constant_override("caret_width", 8)

func new_ctx() -> void:
	console_ctx = EditorConsoleSingleton.get_main_ctx()
	console_ctx.host_data["console"] = weakref(self)
	console.set_context(console_ctx)

func set_console_text(text:String) -> void:
	line_edit.text = text
	line_edit.set_caret_column(text.length())

func _execute_submission(text:String, result:Sh.Context) -> void:
	if text == "os":
		os_mode = not os_mode
		console.set_highlighter(null if os_mode else _normal_highlighter)
		# The prompt still shows the mode the toggle was typed in.
		print_to_console(console.prompt_label.text + (" Entered OS mode." if os_mode else " Exited OS mode."))
	elif text == "new_ctx":
		new_ctx()
	elif os_mode and not (text == "clear" or text.begins_with("clear ")):
		var command = text.trim_prefix("os ")
		result.exit_code = Adapter.execute(command, result)
		result.last_status = result.exit_code
	else:
		Sh.Execute.execute_command_multiline(text, result)

func _make_completion(text:String, ctx:Sh.Context, caret:int) -> Sh.Completion:
	return OSCompletion.new(text, ctx, caret) if os_mode else Sh.Completion.new(text, ctx, caret)

func get_rich_text(allow_editor:=false):
	if is_instance_valid(rich_text_label) or not allow_editor: return rich_text_label
	return EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL)

func update_console_label() -> void:
	console.update_prompt()

func get_console_label_string(os:=false) -> String:
	if console_ctx == null: return "Console $"
	var cwd = ProjectSettings.globalize_path(console_ctx.cwd).trim_suffix("/")
	var home = UtilsLocal.ConsoleOS.get_os_home_dir().trim_suffix("/")
	var display = cwd.get_file()
	if cwd.is_empty(): display = "/"
	elif cwd == home: display = "~"
	elif not os and cwd == ProjectSettings.globalize_path("res://").trim_suffix("/"): display = ""
	var label = "Console"
	var color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.ACCENT)
	if os:
		if _os_user.is_empty(): _os_user = UtilsLocal.ConsoleOS.get_os_string()
		label = _os_user
		color = UtilsLocal.Colors.OS_USER
	var out = "[color=%s]%s[/color]" % [color.to_html(), label.replace("[", "[lb]")]
	if not display.is_empty():
		out += " [color=%s]%s[/color]" % [UtilsLocal.Colors.OS_PATH.to_html(), display.replace("[", "[lb]")]
	return out + " $"

func print_to_console(text:String) -> void:
	if is_instance_valid(rich_text_label):
		rich_text_label.append_text(text + "\n")
	else:
		print_rich(text)
