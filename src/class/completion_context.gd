
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UString = UtilsRemote.UString

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleLineEdit = UtilsLocal.ConsoleLineContainer.ConsoleLineEdit

static var _arg_delim_regex:RegEx

var line_edit:ConsoleLineEdit

var console_display_string:String


var command_statements = []
var current_command_statement_index:int = 0
var adjusted_command_caret:int

var chained_command:=false
# common used

var execute:bool = false
var expanded_command_statements:= []
var unconsumed_tokens:= []
var data := {}

var input:String
var output:String
var output_rich:String
var error:String
#

# headless
var print:= true
var add_to_hist:=true
#

var _alias_dict:= {}

var caret_col:int
var char_before_cursor:String
var word_before_cursor:String
var token_before_cursor:String
var raw_text:String
var input_text:String
var expanded_text:String

var commands:Array
var arguments:Array
var display_text:String

var argument_index:int = -1

func _init(text:="") -> void:
	if not is_instance_valid(_arg_delim_regex):
		_arg_delim_regex = RegEx.new()
		#_arg_delim_regex.compile("(--)(?:[ ]|$)")
		_arg_delim_regex.compile("(-- )") # simple seems to be the best
	
	raw_text = text
	caret_col = text.length()



func parse():
	var console = EditorConsoleSingleton.get_instance()
	var os_mode = console.os_mode
	
	if is_instance_valid(line_edit):
		raw_text = line_edit.text
		
		word_before_cursor = line_edit.get_word_at_pos(line_edit.get_caret_draw_pos())
		if word_before_cursor == "":
			if char_before_cursor == "-":
				var arg_check_i = caret_col - 2
				if arg_check_i > -1 and raw_text[arg_check_i] == "-":
					word_before_cursor = "--"
		
		caret_col = line_edit.get_caret_column()
	
	
	# visual statements
	command_statements = [raw_text]
	if raw_text.contains("|"):
		var command_start = command_statements.size()
		command_statements = UString.string_safe_split(raw_text, "|", true)
		for i in range(command_statements.size()):
			var statement:String = command_statements[i]
			var statement_idx = raw_text.find(statement, command_start)
			var statement_end = statement_idx + statement.length()
			command_start = statement_end + 1
			if statement_idx <= caret_col and statement_end >= caret_col:
				current_command_statement_index = i
				adjusted_command_caret = caret_col - statement_idx
			
			command_statements[i] = statement#.strip_edges()
	
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var token_data = tokenizer.parse_command_string(raw_text, true)
	
	
	expanded_text = " ".join(token_data.expanded)
	print(expanded_text)
	# logical statements
	expanded_command_statements = [expanded_text]
	if expanded_text.contains("|"):
		expanded_command_statements = UString.string_safe_split(expanded_text, "|", true)
	
	
	
	input_text = expanded_text
	#if line_edit.os_mode and not input_text.strip_edges().begins_with("os"):
	if os_mode and not input_text.strip_edges().begins_with("os"):
		input_text = "os " + expanded_text # add os so that the parser triggers, will be consumed by the os node
	
	print("input text: ", input_text)
	
	#print(input_text)
	#print(raw_text)
	#print(caret_col)
	#print(current_command_statement_index)
	
	
	char_before_cursor = ""
	if caret_col - 1 > -1:
		char_before_cursor = raw_text[caret_col - 1]
	
	#word_before_cursor = line_edit.get_word_at_pos(line_edit.get_caret_draw_pos())
	#if word_before_cursor == "":
		#if char_before_cursor == "-":
			#var arg_check_i = caret_col - 2
			#if arg_check_i > -1 and raw_text[arg_check_i] == "-":
				#word_before_cursor = "--"
	
	#words = input_text.split(" ", false)
	
	#var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var result = tokenizer.parse_command_string(input_text)
	var command_tokens = result.commands
	print("IN RES::", result)
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
	
	#var left_tokens = tokenizer.parse_command_string(input_text.left(caret_col))
	token_before_cursor = ""
	if command_tokens.size() > 0:
		var idx = 0
		var start_idx = 0
		for t in command_tokens:
			var start_tok = raw_text.find(t, start_idx)
			var end_tok = start_tok + t.length()
			start_idx = end_tok
			if start_tok <= caret_col and end_tok >= caret_col:
				token_before_cursor = command_tokens[idx]
				break
			idx += 1
	
	unconsumed_tokens = command_tokens.duplicate()
	print("FINAL: ", unconsumed_tokens)
	#unconsumed_tokens = 



func completion_parse():
	var console = EditorConsoleSingleton.get_instance()
	var os_mode = console.os_mode
	
	if is_instance_valid(line_edit):
		raw_text = line_edit.text
		
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
		
		
	
	
	# visual statements
	var current_command_start = 0
	var current_command_end = 0
	command_statements = [raw_text]
	if raw_text.contains("|"):
		var command_start = 0
		command_statements = UString.string_safe_split(raw_text, "|", true)
		for i in range(command_statements.size()):
			var cmd_str:String = command_statements[i]
			var cmd_start = raw_text.find(cmd_str, command_start)
			var cmd_end = cmd_start + cmd_str.length()
			command_start = cmd_end + 1
			if cmd_start <= caret_col and cmd_end >= caret_col:
				current_command_statement_index = i
				adjusted_command_caret = caret_col - cmd_start
				current_command_start = cmd_start
				current_command_end = cmd_end
			
			command_statements[i] = cmd_str#.strip_edges()
	
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var current_command = command_statements[current_command_statement_index]
	if os_mode and not current_command.strip_edges().begins_with("os"):
		current_command = "os " + current_command # add os so that the parser triggers, will be consumed by the os node
	
	
	var current_token_data = tokenizer.parse_command_string(current_command, true)
	unconsumed_tokens = current_token_data.expanded #.duplicate()
	if "|" in unconsumed_tokens:
		unconsumed_tokens = unconsumed_tokens.slice(unconsumed_tokens.rfind("|"))
		unconsumed_tokens.remove_at(0)
	
	print(current_token_data.commands)
	print(current_token_data.expanded)
	arguments = current_token_data.args
	var arg_delim_match = _arg_delim_regex.search(raw_text, current_command_start, current_command_end)
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
	
	
	var typed_commands = current_token_data.commands
	token_before_cursor = ""
	if typed_commands.size() > 0:
		var idx = 0
		var start_idx = 0
		for t in typed_commands:
			var start_tok = raw_text.find(t, start_idx)
			var end_tok = start_tok + t.length()
			start_idx = end_tok
			if start_tok <= caret_col and end_tok >= caret_col:
				token_before_cursor = typed_commands[idx]
				break
			idx += 1
	
	print("FINAL: ", unconsumed_tokens)



func expand():
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var token_data = tokenizer.parse_command_string(raw_text, true)
	expanded_text = " ".join(token_data.expanded)
	print(expanded_text)
	# logical statements
	expanded_command_statements = [expanded_text]
	if expanded_text.contains("|"):
		expanded_command_statements = UString.string_safe_split(expanded_text, "|", true)

func execute_parse():
	var console = EditorConsoleSingleton.get_instance()
	var os_mode = console.os_mode
	input_text = raw_text
	#if line_edit.os_mode and not input_text.strip_edges().begins_with("os"):
	if os_mode and not input_text.strip_edges().begins_with("os"):
		input_text = "os " + raw_text # add os so that the parser triggers, will be consumed by the os node
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	var token_data = tokenizer.parse_command_string(raw_text, true)
	display_text = token_data.display
	unconsumed_tokens = token_data.expanded
	arguments = token_data.args

func tokens_empty_and_execute() -> bool:
	return unconsumed_tokens.is_empty() and execute

func tokens_empty() -> bool:
	return unconsumed_tokens.is_empty()

func in_arguments() -> bool:
	return argument_index > -1

func get_current_command_context_object():
	if command_statements.size() == 1:
		return self
	var adj_caret = adjusted_command_caret
	var ctx = new(command_statements[current_command_statement_index])
	ctx.caret_col = adj_caret
	ctx.parse()
	return ctx

func append_output(line:String, to_rich:=false) -> void:
	output += "\n" + line
	if to_rich:
		append_output_rich(line)

func append_output_rich(line:String) -> void:
	output_rich += "\n" + line

func append_error(line:String) -> void:
	error += "\n" + line

func append_output_with_pr(pr:UtilsRemote.UString.PrintRich, clear:=true):
	append_output(pr.get_raw_string())
	append_output_rich(pr.get_string(clear))


func _expand_token(token:String):
	return _alias_dict.get(token, token)
