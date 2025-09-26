extends EditorContextMenuPlugin

const CALL = "EditorConsole/Call"

func _popup_menu(paths: PackedStringArray) -> void:
	var script_editor = Engine.get_main_loop().root.get_node(paths[0])
	
	var valid_items = _get_valid_items(script_editor)
	PopupWrapper.create_context_plugin_items(self, script_editor, valid_items, _callback)

func _callback(script_editor:CodeEdit, path):
	if path == CALL:
		var ed_console = EditorConsole.get_instance()
		if not is_instance_valid(ed_console):
			return
		ed_console.set_console_text("script call -- %s" % script_editor.get_word_under_caret())
		if not ed_console.console_line_container.console_line_edit.visible:
			ed_console._toggle_console()
		
		ed_console.console_line_container.console_line_edit.grab_focus()


func _get_valid_items(script_editor:CodeEdit):
	var valid_items = {}
	var word = script_editor.get_word_under_caret()
	var current_script = EditorInterface.get_script_editor().get_current_script()
	var methods = current_script.get_script_method_list()
	for data in methods:
		var _name = data.get("name")
		if _name == word:
			var flags = data.get("flags")
			if flags & METHOD_FLAG_STATIC:
				valid_items[CALL] = {}
				break
	
	return valid_items
