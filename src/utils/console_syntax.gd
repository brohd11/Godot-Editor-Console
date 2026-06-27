extends SyntaxHighlighter

var default_text_color = EditorInterface.get_editor_settings().get("text_editor/theme/highlighting/text_color")

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer
const Colors = UtilsLocal.Colors

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const Pr = UString.PrintRich
const UClassDetail = UtilsRemote.UClassDetail
const EditorColors = UtilsRemote.EditorColors

const HIGHLIGHT_DELIMS = [" ", '"']

var current_ctx:UtilsLocal.CompletionContext

var global_names:= []
var var_names:= []
var scope_names:= []
var func_names:= []
var aliases:= []

var os_mode:bool

var setting_helper:UtilsRemote.SettingHelperEditor
var global_color:Color
var func_color:Color

func _init() -> void:
	setting_helper = UtilsRemote.SettingHelperEditor.new()
	setting_helper.subscribe_property(self, &"global_color", "text_editor/theme/highlighting/user_type_color", Color())
	setting_helper.subscribe_property(self, &"func_color", "text_editor/theme/highlighting/gdscript/function_definition_color", Color())
	setting_helper.initialize()

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text_edit = get_text_edit()
	var line_text = text_edit.get_line(line)
	if os_mode:
		return check_keyword(line_text, ["os"], Colors.SCOPE, 0)
	
	global_names = UClassDetail.get_all_global_class_paths().keys()
	if is_instance_valid(current_ctx):
		var_names = current_ctx.variables.keys()
		scope_names = current_ctx.scopes.keys()
		func_names = current_ctx.functions.keys()
		aliases = current_ctx.aliases.keys()
	
	var hl_info = {}
	
	hl_info.merge(check_keyword(line_text, ConsoleTokenizer.HL_TOKENS, Colors.SYMBOL))
	hl_info.merge(check_keyword(line_text, scope_names, Colors.SCOPE))
	hl_info.merge(check_keyword_variables(line_text, var_names, Colors.VAR_GREEN))
	
	var global_name_hl = check_keyword(line_text, global_names, global_color)
	hl_info.merge(global_name_hl)
	
	hl_info.merge(check_keyword(line_text, func_names, func_color)) # these should have new colors
	hl_info.merge(check_keyword(line_text, aliases, Colors.VAR_GREY))
	
	var hl_info_keys = hl_info.keys()
	hl_info_keys.sort()
	var sorted = {}
	for idx in hl_info_keys: 
		sorted[idx] = hl_info[idx]
	return sorted

func check_keyword(line_text:String, keywords:Array, color:Color, max_idx:=-1) -> Dictionary:
	if max_idx == -1:
		max_idx = line_text.length()
	var hl_info = {}
	for keyword in keywords:
		var key_idx = line_text.find(keyword)
		while key_idx > -1 and key_idx <= max_idx:
			var end_idx = key_idx + keyword.length()
			var valid_hl = false
			if line_text.length() == end_idx:
				valid_hl = true
			if line_text.length() > end_idx:
				if line_text[end_idx] in HIGHLIGHT_DELIMS or line_text[end_idx] == ".":
					valid_hl = true
			if key_idx - 1 > -1:
				if not line_text[key_idx - 1] in HIGHLIGHT_DELIMS:
					valid_hl = false
			if valid_hl:
				hl_info[key_idx] = {"color":color}
				hl_info[end_idx] = {"color":default_text_color}
			key_idx = line_text.find(keyword, end_idx)
	
	return hl_info

func check_keyword_variables(line_text:String, keywords:Array, color:Color, max_idx:=-1) -> Dictionary:
	if max_idx == -1:
		max_idx = line_text.length()
	
	var matches = ConsoleTokenizer.get_variable_regex().search_all(line_text)
	if matches.is_empty():
		return {}
	
	var hl_info = {}
	for m in matches:
		var string = m.get_string()
		if current_ctx.variables.has(string):
			hl_info[m.get_start()] = {"color":color}
			hl_info[m.get_end()] = {"color":default_text_color}
		else:
			hl_info[m.get_start()] = {"color":Colors.VAR_GREY}
			hl_info[m.get_end()] = {"color":default_text_color}
	
	return hl_info
