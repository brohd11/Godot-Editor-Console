
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UString = UtilsRemote.UString

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleLineEdit = UtilsLocal.ConsoleLineContainer.ConsoleLineEdit
const ExitCode = UtilsLocal.CommandBase.ExitCode

const CompletionContext = UtilsLocal.CompletionContext

static var _arg_delim_regex:RegEx
static var _clean_output_regex:RegEx

var line_edit:ConsoleLineEdit

var console_display_string:String


var command_statements:Array = []
var current_command_statement_index:int = 0
var current_command_caret:int
var expanded_text:String # this is the text the console runs

var chained_command:=false
# common used

var execute:bool = false
var expanded_command_statements:= []
var unconsumed_tokens:= []
var data := {}

var root_ctx:CompletionContext
var positional_args := []
var variables := {}
var functions := {}

var input:String
var output:String
var error:String
var exit_code:ExitCode = ExitCode.OK
#

# headless
var print:= false
var add_to_hist:=false
#
var raw_text:String
var caret_col:int
var char_before_cursor:String
var word_before_cursor:String
var token_before_cursor:String




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

func set_positional_args(args:Array):
	var arg_size = args.size()
	for i in range(20):
		var val = ""
		if i < arg_size:
			val = args[i]
		variables["$" + str(i)] = val
	
	variables["$@"] = " ".join(args)

func set_line_edit(_line_edit:CodeEdit):
	line_edit = _line_edit
	raw_text = line_edit.text
		
	word_before_cursor = line_edit.get_word_at_pos(line_edit.get_caret_draw_pos())
	if word_before_cursor == "":
		if char_before_cursor == "-":
			var arg_check_i = caret_col - 2
			if arg_check_i > -1 and raw_text[arg_check_i] == "-":
				word_before_cursor = "--"
	
	caret_col = line_edit.get_caret_column()


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
	if not raw_text.contains("|"): # set adjusted to caret, we can always work of adjusted
		current_command_caret = caret_col
	else:
		var command_start = 0
		command_statements = UString.string_safe_split(raw_text, "|", true)
		for i in range(command_statements.size()):
			var cmd_str:String = command_statements[i]
			var cmd_start = raw_text.find(cmd_str, command_start)
			var cmd_end = cmd_start + cmd_str.length()
			command_start = cmd_end + 1
			if cmd_start <= caret_col and cmd_end >= caret_col:
				current_command_statement_index = i
				current_command_caret = caret_col - cmd_start
				current_command_start = cmd_start
				current_command_end = cmd_end
			
			command_statements[i] = cmd_str#.strip_edges()
	
	
	
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	tokenizer.variables = variables
	var current_command = command_statements[current_command_statement_index]
	if os_mode and not current_command.strip_edges().begins_with("os"):
		current_command = "os " + current_command # add os so that the parser triggers, will be consumed by the os node
	
	
	var current_token_data = tokenizer.parse_command_string(current_command, true)
	unconsumed_tokens = current_token_data.expanded #.duplicate()
	if "|" in unconsumed_tokens:
		unconsumed_tokens = unconsumed_tokens.slice(unconsumed_tokens.rfind("|"))
		unconsumed_tokens.remove_at(0)
	
	#print(current_token_data.commands)
	#print(current_token_data.expanded)
	
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
		token_before_cursor = typed_commands[typed_commands.size() - 1]
		var end = current_command.length()
		for i in range(typed_commands.size() - 1, -1, -1):
			var cmd = typed_commands[i]
			var idx = UString.rfind_index_safe(current_command, cmd, end)
			end = idx
			if idx < current_command_caret:
				token_before_cursor = cmd
				break
	
	
	#print("FINAL: ", unconsumed_tokens)


#! keys commands:Array display:String
static func expand_commands(text:String, variable_dict:Dictionary):
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	tokenizer.variables = variable_dict
	var token_data = tokenizer.parse_command_string(text, true)
	var all_expanded_text = " ".join(token_data.expanded)
	# logical statements
	var valid_expanded_command_statements = [all_expanded_text]
	if all_expanded_text.contains("|"):
		valid_expanded_command_statements = UString.string_safe_split(all_expanded_text, "|", true)
	return {
		&"commands": valid_expanded_command_statements,
		&"display": token_data.display
	}

func expand():
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	tokenizer.variables = variables
	var token_data = tokenizer.parse_command_string(raw_text, true)
	expanded_text = " ".join(token_data.expanded)
	# logical statements
	expanded_command_statements = [expanded_text]
	if expanded_text.contains("|"):
		expanded_command_statements = UString.string_safe_split(expanded_text, "|", true)

func execute_parse():
	if expanded_command_statements.is_empty():
		expand()
	
	var console = EditorConsoleSingleton.get_instance()
	var os_mode = console.os_mode
	var text_in = raw_text
	var stripped = text_in.strip_edges()
	if os_mode and not stripped.is_empty() and not stripped.begins_with("os"):
		text_in = "os " + text_in # add os so that the parser triggers, will be consumed by the os node
	
	var tokenizer = UtilsLocal.ConsoleTokenizer.new()
	tokenizer.variables = variables
	var token_data = tokenizer.parse_command_string(text_in, true)
	display_text = token_data.display
	unconsumed_tokens = token_data.expanded
	arguments = token_data.args
	execute = true # expanded text used for input, set in "expand"

func tokens_empty_and_execute() -> bool:
	return unconsumed_tokens.is_empty() and execute

func tokens_empty() -> bool:
	return unconsumed_tokens.is_empty()

func in_arguments() -> bool:
	return argument_index > -1

func get_current_command():
	return command_statements[current_command_statement_index]

func get_current_command_context_object():
	if command_statements.size() == 1:
		return self
	var adj_caret = current_command_caret
	var ctx = new(command_statements[current_command_statement_index])
	ctx.caret_col = adj_caret
	ctx.completion_parse() # what parse should this be? is this irrelevant?
	return ctx

func append_output(line:String) -> void:
	output += "\n" + line

func append_error(line:String) -> void:
	error += "\n" + line


func clean_output():
	return clean_text(output)

func clean_text(text:String):
	if not is_instance_valid(_clean_output_regex):
		_clean_output_regex = RegEx.new()
		_clean_output_regex.compile("\\[color=[A-Za-z0-9]*]|\\[\\/color]")
	return _clean_output_regex.sub(text, "", true)


static func new_ctx(text:String, parent_ctx:CompletionContext=null):
	var ctx = CompletionContext.new(text)
	if is_instance_valid(parent_ctx):
		ctx.variables = parent_ctx.variables.duplicate()
		ctx.functions = parent_ctx.functions.duplicate()
		ctx.input = parent_ctx.input # non piped inherit input
		if is_instance_valid(parent_ctx.root_ctx):
			ctx.root_ctx = parent_ctx.root_ctx
		else:
			ctx.root_ctx = parent_ctx
	
	return ctx
