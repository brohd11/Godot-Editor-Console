
const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UClassDetail = UtilsRemote.UClassDetail
const UString = UtilsRemote.UString

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const ConsoleLineEdit = UtilsLocal.ConsoleLineEdit
const ExitCode = UtilsLocal.CommandBase.ExitCode

const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer

const CompletionContext = UtilsLocal.CompletionContext

static var _arg_delim_regex:RegEx
static var _clean_output_regex:RegEx

enum Propagate{
	VARIABLES,
	FUNCTIONS,
	ALIASES,
	PROPERTY,
}

var title:String

var console_container:UtilsLocal.ConsoleContainer
var line_edit:CodeEdit #:ConsoleLineEdit

var command_statements:Array = []
var current_command_statement_index:int = 0
var current_command_caret:int

# common used

var execute:bool = false
var expanded_command_statements:= []
var unconsumed_tokens:= []
var data := {}

var parent_ctx:CompletionContext

var positional_args := []
var variables := {}
var functions := {}
var aliases := {}
var scopes := {}

var cwd:String = ProjectSettings.globalize_path("res://")

var stdin:String
var stdout:String
var stderr:String
var last_status:int = ExitCode.OK
var exit_code:int = ExitCode.OK
var exit_requested:=false


# headless
var os_mode:=false
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
	
	if text.is_empty():
		title = "Un-Named Context"
	else:
		title = text
	
	raw_text = text
	caret_col = text.length()

func set_positional_args(path_or_name:String, args:Array):
	variables["$0"] = path_or_name
	positional_args = args

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
	#var console = EditorConsoleSingleton.get_instance()
	#var os_mode = console.os_mode
	
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
	if not raw_text.contains(" | "): # set adjusted to caret, we can always work of adjusted
		current_command_caret = caret_col
	else:
		var command_start = 0
		command_statements = UString.string_safe_split(raw_text, " | ", true)
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
	
	
	
	
	var tokenizer = ConsoleTokenizer.new(self)
	tokenizer.active_ctx = parent_ctx
	var current_command = command_statements[current_command_statement_index]
	if os_mode and not current_command.strip_edges().begins_with("os"):
		current_command = "os " + current_command # add os so that the parser triggers, will be consumed by the os node
	
	
	var current_token_data = tokenizer.parse_command_string_completion(current_command)

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


func execute_parse():
	var text_in = raw_text
	var stripped = text_in.strip_edges()
	if os_mode and not stripped.is_empty() and not stripped.begins_with("os"):
		text_in = "os " + text_in # add os so that the parser triggers, will be consumed by the os node
	
	var tokenizer = ConsoleTokenizer.new(self)
	tokenizer.execute = true
	var token_data = tokenizer.parse_command_string_execute(text_in)
	unconsumed_tokens = token_data.expanded
	arguments = token_data.args
	execute = true

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
	if  line.is_empty():
		return
	stdout += line.trim_suffix("\n") + "\n"

func strip_output_newlines():
	stdout = stdout.lstrip("\n").rstrip("\n")
	return stdout

func clean_output():
	return clean_text(stdout)

func clean_text(text:String):
	if not is_instance_valid(_clean_output_regex):
		_clean_output_regex = RegEx.new()
		_clean_output_regex.compile("\\[color=[A-Za-z0-9]*]|\\[\\/color]")
	return _clean_output_regex.sub(text, "", true)


func append_error(line:String) -> void:
	if line.is_empty():
		return
	stderr += line.trim_suffix("\n") + "\n"

func strip_error_newlines():
	stderr = stderr.lstrip("\n").rstrip("\n")
	return stderr

func get_variable(name:String):
	return ConsoleTokenizer.check_variable(name, self)

func get_root_ctx():
	var inherited = get_inherited_ctxs()
	if inherited.is_empty():
		return self
	return inherited.back()

func get_inherited_ctxs():
	var inherited = []
	if not is_instance_valid(parent_ctx):
		return inherited
	var parent:CompletionContext = parent_ctx
	while is_instance_valid(parent):
		inherited.append(parent)
		parent = parent.parent_ctx
	
	return inherited


static func new_ctx(text:String, parent:CompletionContext=null, sub_shell:=false):
	var ctx = CompletionContext.new(text)
	if is_instance_valid(parent):
		if not sub_shell: # so that function definitions do not populate up
			ctx.parent_ctx = parent
		
		ctx.console_container = parent.console_container
		ctx.cwd = parent.cwd
		ctx.execute = parent.execute
		ctx.os_mode = parent.os_mode # not sure that this is necessary?
		
		ctx.variables = parent.variables.duplicate()
		ctx.functions = parent.functions.duplicate()
		ctx.aliases = parent.aliases.duplicate()
		ctx.scopes = parent.scopes.duplicate()
		
		 # non piped inherit stdin, this will be overwritten if piped
		ctx.stdin = parent.stdin
	
	return ctx

func write_to_parent(parent:CompletionContext):
	parent.append_output(stdout.trim_suffix("\n"))
	parent.append_error(stderr.trim_suffix("\n"))
	exit_code = last_status
	parent.last_status = exit_code

func propogate(target:Propagate, key:String, value):
	var inher = get_inherited_ctxs()
	inher.append(self)
	match target:
		Propagate.VARIABLES: 
			for inh:CompletionContext in inher: 
				inh.variables[key] = value
		Propagate.FUNCTIONS:
			for inh:CompletionContext in inher: 
				inh.functions[key] = value
		Propagate.ALIASES:
			for inh:CompletionContext in inher: 
				inh.aliases[key] = value
		Propagate.PROPERTY:
			for inh:CompletionContext in inher:
				inh.set(key, value)
