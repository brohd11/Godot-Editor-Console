
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleLineEdit = UtilsLocal.ConsoleLineContainer.ConsoleLineEdit

static var _arg_delim_regex:RegEx

var line_edit:ConsoleLineEdit

# common used
var execute:bool = false
var unconsumed_tokens:= []
var data := {}
#

var caret_col:int
var char_before_cursor:String
var word_before_cursor:String
var token_before_cursor:String
var raw_text:String
var input_text:String

var words:Array

var commands:Array
var arguments:Array
var display_text:String

var argument_index:int= -1

func _init(_line_edit:ConsoleLineEdit):
	line_edit = _line_edit
	
	if not is_instance_valid(_arg_delim_regex):
		_arg_delim_regex = RegEx.new()
		#_arg_delim_regex.compile("(--)(?:[ ]|$)")
		_arg_delim_regex.compile("(-- )") # simple seems to be the best
	
	raw_text = line_edit.text
	input_text = raw_text
	if line_edit.os_mode and not input_text.strip_edges().begins_with("os"):
		input_text = "os " + raw_text # add os so that the parser triggers, will be consumed by the os node
	
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
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var result = tokenizer.parse_command_string(input_text)
	commands = result.commands
	arguments = result.args
	display_text = result.display

	var arg_delim_match = _arg_delim_regex.search(raw_text)
	if arg_delim_match:
		var delim_index = arg_delim_match.get_start(1)
		var arg_string = raw_text.substr(delim_index + 2)
		var adjusted_caret_idx = caret_col - (delim_index + 2)
		var start_idx = 0
		argument_index = arguments.size()
		if char_before_cursor != " ": # if a space before, assume next arg
			argument_index -= 1 # if it's actually in an arg, like string, this will be caught below
			
		for i in range(arguments.size()):
			var arg = arguments[i]
			var arg_start = arg_string.find(arg, start_idx)
			var arg_end = arg_start + arg.length()
			if adjusted_caret_idx >= arg_start and adjusted_caret_idx <= arg_end:
				argument_index = i
			
			start_idx = arg_end
	
	var left_tokens = tokenizer.parse_command_string(input_text.left(caret_col))
	token_before_cursor = ""
	if left_tokens.commands.size() > 0:
		token_before_cursor = left_tokens.commands[left_tokens.commands.size() - 1]
	
	unconsumed_tokens = commands.duplicate()

func tokens_empty_and_execute():
	return unconsumed_tokens.is_empty() and execute

func tokens_empty():
	return unconsumed_tokens.is_empty()

func in_arguments():
	return argument_index > -1
