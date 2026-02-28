
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleLineEdit = UtilsLocal.ConsoleLineContainer.ConsoleLineEdit
const Commands = UtilsLocal.ConsoleCommandBase.Commands

const ARG_DELIMITER = Commands.ARG_DELIMITER

var line_edit:ConsoleLineEdit

var caret_col:int
var char_before_cursor:String
var word_before_cursor:String
var raw_text:String
var input_text:String
var words:Array
var first_word:String

var has_arg_delimiter:=false

var commands:Array
var arguments:Array

var scope_names:Array
var global_classes:Dictionary
var global_class_names:Array

func _init(_line_edit:ConsoleLineEdit):
	line_edit = _line_edit
	
	raw_text = line_edit.text
	input_text = raw_text
	if line_edit.os_mode:
		input_text = "os " + raw_text
	
	caret_col = line_edit.get_caret_column()
	char_before_cursor = ""
	if caret_col - 1 > -1:
		char_before_cursor = raw_text[caret_col - 1]
	
	word_before_cursor = line_edit.get_word_at_pos(line_edit.get_caret_draw_pos())
	if word_before_cursor == "":
		if char_before_cursor == "-":
			var arg_check_i = caret_col - 2
			if arg_check_i > -1 and raw_text[arg_check_i] == "-":
				word_before_cursor = "--"
	
	
	words = input_text.split(" ", false)
	first_word = ""
	if not words.is_empty():
		first_word = words[0]
	
	has_arg_delimiter = input_text.find(Commands.get_arg_delimiter(false)) > -1
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var result = tokenizer.parse_command_string(input_text)
	commands = result.commands
	arguments = result.args
	
	scope_names = line_edit.scope_dict.keys()
	global_classes = UClassDetail.get_all_global_class_paths()
	global_class_names = global_classes.keys()
