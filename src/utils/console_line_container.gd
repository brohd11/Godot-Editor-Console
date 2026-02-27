extends HBoxContainer

const BACKPORTED = 100

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const PopupHelper = UtilsRemote.PopupHelper
const CommandKeys = UtilsLocal.ParsePopupKeys

const UNode = UtilsRemote.UNode

var console_panel:PanelContainer
var console_hsplit:HSplitContainer
var console_line_edit:CodeEdit
var console_button:Button
var os_label:RichTextLabel

func _ready() -> void:
	
	console_panel = PanelContainer.new()
	console_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_panel.hide()
	console_hsplit = HSplitContainer.new()
	console_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	os_label = RichTextLabel.new()
	os_label.bbcode_enabled = true
	os_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	os_label.fit_content = true
	os_label.custom_minimum_size = Vector2(50,0)
	if BACKPORTED >= 4:
		os_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	os_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	
	console_line_edit = ConsoleLineEdit.new()
	var h_bar = console_line_edit.get_h_scroll_bar()
	h_bar.visibility_changed.connect(_on_scroll_bar_vis_changed.bind(h_bar))
	var v_bar = console_line_edit.get_v_scroll_bar()
	v_bar.visibility_changed.connect(_on_scroll_bar_vis_changed.bind(v_bar))
	console_line_edit.hide()
	var syntax := UtilsLocal.SyntaxHl.new()
	console_line_edit.syntax_highlighter = syntax
	
	console_button = Button.new()
	console_button.icon = EditorInterface.get_editor_theme().get_icon("Terminal", &"EditorIcons")
	console_button.focus_mode = Control.FOCUS_NONE
	console_button.flat = true
	
	add_child(console_panel)
	add_child(console_button)
	console_panel.add_child(console_hsplit)
	console_hsplit.add_child(os_label)
	console_hsplit.add_child(console_line_edit)

func apply_styleboxes(line_edit:LineEdit):
	var normal_style_box = line_edit.get_theme_stylebox("normal")
	console_panel.add_theme_stylebox_override("panel", normal_style_box)
	console_line_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	console_line_edit.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	console_line_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	console_line_edit.add_theme_constant_override("caret_width", 8)
	console_line_edit.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var log_text_edit = get_parent().get_parent().get_child(0) as RichTextLabel
	var font = log_text_edit.get_theme_font("normal_font")
	os_label.add_theme_font_override("normal_font", font)
	console_line_edit.add_theme_font_override("font", font)

func _on_scroll_bar_vis_changed(scrollbar):
	scrollbar.visible = false


class ConsoleLineEdit extends CodeEdit:
	var editor_console:EditorConsoleSingleton
	var variable_dict = {}
	var scope_dict = {}
	var combined_scope_dict = {}
	var os_mode:= false
	
	var popup:AutoCompletePopup
	
	func _ready() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("line_spacing", 0)
		caret_blink = true
		auto_brace_completion_enabled = true
		code_completion_enabled = true
		text_changed.connect(_on_text_changed)
	
	func _on_text_changed():
		#if text == "":
			#return
		_request_code_completion(false)
	
	func _request_code_completion(force: bool) -> void:
		if text == "" and not force:
			_clear_popup()
			return
		var input_text = _get_input_text()
		
		var completions = {}
		var scope_names = scope_dict.keys()
		if input_text.strip_edges().is_empty():
			for scope in scope_names:
				completions[scope] = {}
			_build_popup(completions)
			return
		
		var global_class_list = ProjectSettings.get_global_class_list()
		var global_class_dict = {}
		for class_dict in global_class_list:
			var _class_name = class_dict.get("class")
			var path = class_dict.get("path")
			global_class_dict[_class_name] = path
		var global_class_names = global_class_dict.keys()
		
		var words = input_text.split(" ", false)
		var first_word = words[0]
		if first_word in scope_names:
			var scope_data = combined_scope_dict.get(first_word)
			var script = scope_data.get("script")
			if script != null:
				if UNode.has_static_method_compat("get_completion", script):
					var comp_data = _get_script_completion(script)
					if not comp_data.is_empty():
						completions = comp_data
			
		elif first_word in global_class_names:
			var script = UtilsLocal.ConsoleGlobalClass
			if script != null:
				var comp_data = _get_script_completion(script)
				if not comp_data.is_empty():
					completions = comp_data
		else:
			if words.size() != 1:
				return
			for scope in scope_names:
				if scope.to_lower().begins_with(first_word.to_lower()):
					completions[scope] = {CommandKeys.METADATA:{CommandKeys.REPLACE_WORD:true}}
			_build_popup(completions)
			return
		
		var command_meta = completions.get(CommandKeys.COMMAND_META, {})
		var show_variables = command_meta.get(CommandKeys.SHOW_VARIABLES, false)
		if show_variables:
			if input_text.find(" --") > -1:
				var var_nms = variable_dict.keys()
				if not completions.is_empty() and not var_nms.is_empty():
					completions["%sep"] = {}
				for nm in var_nms:
					completions[nm] = {}
		
		_build_popup(completions)
	
	func _build_popup(item_dict:Dictionary):
		#_clear_popup()
		item_dict.erase(CommandKeys.COMMAND_META)
		if item_dict.is_empty():
			_clear_popup()
			return
		#await get_tree().process_frame
		if is_instance_valid(popup):
			popup.clear()
		else:
			popup = AutoCompletePopup.new()
			popup.line_edit = self
			#popup.window_input.connect(_on_popup_window_input)
			#EditorInterface.get_base_control().add_child(popup)
			add_child(popup)
		
		popup.create_items(item_dict)
		#PopupHelper.parse_dict_static(item_dict, popup, _popup_pressed)
		
		var wind_pos
		if BACKPORTED >= 3:
			wind_pos = DisplayServer.window_get_position(get_window().get_window_id())
		else:
			wind_pos = DisplayServer.window_get_position()
		
		#await get_tree().process_frame
		var popup_pos = wind_pos + Vector2i(global_position + get_caret_draw_pos())
		popup_pos = get_caret_draw_pos()
		popup_pos += Vector2(25, -size.y)
		popup.position = popup_pos
		
		
		
		popup.show()
		
		#popup.popup()
		#popup.grab_focus()
		#popup.set_focused_item(0)
	
	func _clear_popup():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	
	func _on_popup_window_input(event:InputEvent):
		return
		if not has_focus():
			return
		var to_skip = [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]
		if event is InputEventKey:
			var keycode = event.keycode
			if keycode in to_skip:
				return
			elif keycode == KEY_SPACE:
				popup.get_viewport().set_input_as_handled()
		
		get_viewport().push_input(event)
	
	func _popup_pressed(id, _popup:PopupMenu):
		#var menu_path = UtilsRemote.PopupHelper.parse_menu_path(id, popup) # maybe use this to allow submenus
		var id_text = UtilsRemote.PopupHelper.parse_id_text(id, _popup)
		var metadata = UtilsRemote.PopupHelper.get_metadata(id, _popup)
		
		var text_to_add = id_text
		var add_args = metadata.get(CommandKeys.ADD_ARGS, false)
		if add_args:
			text_to_add = text_to_add + " --"
		
		var replace_word = metadata.get(CommandKeys.REPLACE_WORD, false)
		if replace_word:
			start_action(TextEdit.ACTION_TYPING)
			select_word_under_caret()
			var text_to_insert = text_to_add + " "
			insert_text_at_caret(text_to_insert)
			end_action()
			return
		_insert_text(text_to_add)
	
	func _insert_text(new_text):
		new_text = _check_for_leading_space(new_text)
		insert_text_at_caret(new_text + " ")
	
	func _check_for_leading_space(new_text):
		var word_under_caret = get_word_under_caret()
		if word_under_caret == "":
			if get_caret_column() > 0:
				if text[get_caret_column() - 1] != " ":
					new_text = " " + new_text
		
		return new_text
	
	func _get_script_completion(script):
		var tokenizer = UtilsLocal.ConsoleTokenizer.new()
		tokenizer.editor_console = editor_console
		var input_text = _get_input_text()
		var result = tokenizer.parse_command_string(input_text)
		var script_comp_data = script.get_completion(input_text, result.commands, result.args)
		
		if script_comp_data == null:
			script_comp_data = {}
		if script_comp_data is Dictionary:
			pass
		elif script_comp_data.has_method("get_commands"):
			script_comp_data = script_comp_data.get_commands()
		else:
			print("Error getting completion in object: %s" % script)
			script_comp_data = {}
		return script_comp_data
	
	func _get_input_text():
		if os_mode:
			return "os " + text
		return text
	
	func _unhandled_key_input(event: InputEvent) -> void:
		if not has_focus():
			return
		
		
		
		accept_event()
		


class AutoCompletePopup extends Panel:
	
	var line_edit
	
	var margin = MarginContainer.new()
	var item_list = ItemList.new()
	
	func _init() -> void:
		var sb = item_list.get_theme_stylebox("panel").duplicate()
		sb.bg_color = ALibEditor.Utils.UEditorTheme.ThemeColor.get_theme_color(ALibEditor.Utils.UEditorTheme.ThemeColor.Type.BASE)
		
		#top_level = true
		item_list.focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(200, 200)
	
	func _ready() -> void:
		add_child(margin)
		#ALibRuntime.NodeUtils.NUMarginContainer.set_margins(margin, 4)
		margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		margin.add_child(item_list)
		item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	func create_items(item_dict):
		for item in item_dict.keys():
			item_list.add_item(item)
			print(item_dict[item])
	
	
	func clear():
		item_list.clear()
	
	
	
	
