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

var global_names = []
var var_names = []
var scope_names = []

var os_mode:bool

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text_edit = get_text_edit()
	var line_text = text_edit.get_line(line)
	if os_mode:
		return check_keyword(line_text, ["os"], Colors.SCOPE, 0)
	
	global_names = UClassDetail.get_all_global_class_paths().keys()
	
	var hl_info = {}
	
	var cmd = line_text # temp for testing
	#var cmd_start = 0
	#for cmd in command_statements:
		#var cmd_start_index = line_text.find(cmd)
		#cmd_start = cmd_start_index + 1
		
	var other_token_hl = check_keyword(cmd, ConsoleTokenizer.HL_TOKENS, Colors.SYMBOL)
	hl_info.merge(other_token_hl)
	
	var scope_hl = check_keyword(cmd, scope_names, Colors.SCOPE)
	hl_info.merge(scope_hl)
	
	#var hidden_scope_hl = check_keyword(cmd, hidden_scope_names, scope_color)
	#hl_info.merge(hidden_scope_hl)
	
	var var_name_hl = check_keyword(cmd, var_names, Colors.VAR_GREEN)
	hl_info.merge(var_name_hl)
	
	var global_name_hl = check_keyword(cmd, global_names, EditorColors.get_syntax_color(EditorColors.SyntaxColor.ENGINE_TYPE))
	hl_info.merge(global_name_hl)
		
		
	
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
				if line_text[end_idx] == " " or line_text[end_idx] == ".":
					valid_hl = true
			if key_idx - 1 > -1:
				if line_text[key_idx - 1] != " ":
					valid_hl = false
			if valid_hl:
				hl_info[key_idx] = {"color":color}
				hl_info[end_idx] = {"color":default_text_color}
			key_idx = line_text.find(keyword, end_idx)
	
	return hl_info
