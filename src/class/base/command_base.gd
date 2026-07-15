const PRINT_DEBUG = false

const UtilsRemote = preload("res://addons/editor_console/src/utils/console_utils_remote.gd")
const UString = UtilsRemote.UString
const Pr = UString.PrintRich


const USort = preload("uid://dtrbpu04wxss0") #! resolve ALibRuntime.Utils.USort

const UtilsLocal = preload("res://addons/editor_console/src/utils/console_utils_local.gd")
const Execution = UtilsLocal.Execution
const ConsoleTokenizer = UtilsLocal.ConsoleTokenizer
const ConsoleUndo = UtilsLocal.ConsoleUndo
const CompletionContext = UtilsLocal.CompletionContext
const Colors = UtilsLocal.Colors

const Options = UtilsLocal.Options

const _RESULTS_TO_SKIP = ["GDScriptFunctionState"]
const _UNAMED = "UnamedCommand"

enum ExitCode {
	OK,
	FAIL,
	ERR,
	HELP,
}

enum FlagType {
	NONE,
	FILE,
	DIR,
	CLASS,
}

static var _positional_arg_count_regex:RegEx

var _ctx_obj:CompletionContext

var consumed_tokens:Array[String] = []
var positional_args:Array[String] = []
var positional_arg_index = -1

var payload:Array = []
var payload_index = -1

func _initialize(ctx:CompletionContext):
	positional_args = []
	consumed_tokens = []
	_ctx_obj = ctx

static func get_command_name() -> String:
	return _UNAMED

func __get_name__():
	var nm = get_command_name()
	if nm == _UNAMED:
		_ctx_obj.append_output("Unamed Command in -> " + get_script().resource_path.get_file())
	return nm

static func get_self_command_data() -> Dictionary:
	return {_UNAMED: true}

#! keys i-Options.add_option;
static func _command_data(params:={}):
	return Options.process_option_dict(params)

func __get_self_command_data__() -> Dictionary:
	var params = get_self_command_data()
	if params.has(_UNAMED):
		_ctx_obj.append_output("Command doesn't have self_option_data defined -> " + get_script().resource_path.get_file())
		#print("Command doesn't have self_option_data defined -> ", get_script().resource_path.get_file())
		return {}
	if params.has(&"option_name"):
		return params
	var name = get_command_name()
	var processed = Options.get_single_option_dict(name, params)
	return processed

func get_help_string(full_string:bool=false) -> String:
	var help = get_self_command_data().get(&"help", "")
	if not full_string or help == "":
		return help
	
	var flags = get_flags()
	flags.erase(Options.Keys.COMMAND_META)
	if flags.size() > 0:
		help += "\nFlags:"
		# width of the widest flag name, so the help descriptions line up in a column
		var flag_width = 0
		for f in flags.keys():
			if Options.Keys.get_seperator(f) != null:
				continue
			flag_width = maxi(flag_width, f.length())
		for f in flags.keys():
			var separator = Options.Keys.get_seperator(f)
			if separator != null:
				# label already carries its own decorators (see Options.add_separator)
				help += "\n  " + separator if separator != "" else "\n"
				continue
			var f_help = flags[f].get(&"help", "")
			if f_help == "":
				help += "\n  " + f
				continue
			if f_help.contains("\n"):
				f_help = f_help.get_slice("\n", 0)
			help += "\n  " + f.rpad(flag_width) + "  " + f_help

	var commands = get_commands()
	commands.erase(Options.Keys.COMMAND_META)
	if commands.size() > 0:
		help += "\nSubcommands:"
		for c in commands.keys():
			help += "\n  " + c
	return help


func _route(ctx:CompletionContext): # shared by both passes
	_initialize(ctx)
	
	if PRINT_DEBUG:
		print("UNCONSUMED BEFORE::", ctx.unconsumed_tokens)
	
	#var self_command_data = __get_self_command_data__()
	var consume_exit = _consume_self(ctx)
	if consume_exit == ExitCode.HELP:
		if ctx.execute:
			_get_help_for_token(consumed_tokens.back())
		return ExitCode.HELP
	var flags = get_flags()
	var commands = get_commands()
	var consumed = 0
	var positional_count = 0
	var selected = null
	#for token in ctx.unconsumed_tokens:
	var i = 0
	while i < ctx.unconsumed_tokens.size():
		var token = ctx.unconsumed_tokens[i]
		i += 1
		if token == "--help":
			if ctx.execute: # i - 2 because we added 1 right away
				if i == 1:
					_get_help_for_token(consumed_tokens.back())
				else:
					_get_help_for_token(ctx.unconsumed_tokens[i - 2])
			return ExitCode.HELP
		
		var full_token = token # keep full to pass to flag
		token = _split_flag(token)
		var option_data = _get_option_data(token, flags, commands)
		if PRINT_DEBUG:
			print("DATA::", option_data)
		if token.begins_with("--") and not token == "--":
			if token in flags:
				# if flag has a token to consume after, unhandled currently
				_process_flag(full_token)
				consumed += 1
			else:
				ctx.append_error("Unrecognized flag: " + token)
				return ExitCode.ERR
		elif token in commands:
			if option_data.has(&"get_command"):
				selected = option_data.get_command.call()
			else:
				selected = _get_command(token)
			break
		else:
			positional_arg_index = 0 # set this to 0, -1 will be an invalid index or payload
			for j in range(consumed, ctx.unconsumed_tokens.size()):
				positional_count += 1
			
			if ctx.execute:
				if ctx.unconsumed_tokens.is_empty(): # not sure about this, think it's irrelavant
					selected = ExitCode.FAIL
				else:
					selected = null # ExitCode will cause an exit. null will attempt execute
					#for j in range(consumed, ctx.unconsumed_tokens.size()):
						#positional_count += 1
				break
			elif token != ctx.token_before_cursor:# or ctx.char_before_cursor == " ": # if you are past the current or char is ' ', do nothing?
				# meant to stop a completion if you are not at the end of the line
				# this may need some tweaking so that token before cursor is the token under cursor?
				#selected = ExitCode.FAIL
				break
			else:
				break
	
	if ctx.execute and selected is ExitCode and selected == ExitCode.FAIL:
		_get_help_for_token(ctx.unconsumed_tokens.front())
	
	for j in range(consumed):
		_consume_token(ctx)
	
	var in_payload = false
	var unwrap_setting = _unwrap_quotes()
	for j in range(positional_count):
		var pos_arg = _consume_token(ctx)
		var is_string:bool = UString.is_string_or_string_name(pos_arg)
		var tok_b_curs = ctx.token_before_cursor
		if PRINT_DEBUG:
			print(":", ctx.char_before_cursor, ":", tok_b_curs.length(), ":", tok_b_curs, ":", pos_arg.length(), ":", pos_arg, ":")
		
		var is_token_before_curs = tok_b_curs.replace(" ", "") == pos_arg.replace(" ", "")
		var new_token_index = false
		if is_token_before_curs:
			new_token_index = ctx.char_before_cursor == " " and not UString.is_string_or_string_name(tok_b_curs) and not tok_b_curs.ends_with(" ")
		
		if in_payload:
			if is_token_before_curs:
				payload_index = j
				if new_token_index:
					payload_index += 1
			if is_string:
				pos_arg = _route_unwrap(pos_arg, unwrap_setting)
			payload.append(pos_arg)
			continue
		elif not is_string and pos_arg.begins_with("--"):
			var split = _split_flag(pos_arg)
			if not split in flags:
				ctx.append_error("Unrecognized flag: " + split)
				return ExitCode.ERR
			_process_flag(pos_arg)  # check flags after the positionals
			continue
		elif pos_arg == "--":
			in_payload = true
			positional_arg_index = -1
			payload_index = 0
			continue
		else:
			if is_token_before_curs:
				positional_arg_index = j
				if new_token_index:
					positional_arg_index += 1
			if is_string:
				pos_arg = _route_unwrap(pos_arg, unwrap_setting)
			
			positional_args.append(pos_arg)
	
	if PRINT_DEBUG:
		print("UNCONSUMED AFTER::", ctx.unconsumed_tokens)
	return selected

func _route_unwrap(string:String, unwrap_setting:int) -> String:
	if unwrap_setting > 0 and string.length() > 1:
		var quote_char = string[0]
		if unwrap_setting == 2 or quote_char == '"':
			string = UString.unquote(string)
	return string

func _consume_self(ctx:CompletionContext) -> ExitCode:
	_consume_token(ctx)
	return ExitCode.OK

func _consume_token(ctx:CompletionContext):
	var tok = ctx.unconsumed_tokens.pop_front()
	consumed_tokens.append(tok)
	return tok

func execute(ctx:CompletionContext):
	var selected = _route(ctx)
	if PRINT_DEBUG:
		print("CommandBase execute - selected::", selected)
	if selected is ExitCode:
		return selected
	if selected:
		return selected.execute(ctx)
	# no child selected: this node requires one -> print usage
	if not _correct_positional_count():
		_get_help_for_token(consumed_tokens.front())
		return ExitCode.FAIL
	
	var result = _execute(ctx)
	if result != null and result is int:
		ctx.exit_code = result
	return result

func _execute(ctx:CompletionContext):
	var help = consumed_tokens.front()
	_get_help_for_token(help)
	return ExitCode.FAIL

func complete(ctx:CompletionContext):
	var selected = _route(ctx)
	if selected is ExitCode and selected == ExitCode.HELP:
		return {} # selected # completions recieve a dictionary, should not be an issue I think
	elif is_instance_valid(selected):
		return selected.complete(ctx)
	
	return _get_completions(ctx)

func _get_completions(ctx:CompletionContext):
	if not _positional_arg_index_valid():
		return {}
	
	var current_flag_completions = _get_flag_type_completions(ctx)
	if current_flag_completions != null:
		return current_flag_completions
	
	return _get_completion_std_w_context(ctx)

func _get_completion_std_w_context(ctx:CompletionContext, commands:=true, flags:=true) -> Dictionary:
	var command_data = get_self_command_data()
	var allow_pos_paths = command_data.get(&"allow_positional_paths", false)
	
	var options = Options.new()
	var _do_com:=false
	var _do_flag:=false
	var _do_path:=false
	if ctx.char_before_cursor == "" or ctx.char_before_cursor == " ":
		_do_flag = true
		_do_com = true
	elif ctx.token_before_cursor.begins_with("--"):
		_do_flag = true
	else:
		_do_com = true
		_do_flag = true
		for s in ["/", "../", "./"]:
			if ctx.token_before_cursor.begins_with(s):
				_do_path = true
				break
	
	if allow_pos_paths and _do_path:
		var for_path_completion = ""
		if positional_args.size() > 0:
			for_path_completion = positional_args[positional_arg_index]
		
		for_path_completion = ctx.token_before_cursor # temp test
		options.merge(_completion_rel_path(ctx, for_path_completion))
	else:
		if _do_com and commands:
			options.merge(get_commands(true))
		if _do_flag and flags:
			options.merge(get_flags(true))
	
	
	return options.get_options()

## checks if the first unconsumed or the last consumed begins with --
func _completion_last_is_flag(ctx:CompletionContext):
	if ctx.unconsumed_tokens.size() == 1 and ctx.unconsumed_tokens.front().begins_with("--"):
		return true
	if consumed_tokens.size() > 0 and consumed_tokens.back().begins_with("--"):
		return true
	return false

func get_flags(hide_consumed:=false) -> Dictionary:
	var options = _get_flags()
	if not hide_consumed:
		return options
	#for c in options.keys():
		#var split = _split_flag(c)
		#if split in consumed_tokens:
			#options.erase(c)
	for c in consumed_tokens:
		var split = _split_flag(c)
		if options.has(split):
			options.erase(split)
	return options


func _get_flags() -> Dictionary:
	return {}

func _split_flag(token:String):
	if not token.contains("="):
		return token
	return token.substr(0, token.find("=") + 1)

func _get_flag_value(token:String):
	if not token.contains("="):
		return ""
	var val = token.substr(token.find("=") + 1)
	val = UString.unquote(val)
	return val

#! keys i-Options.add_option;
func _get_option_data(token:String, flags:Dictionary, commands:Dictionary):
	if token == __get_name__():
		return __get_self_command_data__()
	var data = flags.get(token)
	if data == null:
		data = commands.get(token)
	return data

func _process_flag(flag:String):
	return

func get_commands(hide_consumed:=false) -> Dictionary:
	var options = _get_commands()
	if not hide_consumed:
		return options
	for c in options.keys():
		if c in consumed_tokens:
			options.erase(c)
	return options

func _get_commands() -> Dictionary:
	return _get_commands_in_dir()

func _get_commands_in_dir(sort_priority:=true):
	var path = get_script().resource_path
	var base_dir = path.get_base_dir()
	var dirs = DirAccess.get_directories_at(base_dir)
	var options = {}
	for d in dirs:
		var file_path = base_dir.path_join(d).path_join(d) + ".gd"
		if not FileAccess.file_exists(file_path):
			continue
		if file_path == path:
			continue
		var script = load(file_path)
		Options.add_command_script_to_dict(script, options)
	
	if sort_priority:
		options = USort.sort_dict_with_priority_key(options, &"priority")
	return options



func _get_command(command:String):
	_ctx_obj.append_error("Unrecognized command - get command: " + command)
	return

func _get_help_for_token(token:String):
	var split = _split_flag(token)
	var option_data = _get_option_data(split, get_flags(), get_commands())
	if option_data != null and option_data.has(&"help"):
		_ctx_obj.append_output(get_help_string(true))
	else:
		_get_help(token)


func _get_help(what:String):
	_ctx_obj.append_error("Unrecognized command - help base: " + what)

func _correct_positional_count(target_size:int=-1):
	if target_size == -1:
		target_size = _get_target_positional_count()
	if positional_args.size() != target_size:
		_ctx_obj.append_error("Err: " + get_command_name())
		_ctx_obj.append_error("Positional argument count incorrect: Expected %s, got %s" % [target_size, positional_args.size()])
		_ctx_obj.append_error("Arguments: " + str(positional_args))
		_ctx_obj.exit_code = ExitCode.FAIL
		return false
	return true

func _get_target_positional_count() -> int:
	var count = get_self_command_data().get(&"positional_count", 0)
	if count is int:
		return count
	if count is String:
		_initialize_regex()
		var reg_match = _positional_arg_count_regex.search(count)
		if is_instance_valid(reg_match):
			var min_count = reg_match.get_string("min")
			var max_count = reg_match.get_string("max")
			if min_count == "":
				min_count = 0
			else:
				min_count = min_count.to_int()
			if max_count == "":
				max_count = positional_args.size()
			else:
				max_count = max_count.to_int()
			var arg_size = positional_args.size()
			if arg_size >= min_count and arg_size <= max_count:
				return arg_size
			elif arg_size < min_count:
				return min_count
			elif arg_size > max_count:
				return max_count
			
		
		
	return 0

## 0=No unwrap, 1=doubles, 2=both
func _unwrap_quotes():
	return 2

static func _call_method(ctx:CompletionContext, callable:Callable, args:Array, create_default_args:=false):
	# convert variables to $VAR
	var editor_console = EditorConsoleSingleton.get_instance()
	for i in range(args.size()):
		var arg_str = args[i]
		args[i] = editor_console.working_variable_dict.get(arg_str, arg_str)
	# end
	
	var callable_arg_count = callable.get_argument_count()
	if args.size() != callable_arg_count:
		if not create_default_args:
			ctx.append_error("Arg count mismatch: %s - expected %s, got %s" % [callable.get_method(), callable_arg_count, args.size()])
			return
		
	var obj = callable.get_object()
	var script = obj
	if not obj is GDScript:
		script = obj.get_script()
	
	var method_name = callable.get_method()
	var property_info = UtilsRemote.UClassDetail.get_member_info_by_path(script, method_name)
	if not (property_info is Dictionary and property_info.has("args")):
		ctx.append_error("Could not get method '%s' info in object: %s" % [method_name, obj])
		return
	var valid_args = true
	var callable_args = property_info.get("args")
	if create_default_args or args.size() == callable_arg_count:
		var default_args = property_info.get("default_args", []) as Array
		for i in range(callable_args.size() - default_args.size()):
			default_args.push_front(null)
		var new_args = []
		for i in range(callable_args.size()):
			var arg_data = callable_args[i]
			var type:int = arg_data.get("type")
			if i < args.size():
				var passed = args[i]
				if type > 0 and typeof(passed) != type:
					var err:= true
					var pass_str = type_string(typeof(passed))
					if type != TYPE_OBJECT:
						var converted = ConsoleTokenizer.Var.auto_convert(passed, type)
						if converted != null:
							args[i] = converted
							ctx.append_output("Arg '%s' conversion: %s %s -> %s %s" % [arg_data.get("name"), pass_str, passed, type_string(type), converted])
							err = false
					if err:
						ctx.append_error("Arg '%s' type mismatch: %s passed, should be %s" % [arg_data.get("name"), pass_str, type_string(type)])
						valid_args = false
				continue
			
			var default_val = default_args[i]
			if default_val != null:
				new_args.append(default_val)
				continue
			if arg_data.get("class_name") != "":
				var _class = arg_data.get("class_name")
				if _class == "GDScript" or _class == "Script":
					new_args.append(EditorInterface.get_script_editor().get_current_script())
				continue
			else:
				var variant = type_convert(null, type)
				new_args.append(variant)
		
		if args.size() + new_args.size() != callable_arg_count:
			var err_pr = Pr.new()
			err_pr.append("Could not create default args for method ", Colors.ERROR_RED).append("'%s'" % method_name)\
			.append(" in object: ", Colors.ERROR_RED).append(obj)
			ctx.append_error(err_pr.get_raw_string())
			ctx.append_output(err_pr.get_string(true))
			
			err_pr.append("Passed: ").append("%s" % [args], Colors.ACCENT_MUTE).append(" Created:").append("%s" % [new_args], Colors.ACCENT_MUTE)
			ctx.append_error(err_pr.get_raw_string())
			ctx.append_output(err_pr.get_string(true))
			
			
			Pr.new().append("Could not create default args for method ", Colors.ERROR_RED).append("'%s'" % method_name)\
			.append(" in object: ", Colors.ERROR_RED).append(obj).display()
			Pr.new().append("Passed: ").append("%s" % [args], Colors.ACCENT_MUTE).append(" Created:").append("%s" % [new_args], Colors.ACCENT_MUTE).display()
			return
		
		args.append_array(new_args)
	
	if not valid_args:
		ctx.append_error("Invalid arguments")
		return
	var result = callable.callv(args)
	if result != null:
		if result is Object:
			if result.get_class() in _RESULTS_TO_SKIP:
				return
		ctx.append_output("GDScript Method Call:")
		ctx.append_output(str(result))


# utils

func _positional_arg_index_valid():
	var target_pos_count = _get_target_positional_count()
	if target_pos_count == 0 and positional_arg_index < 1:
		return true  # if 0, allow 1, this will let completion of 1 unconsumed token through
	return target_pos_count > positional_arg_index

func _add_variables_to_completions(dict:Dictionary):
	Options.add_show_variables_to_dict(dict)

func _get_flag_type_completions(ctx:CompletionContext):
	if not (ctx.token_before_cursor.contains("=") and ctx.char_before_cursor != " "):
		return null
	
	var all_options = get_flags(false)
	var flag_name = _split_flag(ctx.token_before_cursor)
	var flag_data = all_options.get(flag_name)
	if flag_data == null or not flag_data.has(&"flag_completion"):
		return null
	var flag_type_data = flag_data.get(&"flag_completion", {"type": FlagType.NONE})
	var flag_type:FlagType = flag_type_data.get("type", FlagType.NONE)
	if flag_type == FlagType.NONE:
		return []
	var target_dir = flag_type_data.get("dir", "res://")
	var completions = []
	if flag_type == FlagType.FILE:
		
		var extensions = flag_type_data.get("ext", [])
		var files = EditorConsoleSingleton.get_file_paths()
		if extensions.is_empty() and target_dir == "res://":
			completions = files
		else:
			for f in files:
				if f.get_extension() in extensions and f.begins_with(target_dir):
					completions.append(f)
		
		
	elif flag_type == FlagType.DIR:
		var dirs = EditorConsoleSingleton.get_dir_paths()
		if target_dir == "res://":
			completions = dirs
		else:
			for d in dirs:
				if d.begins(target_dir):
					completions.append(d)
	
	elif flag_type == FlagType.CLASS:
		var classes = ClassDB.get_class_list()
		completions.append_array(classes)
		var user_classes = UtilsRemote.UClassDetail.get_all_global_class_paths().keys()
		completions.append_array(user_classes)
	
	
	var flag_options = Options.new()
	for c in completions:
		flag_options.add_option(c, {
			
		})
	return flag_options.get_options()


static func _completion_rel_path(ctx:CompletionContext, current_rel_path:String):
	var target_dir = ctx.cwd
	var options = Options.new()
	if current_rel_path != "":
		target_dir = _complete_path(current_rel_path, ctx.cwd)
		if target_dir.ends_with("/"):
			pass
		elif target_dir.contains("/"):
			target_dir = target_dir.get_base_dir()
		
		if not DirAccess.dir_exists_absolute(target_dir):
			return {}
	
	var dirs = DirAccess.get_directories_at(target_dir)
	dirs = Array(dirs)
	dirs.push_front("..")
	for dir in dirs:
		options.add_option(dir, {
			&"trailing_char": "/"
		})
	
	return options.get_options()


func print_available_commands():
	var commands = get_commands()
	commands.erase(Options.Keys.COMMAND_META)
	if commands.size() > 0:
		_ctx_obj.append_output("Available commands:")
		for c in commands:
			_ctx_obj.append_output("\t" + c)

func complete_path(to_check:String):
	return _complete_path(to_check, _ctx_obj.cwd)

## Relative paths will be completed via base_dir, absolute are returned unchanged
static func _complete_path(to_check:String, base_dir:String):
	if to_check.is_absolute_path():
		return to_check
	var simp = base_dir.path_join(to_check).simplify_path()
	simp += "/" if to_check.ends_with("/") else "" # simplify path strips the trailing slash
	return simp
	

func _get_config(type:int=0):
	if type == 0:
		return UtilsLocal.Config.get_merged_config()
	elif type == 1:
		return UtilsLocal.Config.get_global_config()
	elif type == 2:
		return UtilsLocal.Config.get_project_config()
	else:
		_ctx_obj.append_error("Unrecognized config type: %s; 0=Merged, 1=Global, 2=Project\nReturning merged data.")
		return UtilsLocal.Config.get_merged_config()

static func _initialize_regex():
	if not is_instance_valid(_positional_arg_count_regex):
		_positional_arg_count_regex = RegEx.new()
		_positional_arg_count_regex.compile(r"(?=min:|max:)(?:min:\s*(?<min>[0-9]+))?(?:\s*,?\s*)?(?:max:\s*(?<max>[0-9]+))?")
