extends HBoxContainer

const BACKPORTED = 100

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UResource = UtilsRemote.UResource
const UTexture = UtilsRemote.UTexture
const PopupHelper = UtilsRemote.PopupHelper
const UNode = UtilsRemote.UNode
const UList = UtilsRemote.UList
const Pr = UtilsRemote.UString.PrintRich

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Options = UtilsLocal.Options
const CommandKeys = Options.Keys
const Colors = UtilsLocal.Colors

const ConsoleLineEdit = UtilsLocal.ConsoleLineEdit

const CompletionContext = UtilsLocal.CompletionContext

const REPLACE_DELIMS = [" ", ".", "/", "'", '"', "="]

var console_panel:PanelContainer
var console_hsplit:HBoxContainer#:HSplitContainer # this was an hsplit to allow the label to clip I think
var line_edit:ConsoleLineEdit
var console_button:Button
var os_label:RichTextLabel

var is_editor:bool

# params
var console_ctx:CompletionContext

var os_mode:bool
var prompt_history:Array

var rich_text_label:RichTextLabel

var last_command:String
var command_history = []
var current_command_index:int = -1

func _ready() -> void:
	console_panel = PanelContainer.new()
	console_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(console_panel)
	#console_hsplit = HSplitContainer.new()
	
	console_hsplit = HBoxContainer.new()
	console_panel.add_child(console_hsplit)
	console_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	os_label = RichTextLabel.new()
	console_hsplit.add_child(os_label)
	os_label.bbcode_enabled = true
	os_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	os_label.fit_content = true
	os_label.custom_minimum_size = Vector2(50,0)
	if BACKPORTED >= 4:
		os_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	os_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	
	line_edit = ConsoleLineEdit.new()
	console_hsplit.add_child(line_edit)
	
	var sb_call = func(sb:ScrollBar): sb.visible = false
	var h_bar = line_edit.get_h_scroll_bar()
	h_bar.visibility_changed.connect(sb_call.bind(h_bar))
	var v_bar = line_edit.get_v_scroll_bar()
	v_bar.visibility_changed.connect(sb_call.bind(v_bar))
	
	var syntax := UtilsLocal.SyntaxHl.new()
	line_edit.syntax_highlighter = syntax
	
	line_edit.gui_event_passthrough.connect(_console_gui_input)
	
	new_ctx() # also sets syntax ctx
	
	if is_editor:
		console_panel.hide()
		line_edit.hide()
		console_button = Button.new()
		console_button.icon = EditorInterface.get_editor_theme().get_icon("Terminal", &"EditorIcons")
		console_button.focus_mode = Control.FOCUS_NONE
		console_button.flat = true
		add_child(console_button)
	
	apply_editor_styles()
	update_console_label()
	
	var min:int
	if is_instance_valid(EditorConsoleSingleton.get_instance().filter_line_edit):
		min = EditorConsoleSingleton.get_instance().filter_line_edit.size.y
	else:
		min = 28 * EditorInterface.get_editor_scale()
	custom_minimum_size.y = min
	
	EditorConsoleSingleton.get_instance().console_containers.append(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		EditorConsoleSingleton.get_instance().console_containers.erase(self)

func apply_editor_styles():
	var normal_style_box = EditorInterface.get_editor_theme().get_stylebox(&"normal", &"LineEdit")
	console_panel.add_theme_stylebox_override("panel", normal_style_box)
	line_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	line_edit.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	line_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	line_edit.add_theme_constant_override("caret_width", 8)
	line_edit.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	#var log_text_edit = get_parent().get_parent().get_child(0) as RichTextLabel
	var log_text_edit = EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL) as RichTextLabel
	var font = log_text_edit.get_theme_font("normal_font")
	os_label.add_theme_font_override("normal_font", font)
	line_edit.add_theme_font_override("font", font)
	
	if is_instance_valid(rich_text_label):
		rich_text_label.add_theme_font_override("normal_font", font)
		rich_text_label.add_theme_font_size_override("normal_font", log_text_edit.get_theme_font_size("normal_font"))
		


func new_ctx():
	console_ctx = EditorConsoleSingleton.get_main_ctx()
	line_edit.console_ctx = console_ctx
	line_edit.syntax_highlighter.current_ctx = console_ctx
	#if not is_editor:
	console_ctx.console_container = self


func set_console_text(text:String) -> void:
	_set_console_text(text)

func _set_console_text(text:String) -> void:
	line_edit.text = text
	await line_edit.get_tree().process_frame
	line_edit.set_caret_column(text.length())


func add_to_history(command:String):
	last_command = command
	var history_prompt = command
	if os_mode and history_prompt.begins_with("os"):
		history_prompt = history_prompt.trim_prefix("os").strip_edges()
	var cmd_index = command_history.rfind(history_prompt)
	if cmd_index == -1:
		command_history.append(history_prompt)
	else:
		command_history.remove_at(cmd_index)
		command_history.append(history_prompt)

func _console_gui_input(event: InputEvent) -> void:
	if not line_edit.has_focus():
		return
	
	if event is InputEventKey:
		var keycode = event.keycode
		var keycode_text = event.as_text_keycode()
		if event.is_pressed() and keycode == KEY_ENTER:
			_on_console_text_submitted(line_edit.text)
		
		if not event.is_pressed():
			return
		
		if keycode == KEY_UP:
			prev_command()
		elif keycode == KEY_DOWN:
			next_command()

func prev_command():
	current_command_index -= 1
	if current_command_index < -1:
		current_command_index = command_history.size() - 1
	if current_command_index == -1:
		line_edit.clear()
		return
	if current_command_index < command_history.size():
		_set_console_text(command_history[current_command_index])

func next_command():
	current_command_index += 1
	if current_command_index > command_history.size() - 1:
		current_command_index = -1
		line_edit.clear()
		return
	if current_command_index < command_history.size():
		_set_console_text(command_history[current_command_index])





func _on_console_text_submitted(new_text:String) -> void:
	#working_variable_dict.clear()
	current_command_index = -1
	
	# so stdout doesn't progate up to here
	var working_ctx = CompletionContext.new_ctx("", console_ctx)
	var new_stripped = new_text.strip_edges()
	if new_stripped == "os":
		_toggle_os_mode()
	elif new_stripped == "new_ctx":
		new_ctx()
	else:
		EditorConsoleSingleton.execute_interactive(new_text, {
			&"console_container": self,
			&"parent_ctx": working_ctx,
			&"print": true,
			&"add_to_hist": true,
		})
	
	await line_edit.get_tree().process_frame
	line_edit.clear()
	
	var console_text = get_rich_text(true) # not sure about this process
	if is_instance_valid(console_text):
		console_text.scroll_to_line(console_text.get_line_count())
	
	update_console_label()



func get_rich_text(allow_editor:=false):
	if is_instance_valid(rich_text_label) or not allow_editor:
		return rich_text_label
	return EditorNodeRef.get_node_ref(EditorNodeRef.Nodes.EDITOR_LOG_RICH_TEXT_LABEL)

func update_console_label():
	os_label.text = get_console_label_string(os_mode)

func _update_os_string():
	var os_string = get_console_label_string(true)
	if os_label:
		os_label.text = os_string

func _toggle_os_mode():
	os_mode = not os_mode
	console_ctx.os_mode = os_mode
	
	line_edit.syntax_highlighter.os_mode = os_mode
	line_edit.os_mode = os_mode
	
	var con_str = get_console_label_string()
	if os_mode:
		_update_os_string()
		print_to_console(con_str + " Entered OS mode.")
		if line_edit.visible:
			os_label.show()
		os_label.text = get_console_label_string(true)
	else:
		os_label.text = con_str
		print_to_console(con_str + " Exited OS mode")

func get_console_label_string(os:=false):
	var os_user = UtilsLocal.ConsoleOS.get_os_string()
	var display_cwd = ProjectSettings.globalize_path(console_ctx.cwd)
	var home_dir = UtilsLocal.ConsoleOS.get_os_home_dir()

	if display_cwd == "":
		display_cwd = "/"
	elif display_cwd == home_dir:
		display_cwd = "~"
	elif not os_mode and display_cwd.trim_suffix("/") == ProjectSettings.globalize_path("res://").trim_suffix("/"):
		display_cwd = ""
	else:
		display_cwd = display_cwd.trim_suffix("/").get_file()
	
	var pr = Pr.new()
	if os:
		pr.append(os_user, Colors.OS_USER)
		#pr.append(":")
		pr.append(" ")
		return pr.append(display_cwd, Colors.OS_PATH).append(" $").get_string()
	
	var accent_color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.ACCENT)
	pr.append("Console", accent_color)
	if display_cwd != "":
		#pr.append(":")
		pr.append(" ")
		pr.append(display_cwd.trim_suffix("/").get_file(), Colors.OS_PATH)
	pr.append(" ").append("$")#, accent_color)
	return pr.get_string()

func print_to_console(string:String):
	var rich = get_rich_text()
	if is_instance_valid(rich):
		rich.text += string + "\n"
	else:
		print_rich(string)
