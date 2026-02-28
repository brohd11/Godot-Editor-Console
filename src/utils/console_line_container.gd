extends HBoxContainer

const BACKPORTED = 100

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UResource = UtilsRemote.UResource
const PopupHelper = UtilsRemote.PopupHelper
const UNode = UtilsRemote.UNode
const UList = UtilsRemote.UList

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const CommandKeys = UtilsLocal.ParsePopupKeys
const Commands = UtilsLocal.ConsoleCommandObject
const CompletionContext = UtilsLocal.CompletionContext


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
	var editor_console:EditorConsoleSingleton # could probably get rid of...
	var popup:AutoCompletePopup
	
	var variable_dict = {}
	var scope_dict = {}
	var combined_scope_dict = {}
	var os_mode:= false
	
	var _debounce_timer:Timer
	
	signal gui_event_passthrough(event:InputEvent)
	
	func _ready() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("line_spacing", 0)
		caret_blink = true
		auto_brace_completion_enabled = true
		code_completion_enabled = true
		text_changed.connect(_on_text_changed)
		gui_input.connect(_on_gui_input)
		focus_exited.connect(_on_focus_exited)
		_create_timer()
	
	func _on_focus_exited():
		_clear_popup()
	
	func _clear_popup():
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	
	func _create_timer():
		_debounce_timer = Timer.new()
		_debounce_timer.one_shot = true
		_debounce_timer.wait_time = 0.1
		add_child(_debounce_timer)
		_debounce_timer.timeout.connect(_request_code_completion.bind(false))
	
	func _on_text_changed():
		_debounce_timer.start()
	
	func _request_code_completion(force: bool) -> void:
		if not force and (text == ""):# or first_word == ""):
			_clear_popup()
			return
		
		var completion_context = CompletionContext.new(self)
		
		var scope_names = completion_context.scope_names
		var global_class_names = completion_context.global_class_names
		var first_word:String = completion_context.first_word
		
		var commands = Commands.new()
		if not (first_word in scope_names or first_word in global_class_names):
			var list_all = first_word == "" or first_word.length() == 1
			for scope:String in scope_names:
				if list_all:
					commands.add_command(scope)
				elif first_word.is_subsequence_ofn(scope):
					commands.add_command(scope)
			_build_popup(commands.get_commands())
			return
		
		if completion_context.word_before_cursor == first_word:
			_clear_popup()
			return
		
		var command_script = null
		if first_word in scope_names:
			var scope_data = combined_scope_dict.get(first_word)
			command_script = scope_data.get("script")
		elif first_word in global_class_names:
			command_script = editor_console.get_scope_script("global")
		if command_script != null:
			if UNode.has_static_method_compat("get_completion", command_script):
				var comp_data = command_script.get_completion(completion_context)
				if comp_data != null:
					if comp_data is Dictionary:
						commands.set_commands(comp_data)
					else:
						print("Error getting completion in object: %s" % command_script)
		
		var command_meta = commands.get_commands().get(CommandKeys.COMMAND_META, {}) # should this be from the commands?
		var show_variables = command_meta.get(CommandKeys.SHOW_VARIABLES, false)
		show_variables = true #ALERT
		if completion_context.input_text.find(Commands.get_arg_delimiter(false)) > -1:
			commands.remove_command(Commands.get_arg_delimiter(false))
			if show_variables:
				var var_nms = variable_dict.keys()
				if var_nms.size() > 0:
					commands.add_separator("Variables")
				for nm in var_nms:
					commands.add_command(nm)
		
		_build_popup(commands.get_commands())
	
	
	func _build_popup(item_dict:Dictionary):
		item_dict.erase(CommandKeys.COMMAND_META)
		if item_dict.is_empty():
			_clear_popup()
			return
		
		var word_before_cursor = get_word_at_pos(get_caret_draw_pos())
		var word_idx = get_caret_column() - 1
		var pos = get_caret_draw_pos()
		if word_idx > -1:
			var char_width = get_rect_at_line_column(get_caret_line(), 0).size.x
			while word_idx > 0:
				var _char = text[word_idx]
				if _char == " ":
					break
				word_idx -= 1
			word_idx = min(word_idx, text.length())
			pos = Vector2(get_pos_at_line_column(get_caret_line(), word_idx))
			if word_idx > 0:
				pos.x += char_width * 2
		pos.y = 0
		
		if is_instance_valid(popup):
			popup.clear()
		else:
			popup = AutoCompletePopup.new()
			popup.item_selected.connect(_on_item_selected)
			add_child(popup)
		
		
		popup.set_popup_position(pos)
		popup.create_items(item_dict)
		popup.select_closest_item(word_before_cursor)
	
	
	#^ Look at this stuff TODO
	 
	func _on_item_selected(id_text:String, metadata:Dictionary):
		var text_to_add = id_text
		var add_args = metadata.get(CommandKeys.ADD_ARGS, false)
		if add_args:
			text_to_add = text_to_add + " --"
		
		var replace_word = metadata.get(CommandKeys.REPLACE_WORD, false)
		if replace_word and get_word_at_pos(get_caret_draw_pos()) != "":
			start_action(TextEdit.ACTION_TYPING)
			var idxes = _get_indexes_before_caret()
			var start = idxes.start
			text = text.erase(start, idxes.caret - start)
			text_to_add += " "
			text = text.insert(start, text_to_add)
			set_caret_column(start + text_to_add.length())
			end_action()
			_on_text_changed()
			return
		_insert_text(text_to_add)
		
	
	func _insert_text(new_text):
		#new_text = _check_for_leading_space(new_text)
		insert_text_at_caret(new_text + " ")
	
	func _check_for_leading_space(new_text):
		var word_under_caret = get_word_at_pos(get_caret_draw_pos())
		if word_under_caret == "" and get_caret_column() > 0:
			#if text[get_caret_column() - 1] != " ":
			print("ADDOING")
			new_text = " " + new_text
		
		return new_text
	
	#func _check_for_leading_space(new_text):
		#var word_under_caret = get_word_under_caret()
		#if word_under_caret == "":
			#if get_caret_column() > 0:
				#if text[get_caret_column() - 1] != " ":
					#new_text = " " + new_text
		#
		#return new_text
	
	
	func _get_indexes_before_caret():
		var caret_col = get_caret_column()
		var substring = text.substr(0, caret_col).strip_edges()
		var space_idx = UtilsRemote.UString.rfind_index_safe(substring, " ", caret_col)
		if space_idx == -1:
			space_idx = 0
		elif text.substr(0, space_idx).strip_edges() == "":
			space_idx = 0
		else:
			space_idx += 1
		return {"start":space_idx, "caret": caret_col}
	
	
	#^r INPUT ------------
	
	
	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventKey:
			if event.pressed:
				if event.as_text_keycode() == "Ctrl+Backspace":
					_ctrl_backspace()
					accept_event()
				
				var popup_mode = is_instance_valid(popup) and popup.visible
				var popup_selected = popup_mode and popup.has_selection()
				if not popup_mode:
					var to_pass = [KEY_UP, KEY_DOWN, KEY_ENTER]
					if event.keycode in to_pass:
						gui_event_passthrough.emit(event)
						accept_event()
				else:
					var to_accept = [KEY_UP, KEY_DOWN, KEY_ESCAPE, KEY_ENTER]
					if event.keycode == KEY_UP:
						popup.previous_item()
					elif event.keycode == KEY_DOWN:
						popup.next_item()
					elif event.keycode == KEY_ESCAPE:
						_clear_popup()
					elif event.keycode == KEY_ENTER:
						if popup_selected:
							popup.activate_item()
						else:
							gui_event_passthrough.emit(event)
							_clear_popup()
					elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
						_clear_popup()
					
					if event.keycode in to_accept:
						accept_event()
	
	
	func _ctrl_backspace():
		start_action(TextEdit.ACTION_BACKSPACE)
		var idxes = _get_indexes_before_caret()
		var start = idxes.start
		text = text.erase(start, idxes.caret - start)
		set_caret_column(start)
		end_action()
		_on_text_changed()


class AutoCompletePopup extends Panel:
	var item_list = ItemList.new()
	
	var _position:Vector2 = Vector2.ZERO
	var last_item_hash:int
	
	signal item_selected(id_text:String, metadata:Dictionary)
	
	func _init() -> void:
		#var panel_sb = EditorInterface.get_editor_theme().get_stylebox("panel", "Panel").duplicate()
		#panel_sb.bg_color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.BACKGROUND)
		#add_theme_stylebox_override("panel", panel_sb)
		
		var sb = item_list.get_theme_stylebox("panel").duplicate()
		#sb.set_content_margin_all(8)
		sb.bg_color = UtilsRemote.EditorColors.get_theme_color(UtilsRemote.EditorColors.ThemeColor.BACKGROUND)
		item_list.add_theme_stylebox_override("panel", sb)
		item_list.gui_input.connect(_item_list_gui_input)
		item_list.auto_height = true
		item_list.auto_width = true
		item_list.focus_mode = Control.FOCUS_NONE
	
	func _ready() -> void:
		modulate.a = 0
		add_child(item_list)
		item_list.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	
	func create_items(item_dict:Dictionary):
		var _hash = item_dict.hash()
		if _hash != last_item_hash:
			modulate.a = 0
			custom_minimum_size.y = 0
			size.y = 0
		last_item_hash = _hash
		
		for item in item_dict.keys():
			var data = item_dict[item]
			var idx = item_list.item_count
			var icon = data.get(CommandKeys.ICON, [])
			if icon.is_empty():
				icon = null
			else:
				icon = icon[0]
			
			var sep_string = CommandKeys.get_seperator(item)
			if sep_string == null:
				item_list.add_item(item)
			else:
				item_list.add_item(sep_string ,null, false)
				item_list.set_item_disabled(idx, true)
			
			item_list.set_item_icon(idx, icon)
			item_list.set_item_metadata(idx, data.get(CommandKeys.METADATA, {}))
		
		
		await get_tree().process_frame
		
		var rect = item_list.get_item_rect(0)
		var sep = UResource.create_rect_texture(Color.GRAY, rect.size.x)
		for i in range(item_list.item_count):
			if item_list.is_item_selectable(i):
				continue
			if item_list.get_item_text(i) != "":
				continue
			item_list.set_item_icon(i, sep)
		
		custom_minimum_size.y = item_list.get_rect().size.y
		set_anchors_preset(PRESET_BOTTOM_LEFT)
		offset_popup()
		modulate.a = 1
	
	func set_popup_position(new_pos:Vector2):
		_position = new_pos
	
	func offset_popup(offset_y:= -size.y):
		position = _position + Vector2(0, offset_y)
	
	func clear():
		item_list.clear()
	
	func has_selection():
		return not item_list.get_selected_items().is_empty()
	
	func activate_item():
		var selected = item_list.get_selected_items()
		if selected.is_empty():
			return
		selected = selected[0]
		var id_text = item_list.get_item_text(selected)
		var metadata = item_list.get_item_metadata(selected)
		if metadata == null:
			metadata = {}
		item_selected.emit(id_text, metadata)
	
	
	func next_item():
		var selected = _get_selected_idx()
		var next = UList.get_next_item(item_list.item_count, selected)
		if next == -1:
			return
		var first_next = next
		while not item_list.is_item_selectable(next) and next != first_next - 1:
			next = UList.get_next_item(item_list.item_count, next)
		item_list.select(next)
	
	func previous_item():
		var selected = _get_selected_idx()
		var prev = UList.get_previous_item(item_list.item_count, selected)
		if prev == -1:
			return
		var first_prev = prev
		while not item_list.is_item_selectable(prev) and prev != first_prev + 1:
			prev = UList.get_previous_item(item_list.item_count, prev)
		item_list.select(prev)
	
	func _get_selected_idx():
		var selected = item_list.get_selected_items()
		if not selected.is_empty():
			return selected[0]
		else:
			return -1
	
	func select_closest_item(word:String):
		if word == "":
			return
		var items = {}
		for i in range(item_list.item_count):
			if not item_list.is_item_selectable(i): continue
			items[i] = item_list.get_item_text(i)
		if items.is_empty():
			return
		var sorted = UtilsRemote.UString.Filter.subsequence_sorted(items.values(), [word])
		if sorted.is_empty(): return
		for s in sorted:
			if s.begins_with(word):
				item_list.select(items.find_key(s))
				return
		item_list.select(items.find_key(sorted[0]))
	
	
	func _item_list_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var item_at_pos = item_list.get_item_at_position(event.position)
				if item_at_pos == -1:
					return
				if item_list.is_item_selectable(item_at_pos):
					item_list.select(item_at_pos)
					activate_item()
				
		if event is InputEventMouseMotion:
			var item_at_pos = item_list.get_item_at_position(event.position)
			if item_at_pos == -1:
				return
			if not item_list.is_item_selectable(item_at_pos):
				accept_event()
	
