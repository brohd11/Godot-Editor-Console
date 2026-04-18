extends EditorContextMenuPlugin

const SLOT = CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UString = UtilsRemote.UString
const Pr = UString.PrintRich

const CALL = "EditorConsole/Call"
const INFO = "EditorConsole/Info"

func _popup_menu(paths: PackedStringArray) -> void:
	var script_editor = Engine.get_main_loop().root.get_node(paths[0])
	var valid_items = _get_valid_items(script_editor)
	PopupWrapper.create_context_plugin_items(self, script_editor, valid_items, _callback)

func _callback(script_editor:CodeEdit, path):
	var word = script_editor.get_word_under_caret()
	if path == CALL:
		var ed_console = EditorConsoleSingleton.get_instance()
		if not is_instance_valid(ed_console):
			return
		var member_data = _get_member_info(script_editor)
		if member_data != null:
			var member_path = member_data.path
			var method_name = member_path
			var call_string = "script call -- %s" % method_name
			if member_path.find(".") > -1:
				method_name = UString.get_member_access_back(member_path)
				member_path = UString.trim_member_access_back(member_path)
				call_string = "script.%s call -- %s" % [member_path, method_name]
			
			ed_console.set_console_text(call_string)
			if not ed_console.console_line_container.console_line_edit.visible:
				ed_console._toggle_console()
			ed_console.console_line_container.console_line_edit.grab_focus()
		else:
			UtilsLocal.Print.error("Could not resolve access path for: %s" % word)
		
	elif path == INFO:
		var member_info_data = _get_member_info(script_editor)
		if member_info_data != null:
			Pr.new().append("Printing member info: ").append(member_info_data.path, UtilsLocal.Colors.ACCENT_MUTE).display()
			print(member_info_data.info)
		else:
			UtilsLocal.Print.error("Could not resolve access path for: %s" % word)


func _get_valid_items(script_editor:CodeEdit):
	var valid_items = {}
	var member_data = _get_member_info(script_editor)
	if member_data != null:
		valid_items[INFO] = {}
		var property_info = member_data.info
		if property_info is Dictionary and property_info.has("args"):
			var flags = property_info.get("flags")
			if flags & METHOD_FLAG_STATIC:
				valid_items[CALL] = {}
	
	return valid_items

func _get_member_info(script_editor:CodeEdit):
	var word = script_editor.get_word_under_caret()
	if word == "":
		return
	var current_script = EditorInterface.get_script_editor().get_current_script()
	var inner_classes = {"": current_script}
	inner_classes.merge(UClassDetail.script_get_inner_classes(current_script))
	for path in inner_classes:
		var search = word
		if path != "":
			search = path + "." + word
		var member_info = UClassDetail.get_member_info_by_path(current_script, search)
		if member_info != null:
			return {"path": search, "info": member_info}
